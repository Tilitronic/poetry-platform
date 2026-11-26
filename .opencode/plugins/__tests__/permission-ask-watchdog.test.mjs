/**
 * TDD RED suite: V2 permission-ask timeout watchdog
 * (campaign DIA-261112-exon; amendment DIA-261126-q9r9).
 *
 * Design authority: ADR 16, .sdd/dev-infra/architecture.md:171 - "needs-input
 * watchdog residue". Written BEFORE the module exists: ../permission-ask-watchdog.ts
 * is absent, so this file fails at import. That is the deliverable
 * (DIA-175: a different coder instance writes the implementation).
 *
 * CONTRACT UNDER TEST (ADR 16:171):
 *   - default export: async (ctx) => hooks; hooks hold at most `event` and `dispose`.
 *   - Feature detection: unless ctx.permission?.list AND ctx.permission.reply are
 *     both functions, the factory returns an EMPTY hooks object - no event, no
 *     dispose, no timers. That is the installed V1 host (@opencode-ai/plugin
 *     1.17.7: PluginInput has no `permission`) and is the most important case.
 *   - permission.asked / permission.v2.asked arms one timer per ask, keyed by
 *     sessionID + ask id. Threshold = env PERMISSION_STALL_TIMEOUT_MINUTES,
 *     default 5; 0 / empty / negative / non-numeric disable arming. The env is
 *     read at ARM time (these tests set it after the module was imported).
 *   - Expiry: await ctx.permission.list({ sessionID }); if the ask whose `id`
 *     matches is still listed, await ctx.permission.reply({ sessionID,
 *     requestID: ask.id, decision: "reject" }) EXACTLY ONCE. Ask gone -> no reply.
 *   - One reject clears every pending ask of the session
 *     (docs-permissions.md:225), so N pending asks in one session = at most one
 *     reply. A timer that fires after the session was already resolved must not
 *     add a second reply.
 *   - Timer cleared on permission.replied / permission.rejected for that ask;
 *     all session timers cleared on session.deleted; dispose clears every timer.
 *   - V2 field names only: `action`, `resources`, `id` - never V1 `permission`
 *     or `patterns` copied into the reply call.
 *
 * FIXTURES:
 *   - fake ctx.permission recorder; list/reply signatures per
 *     knowledge/res-261113-hi88-opencode-v2-native-capabilities/sources/
 *     docs-build-plugins-server.md:619-621 (`await ctx.permission.list({
 *     sessionID })` returns the pending array; `reply({ sessionID, requestID,
 *     decision })`).
 *   - event payload shapes mirror needs-input-observer.ts:1527-1583
 *     (permission.asked carries V1 fields sessionID/id/permission/patterns;
 *     permission.v2.asked carries V2 fields sessionID/id/action/resources) and
 *     :1620-1637 (permission.replied carries requestID in V2, permissionID in
 *     V1).
 *   - timers: bun fake timers (jest.useFakeTimers + advanceTimersByTime), so the
 *     implementation must arm through global setTimeout/setInterval/clearTimeout.
 *     The expiry callback is async (list -> reply); each advance is followed by
 *     a microtask drain so the transition is deterministic without real waiting.
 *
 * Tests 1-6 are the brief's cases; 7-8 pin the remaining ADR 16:171 clauses
 * (session.deleted + dispose teardown, default 5-minute threshold).
 *
 * DIA-079: ASCII-only.
 *
 * RUN (bun in the dev container):
 *   cd .opencode/plugins && bun test __tests__/permission-ask-watchdog.test.mjs
 */
import { test, expect, describe, beforeEach, afterEach, jest } from "bun:test"

import createPermissionAskWatchdog from "../permission-ask-watchdog.ts"

const THRESHOLD_ENV = "PERMISSION_STALL_TIMEOUT_MINUTES"
const ORIGINAL_THRESHOLD = process.env[THRESHOLD_ENV]

// bun runs test FILES in one shared process: never leak the threshold to a
// sibling suite (same pattern as needs-input-observer.fast-resolve.test.mjs).
afterEach(() => {
  jest.useRealTimers()
  if (ORIGINAL_THRESHOLD === undefined) delete process.env[THRESHOLD_ENV]
  else process.env[THRESHOLD_ENV] = ORIGINAL_THRESHOLD
})

beforeEach(() => {
  jest.useFakeTimers()
  // Unset = the 5-minute default; each test opts into a threshold explicitly.
  delete process.env[THRESHOLD_ENV]
})

// The expiry callback awaits list() then reply(); both settle as microtasks,
// so draining is enough - no real time passes under fake timers.
async function drainMicrotasks(times = 50) {
  for (let i = 0; i < times; i += 1) await Promise.resolve()
}

async function advance(ms) {
  jest.advanceTimersByTime(ms)
  await drainMicrotasks()
}

function fakeCtx() {
  const state = { pending: [] }
  const listCalls = []
  const replies = []
  const ctx = {
    directory: "permission-ask-watchdog-fixture",
    // No-op diagnostic sinks: the contract does not forbid logging, and a
    // recorder-only ctx would fail an otherwise correct implementation.
    client: {
      app: { log: async () => {} },
      tui: { showToast: async () => {} },
    },
    permission: {
      list: async (args) => {
        listCalls.push(args)
        return state.pending.filter((ask) => ask.sessionID === args?.sessionID)
      },
      reply: async (args) => {
        replies.push(args)
        // Real V2 semantics: reject clears every pending ask of the session.
        state.pending = state.pending.filter(
          (ask) => ask.sessionID !== args?.sessionID
        )
        return {}
      },
    },
  }
  return { ctx, state, listCalls, replies }
}

// V1-shaped asked payload (needs-input-observer.ts:1527-1545).
function permissionAsked(sessionID, askId) {
  return {
    event: {
      type: "permission.asked",
      properties: {
        sessionID,
        id: askId,
        permission: "bash",
        patterns: ["git push"],
      },
    },
  }
}

// V2-shaped asked payload, dotted type name (needs-input-observer.ts:1530-1545).
function permissionV2Asked(sessionID, askId) {
  return {
    event: {
      type: "permission.v2.asked",
      properties: {
        sessionID,
        id: askId,
        action: "bash",
        resources: ["git push"],
      },
    },
  }
}

// Reply event (needs-input-observer.ts:1620-1637): V2 carries requestID, V1
// carries permissionID. The fixture carries both so this suite pins the CLEAR
// behaviour instead of guessing which field name the implementation reads.
function permissionReplied(sessionID, askId, type = "permission.replied") {
  return {
    event: {
      type,
      properties: { sessionID, requestID: askId, permissionID: askId },
    },
  }
}

function sessionDeleted(sessionID) {
  return { event: { type: "session.deleted", properties: { sessionID } } }
}

describe("DIA-261126-q9r9: V2 permission-ask watchdog", () => {
  test("1: inert on a V1 ctx - empty hooks, no timer when permission.* is absent or partial", async () => {
    const v1Hooks = await createPermissionAskWatchdog({
      directory: "permission-ask-watchdog-fixture",
    })
    expect(Object.keys(v1Hooks)).toEqual([])
    expect(jest.getTimerCount()).toBe(0)

    // Feature detection is a conjunction: half the surface is still V1.
    const partialHooks = await createPermissionAskWatchdog({
      directory: "permission-ask-watchdog-fixture",
      permission: { list: async () => [] },
    })
    expect(Object.keys(partialHooks)).toEqual([])
    expect(jest.getTimerCount()).toBe(0)

    await advance(10 * 60_000)
    expect(jest.getTimerCount()).toBe(0)
  })

  test("2: rejects once after the threshold with {sessionID, requestID, decision}", async () => {
    // Set AFTER the module import: the env must be read at arm time.
    process.env[THRESHOLD_ENV] = "1"
    const { ctx, state, listCalls, replies } = fakeCtx()
    state.pending = [
      {
        id: "per_ask_A",
        sessionID: "ses_wd_02",
        action: "bash",
        resources: ["git push"],
      },
    ]

    const hooks = await createPermissionAskWatchdog(ctx)
    await hooks.event(permissionAsked("ses_wd_02", "per_ask_A"))
    expect(jest.getTimerCount()).toBe(1)

    await advance(59_000)
    expect(replies).toEqual([])

    await advance(1_000)
    expect(listCalls).toEqual([{ sessionID: "ses_wd_02" }])
    // Exact object: V2 names only, no V1 `permission` / `patterns` leakage.
    expect(replies).toEqual([
      { sessionID: "ses_wd_02", requestID: "per_ask_A", decision: "reject" },
    ])
    await hooks.dispose()
  })

  test("3: no reply when the ask already left permission.list", async () => {
    process.env[THRESHOLD_ENV] = "1"
    const { ctx, listCalls, replies } = fakeCtx() // pending stays []

    const hooks = await createPermissionAskWatchdog(ctx)
    // Dotted V2 event name (needs-input-observer.ts:1531) arming path.
    await hooks.event(permissionV2Asked("ses_wd_03", "per_ask_GONE"))
    expect(jest.getTimerCount()).toBe(1)

    await advance(60_000)
    expect(listCalls).toEqual([{ sessionID: "ses_wd_03" }])
    expect(replies).toEqual([])
  })

  test("4: exactly one reply for two pending asks in the same session", async () => {
    process.env[THRESHOLD_ENV] = "1"
    const { ctx, state, replies } = fakeCtx()
    state.pending = [
      {
        id: "per_ask_A",
        sessionID: "ses_wd_04",
        action: "bash",
        resources: ["git push"],
      },
      {
        id: "per_ask_B",
        sessionID: "ses_wd_04",
        action: "edit",
        resources: ["src/app.ts"],
      },
    ]

    const hooks = await createPermissionAskWatchdog(ctx)
    await hooks.event(permissionAsked("ses_wd_04", "per_ask_A"))
    await hooks.event(permissionAsked("ses_wd_04", "per_ask_B"))
    expect(jest.getTimerCount()).toBe(2)

    // Both timers come due at the same moment. Whichever fires first rejects
    // the whole session, so the second must stay silent (its `list` call shows
    // the ask gone) - one reject, one reply, no per-ask loop.
    await advance(60_000)
    await advance(60_000)

    expect(replies).toHaveLength(1)
    expect(replies[0].sessionID).toBe("ses_wd_04")
    expect(replies[0].decision).toBe("reject")
  })

  test("5: reply and reject events clear the ask's timer - no reply after the threshold", async () => {
    process.env[THRESHOLD_ENV] = "1"
    const { ctx, state, replies } = fakeCtx()
    state.pending = [
      {
        id: "per_ask_A",
        sessionID: "ses_wd_05",
        action: "bash",
        resources: ["git push"],
      },
      {
        id: "per_ask_B",
        sessionID: "ses_wd_05",
        action: "edit",
        resources: ["src/app.ts"],
      },
    ]

    const hooks = await createPermissionAskWatchdog(ctx)
    await hooks.event(permissionAsked("ses_wd_05", "per_ask_A"))
    await hooks.event(permissionAsked("ses_wd_05", "per_ask_B"))
    expect(jest.getTimerCount()).toBe(2)

    await hooks.event(permissionReplied("ses_wd_05", "per_ask_A"))
    await hooks.event(
      permissionReplied("ses_wd_05", "per_ask_B", "permission.rejected")
    )
    // Cleared, not merely ignored at expiry.
    expect(jest.getTimerCount()).toBe(0)

    await advance(5 * 60_000)
    expect(replies).toEqual([])
  })

  test("6: disabled threshold (0, empty, negative, non-numeric) arms no timer", async () => {
    for (const value of ["0", "", "-3", "abc"]) {
      process.env[THRESHOLD_ENV] = value
      const { ctx, state, replies } = fakeCtx()
      state.pending = [
        {
          id: "per_ask_A",
          sessionID: "ses_wd_06",
          action: "bash",
          resources: ["git push"],
        },
      ]

      const hooks = await createPermissionAskWatchdog(ctx)
      await hooks.event(permissionAsked("ses_wd_06", "per_ask_A"))
      const label = `threshold ${JSON.stringify(value)}`
      expect(jest.getTimerCount(), label).toBe(0)

      await advance(10 * 60_000)
      expect(replies, label).toEqual([])
      await hooks.dispose()
    }
  })

  test("7: session.deleted clears that session's timers; dispose clears the rest", async () => {
    process.env[THRESHOLD_ENV] = "1"
    const { ctx, state, replies } = fakeCtx()
    state.pending = [
      {
        id: "per_ask_A1",
        sessionID: "ses_wd_07A",
        action: "bash",
        resources: ["git push"],
      },
      {
        id: "per_ask_A2",
        sessionID: "ses_wd_07A",
        action: "edit",
        resources: ["src/app.ts"],
      },
      {
        id: "per_ask_B1",
        sessionID: "ses_wd_07B",
        action: "bash",
        resources: ["npm publish"],
      },
    ]

    const hooks = await createPermissionAskWatchdog(ctx)
    await hooks.event(permissionAsked("ses_wd_07A", "per_ask_A1"))
    await hooks.event(permissionAsked("ses_wd_07A", "per_ask_A2"))
    await hooks.event(permissionAsked("ses_wd_07B", "per_ask_B1"))
    expect(jest.getTimerCount()).toBe(3)

    await hooks.event(sessionDeleted("ses_wd_07A"))
    expect(jest.getTimerCount()).toBe(1) // only session B's ask survives

    await advance(60_000)
    expect(replies).toHaveLength(1)
    expect(replies[0].sessionID).toBe("ses_wd_07B")
    expect(replies[0].requestID).toBe("per_ask_B1")

    await hooks.dispose()
    expect(jest.getTimerCount()).toBe(0)
  })

  test("8: default threshold is 5 minutes when the env is unset", async () => {
    const { ctx, state, replies } = fakeCtx()
    state.pending = [
      {
        id: "per_ask_A",
        sessionID: "ses_wd_08",
        action: "bash",
        resources: ["git push"],
      },
    ]

    const hooks = await createPermissionAskWatchdog(ctx)
    await hooks.event(permissionAsked("ses_wd_08", "per_ask_A"))
    expect(jest.getTimerCount()).toBe(1)

    await advance(4 * 60_000 + 59_000)
    expect(replies).toEqual([])

    await advance(1_000)
    expect(replies).toHaveLength(1)
    expect(replies[0].decision).toBe("reject")
    await hooks.dispose()
  })
})
