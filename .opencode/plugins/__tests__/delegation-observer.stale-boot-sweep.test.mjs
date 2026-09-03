/**
 * DIA-260822-fksf RED tests: stale stall-sweep startup protection.
 *
 * Encodes the 5 acceptance criteria for sweepStalledSessions boot-time
 * cascade suppression. The current implementation (sweepStalledSessions
 * L2553-L2616) has NO boot-time cutoff, NO processStartedAt comparison,
 * NO firstSweep flag, NO staleAtBoot watchlist (grep 0 hits). After a
 * crash/restart the registry can hold hundreds of stale nonterminal keys;
 * the FIRST sweep emits a stall_detected row for EACH at once.
 *
 * The test MUST FAIL against the current unmodified plugin (RED state
 * proving the cascade exists). The GREEN implementation may use any
 * mechanism (boot-time cutoff, watchlist, first-sweep skip) as long as
 * behavior matches.
 *
 * DIA-079: ASCII-only.
 *
 * RUN (bun in poetry-dev container, no docker compose exec needed):
 *   cd /workspace/.opencode/plugins/__tests__ && \
 *     bun test delegation-observer.stale-boot-sweep.test.mjs
 */

import { mock, test, expect, describe } from "bun:test"
import {
  appendFileSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
} from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

// ---- @opencode-ai/plugin mock (registered BEFORE the plugin import) ----
const desc = { describe: () => desc }
const withOptional = { optional: () => desc }
const schema = { enum: () => withOptional, string: () => withOptional }
const toolFn = (def) => def
toolFn.schema = schema
mock.module("@opencode-ai/plugin", () => ({ tool: toolFn }))

const { default: createDelegationObserver } = await import(
  "../delegation-observer.ts"
)

// ---------------------------------------------------------------------------
// Harness plumbing
// ---------------------------------------------------------------------------

const tempDirs = []
process.on("exit", () => {
  for (const dir of tempDirs) {
    try { rmSync(dir, { recursive: true, force: true }) } catch { void 0; /* best-effort */ }
  }
})

// Well-known symbols the plugin uses
const BOOT_EMITTED_KEY = Symbol.for("delegation-observer.bootEmitted")
const STALL_SWEEP_KEY = Symbol.for("delegation-observer.stallSweepInterval")

function freshCtx() {
  const directory = mkdtempSync(join(tmpdir(), "dia260822-fksf-"))
  tempDirs.push(directory)
  mkdirSync(join(directory, ".opencode", "session"), { recursive: true })
  return {
    directory,
    client: { app: { log: async () => {} } },
  }
}

function registryPath(directory) {
  return join(directory, ".opencode/session/registry.jsonl")
}

function readRegistryRows(directory) {
  const p = registryPath(directory)
  if (!existsSync(p)) return []
  return readFileSync(p, "utf-8")
    .trim().split("\n").filter(Boolean).map((l) => {
      try { return JSON.parse(l) } catch { return null }
    }).filter(Boolean)
}

function countStallDetected(directory) {
  return readRegistryRows(directory).filter((r) => r.event === "stall_detected").length
}

function countDeadDetected(directory) {
  return readRegistryRows(directory).filter((r) => r.event === "stall_detected" && r.escalation === "dead").length
}

function appendRawRow(directory, row) {
  appendFileSync(registryPath(directory), JSON.stringify(row) + "\n")
}

// Seed a nonterminal delegation key with controlled timestamp.
// Role signal: role:"subagent" + dispatch_state running -> subagent threshold 10min.
function seedNonTerminalKey(directory, key, timestampIso, opts = {}) {
  const row = {
    timestamp: timestampIso,
    event: "task_success",
    session_id: key,
    dispatch_state: opts.dispatch_state ?? "running",
    status: "RUNNING",
    role: opts.role ?? "subagent",
    seq: opts.seq ?? Math.floor(Math.random() * 1000000),
    writer: "plugin",
  }
  if (opts.extra) Object.assign(row, opts.extra)
  appendRawRow(directory, row)
}

// Capture the setInterval callback the plugin registers for the 60s sweep.
// Must be installed BEFORE createDelegationObserver call.
function captureSweepInstall() {
  let captured = null
  const orig = globalThis.setInterval
  // Wrap: record the callback for the stall sweep (60_000 ms interval).
  // Other intervals (if any) also captured but the stall sweep is the 60s one.
  globalThis.setInterval = function(fn, ms, ...args) {
    if (ms === 60_000) captured = fn
    // Always delegate to original so timers actually work (and can be cleared).
    return orig.call(this, fn, ms, ...args)
  }
  return {
    get: () => captured,
    restore: () => { globalThis.setInterval = orig },
  }
}

// Mock Date.now to a fixed fake time. Restores on restore().
// new Date() without args delegates to Date.now in V8/Bun, so mocking Date.now
// is sufficient for processStartedAt capture and sweep now.
function mockDateNow(fakeNowMs) {
  const orig = Date.now
  Date.now = () => fakeNowMs
  // Also mock Date constructor for ISO string: new Date().toISOString() will
  // use the mocked Date.now via the internal slot. Verify by patching Date.
  const OrigDate = globalThis.Date
  const MockDate = class extends OrigDate {
    constructor(...args) {
      if (args.length === 0) super(fakeNowMs)
      else super(...args)
    }
    static now() { return fakeNowMs }
  }
  // Copy static members
  Object.setPrototypeOf(MockDate, OrigDate)
  // Keep original Date for parsing but ensure no-arg construction is mocked.
  // Instead of replacing global Date (risky), we only replace Date.now and
  // also ensure new Date().toISOString() uses mocked time by checking that
  // `new Date()` without args in the plugin will go through our MockDate.
  // Safer: replace global Date with MockDate.
  globalThis.Date = MockDate
  return {
    restore: () => {
      Date.now = orig
      globalThis.Date = OrigDate
    },
    advance: (deltaMs) => {
      fakeNowMs += deltaMs
      Date.now = () => fakeNowMs
    },
    set: (newMs) => {
      fakeNowMs = newMs
      Date.now = () => fakeNowMs
    },
    get: () => fakeNowMs,
  }
}

// Helper: create a handles bundle per test (ctx + hooks + captured sweep + date mock)
async function makeHarnessWithSweep(bootTimeMs) {
  const dateMock = mockDateNow(bootTimeMs)
  const sweepCapture = captureSweepInstall()
  const ctx = freshCtx()
  // Isolate boot flag: clear so each test gets a fresh boot emission.
  const prevBootFlag = globalThis[BOOT_EMITTED_KEY]
  globalThis[BOOT_EMITTED_KEY] = false
  const hooks = await createDelegationObserver(ctx)
  const sweepFn = sweepCapture.get()
  return {
    ctx,
    hooks,
    sweepFn,
    dateMock,
    sweepCapture,
    prevBootFlag,
    async cleanup() {
      try { await hooks.dispose() } catch { void 0; }
      const h = globalThis[STALL_SWEEP_KEY]
      if (h !== undefined) { try { clearInterval(h) } catch { void 0; } }
      globalThis[STALL_SWEEP_KEY] = undefined
      sweepCapture.restore()
      dateMock.restore()
      // Restore boot flag to previous to not pollute next test's isolation
      globalThis[BOOT_EMITTED_KEY] = prevBootFlag
    },
  }
}

// ---------------------------------------------------------------------------
// Tests - encode the 5 acceptance criteria as BEHAVIOR tests
// ---------------------------------------------------------------------------

describe("DIA-260822-fksf stale stall-sweep startup protection (RED)", () => {
  test("AC1: N=390 stale nonterminal keys - first sweep emits ZERO stall_detected", async () => {
    const bootTime = Date.now()
    const staleTs = new Date(bootTime - 24 * 60 * 60 * 1000).toISOString() // 24h before boot - unambiguously stale
    // Seed BEFORE boot so snapshot mechanism also sees them
    const directory = mkdtempSync(join(tmpdir(), "dia260822-fksf-ac1-"))
    tempDirs.push(directory)
    mkdirSync(join(directory, ".opencode", "session"), { recursive: true })
    for (let i = 0; i < 390; i++) {
      seedNonTerminalKey(directory, `ses_stale_${i}`, staleTs)
    }
    // Now boot plugin with mocked time
    const sweepCapture = captureSweepInstall()
    const dateMock = mockDateNow(bootTime)
    const prevBootFlag = globalThis[BOOT_EMITTED_KEY]
    globalThis[BOOT_EMITTED_KEY] = false
    const ctx = { directory, client: { app: { log: async () => {} } } }
    const hooks = await createDelegationObserver(ctx)
    const sweepFn = sweepCapture.get()
    expect(sweepFn).not.toBeNull()

    try {
      // Advance to 15 minutes after boot so stale age = 24h+15m > threshold
      dateMock.set(bootTime + 15 * 60 * 1000)
      const before = countStallDetected(directory)
      sweepFn()
      const after = countStallDetected(directory)
      const emitted = after - before
      // REQUIRED BEHAVIOR: first sweep suppresses already-stale keys -> 0
      // CURRENT BUGGY BEHAVIOR: emits 390 (cascade)
      expect(emitted).toBe(0)
    } finally {
      try { await hooks.dispose() } catch { void 0; }
      const h = globalThis[STALL_SWEEP_KEY]
      if (h !== undefined) { try { clearInterval(h) } catch { void 0; } }
      globalThis[STALL_SWEEP_KEY] = undefined
      sweepCapture.restore()
      dateMock.restore()
      globalThis[BOOT_EMITTED_KEY] = prevBootFlag
    }
  })

  test("AC2: fresh key (timestamp after load) emits once its role threshold is crossed", async () => {
    const bootTime = Date.now()
    const h = await makeHarnessWithSweep(bootTime)
    try {
      expect(h.sweepFn).not.toBeNull()
      // Fresh key: timestamp 1s after boot, so not stale
      const freshTs = new Date(bootTime + 1000).toISOString()
      // Advance to 15m after boot so fresh age ~15m > 10m subagent threshold
      h.dateMock.set(bootTime + 15 * 60 * 1000)
      seedNonTerminalKey(h.ctx.directory, "ses_fresh_ac2", freshTs)
      const before = countStallDetected(h.ctx.directory)
      h.sweepFn()
      const after = countStallDetected(h.ctx.directory)
      const emitted = after - before
      // Fresh current stall MUST fire (detection preserved)
      expect(emitted).toBe(1)
    } finally {
      await h.cleanup()
    }
  })

  test("AC3: key that becomes nonterminal DURING current lifetime is detected on subsequent sweep", async () => {
    const bootTime = Date.now()
    const h = await makeHarnessWithSweep(bootTime)
    try {
      expect(h.sweepFn).not.toBeNull()
      // First sweep with no keys - establishes first-sweep guard has run
      h.dateMock.set(bootTime + 60 * 1000) // 1m after boot
      const beforeFirst = countStallDetected(h.ctx.directory)
      h.sweepFn()
      expect(countStallDetected(h.ctx.directory) - beforeFirst).toBe(0)

      // Now a new key becomes nonterminal during current lifetime
      // Its timestamp is after the first sweep, i.e. during current lifetime
      const duringTs = new Date(bootTime + 2 * 60 * 1000).toISOString() // 2m after boot
      // Advance to 15m after boot so age = 13m >10m threshold
      h.dateMock.set(bootTime + 15 * 60 * 1000)
      seedNonTerminalKey(h.ctx.directory, "ses_during_ac3", duringTs)
      const beforeSecond = countStallDetected(h.ctx.directory)
      h.sweepFn()
      const afterSecond = countStallDetected(h.ctx.directory)
      const emitted = afterSecond - beforeSecond
      // Must NOT be suppressed by boot guard - detected on subsequent sweep
      expect(emitted).toBe(1)
    } finally {
      await h.cleanup()
    }
  })

  test("AC4: dead-escalation path unaffected for current-lifetime key crossing 60-min deadline", async () => {
    const bootTime = Date.now()
    const h = await makeHarnessWithSweep(bootTime)
    try {
      expect(h.sweepFn).not.toBeNull()
      // Current-lifetime key: timestamp 1s after boot
      const freshTs = new Date(bootTime + 1000).toISOString()
      seedNonTerminalKey(h.ctx.directory, "ses_dead_ac4", freshTs)
      // Advance to 61m after boot so age ~61m >=60m dead threshold
      h.dateMock.set(bootTime + 61 * 60 * 1000)
      const before = countDeadDetected(h.ctx.directory)
      h.sweepFn()
      const after = countDeadDetected(h.ctx.directory)
      const emittedDead = after - before
      // Dead escalation MUST still fire for genuinely current-lifetime keys
      expect(emittedDead).toBe(1)
      // Also verify at least one stall_detected total was emitted (dead tier)
      const stalls = countStallDetected(h.ctx.directory)
      expect(stalls).toBeGreaterThanOrEqual(1)
    } finally {
      await h.cleanup()
    }
  })

  test("AC5 regression: 390 stale + 1 fresh -> exactly 1 stall_detected", async () => {
    const bootTime = Date.now()
    const staleTs = new Date(bootTime - 24 * 60 * 60 * 1000).toISOString()
    const freshTs = new Date(bootTime + 1000).toISOString()
    // Seed 390 stale BEFORE boot (snapshot path) + 1 fresh
    const directory = mkdtempSync(join(tmpdir(), "dia260822-fksf-ac5-"))
    tempDirs.push(directory)
    mkdirSync(join(directory, ".opencode", "session"), { recursive: true })
    for (let i = 0; i < 390; i++) {
      seedNonTerminalKey(directory, `ses_stale_${i}`, staleTs)
    }
    // Fresh will be seeded after boot time manipulation so timestamp after load
    const sweepCapture = captureSweepInstall()
    const dateMock = mockDateNow(bootTime)
    const prevBootFlag = globalThis[BOOT_EMITTED_KEY]
    globalThis[BOOT_EMITTED_KEY] = false
    const ctx = { directory, client: { app: { log: async () => {} } } }
    const hooks = await createDelegationObserver(ctx)
    const sweepFn = sweepCapture.get()
    expect(sweepFn).not.toBeNull()

    try {
      // Advance to 15m after boot, seed fresh then sweep
      dateMock.set(bootTime + 15 * 60 * 1000)
      seedNonTerminalKey(directory, "ses_fresh_ac5", freshTs)
      const before = countStallDetected(directory)
      sweepFn()
      const after = countStallDetected(directory)
      const emitted = after - before
      // REQUIRED: exactly 1 (the fresh one), not 391
      // CURRENT BUGGY: 391 (390 stale + 1 fresh cascaded)
      expect(emitted).toBe(1)
    } finally {
      try { await hooks.dispose() } catch { void 0; }
      const h = globalThis[STALL_SWEEP_KEY]
      if (h !== undefined) { try { clearInterval(h) } catch { void 0; } }
      globalThis[STALL_SWEEP_KEY] = undefined
      sweepCapture.restore()
      dateMock.restore()
      globalThis[BOOT_EMITTED_KEY] = prevBootFlag
    }
  })
})
