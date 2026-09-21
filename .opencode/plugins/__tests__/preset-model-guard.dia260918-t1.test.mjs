/**
 * DIA-260918-ok9m T1 RED (test-author lane ONLY, DIA-175 instance separation).
 *
 * This file is written by RED instance A. It must FAIL against the current
 * tree because .opencode/plugins/preset-model-guard.ts does not exist yet.
 * GREEN instance B (a different session) implements the guard until these
 * tests go green. This instance never implements the guard.
 *
 * Seams under test (per design.md, pre-agreed with developer, no others):
 *   S1 v2 session.created event hook of the new guard file. ALL behavior
 *      tests live here, driven through the same "event" channel family as
 *      the delegation-observer seam: hooks.event({event:{type, properties}}).
 *   S2 setup shape-probe branch is slice 2 (T3), not covered here.
 *
 * Assumed guard contract (GREEN must satisfy exactly this):
 *   - Module: ../preset-model-guard.ts, default-exporting either a v1
 *     factory function (ctx) => hooks, or the dual-runtime v2 shape
 *     {id, server, setup} per OMO dist/v2/index.d.ts:4-6, where server(ctx)
 *     returns the {event} hooks. The resolver below accepts both spellings.
 *   - The event hook reads preset intent from OH_MY_OPENCODE_SLIM_PRESET.
 *     T1 pins the fully-qualified model-ref spelling "provider/model"
 *     (split on "/" gives {providerID, id}); preset-name lookup is a
 *     GREEN extension that must not break this spelling.
 *   - The newborn model M is carried redundantly in the fixture at
 *     properties.info.model AND via ctx.session.get(), so GREEN may read
 *     either path without breaking these tests.
 *   - The switchModel call shape follows the v2 session surface:
 *     switchModel({sessionID, model:{providerID, id}}).
 *   - Fixtures carry no explicit-override marker, so slice-2 override
 *     exemption logic must default to "act" for these payloads.
 *   - Each test uses a unique session ID so the module-scope fired-set
 *     (design D2) cannot leak between tests in one worker.
 *
 * Test plan in plain language:
 *   - T1a divergent newborn + env set + no override -> exactly one
 *     switchModel call carrying the preset intent.
 *   - T1b already-correct newborn (M equals P) -> zero calls.
 *   - T1c env absent -> zero calls, session untouched.
 *   Deliberately NOT here (slice 2, task 3.1): override exemption,
 *   duplicate-event exactly-once, throwing-switchModel survival, S2 probe.
 *
 * Hermetic: fresh mkdtemp workspace per test, mocked ctx only (no real
 * client, no filesystem writes outside the temp dir, no subprocess).
 * Env var is snapshotted in beforeEach and restored in afterEach so the
 * fixture never leaks between same-worker tests.
 *
 * ASCII-only per DIA-079 (no em-dashes, no smart quotes, no non-ASCII).
 *
 * RUN (bun in poetry-dev container, from inside __tests__ -- bun test
 * skips dot-directories in default discovery so a path filter from the
 * repo root does NOT match):
 *   cd /workspace/.opencode/plugins/__tests__ && \
 *     bun test preset-model-guard.dia260918-t1.test.mjs
 *
 * RED expectation: all 3 tests fail because the guard module is missing.
 */
import { test, expect, describe, beforeEach, afterEach } from "bun:test"
import { createTempWorkspace, mockOpencodePlugin } from "./helpers/plugin-harness.mjs"

mockOpencodePlugin()

const ENV_KEY = "OH_MY_OPENCODE_SLIM_PRESET"
// Independent source of truth: fully-qualified model ref; the intent model
// below is the literal split of this string, not recomputed by the guard.
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

// The guard file does not exist yet (GREEN instance B creates it). Catch
// the import failure here so each test reports it as a RED failure instead
// of a module load error; the branch goes cold once GREEN lands.
let guardMod = null
let guardLoadError = null
try {
  guardMod = await import("../preset-model-guard.ts")
} catch (err) {
  guardLoadError = err
}

function requireGuard() {
  if (guardLoadError) {
    throw new Error(`RED: preset-model-guard.ts not implemented yet: ${guardLoadError.message}`)
  }
  return guardMod
}

// Mocked v2 ctx: session.get reports the newborn model, session.switchModel
// is a spy capturing every call. No real client, no I/O.
async function makeGuardCtx(sessionID, newbornModel) {
  const { directory, cleanup } = createTempWorkspace("dia260918-t1-")
  workspaceCleanups.push(cleanup)
  const switchModelCalls = []
  const ctx = {
    directory,
    client: { app: { log: async () => {} } },
    session: {
      get: async () => ({ id: sessionID, model: newbornModel }),
      switchModel: async (arg) => {
        switchModelCalls.push(arg)
        return {}
      },
    },
  }
  return { ctx, switchModelCalls }
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

// session.created payload in the v1 properties.info shape; the newborn
// model rides redundantly at properties.info.model (GREEN may read the
// event or session.get -- both carry the same model).
function createdEvent(sessionID, model) {
  return {
    event: {
      type: "session.created",
      properties: {
        sessionID,
        info: { id: sessionID, model },
      },
    },
  }
}

describe("DIA-260918-ok9m T1: session.created model guard core decision", () => {
  test("T1a divergent newborn + env set + no override switches exactly once to preset intent", async () => {
    process.env[ENV_KEY] = INTENT_REF
    const sessionID = "ses_t1a_divergent"
    const { ctx, switchModelCalls } = await makeGuardCtx(sessionID, DIVERGENT_MODEL)
    const hooks = await loadHooks(ctx)
    await hooks.event(createdEvent(sessionID, DIVERGENT_MODEL))
    expect(switchModelCalls.length).toBe(1)
    expect(switchModelCalls[0].sessionID).toBe(sessionID)
    expect(switchModelCalls[0].model.providerID).toBe(INTENT_MODEL.providerID)
    expect(switchModelCalls[0].model.id).toBe(INTENT_MODEL.id)
  })

  test("T1b already-correct newborn makes zero switchModel calls", async () => {
    process.env[ENV_KEY] = INTENT_REF
    const sessionID = "ses_t1b_already_correct"
    const { ctx, switchModelCalls } = await makeGuardCtx(sessionID, INTENT_MODEL)
    const hooks = await loadHooks(ctx)
    await hooks.event(createdEvent(sessionID, INTENT_MODEL))
    expect(switchModelCalls.length).toBe(0)
  })

  test("T1c env absent leaves session untouched with zero switchModel calls", async () => {
    delete process.env[ENV_KEY]
    const sessionID = "ses_t1c_env_absent"
    const { ctx, switchModelCalls } = await makeGuardCtx(sessionID, DIVERGENT_MODEL)
    const hooks = await loadHooks(ctx)
    await hooks.event(createdEvent(sessionID, DIVERGENT_MODEL))
    expect(switchModelCalls.length).toBe(0)
  })
})
