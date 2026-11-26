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
  last_stall_timestamp?: string
  last_dead_timestamp?: string
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
  readActiveEntries?: () => RegistryRow[]
  emitStall?: (key: string, row: RegistryRow, ageSec: number, thresholdMin: number, escalation?: "dead") => void
  compareAndAppendStall?: (candidate: {
    session_id?: string
    task_id?: string
    lifecycle_generation?: number
    tier: "stall" | "dead"
    row: RegistryRow
  }) => { ok: boolean; [key: string]: unknown }
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
    if (!r || typeof r !== "object") continue
    if ((r.session_id ?? r.task_id) !== key) continue
    if (r.role === "orchestrator") return "orchestrator"
  }
  let sawSubagent = false
  for (const r of rows) {
    if (!r || typeof r !== "object") continue
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
  const readSweepRows = deps.readActiveEntries ?? deps.readRegistryRows ?? (() => [] as RegistryRow[])
  const emitStall = deps.emitStall ?? (() => {})
  const compareAndAppendStall = deps.compareAndAppendStall ?? (() => ({ ok: true }))
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
  const reportedWarnings = new Set<string>()
  const MAX_REPORTED_WARNINGS = 32

  function reportWarning(error: unknown, fingerprint?: string): void {
    const message = error instanceof Error ? error.message : String(error)
    const key = fingerprint ?? message
    if (reportedWarnings.has(key)) return
    if (reportedWarnings.size >= MAX_REPORTED_WARNINGS) return
    reportedWarnings.add(key)
    try { onError(error instanceof Error ? error : new Error(message)) } catch { /* noop */ }
  }

  function sweep(): void {
    if (inFlight) return
    inFlight = true
    try {
      let rows: RegistryRow[]
      try {
        rows = readSweepRows()
      } catch (e) {
        reportWarning(e, `read:${e instanceof Error ? e.message : String(e)}`)
        return
      }

      const latestByKey = new Map<string, RegistryRow>()
      const validRows: RegistryRow[] = []
      let malformedRows = 0
      for (const r of rows) {
        try {
          if (!r || typeof r !== "object") {
            malformedRows += 1
            continue
          }
          validRows.push(r)
          if (typeof r.dispatch_state !== "string") continue
          const key = (r.session_id ?? r.task_id) as string | undefined
          if (!key) continue
          const prev = latestByKey.get(key)
          if (!prev || (r.timestamp ?? "") >= (prev.timestamp ?? "")) {
            latestByKey.set(key, r)
          }
        } catch {
          malformedRows += 1
          continue
        }
      }
      if (malformedRows > 0) reportWarning(new Error(`malformed registry rows skipped: ${malformedRows}`), "malformed-rows")
      if (latestByKey.size === 0) {
        stallSweepFirstDone = true
        return
      }

      const lastStallByKey = new Map<string, number>()
      const lastDeadByKey = new Map<string, number>()
      for (const r of validRows) {
        try {
          const key = (r.session_id ?? r.task_id) as string | undefined
          if (!key) continue
          const stallTimestamp = r.last_stall_timestamp ?? (r.event === "stall_detected" && r.escalation !== "dead" ? r.timestamp : undefined)
          const deadTimestamp = r.last_dead_timestamp ?? (r.event === "stall_detected" && r.escalation === "dead" ? r.timestamp : undefined)
          for (const [value, tier] of [[stallTimestamp, lastStallByKey], [deadTimestamp, lastDeadByKey]] as const) {
            const ts = Date.parse(value ?? "")
            if (Number.isNaN(ts)) continue
            const prev = tier.get(key)
            if (prev === undefined || ts > prev) tier.set(key, ts)
          }
        } catch {
          malformedRows += 1
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
            const result = compareAndAppendStall({
              session_id: row.session_id,
              task_id: row.task_id,
              lifecycle_generation: typeof row.lifecycle_generation === "number" ? row.lifecycle_generation : undefined,
              tier: "dead",
              row: {
                event: "stall_detected",
                session_id: row.session_id,
                task_id: row.task_id,
                lifecycle_generation: row.lifecycle_generation,
                dispatch_state: row.dispatch_state,
                stall_duration_seconds: ageSec,
                last_status: row.status,
                detected_at: new Date(nowMs).toISOString(),
                escalation: "dead",
                note: "assumed dead - still non-terminal past STALL_DEAD_MINUTES (ana011 claim-staleness protocol)",
                writer: "plugin",
              },
            })
            if (result?.ok === true) emitStall(key, row, ageSec, thresholds.dead, "dead")
            continue
          }
          if (ageSec < thresholdMin * 60) continue
          const lastStall = lastStallByKey.get(key)
          if (lastStall !== undefined && nowMs - lastStall < thresholdMin * 60_000) continue
          const result = compareAndAppendStall({
            session_id: row.session_id,
            task_id: row.task_id,
            lifecycle_generation: typeof row.lifecycle_generation === "number" ? row.lifecycle_generation : undefined,
            tier: "stall",
            row: {
              event: "stall_detected",
              session_id: row.session_id,
              task_id: row.task_id,
              lifecycle_generation: row.lifecycle_generation,
              dispatch_state: row.dispatch_state,
              stall_duration_seconds: ageSec,
              last_status: row.status,
              detected_at: new Date(nowMs).toISOString(),
              writer: "plugin",
            },
          })
          if (result?.ok === true) emitStall(key, row, ageSec, thresholdMin, undefined)
        } catch (e) {
          reportWarning(e)
          continue
        }
      }
      stallSweepFirstDone = true
    } catch (e) {
      reportWarning(e)
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
