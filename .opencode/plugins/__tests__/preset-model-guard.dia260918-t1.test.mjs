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

// Guard handle (import + event-seam hooks resolver) comes from the shared
// fixture; T1 only drives the event seam, so it takes loadHooks alone.
const { loadHooks } = await createGuardHandle()

describe("DIA-260918-ok9m T1: session.created model guard core decision", () => {
  test("T1a divergent newborn + env set + no override switches exactly once to preset intent", async () => {
    process.env[ENV_KEY] = INTENT_REF
    const sessionID = "ses_t1a_divergent"
    const { ctx, switchModelCalls } = await makeGuardCtx(workspaces, sessionID, DIVERGENT_MODEL)
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
    const { ctx, switchModelCalls } = await makeGuardCtx(workspaces, sessionID, INTENT_MODEL)
    const hooks = await loadHooks(ctx)
    await hooks.event(createdEvent(sessionID, INTENT_MODEL))
    expect(switchModelCalls.length).toBe(0)
  })

  test("T1c env absent leaves session untouched with zero switchModel calls", async () => {
    delete process.env[ENV_KEY]
    const sessionID = "ses_t1c_env_absent"
    const { ctx, switchModelCalls } = await makeGuardCtx(workspaces, sessionID, DIVERGENT_MODEL)
    const hooks = await loadHooks(ctx)
    await hooks.event(createdEvent(sessionID, DIVERGENT_MODEL))
    expect(switchModelCalls.length).toBe(0)
  })
})
