/**
 * delegation-observer — OpenCode plugin for session-attributed delegation tracking.
 *
 * Maintains .opencode/session/registry.jsonl — the delegation registry that
 * cross-references tickets, lanes, sessions, and artifacts (Tickets System 2.0
 * Phase 3/4; arc-2 design, ai--2 fold-in).
 *
 * ALSO maintains .opencode/session/messages.jsonl — the orchestrator-level
 * semantic event log (silent session logging, ana007 Option E, arc-1). The
 * split: messages.jsonl records delegations/decisions/handoffs (written by
 * this plugin via hooks + the log_decision tool); registry.jsonl records the
 * plugin lifecycle (task()/session spawn→complete/fail). Complementary files,
 * reconciled in Phase 5 validation. messages.md is now a DERIVED VIEW
 * regenerated from messages.jsonl by scripts/session-log render — never
 * edited directly.
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
import { createHash, randomUUID } from "node:crypto"
import {
  appendFileSync,
  closeSync,
  existsSync,
  fsyncSync,
  mkdirSync,
  openSync,
  readFileSync,
  renameSync,
  unlinkSync,
  writeFileSync,
} from "node:fs"
import { dirname, isAbsolute, join, relative, resolve } from "node:path"
import { tool, type Hooks, type Plugin } from "@opencode-ai/plugin"

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

/**
 * Highest numeric row number in messages.md (the pre-derivation human log).
 * The `#` column of the markdown table is `| <n> |`; VP-evidence rows have a
 * non-numeric first column and are skipped by the regex. Used ONLY as the
 * row_id seed source for the boot scan — after this plugin starts writing,
 * messages.md is derived from messages.jsonl and this fallback is inert.
 * Returns 0 when the file is absent or has no numbered rows.
 */
function lastMessagesMdRowNumber(mdPath: string): number {
  if (!existsSync(mdPath)) return 0
  let max = 0
  for (const line of readFileSync(mdPath, "utf-8").split("\n")) {
    const m = /^\|\s*(\d+)\s*\|/.exec(line)
    if (m) {
      const n = Number.parseInt(m[1], 10)
      if (n > max) max = n
    }
  }
  return max
}

/**
 * Highest row_id present in an existing messages.jsonl (plugin-written rows).
 * Legacy orchestrator-written rows (lines 1-474 at migration time) LACK
 * row_id entirely, so this returns 0 for them — the authoritative seed then
 * falls back to the messages.md row numbering (see nextRowId seeding).
 * Malformed lines are skipped (same policy as the registry boot scan).
 */
function maxRowIdInJsonl(jsonlPath: string): number {
  if (!existsSync(jsonlPath)) return 0
  let max = 0
  for (const line of readFileSync(jsonlPath, "utf-8").split("\n")) {
    if (!line) continue
    try {
      const row = JSON.parse(line) as { row_id?: number }
      if (typeof row.row_id === "number" && row.row_id > max) {
        max = row.row_id
      }
    } catch {
      // Malformed line — skip during the boot scan too.
    }
  }
  return max
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

  // messages.jsonl paths — the orchestrator-level semantic event log
  // (silent session logging, ana007 Option E). Same directory discipline as
  // registry.jsonl; appendFileSync is SILENT (plugin fs writes never appear
  // in the transcript — proven by registry.jsonl's 634 rows, 0 pollution).
  const messagesPath = join(ctx.directory, ".opencode/session/messages.jsonl")
  const messagesMdPath = join(ctx.directory, ".opencode/session/messages.md")

  // §10 AI Devtools Modernization gate: the gate token file that @ai-specialist
  // writes after completing its gate review. Edits to .opencode/ and AGENTS.md
  // are mechanically blocked until this file exists with valid content.
  const gateTokenPath = join(
    ctx.directory,
    ".opencode/session/gate-tokens/ai-specialist-reviewed"
  )
  const gateTokenDir = dirname(gateTokenPath)

  // Handoff paths — deterministic fixed path under .opencode/session/ (the
  // orchestrator artifact directory). No separate directory needed; the session
  // directory already exists and is gitignored. The consumer always reads the
  // SAME path via read(); no glob needed.
  const handoffDir = join(ctx.directory, ".opencode/session")
  const handoffPath = join(handoffDir, "current-handoff.json")
  const handoffTmpPath = join(handoffDir, ".current-handoff.json.tmp")

  /** Paths (relative to workspace root) that require @ai-specialist gate review. */
  const protectedPaths = [".opencode/", "AGENTS.md"]

  // row_id seed logic (READER rule — "continue from the last row # across
  // sessions, never restart"): the authoritative monotonic series is the
  // messages.md row numbering (last row = 601 at implementation time).
  // Legacy messages.jsonl rows LACK row_id, so nextRowId = MAX(max row_id
  // in messages.jsonl, last messages.md row #) + 1 — at migration that is
  // 602. Once plugin rows carry row_id, messages.md itself is derived from
  // messages.jsonl and the two sources converge; the MAX keeps the seed
  // correct even if messages.md was regenerated with fewer rows.
  let nextRowId =
    Math.max(maxRowIdInJsonl(messagesPath), lastMessagesMdRowNumber(messagesMdPath)) + 1

  // Orchestrator session -> number of task() delegations dispatched since the
  // last handoff row. Used for decision #3 (one handoff row per orchestrator
  // idle turn that follows delegations) — reset on each handoff write so
  // repeated orchestrator idles without new delegations stay silent.
  const delegationsSinceHandoff = new Map<string, number>()

  // Child session id (task_id) -> agent name captured at dispatch. Enriches
  // completion/failure messages rows with the actual delegated agent.
  const childSessionAgent = new Map<string, string>()

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
    // Failure policy (mirrors appendMessageRow): never crash the plugin — on
    // write error console.warn and continue. A lost registry row is preferable
    // to a crashed orchestrator (appendFileSync is atomic; the last row is
    // lost, never corrupted).
    try {
      appendFileSync(registryPath, JSON.stringify(entry) + "\n")
    } catch (err) {
      console.warn(
        `[delegation-observer] registry.jsonl write failed (seq=${seq}): ${errorMessage(err)}`
      )
    }
  }

  /**
   * messages.jsonl writer — ONE JSON object + "\n", silent appendFileSync
   * (mirrors the registry appendRow pattern). Row fields: row_id (monotonic
   * campaign row number), event_uuid (idempotent event identity — the row
   * survives replay/compaction without duplicating), timestamp, semconv
   * v1.42.0 gen_ai.* attributes, project extensions (gen_ai.agent.id,
   * ticket_id), writer provenance "plugin".
   *
   * No write queue (decision #4): appendFileSync is synchronous and blocks
   * the event loop, but at the observed volume (registry: 634 rows) this is
   * unmeasurable. Deferred to a ~10K-row threshold — when messages.jsonl
   * approaches 10K rows, switch to an async write queue (e.g. a batched
   * setImmediate drain) to keep the event loop responsive.
   *
   * Failure policy: never crash the plugin, never block the event loop — on
   * write error console.warn and continue. A lost row is preferable to a
   * crashed orchestrator (appendFileSync is atomic; the last row is lost,
   * never corrupted).
   */
  function appendMessageRow(row: Record<string, unknown>): void {
    nextRowId++
    const entry: Record<string, unknown> = {
      row_id: nextRowId,
      event_uuid: randomUUID(),
      timestamp: new Date().toISOString(),
      // Best-effort provider default — the project's orchestrator provider
      // is opencode-go (observed in every legacy row). Callers can override
      // via the row spread. gen_ai.request.model is NOT set here: plugin
      // hooks do not expose the model id, so writing one would be a lie.
      "gen_ai.provider.name": "opencode-go",
      writer: "plugin",
      ...row,
    }
    try {
      appendFileSync(messagesPath, JSON.stringify(entry) + "\n")
    } catch (err) {
      console.warn(
        `[delegation-observer] messages.jsonl write failed (row_id=${nextRowId}): ${errorMessage(err)}`
      )
    }
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
   * §10 gate token check: returns true if the @ai-specialist gate review token
   * file exists and contains valid JSON with required fields. Fail-soft: if
   * the check itself crashes (e.g. disk error), returns false so the gate
   * blocks edits — a failed gate check is safer than allowing un-reviewed edits.
   */
  function gateTokenValid(): boolean {
    try {
      if (!existsSync(gateTokenPath)) return false
      const raw = readFileSync(gateTokenPath, "utf-8")
      const token = JSON.parse(raw) as {
        session_id?: string
        timestamp?: string
        event_uuid?: string
      }
      return Boolean(token.session_id && token.timestamp && token.event_uuid)
    } catch {
      return false
    }
  }

  /**
   * Compute SHA256 checksum of the prognosis object. The checksum covers only
   * the prognosis, not the wrapper fields — this way integrity verification is
   * independent of status/timestamp/session_id changes.
   */
  function computeChecksum(prognosis: object): string {
    // Canonical serialization MUST stay byte-identical with
    // scripts/validate-handoff.sh (jq -c '.prognosis | to_entries |
    // sort_by(.key) | from_entries' via printf '%s' — no trailing newline).
    // Top-level keys are byte-sorted (Object.keys().sort() == jq's sort_by(.key)
    // for ASCII keys); nested objects keep their existing insertion order
    // (matches jq's parse order). JSON.stringify emits compact JSON with no
    // trailing newline — byte-identical to the validator's pipeline.
    const canonical: Record<string, unknown> = {}
    for (const key of Object.keys(prognosis).sort()) {
      canonical[key] = (prognosis as Record<string, unknown>)[key]
    }
    return createHash("sha256")
      .update(JSON.stringify(canonical))
      .digest("hex")
  }

  /**
   * Atomic write of the handoff JSON file. Pattern: temp file → fsync →
   * atomic rename → fsync directory. On same-filesystem rename is atomic by
   * POSIX guarantee — the reader sees either the old file or the new file,
   * never a partial write. Catches errors: unlinks tmp on failure (if not yet
   * renamed).
   */
  function atomicWriteHandoff(content: Record<string, unknown>): void {
    const json = JSON.stringify(content, null, 2) + "\n"
    try {
      writeFileSync(handoffTmpPath, json)
      const tmpFd = openSync(handoffTmpPath, "r+")
      fsyncSync(tmpFd)
      closeSync(tmpFd)
      renameSync(handoffTmpPath, handoffPath)
      const dirFd = openSync(handoffDir, "r")
      fsyncSync(dirFd)
      closeSync(dirFd)
    } catch (err) {
      // Best-effort cleanup: unlink tmp if it still exists (rename failed).
      try {
        if (existsSync(handoffTmpPath)) unlinkSync(handoffTmpPath)
      } catch {
        // Secondary failure — nothing more we can do.
      }
      throw err
    }
  }

  /**
   * Check whether `filePath` (absolute or relative) is under a protected
   * directory or equals a protected file. Resolves against the workspace root.
   */
  function isProtectedPath(filePath: string): boolean {
    // Resolve to an absolute path first, then make it relative to workspace.
    const absolute = isAbsolute(filePath)
      ? filePath
      : resolve(ctx.directory, filePath)
    const rel = relative(ctx.directory, absolute)
    // A path is protected if it startsWith any prefix or equals any exact file.
    for (const prefix of protectedPaths) {
      if (rel === prefix || rel.startsWith(prefix)) return true
    }
    return false
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
    "tool.execute.before": async (input, output) => {
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

      // §10 gate: mechanically block edits to .opencode/ and AGENTS.md until
      // @ai-specialist gate review has been completed (token file exists).
      // Intercept edit, write, apply_patch; bash is excluded (too many false
      // positives from sed/git operations). The check is fail-soft: if the
      // path resolution or gate-token check itself throws, we allow the edit
      // rather than breaking the session — a broken gate is worse than no gate.
      if (
        input.tool === "edit" ||
        input.tool === "write" ||
        input.tool === "apply_patch"
      ) {
        try {
          // The before-hook type doesn't declare `args`, but it's present at
          // runtime — cast through unknown to access it.
          const args =
            ((output as unknown as { args?: unknown }).args ??
              {}) as Record<string, unknown>
          let filePath: string | undefined
          if (input.tool === "edit" || input.tool === "write") {
            filePath =
              typeof args.filePath === "string" ? args.filePath : undefined
          } else if (input.tool === "apply_patch") {
            // Multi-marker, multi-file path scan (DIA-059 §10 gate hardening).
            // Two fail-open triggers motivated this: (1) the old parse looked
            // only at the FIRST line, so patches with leading blank lines /
            // format-patch / MIME headers resolved no path -> gate opened; (2)
            // omo's rewritePatch runs BEFORE this hook (opencode.jsonc plugin
            // array order: oh-my-opencode-slim before this plugin) and rewrites
            // patches to `*** Begin Patch` / `*** Add File:` / `*** Update
            // File:` / `*** Delete File:` markers that match neither
            // `Index:` nor `diff --git` -> gate opened for every rewritten
            // patch touching .opencode/**. Scanning ALL lines for every marker
            // and checking each candidate against isProtectedPath() closes both
            // gaps and also covers multi-file patches (blocked if ANY
            // protected file appears in them).
            const patchText =
              typeof args.patchText === "string" ? args.patchText : ""
            const lines = patchText.split(/\r?\n/)
            for (const line of lines) {
              const indexMatch = /^Index:\s*(\S+)/i.exec(line)
              const diffMatch = /^diff\s+--git\s+a\/\S+\s+b\/(\S+)/.exec(line)
              const plusPlusMatch = /^\+\+\+\s+b\/(\S+)/.exec(line)
              const addFileMatch = /^\*\*\*\s+Add File:\s*(.+)/.exec(line)
              const updateFileMatch = /^\*\*\*\s+Update File:\s*(.+)/.exec(line)
              const deleteFileMatch = /^\*\*\*\s+Delete File:\s*(.+)/.exec(line)
              // omo rename destination (codec.ts formatPatch L343: `*** Move to:
              // <path>`) — a patch that MOVES a file INTO .opencode/** must be
              // blocked just like Add/Update/Delete.
              const moveToMatch = /^\*\*\*\s+Move to:\s*(.+)/.exec(line)
              const matchedPath =
                indexMatch?.[1] ??
                diffMatch?.[1] ??
                plusPlusMatch?.[1] ??
                addFileMatch?.[1]?.trim() ??
                updateFileMatch?.[1]?.trim() ??
                deleteFileMatch?.[1]?.trim() ??
                moveToMatch?.[1]?.trim()
              if (matchedPath && isProtectedPath(matchedPath)) {
                filePath = matchedPath
                break
              }
            }
          }
          if (filePath && isProtectedPath(filePath)) {
            if (!gateTokenValid()) {
              const gateError = new Error(
                "§10 GATE: Editing .opencode/ files requires @ai-specialist gate review.\n" +
                  "The §10 workflow (AGENTS.md §10, AGENTS.md §2.5) requires:\n" +
                  "  1. @ai-specialist gate research → findings\n" +
                  "  2. User reviews & approves\n" +
                  "  3. THEN implementation can proceed\n" +
                  "Action: dispatch @ai-specialist for gate research first."
              )
              throw gateError
            }
          }
        } catch (err) {
          // Re-throw §10 gate errors; all other errors (path resolution,
          // gate-token read failure) are fail-soft — a broken gate is worse
          // than no gate.
          if (
            err instanceof Error &&
            err.message.startsWith("§10 GATE:")
          ) {
            throw err
          }
        }
      }
    },

    // A2 (B3): capture task_id from the task() tool RESULT. Per the d.ts the
    // result is the SECOND argument output.output — a text string; input.result
    // does not exist. Parse with the established parser pattern.
    "tool.execute.after": async (input, output) => {
      // Reset the per-session turn-tracking list (message-boundary heuristic).
      turnToolCalls.delete(input.sessionID)

      // §10 gate token: log_decision events with event_type "gate-token"
      // write or clear the @ai-specialist gate review token file.
      if (input.tool === "log_decision") {
        const args = (input.args ?? {}) as Record<string, unknown>
        if (args.event_type === "gate-token") {
          try {
            if (args.resolution_status === "done") {
              mkdirSync(gateTokenDir, { recursive: true })
              writeFileSync(
                gateTokenPath,
                JSON.stringify({
                  session_id: input.sessionID,
                  timestamp: new Date().toISOString(),
                  event_uuid: randomUUID(),
                })
              )
            } else if (args.resolution_status === "cleared") {
              if (existsSync(gateTokenPath)) {
                unlinkSync(gateTokenPath)
              }
            }
          } catch (err) {
            console.warn(
              `[delegation-observer] gate-token write failed: ${errorMessage(err)}`
            )
          }
        }
        return
      }

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

      // messages.jsonl delegation row (orchestrator-level log): one row per
      // task() dispatch, resolution "in-flight". Agent/lane/task_ref come
      // from the task() tool args (subagent_type / task_id / description |
      // prompt — the OMO task-session-manager shape); the spawned child
      // session id (taskId) enriches gen_ai.agent.id and the completion
      // row written on session.idle. Do NOT double-write: registry.jsonl
      // keeps its own task_success/task_no_id rows above.
      const taskArgs = (input.args ?? {}) as Record<string, unknown>
      const agentName =
        typeof taskArgs.subagent_type === "string" && taskArgs.subagent_type
          ? taskArgs.subagent_type
          : "subagent"
      const laneId =
        typeof taskArgs.task_id === "string" && taskArgs.task_id
          ? taskArgs.task_id
          : undefined
      const taskRef =
        (typeof taskArgs.description === "string" && taskArgs.description
          ? taskArgs.description
          : typeof taskArgs.prompt === "string" && taskArgs.prompt
            ? taskArgs.prompt
            : "task() delegation"
        ).slice(0, 300)
      if (taskId) childSessionAgent.set(taskId, agentName)
      delegationsSinceHandoff.set(
        input.sessionID,
        (delegationsSinceHandoff.get(input.sessionID) ?? 0) + 1
      )
      appendMessageRow({
        "gen_ai.operation.name": "invoke_agent",
        "gen_ai.agent.name": agentName,
        ...(laneId ? { lane_id: laneId } : {}),
        from: "orchestrator",
        event_type: "delegation",
        task_ref: taskRef,
        resolution_status: "in-flight",
        ...(taskId ? { "gen_ai.agent.id": taskId } : {}),
      })

      // PERSISTENCE_RECOMMENDED detector (DIA-057/DIA-058, ai--3 fold-in +
      // Phase-6 lane scoping): when a COMPLETED researcher task result carries
      // the persistence flag, write .opencode/session/persistence-pending.json
      // so the orchestrator's Research Persistence Gate
      // (orchestrator_append.md) can pick it up. The task() output wraps the
      // subagent's final result in <task_result>...</task_result> and the
      // <task> header carries `state="completed"` as an XML ATTRIBUTE on
      // completion (per OMO parseTaskStateFromOutput — XML attribute form is
      // primary, `state: completed` colon form is fallback; the state regex
      // below therefore tolerates both `state=`/`state:` and optional
      // quotes). Researcher lane only — avoids false positives from other
      // agents quoting the flag string in a prompt or meta-comment: the lane
      // check uses input.args.subagent_type (falling back to the resolved
      // child session agent), and the flag regex is applied to the
      // <task_result> payload segment only. Pure additive — no changes to
      // registry rows, checksum logic, gate logic, or other hooks. Same
      // failure policy as the registry writes: never crash the plugin,
      // console.warn and continue.
      const isResearcherLane =
        agentName === "researcher" ||
        childSessionAgent.get(taskId ?? "") === "researcher"
      // Extract the task-result payload segment (matching OMO
      // parseTaskResultFromOutput) so a quote of the flag string elsewhere in
      // the output cannot trip the detector; fall back to the full output if
      // no wrapper is present (backward-compatible edge case).
      const taskResultBody =
        /<task_result>\s*([\s\S]*?)\s*<\/task_result>/i.exec(text)
      const flagText = taskResultBody ? taskResultBody[1] : text
      if (
        isResearcherLane &&
        /state\b\s*[:=]\s*["']?completed["']?/i.test(text) &&
        /PERSISTENCE_RECOMMENDED:\s*true/i.test(flagText)
      ) {
        try {
          mkdirSync(join(ctx.directory, ".opencode/session"), {
            recursive: true,
          })
          writeFileSync(
            join(ctx.directory, ".opencode/session/persistence-pending.json"),
            JSON.stringify(
              {
                session_id: taskId ?? "",
                agent: childSessionAgent.get(taskId ?? "") ?? "researcher",
                detected_at: new Date().toISOString(),
                flag: "PERSISTENCE_RECOMMENDED: true",
              },
              null,
              2
            )
          )
          console.log(`[delegation-observer] persistence flag: ${taskId}`)
        } catch (err) {
          console.warn(
            `[delegation-observer] persistence-pending.json write failed: ${errorMessage(err)}`
          )
        }
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
            // Handoff row (decision #3, approved): write ONE event_type
            // "handoff" row (operation invoke_workflow) on the orchestrator's
            // own idle when the session has performed delegations since the
            // last handoff — a single row per orchestrator idle turn, then
            // reset so subsequent idles without new delegations stay silent.
            const pending = delegationsSinceHandoff.get(sessionID) ?? 0
            if (pending > 0) {
              delegationsSinceHandoff.set(sessionID, 0)
              appendMessageRow({
                "gen_ai.operation.name": "invoke_workflow",
                from: "orchestrator",
                event_type: "handoff",
                task_ref: "orchestrator idle turn — delegations complete",
                resolution_status: "done",
                "gen_ai.agent.id": sessionID,
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
          // messages.jsonl completion row: delegation resolved "done".
          // gen_ai.agent.name is enriched from the dispatch capture
          // (childSessionAgent) when available.
          appendMessageRow({
            "gen_ai.operation.name": "invoke_agent",
            "gen_ai.agent.name": childSessionAgent.get(sessionID) ?? "subagent",
            from: "orchestrator",
            event_type: "delegation",
            task_ref: "subagent session completed",
            resolution_status: "done",
            "gen_ai.agent.id": sessionID,
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
          // messages.jsonl failure row: delegation resolution "escalated".
          // Written for ANY failing session (child or orchestrator) — a
          // failure is a crisis-level event in the orchestrator-level log.
          appendMessageRow({
            "gen_ai.operation.name": "invoke_agent",
            "gen_ai.agent.name": childSessionAgent.get(sessionID) ?? role,
            from: "orchestrator",
            event_type: "delegation",
            task_ref: "session error — delegation failed",
            resolution_status: "escalated",
            "gen_ai.agent.id": sessionID,
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

    // log_decision — compact semantic-event logger (decision #5, approved;
    // ana007 Option E / Phase 3). Registered via Hooks.tool (the
    // @opencode-ai/plugin@1.18.10 Hooks interface already carries `tool`), so
    // the approved "{hooks, tool}" return shape maps to `Hooks.tool` — the
    // delegation-observer is a standalone hooks-style plugin and must keep
    // returning the Hooks contract its file already uses.
    tool: {
      log_decision: tool({
        description:
          "Log a semantic orchestrator event (decision/handoff/crisis) to the session messages.jsonl log. COMPACT replacement for manual messages.md/jsonl edits: use for owner decisions, handoffs, and crisis declarations; mechanical delegation events are captured automatically by hooks and must NOT be logged via this tool.",
        args: {
          event_type: tool.schema.enum([
            "decision",
            "handoff",
            "crisis",
            "gate-token",
          ]),
          task_ref: tool.schema.string(),
          resolution_status: tool.schema.enum([
            "done",
            "in-flight",
            "pending-owner",
            "escalated",
            "acknowledged",
            "cleared",
          ]),
          lane_id: tool.schema.string().optional(),
          cycle_id: tool.schema.string().optional(),
          ticket_id: tool.schema.string().optional(),
          content_ref: tool.schema.string().optional(),
          next_action: tool.schema.string().optional(),
          /** JSON-stringified prognosis object — only meaningful for handoff events. */
          prognosis: tool.schema.string().optional(),
        },
        async execute(args) {
          // When event_type is "handoff" and prognosis is provided, write the
          // atomic handoff JSON to .opencode/session/current-handoff.json so the
          // successor session can detect it via a deterministic read() — no
          // glob needed (eliminates the fast-glob dot:false footgun).
          if (
            args.event_type === "handoff" &&
            typeof args.prognosis === "string" &&
            args.prognosis
          ) {
            try {
              const prognosis = JSON.parse(args.prognosis) as Record<
                string,
                unknown
              >
              const statusMap: Record<string, string> = {
                done: "done",
                escalated: "failed",
                "pending-owner": "manual-halt",
              }
              const status =
                statusMap[args.resolution_status] ?? "manual-halt"
              const checksum = computeChecksum(prognosis)
              atomicWriteHandoff({
                status,
                session_id: parentSessionId ?? args.lane_id ?? "unknown",
                cycle_id: args.cycle_id ?? null,
                timestamp: new Date().toISOString(),
                checksum,
                prognosis,
              })
            } catch (err) {
              console.warn(
                `[delegation-observer] handoff atomic write failed: ${errorMessage(err)}`
              )
              // Fall through: still log the message row below. A lost handoff
              // file is recoverable (orchestrator can retry), but a lost log
              // row means the event is invisible.
            }
          }
          appendMessageRow({
            "gen_ai.operation.name": "invoke_workflow",
            from: "orchestrator",
            event_type: args.event_type,
            task_ref: args.task_ref,
            resolution_status: args.resolution_status,
            ...(args.lane_id ? { lane_id: args.lane_id } : {}),
            ...(args.cycle_id ? { cycle_id: args.cycle_id } : {}),
            ...(args.ticket_id ? { ticket_id: args.ticket_id } : {}),
            ...(args.content_ref ? { content_ref: args.content_ref } : {}),
            ...(args.next_action ? { next_action: args.next_action } : {}),
          })
          return `Logged: ${args.event_type} — ${args.task_ref.slice(0, 60)}`
        },
      }),

      // context_usage — context-window usage estimate from proxy signals
      // (approved plugin-removal campaign §10 Phase 3 design, option (e)).
      // Replaces the removed token_stats tool for the two orchestrator
      // safety mechanisms (self-rerun detection, council budget guard).
      // NOT token-accurate: registry.jsonl activity rows + messages.jsonl
      // line count + session metadata are proxies, not real token counts.
      // The formula deliberately UNDER-estimates (conservative): the
      // self-rerun thresholds fire on the estimated fraction, so a low
      // estimate keeps the orchestrator rerunning earlier rather than
      // risking context degradation (campaign-critical state loss).
      context_usage: tool({
        description:
          "Estimate context-window usage for the current session. Returns JSON with estimated usage fraction, delegation counts, and optional council-scoped breakdown. NOT token-accurate — uses registry.jsonl activity signals as a proxy. Sufficient for self-rerun (>=50%) and council budget guard decisions.",
        args: {
          scope: tool.schema
            .enum(["session", "council"])
            .optional()
            .describe(
              "Scope: 'session' (default) = full session; 'council' = council-dispatch subset only."
            ),
        },
        async execute(args) {
          const scope = args.scope ?? "session"

          // Signal 1 — registry delegation count. Delegation/session-spawn
          // events only (task_success, task_no_id, session_spawn); terminal
          // and gate rows are outcomes, not dispatches, and would double
          // count. Fail-soft: unreadable registry yields an empty list.
          const DELEGATION_EVENTS = new Set([
            "task_success",
            "task_no_id",
            "session_spawn",
          ])
          let registryRows: RegistryRow[] = []
          try {
            registryRows = readRegistryRows()
          } catch {
            registryRows = []
          }
          const delegationRows = registryRows.filter((r) =>
            DELEGATION_EVENTS.has(r.event ?? "")
          )

          // Council scope needs agent attribution, but registry rows carry no
          // agent field (the plugin never writes one). Attribute via the
          // dispatch capture (childSessionAgent: task_id -> agent) enriched
          // with the messages log's gen_ai.agent.id -> gen_ai.agent.name
          // mapping so pre-boot dispatches (ids not in the in-memory map) are
          // still attributed. Last row wins (append-only log; completion rows
          // repeat the same agent, so the overwrite is idempotent in practice).
          const isCouncilAgent = (agent: string | undefined): boolean =>
            agent === "council" || agent === "councillor"
          const attribution = new Map<string, string>()
          if (scope === "council") {
            for (const [id, agent] of childSessionAgent) {
              attribution.set(id, agent)
            }
            try {
              if (existsSync(messagesPath)) {
                for (const line of readFileSync(messagesPath, "utf-8").split("\n")) {
                  if (!line) continue
                  try {
                    const row = JSON.parse(line) as {
                      "gen_ai.agent.id"?: unknown
                      "gen_ai.agent.name"?: unknown
                    }
                    if (
                      typeof row["gen_ai.agent.id"] === "string" &&
                      row["gen_ai.agent.id"] &&
                      typeof row["gen_ai.agent.name"] === "string" &&
                      row["gen_ai.agent.name"]
                    ) {
                      attribution.set(
                        row["gen_ai.agent.id"],
                        row["gen_ai.agent.name"]
                      )
                    }
                  } catch {
                    // Malformed line — skip (same policy as readRegistryRows).
                  }
                }
              }
            } catch {
              // Fail-soft: unreadable messages log leaves the attribution map
              // with only the in-memory childSessionAgent entries.
            }
          }
          const isCouncilRow = (r: RegistryRow): boolean =>
            isCouncilAgent(attribution.get(r.session_id ?? r.task_id ?? ""))

          const delegationCount =
            scope === "council"
              ? delegationRows.filter(isCouncilRow).length
              : delegationRows.length

          // Signal 2 — messages row count (session scope only). Fail-soft:
          // unreadable log yields 0, mirroring the plugin's fail-soft policy.
          let messageCount = 0
          if (scope === "session") {
            try {
              if (existsSync(messagesPath)) {
                messageCount = readFileSync(messagesPath, "utf-8")
                  .split("\n")
                  .filter((line) => line.trim() !== "").length
              }
            } catch {
              messageCount = 0
            }
          }

          // Signal 3 — session count. Session scope: the plugin's tracked
          // session metadata (root + children). Council scope: distinct
          // council-attributed delegation ids (the council child sessions).
          let sessionCount = 0
          if (scope === "council") {
            const councilIds = new Set<string>()
            for (const r of delegationRows) {
              if (isCouncilRow(r)) {
                const key = r.session_id ?? r.task_id
                if (key) councilIds.add(key)
              }
            }
            sessionCount = councilIds.size
          } else {
            sessionCount = sessionMeta.size
          }

          // Conservative estimation formula (approved design): per-delegation
          // weight 3000, per-message weight 1000 (session scope only),
          // per-session weight 10000. Context window hardcoded to 1M — the
          // plugin has no model metadata access and the orchestrator models
          // are the deepseek-v4-flash / qwen3.7-max 1M-window class.
          const estimatedTokens =
            delegationCount * 3000 +
            (scope === "session" ? messageCount * 1000 : 0) +
            sessionCount * 10000
          const contextWindow = 1_000_000
          const usageFraction = Math.min(estimatedTokens / contextWindow, 1)
          const estimatedCredits =
            scope === "council" ? delegationCount * 150 : undefined

          const result: Record<string, unknown> = {
            scope,
            estimated_tokens: estimatedTokens,
            context_window: contextWindow,
            usage_fraction: Number(usageFraction.toFixed(6)),
            usage_percent: `${Math.round(usageFraction * 100)}%`,
            delegation_count: delegationCount,
            session_count: sessionCount,
            threshold_30pct: usageFraction >= 0.3,
            threshold_50pct: usageFraction >= 0.5,
            confidence: "low — proxy estimation, not token-accurate",
            fallback_note:
              "If this seems inaccurate, use registry.jsonl row count × 3000 as a rough guide",
          }
          if (scope === "session") {
            result.message_count = messageCount
          }
          if (scope === "council") {
            result.estimated_credits = estimatedCredits
            result.council_budget_75pct = (estimatedCredits ?? 0) >= 1125
            result.council_budget_90pct = (estimatedCredits ?? 0) >= 1350
          }
          return JSON.stringify(result, null, 2)
        },
      }),
    },
  }

  return hooks
}

export default delegationObserver
