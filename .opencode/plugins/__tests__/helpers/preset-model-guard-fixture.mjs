/**
 * Shared harness for the preset-model-guard suites (T1/T3/T5, DIA-260918-ok9m).
 *
 * WHY one fixture: T1/T3/T5 drive the same S1 event seam with the same
 * mocked v2 ctx shape; duplicating the factory across three files invites
 * drift (a T5 mock edit silently changing what T1 pins). The fixture owns
 * payload shapes; test files own expectations only.
 *
 * Payload-shape guarantee: marker-less fixtures build byte-identical event
 * and session.get payloads to the pre-extraction T1/T3 versions (override
 * keys are added only when defined), so thinning T1/T3 to this file
 * changes no behavior. Unique ses_t* ID discipline stays per test file.
 *
 * No module-level mutable state: everything is a factory or a constant,
 * so T1/T3/T5 sharing one bun process cannot leak state via this file.
 *
 * ASCII-only per DIA-079 (no em-dashes, no smart quotes, no non-ASCII).
 */
import { createTempWorkspace } from "./plugin-harness.mjs"

export const ENV_KEY = "OH_MY_OPENCODE_SLIM_PRESET"
// Independent source of truth: fully-qualified model ref; INTENT_MODEL is the
// literal split of this string, not recomputed by the guard.
export const INTENT_REF = "test-provider/test-intent-model"
export const INTENT_MODEL = { providerID: "test-provider", id: "test-intent-model" }
export const DIVERGENT_MODEL = { providerID: "other-provider", id: "other-model" }

export function snapshotEnv() {
  return process.env[ENV_KEY]
}

export function restoreEnv(saved) {
  if (typeof saved === "undefined") delete process.env[ENV_KEY]
  else process.env[ENV_KEY] = saved
}

// Per-file workspace tracker: one instance per test file keeps temp-dir
// cleanup isolated when T1/T3/T5 share a bun process.
export function createCleanupTracker() {
  const cleanups = []
  return {
    track(fn) {
      cleanups.push(fn)
    },
    drain() {
      while (cleanups.length) {
        const fn = cleanups.pop()
        try {
          fn()
        } catch {
          // best-effort temp cleanup only
        }
      }
    },
  }
}

// Bare temp dir for tests that need no ctx (e.g. the S2 setup probe).
export function makeTempDir(tracker, prefix) {
  const { directory, cleanup } = createTempWorkspace(prefix)
  tracker.track(cleanup)
  return directory
}

// Guarded guard import (a missing module reports as per-test RED failures,
// not a load error) plus the {event} hooks resolver accepting either
// export spelling: plain v1 factory or dual-runtime {id,server,setup}.
export async function createGuardHandle() {
  let guardMod = null
  let guardLoadError = null
  try {
    guardMod = await import("../../preset-model-guard.ts")
  } catch (err) {
    guardLoadError = err
  }
  function requireGuard() {
    if (guardLoadError) {
      throw new Error(`RED: preset-model-guard.ts not loadable: ${guardLoadError.message}`)
    }
    return guardMod
  }
  async function loadHooks(ctx) {
    const mod = requireGuard()
    const def = mod.default ?? mod
    if (typeof def === "function") return await def(ctx)
    if (def && typeof def.server === "function") return await def.server(ctx)
    throw new Error("RED: guard must default-export a factory or {id,server,setup} with server()")
  }
  return { requireGuard, loadHooks }
}

// Mocked v2 ctx: session.get reports the newborn model (plus the override
// marker when given), session.switchModel is a spy capturing every call,
// client.app.log captures log lines. opts: override ("model" | "agent"),
// switchImpl to replace the spy body (e.g. throwing), logCalls array to
// share with the caller, omitSwitchModel to simulate event-time shape
// drift (no switchModel on the session surface at all). No real client.
export async function makeGuardCtx(tracker, sessionID, newbornModel, opts = {}) {
  const { directory, cleanup } = createTempWorkspace("dia260918-tx-")
  tracker.track(cleanup)
  const switchModelCalls = []
  const logCalls = opts.logCalls ?? []
  const switchImpl =
    opts.switchImpl ??
    (async (arg) => {
      switchModelCalls.push(arg)
      return {}
    })
  const record = { id: sessionID, model: newbornModel }
  if (opts.override !== undefined) record.override = opts.override
  const session = {
    get: async () => ({ ...record }),
  }
  if (!opts.omitSwitchModel) {
    session.switchModel = async (arg) => switchImpl(arg)
  }
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
    session,
  }
  return { ctx, switchModelCalls, logCalls }
}

// session.created payload in the v1 properties.info shape; the newborn
// model rides at info.model and the override marker at info.override
// (added only when defined, so marker-less fixtures carry no extra key).
export function createdEvent(sessionID, model, override) {
  const info = { id: sessionID, model }
  if (override !== undefined) info.override = override
  return {
    event: {
      type: "session.created",
      properties: { sessionID, info },
    },
  }
}
