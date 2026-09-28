/**
 * TDD RED suite: unattended permission fast-resolve + O-D envelope guard
 * (campaign ticket DIA-260928-nm2u, permission-stall-hardening).
 *
 * Design authority: .sdd/permission-stall-hardening/architecture.md
 * (SEAMS_AND_TESTS RED-1..RED-7, MECHANISM). Written BEFORE any
 * implementation exists - every test except the interactive pin RED-4 MUST
 * FAIL against today's plugin. That is the deliverable.
 *
 * No static import of the not-yet-existing lib module
 * (permission-fast-resolve.ts): everything is driven through the plugin's
 * own hook surface (hooks.event / hooks["tool.execute.after"]) so this file
 * always loads and each failure lands on its assertions, not on module
 * resolution.
 *
 * Hermetic pattern (mirrors needs-input-observer.per-permission-rows.test.mjs):
 * REAL plugin factory + temp workspace + fake SDK client capturing
 * postSessionIdPermissionsPermissionId calls; registry rows judged out of the
 * real registry.jsonl; real setTimeout handles cleaned by dispose.
 *
 * DIA-079: ASCII-only.
 *
 * RUN (bun in poetry-dev container):
 *   cd .opencode/plugins/__tests__ && \
 *     bun test needs-input-observer.fast-resolve.test.mjs
 */
import { test, expect, describe, beforeEach, afterEach } from "bun:test"
import { readFileSync, writeFileSync, mkdirSync } from "node:fs"
import { join } from "node:path"
import { createTempWorkspace } from "./helpers/plugin-harness.mjs"

const NEEDS_INPUT_PERM_TIMERS_KEY = Symbol.for("needs-input-observer.permissionTimers")
const NEEDS_INPUT_TITLE_BOOT_KEY = Symbol.for("needs-input-observer.titleSuffixBootDone")
const NEEDS_INPUT_TOAST_KEY = Symbol.for("needs-input-observer.notifiedAsks")
const NEEDS_INPUT_TICKER_BOOT_KEY = Symbol.for("needs-input-observer.tickerBootSeeded")

const { default: createNeedsInputObserver } = await import(
  "../needs-input-observer.ts"
)

// Env save/restore: bun runs test FILES in one shared process, so a leaked
// OPENCODE_UNATTENDED=1 would silently flip other suites to unattended mode.
const ORIGINAL_UNATTENDED = process.env.OPENCODE_UNATTENDED

const liveHooks = []
afterEach(async () => {
  while (liveHooks.length) {
    const h = liveHooks.pop()
    try {
      await h.dispose()
    } catch {
      // best-effort: dispose must never fail a test
    }
  }
  if (ORIGINAL_UNATTENDED === undefined) delete process.env.OPENCODE_UNATTENDED
  else process.env.OPENCODE_UNATTENDED = ORIGINAL_UNATTENDED
})

let permissionCalls = []
// "ok" -> fake SDK succeeds; "error" -> fake SDK returns {error} (RED-7).
let permissionCallMode = "ok"

// Isolate the process-scoped guards: bun shares globalThis across tests in
// one file, so start each test from a clean process (sibling pattern).
beforeEach(() => {
  globalThis[NEEDS_INPUT_PERM_TIMERS_KEY] = undefined
  globalThis[NEEDS_INPUT_TITLE_BOOT_KEY] = undefined
  globalThis[NEEDS_INPUT_TOAST_KEY] = undefined
  globalThis[NEEDS_INPUT_TICKER_BOOT_KEY] = undefined
  permissionCalls = []
  permissionCallMode = "ok"
  // Interactive is the FAIL-SAFE default (ADR-002): tests opt in explicitly.
  delete process.env.OPENCODE_UNATTENDED
})

function freshCtx(directory, extra = {}) {
  return {
    directory,
    client: {
      pty: { list: async () => [], update: async () => ({}) },
      session: {
        list: async () => [],
        update: async () => ({}),
        get: async () => ({ data: { title: "x" }, error: undefined }),
      },
      tui: { showToast: async () => ({}) },
      app: { log: async () => {} },
      postSessionIdPermissionsPermissionId: async (args) => {
        permissionCalls.push(args)
        if (permissionCallMode === "error") {
          return { error: { data: { message: "permission endpoint unavailable" } } }
        }
        return {}
      },
      ...extra,
    },
  }
}

function tickerPath(dir) {
  return join(dir, ".opencode", "session", "ticker.json")
}

function readTicker(dir) {
  return JSON.parse(readFileSync(tickerPath(dir), "utf-8"))
}

// Fail-soft read: a missing registry.jsonl yields [] so the assertion says
// "expected 1 row, got 0" instead of dying on ENOENT.
function registryRows(dir) {
  try {
    return readFileSync(join(dir, ".opencode/session/registry.jsonl"), "utf8")
      .trim()
      .split("\n")
      .filter(Boolean)
      .map((line) => JSON.parse(line))
  } catch {
    return []
  }
}

function permissionAsked(sessionID, permissionID, patterns) {
  return {
    event: {
      type: "permission.asked",
      properties: {
        sessionID,
        id: permissionID,
        permission: "bash",
        patterns: Array.isArray(patterns) ? patterns : [patterns],
      },
    },
  }
}

function minutesAgo(n) {
  return new Date(Date.now() - n * 60_000).toISOString()
}

// Let async resolutions land (fast path await / 0 ms backstop fire / warn).
function settle(ms = 30) {
  return new Promise((r) => setTimeout(r, ms))
}

// Returns the <task_result> body, or null when no envelope is parseable;
// length of the trimmed body is the invariant's "zero-length" measure.
function taskResultBody(text) {
  const m = /<task_result>\s*([\s\S]*?)\s*<\/task_result>/i.exec(
    typeof text === "string" ? text : ""
  )
  return m ? m[1] : null
}

function bodyLength(body) {
  return body === null ? -1 : body.trim().length
}

describe("DIA-260928-nm2u: unattended fast-resolve (permission-stall-hardening RED)", () => {
  test("RED-1: unattended + single-target rm under .scratch -> SDK once + fast_resolved row + timer cleared", async () => {
    const { directory: dir, cleanup } = createTempWorkspace("fastres-r1-")
    try {
      process.env.OPENCODE_UNATTENDED = "1"
      const hooks = await createNeedsInputObserver(freshCtx(dir))
      liveHooks.push(hooks)

      await hooks.event(
        permissionAsked("ses_fast_01", "perm_fast_01", "rm -rf /workspace/.scratch/ordertest")
      )
      await settle()

      expect(permissionCalls).toHaveLength(1)
      expect(permissionCalls[0]).toMatchObject({
        body: { response: "once" },
        path: { id: "ses_fast_01", permissionID: "perm_fast_01" },
      })
      const resolved = registryRows(dir).filter(
        (r) => r.event === "permission_fast_resolved"
      )
      expect(resolved).toHaveLength(1)
      expect(resolved[0]).toMatchObject({
        session_id: "ses_fast_01",
        permission_id: "perm_fast_01",
        decision: "once",
        matched_rule: "rm .scratch single-target",
      })
      // Timer handle gone from the globalThis store: the backstop cannot fire.
      const timers = globalThis[NEEDS_INPUT_PERM_TIMERS_KEY]
      expect(timers.has("ses_fast_01:perm_fast_01")).toBe(false)
    } finally {
      cleanup()
    }
  })

  test("RED-2: unattended + ask outside the sublist -> SDK reject, matched_rule null", async () => {
    const { directory: dir, cleanup } = createTempWorkspace("fastres-r2-")
    try {
      process.env.OPENCODE_UNATTENDED = "1"
      const hooks = await createNeedsInputObserver(freshCtx(dir))
      liveHooks.push(hooks)

      await hooks.event(permissionAsked("ses_out_01", "perm_out_01", "rm -rf /tmp/x"))
      await settle()

      expect(permissionCalls).toHaveLength(1)
      expect(permissionCalls[0]).toMatchObject({
        body: { response: "reject" },
        path: { id: "ses_out_01", permissionID: "perm_out_01" },
      })
      const resolved = registryRows(dir).filter(
        (r) => r.event === "permission_fast_resolved"
      )
      expect(resolved).toHaveLength(1)
      expect(resolved[0]).toMatchObject({
        decision: "reject",
        matched_rule: null,
      })
    } finally {
      cleanup()
    }
  })

  test("RED-3: unattended + MULTI-ARG rm -> SDK reject (falsified-invariant guard)", async () => {
    const { directory: dir, cleanup } = createTempWorkspace("fastres-r3-")
    try {
      process.env.OPENCODE_UNATTENDED = "1"
      const hooks = await createNeedsInputObserver(freshCtx(dir))
      liveHooks.push(hooks)

      // Two non-flag targets: the "anchored allows contain multi-arg rm"
      // invariant was FALSIFIED (memory/adr.md:2513-2545). Even with one
      // target under .scratch, a second target fails closed to reject.
      await hooks.event(
        permissionAsked("ses_multi_01", "perm_multi_01", [
          "rm -rf /workspace/.scratch/x /tmp/y",
        ])
      )
      await settle()

      expect(permissionCalls).toHaveLength(1)
      expect(permissionCalls[0]).toMatchObject({
        body: { response: "reject" },
        path: { id: "ses_multi_01", permissionID: "perm_multi_01" },
      })
      const resolved = registryRows(dir).filter(
        (r) => r.event === "permission_fast_resolved"
      )
      expect(resolved).toHaveLength(1)
      expect(resolved[0]).toMatchObject({
        decision: "reject",
        matched_rule: null,
      })
    } finally {
      cleanup()
    }
  })

  test("RED-4: interactive (env unset) -> NO SDK call, timer armed, waiting row, only permission_asked_logged", async () => {
    const { directory: dir, cleanup } = createTempWorkspace("fastres-r4-")
    try {
      // beforeEach deleted OPENCODE_UNATTENDED = interactive fail-safe default.
      const hooks = await createNeedsInputObserver(freshCtx(dir))
      liveHooks.push(hooks)

      await hooks.event(permissionAsked("ses_int_01", "perm_int_01", "rm -rf /tmp/x"))
      await settle()

      // Fast path behaviorally compiled out interactively (ADR-002).
      expect(permissionCalls).toHaveLength(0)
      // Backstop timer armed exactly as today.
      const timers = globalThis[NEEDS_INPUT_PERM_TIMERS_KEY]
      expect(timers.has("ses_int_01:perm_int_01")).toBe(true)
      const doc = readTicker(dir)
      expect(
        doc.waiting.some(
          (w) => w.permission_id === "perm_int_01" && w.session_id === "ses_int_01"
        )
      ).toBe(true)
      // Registry emits ONLY the pre-existing audit row.
      expect(registryRows(dir).map((r) => r.event)).toEqual(["permission_asked_logged"])
    } finally {
      cleanup()
    }
  })

  test("RED-5: INVARIANT - backdated unresolved ask + empty task_result envelope -> non-empty synthesized body + audit row", async () => {
    const { directory: dir, cleanup } = createTempWorkspace("fastres-r5-")
    try {
      const CHILD = "ses_stall_child"
      const PERM = "perm_stall_01"
      mkdirSync(join(dir, ".opencode", "session"), { recursive: true })
      // Seed: one outstanding ask backdated 10 min (past the 300 s bound), so
      // the re-armed boot timer has 0 ms remaining (sibling test 3 pattern).
      writeFileSync(
        tickerPath(dir),
        JSON.stringify({
          version: 1,
          updated_at: minutesAgo(10),
          waiting: [
            {
              session_id: CHILD,
              reason: "permission",
              detail: "bash rm -rf /workspace/.scratch/stall-x",
              since: minutesAgo(10),
              permission_id: PERM,
            },
          ],
          errors: [],
          permissions: [
            {
              session_id: CHILD,
              permission_id: PERM,
              timestamp: minutesAgo(10),
              patterns: ["rm -rf /workspace/.scratch/stall-x"],
            },
          ],
        })
      )
      process.env.OPENCODE_UNATTENDED = "1"
      const hooks = await createNeedsInputObserver(freshCtx(dir))
      liveHooks.push(hooks)
      // Boot resolution: the fast path resolves it (post-fix); today the 0 ms
      // backstop auto-rejects. Either way a resolution row must exist.
      await settle(150)

      const bootRows = registryRows(dir)
      const bootResolutions = bootRows.filter(
        (r) =>
          r.event === "permission_fast_resolved" ||
          r.event === "permission_auto_rejected"
      )
      expect(bootResolutions.length).toBeGreaterThan(0)
      expect(bootRows.find((r) => r.event === "permission_fast_resolved")?.decision).toBe("reject")

      // Drive the O-D guard seam with the cod-8 shape: task envelope whose
      // <task_result> body is EMPTY.
      const envelope = `<task id="${CHILD}"><state>completed</state><task_result></task_result></task>`
      const output = { output: envelope }
      await hooks["tool.execute.after"](
        { tool: "task", sessionID: "ses_parent_stall", callID: "call_stall_01" },
        output
      )

      const rows = registryRows(dir)
      const autoRejected = rows.filter((r) => r.event === "permission_auto_rejected")
      const body = taskResultBody(output.output)

      // INVARIANT (the cod-8 death signature): a permission_auto_rejected row
      // must NEVER be followed by a zero-length <task_result> envelope.
      if (autoRejected.length > 0) {
        expect(bodyLength(body)).toBeGreaterThan(0)
      }
      // The returned output carries a NON-EMPTY <task_result> body.
      expect(bodyLength(body)).toBeGreaterThan(0)
      // The synthesis audit row exists regardless of mutation honoring.
      expect(
        rows.filter((r) => r.event === "permission_stall_envelope_synthesized")
      ).toHaveLength(1)
    } finally {
      cleanup()
    }
  })

  test("RED-6: race - fast-resolved permission, would-be timer callback is a no-op", async () => {
    const { directory: dir, cleanup } = createTempWorkspace("fastres-r6-")
    try {
      process.env.OPENCODE_UNATTENDED = "1"
      const hooks = await createNeedsInputObserver(freshCtx(dir))
      liveHooks.push(hooks)

      // Capture the backstop callback armed during the ask event. The
      // plugin's ONLY setTimeout call site is armPermissionTimer
      // (needs-input-observer.ts:358), so everything captured in this
      // window is a permission watchdog callback.
      const captured = []
      const realSetTimeout = globalThis.setTimeout
      globalThis.setTimeout = (fn, ms, ...rest) => {
        captured.push({ fn, ms })
        return realSetTimeout(fn, ms, ...rest)
      }
      try {
        await hooks.event(permissionAsked("ses_race_01", "perm_race_01", "rm -rf /tmp/x"))
      } finally {
        globalThis.setTimeout = realSetTimeout
      }
      await settle()

      // Precondition: the fast path resolved the ask at T~0.
      expect(permissionCalls).toHaveLength(1)
      expect(captured).toHaveLength(1)

      // A queued backstop fire: invoke the would-be timer callback manually.
      captured[0].fn()
      await settle(50)

      // autoRejectPermission must stand down: no second SDK call, no
      // permission_auto_rejected row for an already-resolved permission.
      expect(permissionCalls).toHaveLength(1)
      const rows = registryRows(dir)
      expect(rows.filter((r) => r.event === "permission_auto_rejected")).toHaveLength(0)
    } finally {
      cleanup()
    }
  })

  test("RED-7: SDK failure - warn only, record + timer retained, backstop still armed", async () => {
    const { directory: dir, cleanup } = createTempWorkspace("fastres-r7-")
    try {
      permissionCallMode = "error"
      process.env.OPENCODE_UNATTENDED = "1"

      const warns = []
      const realWarn = console.warn
      console.warn = (...args) => {
        warns.push(args.map(String).join(" "))
      }
      let hooks
      try {
        hooks = await createNeedsInputObserver(freshCtx(dir))
        liveHooks.push(hooks)
        await hooks.event(permissionAsked("ses_err_01", "perm_err_01", "rm -rf /tmp/x"))
        await settle()
      } finally {
        console.warn = realWarn
      }

      // The fast path ATTEMPTED the reply: one SDK call, error response.
      expect(permissionCalls).toHaveLength(1)
      // Fail-soft: console.warn, never a thrown hook (plugin header contract).
      expect(warns.length).toBeGreaterThan(0)
      // Record retained (waiting row + watchdog record).
      const doc = readTicker(dir)
      expect(
        doc.waiting.some((w) => w.permission_id === "perm_err_01")
      ).toBe(true)
      expect(
        doc.permissions.some((p) => p.permission_id === "perm_err_01")
      ).toBe(true)
      // Timer retained: the 300 s backstop is still armed (invariant clause 1
      // under fast-path failure).
      const timers = globalThis[NEEDS_INPUT_PERM_TIMERS_KEY]
      expect(timers.has("ses_err_01:perm_err_01")).toBe(true)
      // No resolution row written: the backstop owns resolution now.
      const rows = registryRows(dir)
      expect(rows.filter((r) => r.event === "permission_fast_resolved")).toHaveLength(0)
      expect(rows.filter((r) => r.event === "permission_auto_rejected")).toHaveLength(0)
    } finally {
      cleanup()
    }
  })

  test("RED-8: non-interference pin - empty task_result with NO stall record -> guard stands down (0 synthesized rows, output untouched)", async () => {
    const { directory: dir, cleanup } = createTempWorkspace("fastres-r8-")
    try {
      // Interactive-safety pin for the DELIBERATELY UNGATED O-D guard
      // (ADR-003): record-absence is the guard's only stand-down, so it must
      // not fire even with the full permission-watch machinery active. The
      // ask below PENDING never resolves interactively (gate off per
      // beforeEach), hence no stall record ever exists for any child id.
      const hooks = await createNeedsInputObserver(freshCtx(dir))
      liveHooks.push(hooks)
      await hooks.event(
        permissionAsked("ses_nostall_01", "perm_nostall_01", "rm -rf /tmp/x")
      )
      await settle()

      // Same cod-8 EMPTY body shape as RED-5, but for a child with no stall
      // record: the empty envelope must flow through UNTOUCHED so the
      // existing empty-result detector (delegation-observer) keeps its
      // semantics - this plugin must neither synthesize nor rewrite it.
      const envelope = `<task id="ses_nostall_child"><state>completed</state><task_result></task_result></task>`
      const output = { output: envelope }
      await hooks["tool.execute.after"](
        { tool: "task", sessionID: "ses_parent_nostall", callID: "call_nostall_01" },
        output
      )

      // Output NOT mutated by the guard (byte-identical) and still empty, so
      // the existing empty-result detector path sees exactly what core gave.
      expect(output.output).toBe(envelope)
      expect(bodyLength(taskResultBody(output.output))).toBe(0)
      // ZERO synthesis audit rows: the guard never engaged.
      expect(
        registryRows(dir).filter(
          (r) => r.event === "permission_stall_envelope_synthesized"
        )
      ).toHaveLength(0)
    } finally {
      cleanup()
    }
  })
})
