/**
 * DIA-260827-gnsv per-permission ticker rows: one waiting row per pending
 * permission, scoped clearing, merged persist/seed, C2 permission_id.
 *
  * Hermetic pattern (mirrors reload-dedup/ticker-expiry suites): the REAL
  * plugin factory runs against a temp workspace (createTempWorkspace) - the
 * real ticker.json is NEVER touched. Timers are real setTimeout handles;
 * each test disposes its hooks so no 5-minute watchdog leaks.
 *
 * Acceptance (6):
 *   1. A-then-B: two permission.asked for one session -> two waiting rows
 *   2. reply requestID=A (twice: reply:once) keeps B (waiting + permissions)
 *   3. timeout of A keeps B (stale seed fires A immediately)
 *   4. session.error bulk-clears session + all permission rows/timers
 *   5. session.deleted bulk-clears session + all permission rows/timers
  *   6. restart restores both rows + arms 2 timers (no dup) + C2 shows both IDs
  *   7. cross-session: bulk-clear on A preserves B rows + timers (F7)
  *
  * DIA-079: ASCII-only.
 *
 * RUN (bun in poetry-dev container):
 *   cd .opencode/plugins/__tests__ && \
 *     bun test needs-input-observer.per-permission-rows.test.mjs
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
})

// Isolate the process-scoped guards: bun shares globalThis across tests in
// one file, so start each test from a clean process.
beforeEach(() => {
  globalThis[NEEDS_INPUT_PERM_TIMERS_KEY] = undefined
  globalThis[NEEDS_INPUT_TITLE_BOOT_KEY] = undefined
  globalThis[NEEDS_INPUT_TOAST_KEY] = undefined
  globalThis[NEEDS_INPUT_TICKER_BOOT_KEY] = undefined
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
        permissionRejectCalls.push(args)
        return {}
      },
      ...extra,
    },
  }
}

let permissionRejectCalls = []
beforeEach(() => {
  permissionRejectCalls = []
})

function tickerPath(dir) {
  return join(dir, ".opencode", "session", "ticker.json")
}

function readTicker(dir) {
  return JSON.parse(readFileSync(tickerPath(dir), "utf-8"))
}

function permissionAsked(sessionID, permissionID, pattern) {
  return {
    event: {
      type: "permission.asked",
      properties: {
        sessionID,
        id: permissionID,
        permission: "bash",
        patterns: [pattern],
      },
    },
  }
}

function permissionReplied(sessionID, requestID) {
  return {
    event: {
      type: "permission.v2.replied",
      properties: { sessionID, requestID },
    },
  }
}

async function compactSnapshot(hooks) {
  const output = { context: [] }
  await hooks["experimental.session.compacting"]({}, output)
  return output.context.join("\n")
}

function minutesAgo(n) {
  return new Date(Date.now() - n * 60_000).toISOString()
}

describe("DIA-260827-gnsv: per-permission waiting rows", () => {
  test("1: A-then-B two permission asks render two rows (waiting + permissions)", async () => {
    const { directory: dir, cleanup } = createTempWorkspace("gnsv-rows-")
    try {
      const hooks = await createNeedsInputObserver(freshCtx(dir))
      liveHooks.push(hooks)
      await hooks.event(permissionAsked("ses_gnsv_01", "perm_A", "/tmp/a.sh"))
      await hooks.event(permissionAsked("ses_gnsv_01", "perm_B", "/tmp/b.sh"))

      const doc = readTicker(dir)
      expect(doc.waiting.length).toBe(2)
      const ids = doc.waiting.map((e) => e.permission_id).sort()
      expect(ids).toEqual(["perm_A", "perm_B"])
      for (const row of doc.waiting) {
        expect(row.session_id).toBe("ses_gnsv_01")
        expect(row.reason).toBe("permission")
      }
      const permIds = (doc.permissions || []).map((p) => p.permission_id).sort()
      expect(permIds).toEqual(["perm_A", "perm_B"])
    } finally {
      cleanup()
    }
  })

  test("2: reply requestID=A once keeps B (duplicate reply no-op; session+permission asserts)", async () => {
    const { directory: dir, cleanup } = createTempWorkspace("gnsv-reply-")
    try {
      const hooks = await createNeedsInputObserver(freshCtx(dir))
      liveHooks.push(hooks)
      await hooks.event(permissionAsked("ses_gnsv_02", "perm_A", "/tmp/a.sh"))
      await hooks.event(permissionAsked("ses_gnsv_02", "perm_B", "/tmp/b.sh"))

      await hooks.event(permissionReplied("ses_gnsv_02", "perm_A"))
      // reply:once - a duplicate reply for the same id is a no-op.
      await hooks.event(permissionReplied("ses_gnsv_02", "perm_A"))

      const doc = readTicker(dir)
      expect(doc.waiting.length).toBe(1)
      expect(doc.waiting[0].permission_id).toBe("perm_B")
      expect(doc.waiting[0].session_id).toBe("ses_gnsv_02")
      const permIds = (doc.permissions || []).map((p) => p.permission_id)
      expect(permIds).toEqual(["perm_B"])
    } finally {
      cleanup()
    }
  })

  test("3: timeout of A keeps B (SDK reject targets A only)", async () => {
    const { directory: dir, cleanup } = createTempWorkspace("gnsv-timeout-")
    try {
      // Seed: A is 10min old (past the 5min default stall timeout, so its
      // re-armed timer fires immediately); B is fresh. New-format waiting
      // rows with permission_id (forward seed path).
      mkdirSync(join(dir, ".opencode", "session"), { recursive: true })
      writeFileSync(
        tickerPath(dir),
        JSON.stringify({
          version: 1,
          updated_at: minutesAgo(10),
          waiting: [
            {
              session_id: "ses_gnsv_03",
              reason: "permission",
              detail: "bash /tmp/a.sh",
              since: minutesAgo(10),
              permission_id: "perm_A",
            },
            {
              session_id: "ses_gnsv_03",
              reason: "permission",
              detail: "bash /tmp/b.sh",
              since: new Date().toISOString(),
              permission_id: "perm_B",
            },
          ],
          errors: [],
          permissions: [],
        })
      )
      const hooks = await createNeedsInputObserver(freshCtx(dir))
      liveHooks.push(hooks)
      // Let the immediate (remaining 0ms) watchdog timer for A fire.
      await new Promise((r) => setTimeout(r, 50))

      expect(permissionRejectCalls.length).toBe(1)
      expect(permissionRejectCalls[0].path.permissionID).toBe("perm_A")
      const doc = readTicker(dir)
      expect(doc.waiting.length).toBe(1)
      expect(doc.waiting[0].permission_id).toBe("perm_B")
      const permIds = (doc.permissions || []).map((p) => p.permission_id)
      expect(permIds).toEqual(["perm_B"])
      const registryRows = readFileSync(join(dir, ".opencode/session/registry.jsonl"), "utf8")
        .trim().split("\n").map((line) => JSON.parse(line))
      const rejected = registryRows.filter((row) => row.event === "permission_auto_rejected")
      expect(rejected).toHaveLength(1)
      expect(rejected[0]).toMatchObject({
        session_id: "ses_gnsv_03",
        permission_id: "perm_A",
        timeout_seconds: 300,
        reason: "no_human_response_within_threshold",
      })
      const messageRows = readFileSync(join(dir, ".opencode/session/messages.jsonl"), "utf8")
        .trim().split("\n").map((line) => JSON.parse(line))
      const decisions = messageRows.filter((row) => row.content_ref === "permission_auto_rejected_after_5min")
      expect(decisions).toHaveLength(1)
      expect(decisions[0]).toMatchObject({
        "gen_ai.operation.name": "invoke_workflow",
        from: "orchestrator",
        event_type: "decision",
        task_ref: "ses_gnsv_03",
        resolution_status: "escalated",
        content_ref: "permission_auto_rejected_after_5min",
        next_action: "re-dispatch or fail-fast",
        "gen_ai.agent.id": "ses_gnsv_03",
      })
    } finally {
      cleanup()
    }
  })

  test("4: session.error bulk-clears session + all permission rows/timers", async () => {
    const { directory: dir, cleanup } = createTempWorkspace("gnsv-error-")
    try {
      const hooks = await createNeedsInputObserver(freshCtx(dir))
      liveHooks.push(hooks)
      await hooks.event(permissionAsked("ses_gnsv_04", "perm_A", "/tmp/a.sh"))
      await hooks.event(permissionAsked("ses_gnsv_04", "perm_B", "/tmp/b.sh"))
      expect(readTicker(dir).waiting.length).toBe(2)

      await hooks.event({
        event: {
          type: "session.error",
          properties: { sessionID: "ses_gnsv_04", error: new Error("boom") },
        },
      })

      const doc = readTicker(dir)
      expect(doc.waiting).toEqual([])
      expect(doc.permissions).toEqual([])
      expect(doc.errors.length).toBe(1)
      expect(doc.errors[0].session_id).toBe("ses_gnsv_04")
      const timers = globalThis[NEEDS_INPUT_PERM_TIMERS_KEY]
      expect(timers.size).toBe(0)
    } finally {
      cleanup()
    }
  })

  test("5: session.deleted bulk-clears session + all permission rows/timers", async () => {
    const { directory: dir, cleanup } = createTempWorkspace("gnsv-deleted-")
    try {
      const hooks = await createNeedsInputObserver(freshCtx(dir))
      liveHooks.push(hooks)
      await hooks.event(permissionAsked("ses_gnsv_05", "perm_A", "/tmp/a.sh"))
      await hooks.event(permissionAsked("ses_gnsv_05", "perm_B", "/tmp/b.sh"))
      expect(readTicker(dir).waiting.length).toBe(2)

      await hooks.event({
        event: {
          type: "session.deleted",
          properties: { sessionID: "ses_gnsv_05" },
        },
      })

      const doc = readTicker(dir)
      expect(doc.waiting).toEqual([])
      expect(doc.permissions).toEqual([])
      const timers = globalThis[NEEDS_INPUT_PERM_TIMERS_KEY]
      expect(timers.size).toBe(0)
    } finally {
      cleanup()
    }
  })

  test("6: restart restores both rows + arms 2 timers (no dup) + C2 shows both IDs", async () => {
    const { directory: dir, cleanup } = createTempWorkspace("gnsv-restart-")
    try {
      mkdirSync(join(dir, ".opencode", "session"), { recursive: true })
      writeFileSync(
        tickerPath(dir),
        JSON.stringify({
          version: 1,
          updated_at: new Date().toISOString(),
          waiting: [
            {
              session_id: "ses_gnsv_06",
              reason: "permission",
              detail: "bash /tmp/a.sh",
              since: new Date().toISOString(),
              permission_id: "perm_A",
            },
            {
              session_id: "ses_gnsv_06",
              reason: "permission",
              detail: "bash /tmp/b.sh",
              since: new Date().toISOString(),
              permission_id: "perm_B",
            },
          ],
          errors: [],
          permissions: [],
        })
      )
      const hooks = await createNeedsInputObserver(freshCtx(dir))
      liveHooks.push(hooks)
      const timers = globalThis[NEEDS_INPUT_PERM_TIMERS_KEY]
      expect(timers.size).toBe(2)

      // In-process reload must not double-arm.
      const hooks2 = await createNeedsInputObserver(freshCtx(dir))
      liveHooks.push(hooks2)
      expect(timers.size).toBe(2)

      const doc = readTicker(dir)
      const ids = doc.waiting.map((e) => e.permission_id).sort()
      expect(ids).toEqual(["perm_A", "perm_B"])

      const snap = await compactSnapshot(hooks2)
      expect(snap).toContain("perm_A")
      expect(snap).toContain("perm_B")
      expect(snap).toContain("permission_id=")
    } finally {
      cleanup()
    }
  })

  test("7: cross-session bulk-clear on A preserves B rows + timers", async () => {
    const { directory: dir, cleanup } = createTempWorkspace("gnsv-xsession-")
    try {
      const hooks = await createNeedsInputObserver(freshCtx(dir))
      liveHooks.push(hooks)
      await hooks.event(permissionAsked("ses_gnsv_A", "perm_A1", "/tmp/a1.sh"))
      await hooks.event(permissionAsked("ses_gnsv_A", "perm_A2", "/tmp/a2.sh"))
      await hooks.event(permissionAsked("ses_gnsv_B", "perm_B1", "/tmp/b1.sh"))
      await hooks.event(permissionAsked("ses_gnsv_B", "perm_B2", "/tmp/b2.sh"))
      expect(readTicker(dir).waiting.length).toBe(4)

      await hooks.event({
        event: {
          type: "session.error",
          properties: { sessionID: "ses_gnsv_A", error: new Error("boom") },
        },
      })

      const doc = readTicker(dir)
      expect(doc.waiting.length).toBe(2)
      const ids = doc.waiting.map((e) => e.permission_id).sort()
      expect(ids).toEqual(["perm_B1", "perm_B2"])
      for (const row of doc.waiting) {
        expect(row.session_id).toBe("ses_gnsv_B")
      }
      const permIds = (doc.permissions || []).map((p) => p.permission_id).sort()
      expect(permIds).toEqual(["perm_B1", "perm_B2"])
      const timers = globalThis[NEEDS_INPUT_PERM_TIMERS_KEY]
      expect(timers.size).toBe(2)
      for (const key of timers.keys()) {
        expect(key.startsWith("ses_gnsv_B")).toBe(true)
      }
    } finally {
      cleanup()
    }
  })

  test("DIA-260914-tqor: permission ask keeps the canonical audit payload", async () => {
    const { directory: dir, cleanup } = createTempWorkspace("tqor-needs-input-")
    try {
      const hooks = await createNeedsInputObserver(freshCtx(dir))
      liveHooks.push(hooks)
      await hooks.event(permissionAsked("ses_tqor_01", "perm_tqor_01", "/tmp/task.sh"))

      const rows = readFileSync(join(dir, ".opencode/session/registry.jsonl"), "utf8")
        .trim().split("\n").map((line) => JSON.parse(line))
      const asked = rows.filter((row) => row.event === "permission_asked_logged")
      expect(asked).toHaveLength(1)
      expect(asked[0]).toMatchObject({
        event: "permission_asked_logged",
        session_id: "ses_tqor_01",
        permission_id: "perm_tqor_01",
      })
    } finally {
      cleanup()
    }
  })
})
