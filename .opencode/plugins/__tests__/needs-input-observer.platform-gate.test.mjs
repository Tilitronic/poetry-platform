/**
 * DIA-260821-3blw RED test harness (test-author lane, DIA-175 instance
 * separation; fresh instance after two truncated attempts on DIA-099
 * sessions - prior lane's recon design brief followed verbatim).
 *
 * Defect under test (.opencode/plugins/needs-input-observer.ts,
 * fireDesktopToast ~line 684):
 *   The desktop-toast channel spawns "powershell.exe" UNCONDITIONALLY on
 *   every platform. On pure-linux hosts (this dev container) there is no
 *   WSL interop, so every ENTER transition fires a spawn that can only fail
 *   with ENOENT - a warn per notification, forever, with no platform gate
 *   and no disable latch.
 *
 * Planned fix under test (registered learning
 * .opencode/learnings/external-patterns/2026-08-26-needs-input-observer-
 * platform-detection.md):
 *   1. isWSL(): linux && (existsSync("/mnt/wslg") ||
 *      process.env.WSL_DISTRO_NAME || /proc/version matches /microsoft/i)
 *   2. canUsePowershellToast(): win32 || isWSL()
 *   3. Platform gate early-return at top of fireDesktopToast()
 *   4. Warn-once latch desktopToastDisabled on first ENOENT /
 *      "Executable not found": warn once "[needs-input-observer] desktop
 *      toast disabled (powershell.exe not found)", then silent.
 *      Non-ENOENT spawn errors keep warning every time (no latch).
 *
 * Expected split TODAY (RED phase): P1 + P3 FAIL for the right reasons
 * (unconditional spawn; no latch / wrong warn message). P2/P4/P5 are guard
 * tests that PASS today and must KEEP passing post-fix (same convention as
 * the dia189 suite: guards stay green across the fix).
 *
 * Hermetic mechanics (proven patterns lifted from dia189/dia220 suites):
 *   - mock.module("node:child_process") BEFORE the dynamic plugin import;
 *     the spy records every spawn and returns a stub whose .on() REGISTERS
 *     listeners so a test can emit "error" synchronously (simulating ENOENT
 *     / EACCES without any real subprocess).
 *   - mock.module("node:fs") delegates to the REAL fs except existsSync,
 *     which additionally reports paths added to a virtual marker set - this
 *     is how cases P2/P3/P5 fabricate "/mnt/wslg" without touching the real
 *     filesystem. Real fs still serves ticker.json writes (mkdtemp dir).
 *   - Virtual clock: Date.now advances 3000ms per call, beating both the
 *     2000ms NOTIFY_DEBOUNCE_MS and the 2000ms DESKTOP_TOAST_DEBOUNCE_MS so
 *     consecutive notifies fire without real sleeps.
 *   - Drive path: hooks.event({type:"question.asked"}) -> enter() ->
 *     notify() -> fireDesktopToast(), exactly as the dia189 suite does
 *     (fireDesktopToast is closure-private - it is unreachable directly).
 *
 * RUN COMMAND (bun skips dot-directories in default discovery, so run FROM
 * inside __tests__; bun 1.3.14 present on this host):
 *
 *   cd .opencode/plugins/__tests__ && bun test needs-input-observer.platform-gate.test.mjs
 */
import { mock, test, expect, beforeEach, afterEach } from "bun:test"
import { mkdtempSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

// ---- powershell.exe spawn interception ----
// Registered BEFORE the plugin import (dynamic import below defeats ESM
// hoisting). Each captured call carries emitError(err) so tests drive the
// child.on("error") path synchronously - the ENOENT/EACCES simulation.
const spawnCalls = []
mock.module("node:child_process", () => ({
  spawn: (cmd, args, opts) => {
    const listeners = {}
    const call = {
      cmd,
      args,
      opts,
      emitError: (err) => {
        for (const cb of listeners.error ?? []) cb(err)
      },
    }
    spawnCalls.push(call)
    return {
      on: (ev, cb) => {
        ;(listeners[ev] ??= []).push(cb)
      },
    }
  },
  // ponytail: stub to prevent cross-file mock leakage from breaking
  // delegation-observer.ts (which imports spawnSync) - same mitigation as
  // the dia189 suite; bun 1.3.14 mock.module leak, upgrade trigger: bun
  // test isolates mock.module per file.
  spawnSync: () => {
    throw new Error("spawnSync not mocked in platform-gate test")
  },
}))

// ---- node:fs mock: real fs + virtual WSL markers ----
// Capture the REAL existsSync value before registering the mock so the
// override can never self-reference through the swapped registry.
const realFsModule = await import("node:fs")
const realExistsSync = realFsModule.existsSync
const wslMarkers = new Set()
mock.module("node:fs", () => ({
  ...realFsModule,
  existsSync(p) {
    if (typeof p === "string" && wslMarkers.has(p)) return true
    return realExistsSync(p)
  },
}))

// Import AFTER mock.module registration.
const { default: createNeedsInputObserver } = await import(
  "../needs-input-observer.ts"
)

const SESSION_ID = "ses_platform_gate_0001"

function freshCtx() {
  // Same client shape the dia189 harness uses (proven sufficient for the
  // question.asked -> enter -> notify path plus the boot retro pass).
  const directory = mkdtempSync(join(tmpdir(), "dia3blw-"))
  const ctx = {
    directory,
    client: {
      session: {
        get: async () => ({
          data: { title: "New session - 2026-08-21T10:30:00.000Z" },
          error: undefined,
        }),
        update: async () => ({}),
        list: async () => [],
      },
      pty: {
        list: async () => [],
        update: async () => ({}),
      },
      tui: {
        showToast: async () => ({}),
      },
      app: { log: async () => {} },
      postSessionIdPermissionsPermissionId: async () => ({}),
    },
  }
  return ctx
}

async function makeHarness() {
  const ctx = freshCtx()
  const hooks = await createNeedsInputObserver(ctx)
  return { hooks, ctx }
}

function questionAskedEvent(sessionID = SESSION_ID) {
  return {
    event: {
      type: "question.asked",
      properties: {
        sessionID,
        questions: [{ question: "Need your input?" }],
      },
    },
  }
}

function enoentError() {
  return Object.assign(new Error("spawn powershell.exe ENOENT"), {
    code: "ENOENT",
    errno: -2,
    syscall: "spawn powershell.exe",
    path: "powershell.exe",
  })
}

function eaccesError() {
  return Object.assign(new Error("spawn powershell.exe EACCES"), {
    code: "EACCES",
    errno: -13,
    syscall: "spawn powershell.exe",
    path: "powershell.exe",
  })
}

async function withPlatform(platform, fn) {
  const desc = Object.getOwnPropertyDescriptor(process, "platform")
  Object.defineProperty(process, "platform", {
    value: platform,
    configurable: true,
  })
  try {
    await fn()
  } finally {
    Object.defineProperty(process, "platform", desc)
  }
}

const powershellSpawns = () => spawnCalls.filter((c) => c.cmd === "powershell.exe")
const disabledWarns = () =>
  warns.filter((w) => w.includes("desktop toast disabled"))

// ---- per-test isolation: virtual clock + warn capture ----
// Date.now advancing 3000ms/call beats both 2000ms debounces (notify +
// desktop toast) without real sleeps. console.warn is captured so the
// latch assertions can count "desktop toast disabled" warnings exactly.
const warns = []
let virtualNow = 0
const realDateNow = Date.now.bind(Date)
const realWarn = console.warn

beforeEach(() => {
  spawnCalls.length = 0
  wslMarkers.clear()
  warns.length = 0
  virtualNow = 1756000000000
  Date.now = () => (virtualNow += 3000)
  console.warn = (...a) => warns.push(a.map(String).join(" "))
  // DIA-260821-5r03: clear the plugin's process-scoped globalThis guards so
  // each test's factory instance starts from a clean process state (the plugin
  // now keeps toast-dedupe / boot / ticker flags on globalThis).
  globalThis[Symbol.for("needs-input-observer.permissionTimers")] = undefined
  globalThis[Symbol.for("needs-input-observer.titleSuffixBootDone")] = undefined
  globalThis[Symbol.for("needs-input-observer.notifiedAsks")] = undefined
  globalThis[Symbol.for("needs-input-observer.tickerBootSeeded")] = undefined
})

afterEach(() => {
  Date.now = realDateNow
  console.warn = realWarn
})

// ---------------------------------------------------------------------------
// P1 RED: platform gate - pure linux, no WSL markers -> never spawn
// ---------------------------------------------------------------------------

test("P1 RED: pure linux without WSL markers never spawns powershell.exe", async () => {
  const { hooks } = await makeHarness()
  await hooks.event(questionAskedEvent())
  // Post-fix: canUsePowershellToast() is false here (linux, no /mnt/wslg,
  // no WSL_DISTRO_NAME, no microsoft /proc/version) -> gate early-returns.
  // Today: unconditional spawn happens -> RED.
  expect(powershellSpawns()).toHaveLength(0)
})

// ---------------------------------------------------------------------------
// P2 guard: WSL via /mnt/wslg marker -> spawn happens (green today AND
// post-fix; the marker opens the planned gate)
// ---------------------------------------------------------------------------

test("P2 guard: WSL (/mnt/wslg present) spawns powershell.exe", async () => {
  wslMarkers.add("/mnt/wslg")
  const { hooks } = await makeHarness()
  await hooks.event(questionAskedEvent())
  const calls = powershellSpawns()
  expect(calls).toHaveLength(1)
  expect(calls[0].args[0]).toBe("-NoProfile")
  expect(calls[0].args[1]).toBe("-Command")
})

// ---------------------------------------------------------------------------
// P3 RED: ENOENT latch - warn once, then never spawn again
// ---------------------------------------------------------------------------

test("P3 RED: ENOENT latches desktop toast - warns once, second ask does not spawn again", async () => {
  // WSL marker set so the PLANNED platform gate opens post-fix and the
  // LATCH (not the gate) is what this case exercises.
  wslMarkers.add("/mnt/wslg")
  const { hooks } = await makeHarness()

  // First ask: spawn fires, ENOENT comes back, latch engages with ONE warn.
  await hooks.event(questionAskedEvent("ses_aaaa1111"))
  expect(spawnCalls).toHaveLength(1)
  spawnCalls[0].emitError(enoentError())
  expect(disabledWarns()).toHaveLength(1)

  // Second ask (fresh session id defeats enter() dedupe; virtual clock
  // defeated both debounces): latch must suppress the spawn entirely.
  await hooks.event(questionAskedEvent("ses_bbbb2222"))
  expect(spawnCalls).toHaveLength(1) // unchanged - no respawn after latch
  expect(disabledWarns()).toHaveLength(1) // still exactly one warn
})

// ---------------------------------------------------------------------------
// P4 guard: win32 platform -> spawn happens (green today AND post-fix)
// ---------------------------------------------------------------------------

test("P4 guard: win32 platform spawns powershell.exe", async () => {
  await withPlatform("win32", async () => {
    const { hooks } = await makeHarness()
    await hooks.event(questionAskedEvent())
  })
  expect(powershellSpawns()).toHaveLength(1)
})

// ---------------------------------------------------------------------------
// P5 guard: non-ENOENT spawn errors keep warning every time (no latch)
// ---------------------------------------------------------------------------

test("P5 guard: non-ENOENT spawn errors still warn every time (no latch)", async () => {
  // WSL marker set so the planned gate opens post-fix; the point here is
  // that EACCES must NOT engage the ENOENT-only latch.
  wslMarkers.add("/mnt/wslg")
  const { hooks } = await makeHarness()

  await hooks.event(questionAskedEvent("ses_cccc3333"))
  expect(spawnCalls).toHaveLength(1)
  spawnCalls[0].emitError(eaccesError())

  await hooks.event(questionAskedEvent("ses_dddd4444"))
  expect(spawnCalls).toHaveLength(2) // no latch for non-ENOENT

  spawnCalls[1].emitError(eaccesError())
  const failureWarns = warns.filter(
    (w) => w.includes("toast spawn failed") || w.includes("toast failed")
  )
  expect(failureWarns.length).toBeGreaterThanOrEqual(2)
})
