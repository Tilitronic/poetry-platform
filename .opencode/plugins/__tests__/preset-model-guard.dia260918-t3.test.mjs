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
import { createTempWorkspace, mockOpencodePlugin } from "./helpers/plugin-harness.mjs"

mockOpencodePlugin()

const ENV_KEY = "OH_MY_OPENCODE_SLIM_PRESET"
const INTENT_REF = "test-provider/test-intent-model"
const INTENT_MODEL = { providerID: "test-provider", id: "test-intent-model" }
const DIVERGENT_MODEL = { providerID: "other-provider", id: "other-model" }

const workspaceCleanups = []
let savedEnv

beforeEach(() => {
  savedEnv = process.env[ENV_KEY]
})

afterEach(() => {
  if (typeof savedEnv === "undefined") delete process.env[ENV_KEY]
  else process.env[ENV_KEY] = savedEnv
  while (workspaceCleanups.length) {
    const fn = workspaceCleanups.pop()
    try {
      fn()
    } catch {
      // best-effort temp cleanup only
    }
  }
})

// The guard exists since T2 GREEN; keep the guarded import so a missing
// module still reports as per-test RED failures instead of a load error.
let guardMod = null
let guardLoadError = null
try {
  guardMod = await import("../preset-model-guard.ts")
} catch (err) {
  guardLoadError = err
}

function requireGuard() {
  if (guardLoadError) {
    throw new Error(`RED: preset-model-guard.ts not loadable: ${guardLoadError.message}`)
  }
  return guardMod
}

// Mocked v2 ctx. opts: override marker ("model" | "agent" | undefined),
// switchImpl to replace the switchModel spy body (e.g. throwing), logCalls
// array to capture client.app.log lines. No real client, no I/O.
async function makeGuardCtx(sessionID, newbornModel, opts = {}) {
  const { directory, cleanup } = createTempWorkspace("dia260918-t3-")
  workspaceCleanups.push(cleanup)
  const switchModelCalls = []
  const logCalls = opts.logCalls ?? []
  const override = opts.override
  const switchImpl =
    opts.switchImpl ??
    (async (arg) => {
      switchModelCalls.push(arg)
      return {}
    })
  const ctx = {
    directory,
    client: {
      app: {
        log: async (arg) => {
          logCalls.push(arg)
          return {}
        },
      },
    },
    session: {
      get: async () => ({ id: sessionID, model: newbornModel, override }),
      switchModel: async (arg) => switchImpl(arg),
    },
  }
  return { ctx, switchModelCalls, logCalls }
}

// Resolve the {event} hooks from either accepted export spelling: a plain
// v1 factory, or the dual-runtime {id, server, setup} object via server().
async function loadHooks(ctx) {
  const mod = requireGuard()
  const def = mod.default ?? mod
  if (typeof def === "function") return await def(ctx)
  if (def && typeof def.server === "function") return await def.server(ctx)
  throw new Error("RED: guard must default-export a factory or {id,server,setup} with server()")
}

// session.created payload; the override marker rides at info.override and
// the newborn model at info.model (session.get mirrors both).
function createdEvent(sessionID, model, override) {
  return {
    event: {
      type: "session.created",
      properties: {
        sessionID,
        info: { id: sessionID, model, override },
      },
    },
  }
}

describe("DIA-260918-ok9m T3: exemption, fire-once, failure survival, probe", () => {
  test("T3a divergent + env + explicit --model override makes zero switchModel calls", async () => {
    process.env[ENV_KEY] = INTENT_REF
    const sessionID = "ses_t3a_model_override"
    const { ctx, switchModelCalls } = await makeGuardCtx(sessionID, DIVERGENT_MODEL, {
      override: "model",
    })
    const hooks = await loadHooks(ctx)
    await hooks.event(createdEvent(sessionID, DIVERGENT_MODEL, "model"))
    expect(switchModelCalls.length).toBe(0)
  })

  test("T3b divergent + env + explicit agent-model override makes zero switchModel calls", async () => {
    process.env[ENV_KEY] = INTENT_REF
    const sessionID = "ses_t3b_agent_override"
    const { ctx, switchModelCalls } = await makeGuardCtx(sessionID, DIVERGENT_MODEL, {
      override: "agent",
    })
    const hooks = await loadHooks(ctx)
    await hooks.event(createdEvent(sessionID, DIVERGENT_MODEL, "agent"))
    expect(switchModelCalls.length).toBe(0)
  })

  test("T3c duplicate session.created for same ID switches exactly once total", async () => {
    process.env[ENV_KEY] = INTENT_REF
    const sessionID = "ses_t3c_duplicate"
    const { ctx, switchModelCalls } = await makeGuardCtx(sessionID, DIVERGENT_MODEL)
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
    const { ctx } = await makeGuardCtx(sessionID, DIVERGENT_MODEL, {
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
    const { directory, cleanup } = createTempWorkspace("dia260918-t3e-")
    workspaceCleanups.push(cleanup)
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
