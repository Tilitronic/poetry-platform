/**
 * DIA-260918-ok9m T5 RED (fix-loop additions, same RED instance A; T4 GREEN
 * done). Test-author ONLY: this instance never touches the guard file.
 *
 * Reviewer-found production-contract gaps pinned here (unique ses_t5* IDs,
 * same bun:test harness family via the shared fixture):
 *   T5a preset-NAME env (e.g. OH_MY_OPENCODE_SLIM_PRESET=free, no slash)
 *      with a divergent newborn -> ONE switchModel call carrying the preset
 *      mapped model. The mapped model is read live from the repo config
 *      (presets.free.orchestrator.model, first array entry), so the
 *      expectation tracks the presets block instead of a hardcoded copy.
 *      Pinned rule for GREEN: a slash-less env value resolves as a preset
 *      name through presets[<name>].orchestrator.model; the "provider/model"
 *      spelling from T1 keeps working unchanged.
 *   T5b event-time shape drift: divergent + env + ctx.session WITHOUT
 *      switchModel -> zero calls AND exactly one log line naming the gap.
 *      Zero calls is structural (no surface to call); the line is the
 *      drift-visibility requirement. The session object itself must stay
 *      untouched (no keys installed by the guard).
 *   T5c concurrent duplicates: two session.created for the same ID
 *      dispatched without awaiting between them -> exactly one call total
 *      carrying the intent. Pins that check-then-add is not split by an
 *      await (JS run-to-completion keeps the current sync span atomic).
 *
 * Hermetic: fresh mkdtemp workspace per test, mocked ctx only, env var
 * snapshotted in beforeEach and restored in afterEach.
 *
 * ASCII-only per DIA-079 (no em-dashes, no smart quotes, no non-ASCII).
 *
 * RUN (from inside __tests__):
 *   cd /workspace/.opencode/plugins/__tests__ && \
 *     bun test preset-model-guard.dia260918-t5.test.mjs
 *
 * RED expectation on the current guard: T5a fails (slash-split only, so a
 * preset name parses to nothing and no switch happens) and T5b fails (the
 * missing switchModel short-circuits silently with zero log lines). T5c
 * already passes (no await sits between the fired check and the add) and
 * pins that invariant for the fix loop to keep green.
 */
import { test, expect, describe, beforeEach, afterEach } from "bun:test"
import { readFileSync } from "node:fs"
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

const workspaces = createCleanupTracker()
let savedEnv

beforeEach(() => {
  savedEnv = snapshotEnv()
})

afterEach(() => {
  restoreEnv(savedEnv)
  workspaces.drain()
})

const { loadHooks } = await createGuardHandle()
// Single-owner JSONC stripper (rev-1 Major): owned by preset-model-guard.ts,
// shared here for the T5a live-config read instead of a duplicated copy.
const { stripJsoncComments } = await import("../preset-model-guard.ts")

// Preset-NAME intent source of truth, read live from the repo config:
// presets.free.orchestrator.model, first entry on array form ("a/b" split
// gives {providerID, id}; a plain string works the same way).
function resolveFreeOrchestratorModel() {
  const raw = readFileSync(new URL("../../oh-my-opencode-slim.jsonc", import.meta.url), "utf-8")
  const config = JSON.parse(stripJsoncComments(raw))
  const entry = config?.presets?.free?.orchestrator?.model
  const ref = Array.isArray(entry) ? entry[0] : entry
  if (typeof ref !== "string" || !ref.includes("/")) {
    throw new Error(`T5a setup: presets.free.orchestrator.model has no usable ref, got ${JSON.stringify(ref)}`)
  }
  const slash = ref.indexOf("/")
  return { providerID: ref.slice(0, slash), id: ref.slice(slash + 1) }
}

describe("DIA-260918-ok9m T5: preset-name intent, drift visibility, concurrent fire-once", () => {
  test("T5a preset-NAME env resolves via presets block and switches divergent newborn once", async () => {
    const mapped = resolveFreeOrchestratorModel()
    if (mapped.providerID === DIVERGENT_MODEL.providerID && mapped.id === DIVERGENT_MODEL.id) {
      throw new Error("T5a setup: mapped free model collides with DIVERGENT_MODEL, pick another divergent model")
    }
    process.env[ENV_KEY] = "free"
    const sessionID = "ses_t5a_preset_name"
    const { ctx, switchModelCalls } = await makeGuardCtx(workspaces, sessionID, DIVERGENT_MODEL)
    const hooks = await loadHooks(ctx)
    await hooks.event(createdEvent(sessionID, DIVERGENT_MODEL))
    expect(switchModelCalls.length).toBe(1)
    expect(switchModelCalls[0].sessionID).toBe(sessionID)
    expect(switchModelCalls[0].model.providerID).toBe(mapped.providerID)
    expect(switchModelCalls[0].model.id).toBe(mapped.id)
  })

  test("T5b event-time shape drift without switchModel logs exactly one line and never crashes", async () => {
    process.env[ENV_KEY] = INTENT_REF
    const sessionID = "ses_t5b_drift"
    const logCalls = []
    const { ctx } = await makeGuardCtx(workspaces, sessionID, DIVERGENT_MODEL, {
      logCalls,
      omitSwitchModel: true,
    })
    const hooks = await loadHooks(ctx)
    let threw = null
    try {
      await hooks.event(createdEvent(sessionID, DIVERGENT_MODEL))
    } catch (err) {
      threw = err
    }
    expect(threw).toBe(null)
    expect(typeof ctx.session.switchModel).toBe("undefined")
    expect(logCalls.length).toBe(1)
    expect(/preset-model-guard|switchModel|drift|shape|v1|register/i.test(JSON.stringify(logCalls[0]))).toBe(true)
  })

  test("T5c concurrent duplicate session.created for same ID switches exactly once total", async () => {
    process.env[ENV_KEY] = INTENT_REF
    const sessionID = "ses_t5c_concurrent"
    const { ctx, switchModelCalls } = await makeGuardCtx(workspaces, sessionID, DIVERGENT_MODEL)
    const hooks = await loadHooks(ctx)
    const first = hooks.event(createdEvent(sessionID, DIVERGENT_MODEL))
    const second = hooks.event(createdEvent(sessionID, DIVERGENT_MODEL))
    await Promise.all([first, second])
    expect(switchModelCalls.length).toBe(1)
    expect(switchModelCalls[0].sessionID).toBe(sessionID)
    expect(switchModelCalls[0].model.providerID).toBe(INTENT_MODEL.providerID)
    expect(switchModelCalls[0].model.id).toBe(INTENT_MODEL.id)
  })
})
