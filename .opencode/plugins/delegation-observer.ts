/**
 * delegation-observer — OpenCode plugin for session-attributed delegation tracking.
 *
 * Maintains .opencode/session/registry.jsonl — the delegation registry that
 * cross-references tickets, lanes, sessions, and artifacts (Tickets System 2.0
 * Phase 3/4; arc-2 design, ai--2 fold-in).
 *
 * Hook surface (real @opencode-ai/plugin@1.18.10 shapes):
 *  - "tool.execute.before"  (input, output) — A1 pure-dispatch enforcement
 *  - "tool.execute.after"   (input, output) — A2 task_id capture (parsed from
 *    output.output, a text string; input.result does not exist)
 *  - "event"                (input) — C1 session lifecycle catch-all:
 *    session.created → RUNNING (child spawn), session.idle → COMPLETE + S6
 *    A5 gate + S1 A3 silent-failure scan, session.error → FAILED + A3 scan
 *  - "experimental.session.compacting" (input, output) — inject active
 *    registry snapshot so delegations survive context compaction
 *
 * Design rules enforced: A1 pure-dispatch, A2 task_id capture, A3 retroactive
 * consistency, A4 append-only registry discipline, A5 final-message gate,
 * C3 forward-only status transitions (S2 guard).
 */
import { appendFileSync, existsSync, readFileSync } from "node:fs"
import { join } from "node:path"
import type { Hooks, Plugin } from "@opencode-ai/plugin"

/**
 * Parse a task() tool result to recover the child session id.
 * Mirrors the established parser (oh-my-opencode-slim/src/utils/task.ts:20-38):
 * the task() tool returns `task_id: ses_123` and/or XML `<task id="...">`.
 * In OpenCode the task_id IS the spawned child session id.
 */
function parseTaskIdFromTaskOutput(output: string): string | undefined {
  const xmlMatch = /<task\s+[^>]*\bid=["']([^"']+)["'][^>]*>/i.exec(output)
  if (xmlMatch) return xmlMatch[1]

  for (const line of output.split(/\r?\n/)) {
    const match = /^task_id:\s*([^\s()]+)(?:\s*\(.*)?$/.exec(line.trim())
    if (match) return match[1]
  }

  return undefined
}

/** Best-effort extraction of a human-readable message from an error value. */
function errorMessage(err: unknown): string | undefined {
  if (err === undefined || err === null) return undefined
  if (typeof err === "string") return err
  if (
    typeof err === "object" &&
    "message" in err &&
    typeof (err as { message?: unknown }).message === "string"
  ) {
    return (err as { message: string }).message
  }
  return String(err)
}

interface RegistryRow {
  seq?: number
  timestamp?: string
  event?: string
  session_id?: string
  task_id?: string
  parent_session?: string
  agent?: string
  ticket?: string
  dispatch_state?: string
  status?: string
  dispatched_at?: string
  finished_at?: string
  role?: string
  alert_note?: string
  group_key?: string
  [key: string]: unknown
}

const TERMINAL_STATES = new Set(["completed", "failed"])
const NON_TERMINAL_STATES = new Set(["invoked", "running"])

// Synthetic group-key prefix for task_no_id rows (the expected abort/cancel
// path — task_id absent because PR #13958 is unmerged, so no session/task id
// exists to group by). jsonl-stats.sh excludes this prefix from its
// dangling/orphan checks so the expected path is not flagged as noise (RR-5a);
// `cancelled` stays reserved for real cancel_task events.
const TASK_NO_ID_GROUP_KEY = "__task_no_id__"

const delegationObserver: Plugin = async (ctx) => {
  // Resolve the registry from PluginInput.directory (preferred over
  // process.cwd() — survives invocations started from other directories).
  const registryPath = join(ctx.directory, ".opencode/session/registry.jsonl")

  // Seed the sequence from existing rows so registry rows stay strictly
  // monotonic across plugin re-inits and compactions.
  let seq = 0
  // sessionID -> sessions already given an a5_quality_gate row. Seeded once
  // here (single boot scan) and appended on each gate write, so the per-idle
  // gate check is O(1) instead of re-reading the whole registry on every
  // orchestrator idle (RR-2).
  const gatedSessions = new Set<string>()
  if (existsSync(registryPath)) {
    const lines = readFileSync(registryPath, "utf-8").trim().split("\n")
    seq = lines.filter(Boolean).length
    for (const line of lines) {
      if (!line) continue
      try {
        const row = JSON.parse(line) as RegistryRow
        if (
          row.event === "a5_quality_gate" &&
          typeof row.session_id === "string"
        ) {
          gatedSessions.add(row.session_id)
        }
      } catch {
        // Malformed lines are skipped during the boot scan too (same policy
        // as readRegistryRows).
      }
    }
  }

  // sessionID -> tools executed in the current assistant turn (A1 heuristic).
  // There is no message_id in the hook input, so we group by session and reset
  // on tool.execute.after. Parallel tool calls fire all `before` hooks before
  // any `after` hook, so task()+other tools in one message is still detected.
  const turnToolCalls = new Map<string, string[]>()

  // sessionID -> lifecycle metadata captured at session.created. Used to
  // distinguish the orchestrator's own session (root, no parentID) from child
  // subagent sessions (S6) and to scope the C3 forward-transition guard (S2).
  const sessionMeta = new Map<
    string,
    { parentID?: string; role: "orchestrator" | "subagent" }
  >()

  // Orchestrator session id, derived at runtime: the session that calls task()
  // IS the orchestrator (get-my-session-id tool results are not visible to
  // plugins, so this is the authoritative source). Used by S6 to recognize the
  // orchestrator's own session even when it has a parentID (resumed/child
  // orchestrator scenario).
  let parentSessionId: string | undefined

  function readRegistryRows(): RegistryRow[] {
    if (!existsSync(registryPath)) return []
    return readFileSync(registryPath, "utf-8")
      .split("\n")
      .filter(Boolean)
      .map((line): RegistryRow | null => {
        try {
          return JSON.parse(line) as RegistryRow
        } catch {
          // Malformed line — skip rather than crash. Keeps the compaction
          // read resilient to hand-edits / partial writes.
          return null
        }
      })
      .filter((r): r is RegistryRow => r !== null)
  }

  function appendRow(row: Record<string, unknown>): void {
    seq++
    const entry: Record<string, unknown> = {
      seq,
      timestamp: new Date().toISOString(),
      ...row,
    }
    // Synthetic group keys are resolved here: seq is assigned in this
    // function, so callers cannot reference the final seq (RR-5a).
    if (entry.group_key === TASK_NO_ID_GROUP_KEY) {
      entry.group_key = `${TASK_NO_ID_GROUP_KEY}${seq}`
    }
    appendFileSync(registryPath, JSON.stringify(entry) + "\n")
  }

  /** Last registry row that carries this session_id (used by the S2 guard). */
  function lastRowForSession(sessionID: string): RegistryRow | undefined {
    const rows = readRegistryRows()
    for (let i = rows.length - 1; i >= 0; i--) {
      if (rows[i].session_id === sessionID) return rows[i]
    }
    return undefined
  }

  /**
   * S1 (A3): retroactive consistency check. After a terminal event, scan the
   * whole registry for delegation groups (keyed by session_id ?? task_id —
   * the same id space: task() returns the child session id) that still have
   * non-terminal rows and no terminal row, and append a silent_failure_alert
   * row. Deduped per group (existing silent_failure_alert row) so an
   * in-flight subagent is flagged once, not on every session.idle.
   */
  function checkSilentFailures(): void {
    const rows = readRegistryRows()
    const terminal = new Set<string>()
    const nonTerminalByKey = new Map<string, RegistryRow[]>()
    const alreadyAlerted = new Set<string>()

    // Group-key dedup scans ALL rows: silent_failure_alert rows themselves
    // carry no dispatch_state but must register their key so a group is
    // alerted once.
    for (const r of rows) {
      const key = r.session_id ?? r.task_id
      if (!key) continue
      if (r.event === "silent_failure_alert") alreadyAlerted.add(key)
    }

    // State grouping only from rows that carry a dispatch_state. Rows lacking
    // one (a1_violation, a5_quality_gate) share the session_id namespace but
    // are not delegations — excluding them before the grouping loop keeps the
    // scan meaningful (RR-3); behavior for real dispatch rows is unchanged.
    const dispatchRows = rows.filter((r) => typeof r.dispatch_state === "string")
    for (const r of dispatchRows) {
      const key = r.session_id ?? r.task_id
      if (!key) continue // ungroupable rows are handled individually by jsonl-stats.sh
      if (TERMINAL_STATES.has(r.dispatch_state ?? "")) terminal.add(key)
      if (NON_TERMINAL_STATES.has(r.dispatch_state ?? "")) {
        nonTerminalByKey.set(key, [...(nonTerminalByKey.get(key) ?? []), r])
      }
    }
    for (const [key, keyRows] of nonTerminalByKey) {
      if (terminal.has(key)) continue
      if (alreadyAlerted.has(key)) continue
      const states = keyRows.map((r) => r.dispatch_state).join("/")
      appendRow({
        event: "silent_failure_alert",
        session_id: keyRows[0].session_id,
        task_id: keyRows[0].task_id,
        dispatch_state: states,
        status: "SILENT_FAILURE",
        alert_note: `delegation ${key} has non-terminal rows (${states}) with no terminal event observed`,
        writer: "plugin",
      })
    }
  }

  const hooks: Hooks = {
    // A1: enforce pure-dispatch — task() must be the SOLE tool call in its
    // message. Grouped per session (message_id does not exist in the input);
    // the per-session list is reset on tool.execute.after.
    "tool.execute.before": async (input, _output) => {
      const calls = turnToolCalls.get(input.sessionID) ?? []
      calls.push(input.tool)
      turnToolCalls.set(input.sessionID, calls)
      if (input.tool === "task" && calls.length > 1) {
        console.warn(
          `[delegation-observer] A1 VIOLATION: task() called alongside ${calls.length - 1} other tool(s) in session ${input.sessionID}`
        )
        appendRow({
          event: "a1_violation",
          session_id: input.sessionID,
          call_id: input.callID,
          tools: [...calls],
          writer: "plugin",
        })
      }
    },

    // A2 (B3): capture task_id from the task() tool RESULT. Per the d.ts the
    // result is the SECOND argument output.output — a text string; input.result
    // does not exist. Parse with the established parser pattern.
    "tool.execute.after": async (input, output) => {
      // Reset the per-session turn-tracking list (message-boundary heuristic).
      turnToolCalls.delete(input.sessionID)

      if (input.tool !== "task") return

      // The session that calls task() is the orchestrator (runtime source for
      // S6's "parent_session matches" recognition).
      parentSessionId ??= input.sessionID

      const text = typeof output?.output === "string" ? output.output : ""
      const taskId = parseTaskIdFromTaskOutput(text)
      if (taskId) {
        appendRow({
          event: "task_success",
          task_id: taskId,
          dispatch_state: "invoked",
          status: "DISPATCHED",
          dispatched_at: new Date().toISOString(),
          writer: "plugin",
        })
      } else {
        // task_no_id: the EXPECTED abort/cancel path (task_id absent because
        // PR #13958 is unmerged). The row carries a synthetic group_key
        // (resolved to __task_no_id__<seq> in appendRow) so jsonl-stats can
        // exclude the expected path from dangling/orphan noise while still
        // catching genuinely untrackable dispatches (RR-5a).
        appendRow({
          event: "task_no_id",
          dispatch_state: "invoked",
          status: "PENDING",
          fallback_note: "task_id absent from task() output (abort/cancel path)",
          group_key: TASK_NO_ID_GROUP_KEY,
          writer: "plugin",
        })
      }
    },

    // C1: session lifecycle events arrive via the generic `event` catch-all —
    // session.created / session.idle / session.error are NOT named hooks.
    event: async (input) => {
      const event = input.event as {
        type: string
        properties?: {
          info?: { id?: string; parentID?: string; title?: string }
          sessionID?: string
          error?: unknown
        }
      }

      switch (event.type) {
        case "session.created": {
          const info = event.properties?.info
          if (!info?.id) return
          const role = info.parentID ? "subagent" : "orchestrator"
          sessionMeta.set(info.id, { parentID: info.parentID, role })
          // RUNNING transition: only child spawns are delegations. The root
          // orchestrator session is recorded for role attribution only.
          if (info.parentID) {
            appendRow({
              event: "session_spawn",
              session_id: info.id,
              parent_session: info.parentID,
              dispatch_state: "running",
              status: "RUNNING",
              writer: "plugin",
            })
          }
          return
        }

        case "session.idle": {
          const sessionID = event.properties?.sessionID
          if (!sessionID) return
          const meta = sessionMeta.get(sessionID)
          // S6: the orchestrator's own session (parent_session matches — the
          // session known to call task() — or no parent) gets an
          // a5_quality_gate row instead of a COMPLETE row.
          const role =
            sessionID === parentSessionId
              ? "orchestrator"
              : (meta?.role ?? "unknown")

          // S6 (A5 gate): the orchestrator's own session (root / no parent —
          // also the "parent_session matches" case) gets an a5_quality_gate
          // row instead of a COMPLETE row. Written once per session to avoid
          // row spam (the root idles after every turn). Content-level
          // attribution parsing is deliberately NOT attempted (proportionate
          // fix per review; attribution is enforced by the messages-log
          // discipline in NEXT-RUN.md §2).
          if (role !== "subagent") {
            // O(1) gate check via the boot-seeded set (RR-2): written once
            // per session to avoid row spam (the root idles after every
            // turn). Content-level attribution parsing is deliberately NOT
            // attempted (proportionate fix per review; attribution is
            // enforced by the messages-log discipline in NEXT-RUN.md §2).
            if (!gatedSessions.has(sessionID)) {
              gatedSessions.add(sessionID)
              appendRow({
                event: "a5_quality_gate",
                session_id: sessionID,
                role,
                attribution_check: "deferred_to_messages_log_discipline",
                finished_at: new Date().toISOString(),
                writer: "plugin",
              })
            }
            return
          }

          // S2 (C3): forward-only transition guard — targets child-session
          // rows. (Repeated idles of the orchestrator's own session are
          // handled above and are not anomalies.) If the last row for this
          // child is already terminal (multi-turn subagent re-idling), log an
          // anomaly instead of silently writing another terminal row.
          const last = lastRowForSession(sessionID)
          if (last && TERMINAL_STATES.has(last.dispatch_state ?? "")) {
            appendRow({
              event: "anomaly_backward_transition",
              session_id: sessionID,
              from_state: last.dispatch_state,
              to_state: "completed",
              note: "session.idle observed after a terminal row (multi-idle child session)",
              writer: "plugin",
            })
            return
          }

          appendRow({
            event: "session_complete",
            session_id: sessionID,
            role: "subagent",
            dispatch_state: "completed",
            status: "COMPLETE",
            finished_at: new Date().toISOString(),
            writer: "plugin",
          })
          checkSilentFailures()
          return
        }

        case "session.error": {
          const sessionID = event.properties?.sessionID
          if (!sessionID) return
          const meta = sessionMeta.get(sessionID)
          const role =
            sessionID === parentSessionId
              ? "orchestrator"
              : (meta?.role ?? "unknown")

          // S2 guard targets child-session rows; orchestrator/unknown
          // sessions may error transiently without violating forward-only
          // transitions, so no anomaly is logged for them.
          if (role === "subagent") {
            const last = lastRowForSession(sessionID)
            if (last && TERMINAL_STATES.has(last.dispatch_state ?? "")) {
              appendRow({
                event: "anomaly_backward_transition",
                session_id: sessionID,
                from_state: last.dispatch_state,
                to_state: "failed",
                note: "session.error observed after a terminal row",
                writer: "plugin",
              })
              return
            }
          }

          appendRow({
            event: "session_failed",
            session_id: sessionID,
            role,
            dispatch_state: "failed",
            status: "FAILED",
            finished_at: new Date().toISOString(),
            error: errorMessage(event.properties?.error),
            writer: "plugin",
          })
          checkSilentFailures()
          return
        }

        default:
          return
      }
    },

    // C2: compaction survival — inject the active registry snapshot into the
    // compaction context. Per the d.ts: (input {sessionID}, output {context:
    // string[]}) — context is an array with real .push().
    "experimental.session.compacting": async (_input, output) => {
      if (!existsSync(registryPath)) return
      const rows = readRegistryRows()
      const active = rows.filter((r) =>
        NON_TERMINAL_STATES.has(r.dispatch_state ?? "")
      )
      if (active.length > 0) {
        const snapshot =
          "## Active Delegations (registry.jsonl snapshot)\n" +
          active
            .map(
              (r) =>
                `- seq=${r.seq} ticket=${r.ticket ?? "?"} agent=${r.agent ?? "?"} state=${r.dispatch_state} since=${r.dispatched_at ?? r.timestamp}`
            )
            .join("\n")
        output.context.push(snapshot)
      }
    },
  }

  return hooks
}

export default delegationObserver
