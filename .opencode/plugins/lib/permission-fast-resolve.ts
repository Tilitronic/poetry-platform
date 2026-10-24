/**
 * permission-fast-resolve - unattended permission ask fast path
 * (permission-stall-hardening ADR-001/002/003, campaign DIA-260928-nm2u).
 *
 * Pure/DI'd lib module (the lib/stall-sweep.ts seam): injected calls only,
 * no ctx capture, no registry paths - the plugin injects its own state
 * closures. Contents:
 *
 *   1. unattendedMode()      - the ADR-002 env gate, evaluated per call and
 *                              NEVER cached (tests toggle process.env).
 *   2. classifyAsk()          - the narrow allow-sublist classifier (ADR-001).
 *   3. createFastResolve()    - the fastResolveAsk decision orchestration
 *                              (MECHANISM steps 1-7), fail-soft end to end.
 *   4. buildStallDiagnostic() - the pure O-D diagnostic text builder shared
 *                              by the envelope-guard mutation and its audit
 *                              row (ADR-003).
 *
 * Fail-closed contract: anything the sublist does not explicitly match
 * decides "reject"; an absent/non-"1" gate value means interactive (the fast
 * path is behaviorally compiled out). Never replies "always" - an unattended
 * grant must be per-ask and audited. ASCII-only (DIA-079).
 */
import { errorMessage } from "./errors.ts"

/** One observed permission ask, parsed by the event case / boot re-arm. */
export type AskSignal = {
  sessionID: string
  permissionID: string
  permission?: string
  patterns?: string[]
}

/** Classifier verdict: `once` for sublist matches, fail-closed `reject`. */
export type FastDecision = {
  decision: "once" | "reject"
  matchedRule: string | null
}

/** Consumed-on-use O-D stall record (10-min TTL, pruned by the plugin). */
export interface StallRecord {
  sessionID: string
  permissionID: string
  decision: "once" | "reject"
  source: "fast_resolved" | "auto_rejected"
  at: number
}

/**
 * ADR-002 gate: OPENCODE_UNATTENDED === "1". Evaluated per CALL against the
 * live env (never cached) so a stale "unattended" verdict can never leak
 * into an interactive session and tests can toggle mid-process. Absent /
 * any other value = interactive = fast path behaviorally compiled out.
 */
export function unattendedMode(
  env: { OPENCODE_UNATTENDED?: string } = process.env
): boolean {
  return env.OPENCODE_UNATTENDED === "1"
}

// v1 seed - ONE entry. Adding an entry requires a DIA ticket + developer
// sign-off (practice-protected). Every entry must name its invariant.
const UNATTENDED_ALLOW_SUBLIST = [
  {
    permission: "bash",
    rule: "rm .scratch single-target",
    match: (pattern: string): boolean => {
      const toks = pattern.trim().split(/\s+/)
      if (toks[0] !== "rm") return false
      const targets = toks.slice(1).filter((t) => !t.startsWith("-"))
      // Multi-argument rm is REJECTED here - the "anchored allows contain
      // multi-arg rm" invariant was FALSIFIED (memory/adr.md:2513-2545,
      // probe table A-E). Exactly one non-flag target, under .scratch only.
      if (targets.length !== 1) return false
      const t = targets[0]
      return t.startsWith("/workspace/.scratch/") || t.startsWith(".scratch/")
    },
  },
]
// ponytail: naive whitespace tokenizer (no quote/escape handling - quoted
// forms fail closed to reject). Upgrade to a real shell lexer only if the
// sublist grows beyond the rm family.

/**
 * Pure classifier against the allow-sublist. Fail-closed: an ask whose
 * permission is off-sublist, whose pattern list is empty, or whose pattern
 * is not even a string rejects as a whole - unrecognized never allows.
 */
export function classifyAsk(signal: AskSignal): FastDecision {
  for (const entry of UNATTENDED_ALLOW_SUBLIST) {
    if (signal.permission !== entry.permission) continue
    const patterns = signal.patterns ?? []
    // "once" requires EVERY pattern of the ask to match - an ask carrying
    // any out-of-sublist pattern rejects as a whole.
    if (
      patterns.length > 0 &&
      patterns.every((p) => typeof p === "string" && entry.match(p))
    ) {
      return { decision: "once", matchedRule: entry.rule }
    }
  }
  return { decision: "reject", matchedRule: null }
}

/** FastResolveAsk deps: everything the orchestrration touches is injected. */
export interface FastResolveDeps {
  /** Clock seam (stall-sweep DI style); defaults to Date.now. */
  now?: () => number
  /** SDK permissions reply call, injected by the plugin (no ctx capture). */
  reply: (
    sessionID: string,
    permissionID: string,
    response: "once" | "reject"
  ) => Promise<{ error?: unknown }>
  /** Live watchdog-record lookup - the step-1 stand-down guard. */
  getAsk: (
    sessionID: string,
    permissionID: string
  ) => { timestamp?: string } | undefined
  /** clearPermissionWatch equivalent: timer + record + waiting row. */
  clearWatch: (sessionID: string, permissionID: string) => void
  appendRegistryRow: (row: Record<string, unknown>) => void
  appendMessageRow: (row: Record<string, unknown>) => void
  /** O-D sink: the plugin stores the stall record for the envelope guard. */
  recordStall: (record: StallRecord) => void
  /** Fail-soft sink; defaults to console.warn (stderr, TUI-safe). */
  warn?: (message: string) => void
}

export type FastResolveAsk = (signal: AskSignal) => Promise<void>

/**
 * fastResolveAsk (MECHANISM steps 1-7). Fail-soft contract: never throws,
 * never leaves a half-cleared state - an SDK error/throw warns and LEAVES
 * the record + armed timer untouched (the 300 s backstop is the retry).
 */
export function createFastResolve(deps: FastResolveDeps): FastResolveAsk {
  const now = deps.now ?? Date.now
  const warn = deps.warn ?? ((message: string) => console.warn(message))

  return async function fastResolveAsk(signal: AskSignal): Promise<void> {
    try {
      // Step 1: absent record = a reply or a prior resolution already
      // handled it - stand down with NO SDK call.
      const record = deps.getAsk(signal.sessionID, signal.permissionID)
      if (!record) return
      // Step 2: classify (fail-closed reject for anything off-sublist).
      const { decision, matchedRule } = classifyAsk(signal)
      // Step 3: await the SDK reply. On error or throw: warn and LEAVE the
      // record + waiting row + armed timer untouched - the backstop resolves
      // within the bound (invariant clause 1 holds). No v1 retry; the
      // backstop IS the retry.
      const res = await deps.reply(signal.sessionID, signal.permissionID, decision)
      if (res?.error) {
        warn(
          `[needs-input-observer] permission fast-resolve reply failed for ` +
            `${signal.sessionID}/${signal.permissionID}: ${errorMessage(res.error) ?? "unknown error"}`
        )
        return
      }
      // Step 4: success - drop the timer handle, the watchdog record and the
      // waiting row so the backstop CANNOT fire, and a queued fire hits the
      // record-absence guard (second fence under autoRejectPermission).
      deps.clearWatch(signal.sessionID, signal.permissionID)
      // Step 5: registry audit row (`writer: "plugin"` added by the caller).
      const askedMs = record.timestamp ? Date.parse(record.timestamp) : NaN
      const elapsedMs = Number.isFinite(askedMs) ? Math.max(0, now() - askedMs) : 0
      deps.appendRegistryRow({
        event: "permission_fast_resolved",
        session_id: signal.sessionID,
        permission_id: signal.permissionID,
        decision,
        matched_rule: matchedRule,
        elapsed_ms: elapsedMs,
        mode: "unattended",
      })
      // Step 6: paired messages decision row (log_decision contract).
      deps.appendMessageRow({
        "gen_ai.operation.name": "invoke_workflow",
        from: "orchestrator",
        event_type: "decision",
        task_ref: signal.sessionID,
        resolution_status: "done",
        content_ref: `permission_fast_resolved_${decision}`,
        next_action: "lane continues with decision",
        "gen_ai.agent.id": signal.sessionID,
      })
      // Step 7: the O-D stall record for the envelope guard.
      deps.recordStall({
        sessionID: signal.sessionID,
        permissionID: signal.permissionID,
        decision,
        source: "fast_resolved",
        at: now(),
      })
    } catch (err) {
      warn(
        `[needs-input-observer] permission fast-resolve threw for ` +
          `${signal.sessionID}/${signal.permissionID}: ${errorMessage(err) ?? "unknown error"}`
      )
    }
  }
}

/**
 * Pure O-D diagnostic text (ADR-003): names the session, the permission id,
 * the decision and the registry rows to consult. Shared by the envelope
 * mutation and its audit row, so post-probe cleanup is deleting one branch.
 */
export function buildStallDiagnostic(rec: StallRecord): string {
  return (
    `permission stall: session=${rec.sessionID} permission=${rec.permissionID} ` +
    `decision=${rec.decision} resolved_by=${rec.source}; consult registry rows ` +
    `permission_fast_resolved / permission_auto_rejected and ` +
    `permission_stall_envelope_synthesized for the audit trail`
  )
}
