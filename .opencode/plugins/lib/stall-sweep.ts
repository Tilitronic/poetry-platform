/**
 * stall-sweep seam — SRP extraction (Slice 5, DIA-260902-eqgg).
 *
 * Verbatim move of the stall-sweep logic from delegation-observer.ts
 * (stallThresholdMinutes, STALL_SWEEP_INTERVAL_MS, STALL_SWEEP_KEY,
 * sweepStalledSessions, sessionRoleFromRows, stall timer dedup) as a
 * pure/DI'd lib: no ctx capture, no shell import, inject timer/clock.
 *
 * Shell owns globalThis[STALL_SWEEP_KEY] handle (passed as handleStore);
 * D1: timer-async with sync sweep body.
 */

// ---------------------------------------------------------------------------
// Constants / env helper (verbatim from delegation-observer.ts)
// ---------------------------------------------------------------------------

export function stallThresholdMinutes(envName: string, fallback: number): number {
  const raw = process.env[envName]
  if (!raw) return fallback
  const parsed = Number.parseInt(raw, 10)
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback
}

export const STALL_SWEEP_INTERVAL_MS = 60_000
export const STALL_SWEEP_KEY = Symbol.for("delegation-observer.stallSweepInterval")

// ---------------------------------------------------------------------------
// Internal narrow types / state sets (verbatim)
// ---------------------------------------------------------------------------

interface RegistryRow {
  timestamp?: string
  session_id?: string
  task_id?: string
  dispatch_state?: string
  event?: string
  status?: string
  role?: string
  parent_session?: string
  escalation?: string
  [key: string]: unknown
}

const TERMINAL_STATES = new Set(["completed", "failed"])
const NON_TERMINAL_STATES = new Set(["invoked", "running"])

// ---------------------------------------------------------------------------
// DI factory
// ---------------------------------------------------------------------------

export interface StallSweepThresholds {
  subagent: number
  orchestrator: number
  dead: number
}

export interface StallSweepDeps {
  setInterval?: typeof setInterval
  clearInterval?: typeof clearInterval
  now?: () => number
  readRegistryRows?: () => RegistryRow[]
  emitStall?: (key: string, row: RegistryRow, ageSec: number, thresholdMin: number, escalation?: "dead") => void
  pluginLoadMs?: number
  thresholds?: Partial<StallSweepThresholds>
  handleStore?: Record<symbol, unknown>
  onError?: (err: unknown) => void
  getRootSessionIds?: () => Set<string>
  getSessionMeta?: (key: string) => { role?: string } | undefined
}

export interface StallSweepHandle {
  start(): void
  dispose(): void
  sweep(): void
  getFirstDone(): boolean
}

function sessionRoleFromRows(
  key: string,
  rows: RegistryRow[],
  getRootSessionIds?: () => Set<string>,
  getSessionMeta?: (key: string) => { role?: string } | undefined
): "subagent" | "orchestrator" | "unknown" {
  // Resolution order MUST preserve deleted shell behavior (DIA-260827-y9n9):
  // 1) authoritative root/session metadata FIRST
  // 2) registry-row fallback SECOND
  try {
    if (getRootSessionIds) {
      const roots = getRootSessionIds()
      if (roots.has(key)) return "orchestrator"
    }
  } catch { /* noop */ }
  try {
    if (getSessionMeta) {
      const meta = getSessionMeta(key)
      if (meta?.role === "orchestrator") return "orchestrator"
    }
  } catch { /* noop */ }
  for (const r of rows) {
    if ((r.session_id ?? r.task_id) !== key) continue
    if (r.role === "orchestrator") return "orchestrator"
  }
  let sawSubagent = false
  for (const r of rows) {
    if ((r.session_id ?? r.task_id) !== key) continue
    if (r.role === "subagent") sawSubagent = true
    if (r.parent_session && r.parent_session !== r.session_id) sawSubagent = true
  }
  return sawSubagent ? "subagent" : "unknown"
}

export function createStallSweep(deps: StallSweepDeps = {}): StallSweepHandle {
  const setIntervalFn = (deps.setInterval ?? globalThis.setInterval) as typeof setInterval
  const clearIntervalFn = (deps.clearInterval ?? globalThis.clearInterval) as typeof clearInterval
  const now = deps.now ?? Date.now
  const readRegistryRows = deps.readRegistryRows ?? (() => [] as RegistryRow[])
  const emitStall = deps.emitStall ?? (() => {})
  const pluginLoadMs = deps.pluginLoadMs ?? 0
  const onError = deps.onError ?? (() => {})
  const handleStore = (deps.handleStore ?? (globalThis as unknown as Record<symbol, unknown>)) as Record<symbol, unknown>
  const getRootSessionIds = deps.getRootSessionIds
  const getSessionMeta = deps.getSessionMeta

  // thresholds default verbatim (env-aware): stallThresholdMinutes fallback 10/20/60
  const thresholds: StallSweepThresholds = {
    subagent: deps.thresholds?.subagent ?? stallThresholdMinutes("STALL_SUBAGENT_MINUTES", 10),
    orchestrator: deps.thresholds?.orchestrator ?? stallThresholdMinutes("STALL_ORCHESTRATOR_MINUTES", 20),
    dead: deps.thresholds?.dead ?? stallThresholdMinutes("STALL_DEAD_MINUTES", 60),
  }

  let stallSweepFirstDone = false
  let inFlight = false

  function sweep(): void {
    if (inFlight) return
    inFlight = true
    try {
      let rows: RegistryRow[]
      try {
        rows = readRegistryRows()
      } catch (e) {
        try {
          onError(e)
        } catch { /* noop */ }
        return
      }

      const latestByKey = new Map<string, RegistryRow>()
      for (const r of rows) {
        try {
          if (typeof r.dispatch_state !== "string") continue
          const key = (r.session_id ?? r.task_id) as string | undefined
          if (!key) continue
          const prev = latestByKey.get(key)
          if (!prev || (r.timestamp ?? "") >= (prev.timestamp ?? "")) {
            latestByKey.set(key, r)
          }
        } catch (e) {
          try { onError(e) } catch { /* noop */ }
          continue
        }
      }

      if (latestByKey.size === 0) {
        stallSweepFirstDone = true
        return
      }

      const lastStallByKey = new Map<string, number>()
      const lastDeadByKey = new Map<string, number>()
      for (const r of rows) {
        try {
          if (r.event !== "stall_detected") continue
          const key = (r.session_id ?? r.task_id) as string | undefined
          if (!key) continue
          const ts = Date.parse(r.timestamp ?? "")
          if (Number.isNaN(ts)) continue
          const tier = r.escalation === "dead" ? lastDeadByKey : lastStallByKey
          const prev = tier.get(key)
          if (prev === undefined || ts > prev) tier.set(key, ts)
        } catch (e) {
          try { onError(e) } catch { /* noop */ }
          continue
        }
      }

      const nowMs = now()
      const isFirstSweep = !stallSweepFirstDone
      for (const [key, row] of latestByKey) {
        try {
          if (TERMINAL_STATES.has(row.dispatch_state ?? "")) continue
          if (row.event === "silent_failure_alert") continue
          if (!NON_TERMINAL_STATES.has(row.dispatch_state ?? "")) continue
          const ts = Date.parse(row.timestamp ?? "")
          if (Number.isNaN(ts)) continue
          if (isFirstSweep && ts < pluginLoadMs) continue
          const ageSec = Math.max(0, Math.floor((nowMs - ts) / 1000))
          const role = sessionRoleFromRows(key, rows, getRootSessionIds, getSessionMeta)
          const thresholdMin = role === "orchestrator" ? thresholds.orchestrator : thresholds.subagent

          if (ageSec >= thresholds.dead * 60) {
            const lastDead = lastDeadByKey.get(key)
            if (lastDead !== undefined && nowMs - lastDead < thresholds.dead * 60_000) continue
            emitStall(key, row, ageSec, thresholds.dead, "dead")
            continue
          }
          if (ageSec < thresholdMin * 60) continue
          const lastStall = lastStallByKey.get(key)
          if (lastStall !== undefined && nowMs - lastStall < thresholdMin * 60_000) continue
          emitStall(key, row, ageSec, thresholdMin, undefined)
        } catch (e) {
          try { onError(e) } catch { /* noop */ }
          continue
        }
      }
      stallSweepFirstDone = true
    } catch (e) {
      try { onError(e) } catch { /* noop */ }
    } finally {
      inFlight = false
    }
  }

  function start(): void {
    const prior = handleStore[STALL_SWEEP_KEY] as ReturnType<typeof setInterval> | undefined
    if (prior !== undefined) {
      try {
        clearIntervalFn(prior as unknown as number)
      } catch (e) {
        try { onError(e) } catch { /* noop */ }
      }
    }
    let handle: ReturnType<typeof setInterval>
    try {
      handle = (setIntervalFn as unknown as (fn: () => void, ms: number) => ReturnType<typeof setInterval>)(() => {
        try {
          sweep()
        } catch (err) {
          try { onError(err) } catch { /* noop */ }
        }
      }, STALL_SWEEP_INTERVAL_MS)
    } catch (e) {
      try { onError(e) } catch { /* noop */ }
      return
    }
    try {
      handleStore[STALL_SWEEP_KEY] = handle as unknown
    } catch (e) {
      try { onError(e) } catch { /* noop */ }
    }
  }

  function dispose(): void {
    const handle = handleStore[STALL_SWEEP_KEY] as ReturnType<typeof setInterval> | undefined
    if (handle !== undefined) {
      try {
        clearIntervalFn(handle as unknown as number)
      } catch (e) {
        try { onError(e) } catch { /* noop */ }
      }
    }
    try {
      delete (handleStore as Record<symbol, unknown>)[STALL_SWEEP_KEY]
      if ((handleStore as Record<symbol, unknown>)[STALL_SWEEP_KEY] !== undefined) {
        ;(handleStore as Record<symbol, unknown>)[STALL_SWEEP_KEY] = undefined as unknown as never
      }
    } catch (e) {
      try { onError(e) } catch { /* noop */ }
      try {
        ;(handleStore as Record<symbol, unknown>)[STALL_SWEEP_KEY] = undefined as unknown as never
      } catch { /* noop */ }
    }
  }

  return {
    start,
    dispose,
    sweep,
    getFirstDone: () => stallSweepFirstDone,
  }
}

// Probe-compatible aliases (tests probe all shapes)
