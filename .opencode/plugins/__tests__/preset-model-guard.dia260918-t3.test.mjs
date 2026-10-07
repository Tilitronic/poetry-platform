/**
 * DIA-260918-ok9m T3 RED (test-author lane ONLY, DIA-175 instance separation).
 *
 * Same RED instance A as T1. GREEN instance B implements tasks.md 4.1 until
 * the failing tests below go green. This instance never touches the guard
 * file (.opencode/plugins/preset-model-guard.ts) or the T1 test file.
 *
 * Seams (per design.md, same pre-agreed seams as T1, no others):
 *   S1 v2 session.created event hook: T3a/T3b (override exemption), T3c
 *      (duplicate exactly-once), T3d (throwing-switchModel survival).
 *   S2 setup shape-probe branch: T3e (absent-switchModel degradation).
 *
 * Pinned override contract (GREEN must satisfy exactly this; the runtime
 * carries no standard --model marker on session.created, so the tests pin
 * one -- T1a fixtures carry no such key and must keep switching):
 *   - properties.info.override === "model" signals an explicit --model flag.
 *   - properties.info.override === "agent" signals an explicit agent-model
 *     selection.
 *   - Either value with a divergent model and valid env -> zero calls.
 *   - The marker rides redundantly in the session.get() response, so GREEN
 *     may read the event or session.get -- both carry the same signal.
 *
 * Each test uses a unique ses_t3* session ID so the module-scope fired-set
 * (design D2) cannot leak between tests in one worker, and cannot collide
 * with the ses_t1* IDs when T1+T3 run in one bun process.
 *
 * Test plan in plain language:
 *   - T3a divergent + env + --model override -> zero calls (exemption).
 *   - T3b divergent + env + agent-model override -> zero calls (exemption).
 *   - T3c same session ID delivered twice -> exactly one call total.
 *   - T3d switchModel rejects -> event resolves (no crash), exactly one
 *     attempt (no retry), exactly one log line, session keeps newborn model.
 *   - T3e setup() with a switchModel-less ctx -> returns void (registers
 *     nothing) and logs exactly one line naming the guard or the gap.
 *
 * Hermetic: fresh mkdtemp workspace per test, mocked ctx only, env var
 * snapshotted in beforeEach and restored in afterEach.
 *
 * ASCII-only per DIA-079 (no em-dashes, no smart quotes, no non-ASCII).
 *
 * RUN (from inside __tests__ -- bun test skips dot-directories, so a path
 * filter from the repo root does NOT match):
 *   cd /workspace/.opencode/plugins/__tests__ && \
 *     bun test preset-model-guard.dia260918-t3.test.mjs
 *
 * RED expectation on the T2 guard: T3a/T3b fail (no override detection --
 * one stray switch each) and T3e fails (setup is a silent stub -- zero log
 * lines). T3c/T3d already pass because T2 landed the fired-set (D2) and the
 * switchModel try/catch early; they pin that behavior so T4 keeps it green.
 */
import { test, expect, describe, beforeEach, afterEach } from "bun:test"
import { mockOpencodePlugin } from "./helpers/plugin-harness.mjs"
import {
  ENV_KEY,
  INTENT_REF,
  INTENT_MODEL,
  DIVERGENT_MODEL,
  snapshotEnv,
  restoreEnv,
  createCleanupTracker,
  createGuardHandle,
  makeTempDir,
  makeGuardCtx,
  createdEvent,
} from "./helpers/preset-model-guard-fixture.mjs"

mockOpencodePlugin()

// Shared harness lives in helpers/preset-model-guard-fixture.mjs (T5
// extraction); payloads and call shapes here are unchanged.
const workspaces = createCleanupTracker()
let savedEnv

beforeEach(() => {
  savedEnv = snapshotEnv()
})

afterEach(() => {
  restoreEnv(savedEnv)
  workspaces.drain()
})

// Guard handle (import + hooks resolver) comes from the shared fixture;
// T3e also needs requireGuard for the S2 setup probe.
const { requireGuard, loadHooks } = await createGuardHandle()

describe("DIA-260918-ok9m T3: exemption, fire-once, failure survival, probe", () => {
  test("T3a divergent + env + explicit --model override makes zero switchModel calls", async () => {
    process.env[ENV_KEY] = INTENT_REF
    const sessionID = "ses_t3a_model_override"
    const { ctx, switchModelCalls } = await makeGuardCtx(workspaces, sessionID, DIVERGENT_MODEL, {
      override: "model",
    })
    const hooks = await loadHooks(ctx)
    await hooks.event(createdEvent(sessionID, DIVERGENT_MODEL, "model"))
    expect(switchModelCalls.length).toBe(0)
  })

  test("T3b divergent + env + explicit agent-model override makes zero switchModel calls", async () => {
    process.env[ENV_KEY] = INTENT_REF
    const sessionID = "ses_t3b_agent_override"
    const { ctx, switchModelCalls } = await makeGuardCtx(workspaces, sessionID, DIVERGENT_MODEL, {
      override: "agent",
    })
    const hooks = await loadHooks(ctx)
    await hooks.event(createdEvent(sessionID, DIVERGENT_MODEL, "agent"))
    expect(switchModelCalls.length).toBe(0)
  })

  test("T3c duplicate session.created for same ID switches exactly once total", async () => {
    process.env[ENV_KEY] = INTENT_REF
    const sessionID = "ses_t3c_duplicate"
    const { ctx, switchModelCalls } = await makeGuardCtx(workspaces, sessionID, DIVERGENT_MODEL)
    const hooks = await loadHooks(ctx)
    await hooks.event(createdEvent(sessionID, DIVERGENT_MODEL))
    await hooks.event(createdEvent(sessionID, DIVERGENT_MODEL))
    expect(switchModelCalls.length).toBe(1)
    expect(switchModelCalls[0].sessionID).toBe(sessionID)
    expect(switchModelCalls[0].model.providerID).toBe(INTENT_MODEL.providerID)
    expect(switchModelCalls[0].model.id).toBe(INTENT_MODEL.id)
  })

  test("T3d rejecting switchModel survives: no crash, one attempt, one log line", async () => {
    process.env[ENV_KEY] = INTENT_REF
    const sessionID = "ses_t3d_throwing"
    const switchModelCalls = []
    const logCalls = []
    const { ctx } = await makeGuardCtx(workspaces, sessionID, DIVERGENT_MODEL, {
      logCalls,
      switchImpl: async (arg) => {
        switchModelCalls.push(arg)
        throw new Error("boom: model service down")
      },
    })
    const hooks = await loadHooks(ctx)
    let threw = null
    try {
      await hooks.event(createdEvent(sessionID, DIVERGENT_MODEL))
    } catch (err) {
      threw = err
    }
    expect(threw).toBe(null)
    expect(switchModelCalls.length).toBe(1)
    expect(logCalls.length).toBe(1)
  })

  test("T3e setup probe with absent switchModel registers nothing and logs one line", async () => {
    const mod = requireGuard()
    const def = mod.default ?? mod
    expect(typeof def.setup).toBe("function")
    const directory = makeTempDir(workspaces, "dia260918-t3e-")
    const logCalls = []
    // v1-shaped ctx: session surface exists but switchModel is absent.
    const probeCtx = {
      directory,
      client: {
        app: {
          log: async (arg) => {
            logCalls.push(arg)
            return {}
          },
        },
      },
      session: {},
    }
    let threw = null
    let result
    try {
      result = await def.setup(probeCtx)
    } catch (err) {
      threw = err
    }
    expect(threw).toBe(null)
    expect(result).toBeUndefined()
    expect(logCalls.length).toBe(1)
    expect(/preset-model-guard|switchModel|shape|probe|v1/i.test(JSON.stringify(logCalls[0]))).toBe(true)
  })
})
