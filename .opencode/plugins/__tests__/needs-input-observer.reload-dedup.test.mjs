/**
 * DIA-260821-5r03 reload-dedup tests: needs-input-observer singleton
 * side-effects must not re-fire on an in-process plugin reload (module
 * re-evaluation without dispose). Mirrors
 * delegation-observer.reload-dedup.test.mjs (process-scoped globalThis
 * guards).
 *
 * The four guards (design.md D3 / tasks.md 3.1-3.4):
 *   1. NEEDS_INPUT_PERM_TIMERS_KEY  - permission watchdog timer Map (globalThis
 *      backed so a reload reuses the SAME handles instead of stacking).
 *   2. NEEDS_INPUT_TITLE_BOOT_KEY   - title-suffix boot retro pass runs once
 *      per process.
 *   3. NEEDS_INPUT_TOAST_KEY        - Set of (session_id:reason) already
 *      toasted, so a reload does not re-toast a persisted pending ask.
 *   4. NEEDS_INPUT_TICKER_BOOT_KEY  - ticker boot-seed (watchdog re-arm) runs
 *      once per process.
 *
 * DIA-079: ASCII-only.
 *
 * RUN (bun in poetry-dev container):
 *   cd .opencode/plugins/__tests__ && \
 *     bun test needs-input-observer.reload-dedup.test.mjs
 */
import { test, expect, describe, beforeEach } from "bun:test"
import { mkdtempSync, writeFileSync, rmSync, mkdirSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

// Well-known symbols the implementation MUST use (tasks.md 3.1-3.4). Referenced
// directly so the tests fail deterministically until the implementation sets
// them.
const NEEDS_INPUT_PERM_TIMERS_KEY = Symbol.for("needs-input-observer.permissionTimers")
const NEEDS_INPUT_TITLE_BOOT_KEY = Symbol.for("needs-input-observer.titleSuffixBootDone")
const NEEDS_INPUT_TOAST_KEY = Symbol.for("needs-input-observer.notifiedAsks")
const NEEDS_INPUT_TICKER_BOOT_KEY = Symbol.for("needs-input-observer.tickerBootSeeded")

// Import AFTER any mock.module registration (none needed here - the plugin only
// imports a type from @opencode-ai/plugin).
const { default: createNeedsInputObserver } = await import(
  "../needs-input-observer.ts"
)

const tempDirs = []
process.on("exit", () => {
  for (const dir of tempDirs) {
    try {
      rmSync(dir, { recursive: true, force: true })
    } catch {
      // Best-effort cleanup.
    }
  }
})

// Shared spies so a simulated reload (two factory calls in one process) observes
// suppression across the globalThis-backed guards.
const ptyListCalls = []
const sessionListCalls = []
const toasts = []

function freshCtx() {
  const directory = mkdtempSync(join(tmpdir(), "dia260821-5r03-"))
  tempDirs.push(directory)
  const ctx = {
    directory,
    client: {
      pty: {
        list: async () => {
          ptyListCalls.push(1)
          return []
        },
        update: async () => ({}),
      },
      session: {
        list: async () => {
          sessionListCalls.push(1)
          return []
        },
        update: async () => ({}),
        get: async () => ({ data: { title: "x" }, error: undefined }),
      },
      tui: {
        showToast: async (body) => {
          toasts.push(body)
          return {}
        },
      },
      app: { log: async () => {} },
      postSessionIdPermissionsPermissionId: async () => ({}),
    },
  }
  return ctx
}

function questionAskedEvent(sessionID) {
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

function tick() {
  return new Promise((r) => setTimeout(r, 0))
}

// Isolate the process-scoped guards: bun shares globalThis across tests in one
// file, so clear all four symbols before each test starts from a clean process.
beforeEach(() => {
  globalThis[NEEDS_INPUT_PERM_TIMERS_KEY] = undefined
  globalThis[NEEDS_INPUT_TITLE_BOOT_KEY] = undefined
  globalThis[NEEDS_INPUT_TOAST_KEY] = undefined
  globalThis[NEEDS_INPUT_TICKER_BOOT_KEY] = undefined
  ptyListCalls.length = 0
  sessionListCalls.length = 0
  toasts.length = 0
})

describe("DIA-260821-5r03: needs-input-observer reload dedupe (process-scoped)", () => {
  test("guard 1: permission timer Map is globalThis-backed and reused across reload (no stacking)", async () => {
    const ctx = freshCtx()
    await createNeedsInputObserver(ctx)
    const map1 = globalThis[NEEDS_INPUT_PERM_TIMERS_KEY]
    expect(map1).toBeDefined()
    expect(map1).toBeInstanceOf(Map)

    // In-process reload: second factory call in the SAME process.
    await createNeedsInputObserver(ctx)
    const map2 = globalThis[NEEDS_INPUT_PERM_TIMERS_KEY]
    // The SAME Map reference is reused, so armPermissionTimer's has(key) check
    // dedupes and no second setTimeout handle is stacked.
    expect(map2).toBe(map1)
  })

  test("guard 2: title-suffix boot retro pass runs once per process; reload skips it", async () => {
    const ctx = freshCtx()
    await createNeedsInputObserver(ctx)
    await tick()
    expect(globalThis[NEEDS_INPUT_TITLE_BOOT_KEY]).toBe(true)
    // First process boot: bootRetroPass fired (pty.list + session.list called).
    expect(ptyListCalls.length).toBeGreaterThanOrEqual(1)
    const callsAfterFirst = ptyListCalls.length

    // In-process reload: bootRetroPass must be skipped.
    await createNeedsInputObserver(ctx)
    await tick()
    expect(globalThis[NEEDS_INPUT_TITLE_BOOT_KEY]).toBe(true)
    expect(ptyListCalls.length).toBe(callsAfterFirst) // no new boot pass
  })

  test("guard 3: notified-ask Set is globalThis-backed; reload does not re-toast", async () => {
    const ctx = freshCtx()
    const h1 = await createNeedsInputObserver(ctx)
    const set1 = globalThis[NEEDS_INPUT_TOAST_KEY]
    expect(set1).toBeDefined()
    expect(set1).toBeInstanceOf(Set)

    // First process: a question.asked drives enter() -> notify() -> toast.
    await h1.event(questionAskedEvent("ses_reload_0001"))
    expect(toasts.length).toBe(1)
    expect(set1.has("ses_reload_0001:question")).toBe(true)

    // In-process reload: a fresh instance re-fires enter() for the same ask,
    // but the globalThis-backed Set suppresses the duplicate toast.
    const h2 = await createNeedsInputObserver(ctx)
    const set2 = globalThis[NEEDS_INPUT_TOAST_KEY]
    expect(set2).toBe(set1) // same Set reused across reload

    await h2.event(questionAskedEvent("ses_reload_0001"))
    expect(toasts.length).toBe(1) // NOT re-toasted
  })

  test("guard 4: ticker boot-seed (watchdog re-arm) runs once per process", async () => {
    const ctx = freshCtx()
    // Seed a ticker.json with one pending permission so seedFromDisk arms a
    // watchdog timer on the first factory call.
    const sessionDir = join(ctx.directory, ".opencode", "session")
    mkdirSync(sessionDir, { recursive: true })
    writeFileSync(
      join(sessionDir, "ticker.json"),
      JSON.stringify({
        waiting: [],
        errors: [],
        permissions: [
          {
            session_id: "ses_perm_0001",
            permission_id: "perm_0001",
            timestamp: new Date().toISOString(),
          },
        ],
      })
    )

    const h1 = await createNeedsInputObserver(ctx)
    expect(globalThis[NEEDS_INPUT_TICKER_BOOT_KEY]).toBe(true)
    const timersAfterFirst = globalThis[NEEDS_INPUT_PERM_TIMERS_KEY]
    expect(timersAfterFirst.size).toBe(1) // one watchdog armed

    // In-process reload: ticker boot-seed must NOT re-arm (no double-seed).
    await createNeedsInputObserver(ctx)
    expect(globalThis[NEEDS_INPUT_TICKER_BOOT_KEY]).toBe(true)
    expect(timersAfterFirst.size).toBe(1) // still exactly one, not two

    // Clean up the armed timer so the test process does not hang.
    for (const t of timersAfterFirst.values()) clearTimeout(t)
    await h1.dispose().catch(() => {})
  })

  test("dispose clears all four globalThis symbols", async () => {
    const ctx = freshCtx()
    const h = await createNeedsInputObserver(ctx)
    // Drive one notify so the toast Set is populated, then dispose.
    await h.event(questionAskedEvent("ses_dispose_0001"))
    expect(globalThis[NEEDS_INPUT_PERM_TIMERS_KEY]).toBeDefined()
    expect(globalThis[NEEDS_INPUT_TITLE_BOOT_KEY]).toBe(true)
    expect(globalThis[NEEDS_INPUT_TOAST_KEY]).toBeDefined()
    expect(globalThis[NEEDS_INPUT_TICKER_BOOT_KEY]).toBe(true)

    await h.dispose()

    expect(globalThis[NEEDS_INPUT_PERM_TIMERS_KEY]).toBeUndefined()
    expect(globalThis[NEEDS_INPUT_TITLE_BOOT_KEY]).toBeUndefined()
    expect(globalThis[NEEDS_INPUT_TOAST_KEY]).toBeUndefined()
    expect(globalThis[NEEDS_INPUT_TICKER_BOOT_KEY]).toBeUndefined()
  })
})
