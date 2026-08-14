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
 *  - "tool.execute.before"  (input, output) - A1 batch-dispatch check (warns
 *    on unsafe parallel task() batches per DIA-144/BATCH-DISPATCH A/B/C)
 *  - "tool.execute.after"   (input, output) — A2 task_id capture (parsed from
 *    output.output, a text string; input.result does not exist) + DIA-105
 *    edit-time formatter hook (PostToolUse pattern): after an agent edits a
 *    file via edit/write/apply_patch, run `npx --no-install prettier --write`
 *    on the touched file(s) so formatting diffs do not accumulate until the
 *    DIA-094 commit gate. NON-FATAL by construction: a missing/erroring
 *    formatter writes a format_warn registry row and never blocks the edit.
 *    Deliberately prettier-only (no eslint --fix) and repo-config-respecting
 *    (prettier natively honors .prettierignore/.prettierrc). See the
 *    FORMATTER_* constants and formatEditedFile() below.
 *  - "event"                (input) — C1 session lifecycle catch-all:
 *    session.created → RUNNING (child spawn), session.idle → COMPLETE + S6
 *    A5 gate + S1 A3 silent-failure scan, session.error → FAILED + A3 scan
 *  - "experimental.session.compacting" (input, output) — inject active
 *    registry snapshot so delegations survive context compaction
 *
 * Design rules enforced: A1 batch-dispatch check (warns on unsafe parallel
 * task() batches; advisory not blocking), A2 task_id capture, A3 retroactive
 * consistency, A4 append-only registry discipline, A5 final-message gate,
 * C3 forward-only status transitions (S2 guard), DIA-105 edit-time format
 * (non-fatal, ignore-set-scoped, deterministic local prettier).
 */
import { createHash, randomUUID } from "node:crypto"
import { spawnSync } from "node:child_process"
import {
  appendFileSync,
  closeSync,
  existsSync,
  fsyncSync,
  mkdirSync,
  openSync,
  readFileSync,
  readdirSync,
  renameSync,
  statSync,
  unlinkSync,
  writeFileSync,
} from "node:fs"
import { dirname, extname, isAbsolute, join, relative, resolve } from "node:path"
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

/**
 * Best-effort extraction of a human-readable message from an error value.
 *
 * DIA-098 R1: the runtime session.error payload is one of the SDK error
 * shapes (ProviderAuthError / UnknownError / MessageOutputLengthError /
 * MessageAbortedError / ApiError) typed as { name, data: { message } },
 * NOT a JS Error with a top-level .message — so the previous String(err)
 * fallback produced the useless "[object Object]" in every session_failed
 * row (ana016 F2: 52/52 rows). Resolution order: string -> top-level
 * .message -> SDK data.message -> circular-safe JSON dump -> typed fallback
 * that can never be "[object Object]". DIA-098 ai-auditor finding 2: the
 * chain ALWAYS terminates in a string for any non-null error value —
 * safeJsonStringify returning undefined (an undumpable object) falls
 * through to the typed fallback, never to undefined (which would omit the
 * error field). undefined/null input still returns undefined (no error
 * present — the field is legitimately omitted).
 */
function errorMessage(err: unknown): string | undefined {
  if (err === undefined || err === null) return undefined
  if (typeof err === "string") return err
  if (typeof err === "object") {
    // JS Error / any object carrying a top-level string .message.
    if (
      "message" in err &&
      typeof (err as { message?: unknown }).message === "string"
    ) {
      return (err as { message: string }).message
    }
    // SDK error shapes (ProviderAuthError & co): { name, data: { message } }.
    const data = (err as { data?: unknown }).data
    if (
      typeof data === "object" &&
      data !== null &&
      "message" in data &&
      typeof (data as { message?: unknown }).message === "string"
    ) {
      return (data as { message: string }).message
    }
    // Last-resort structured dump: JSON with a replacer that collapses
    // nested Errors and marks circular refs — never String(obj).
    const dumped = safeJsonStringify(err)
    if (dumped !== undefined) return dumped
    // DIA-098 ai-auditor finding 2: stringify failed (undumpable object) —
    // terminate in the typed fallback, never undefined, never
    // "[object Object]".
    const name = (err as { name?: unknown }).name
    return `[unserializable ${typeof name === "string" && name ? name : "object"}]`
  }
  return `[unserializable ${typeof err}]`
}

/**
 * Circular-safe JSON.stringify for error dumps (DIA-098 R1). Nested Error
 * instances collapse to {name, message, stack}; revisiting an
 * already-serialized object (a cycle or a shared reference) degrades to the
 * literal "[Circular]" marker instead of throwing. Returns undefined on
 * failure so callers can fall back to a typed placeholder.
 */
function safeJsonStringify(value: unknown): string | undefined {
  const seen = new WeakSet<object>()
  function replacer(_key: string, v: unknown): unknown {
    if (typeof v === "object" && v !== null) {
      if (seen.has(v)) return "[Circular]"
      seen.add(v)
      if (v instanceof Error) {
        return { name: v.name, message: v.message, stack: v.stack }
      }
    }
    if (typeof v === "function") {
      return `[Function ${(v as { name?: string }).name ?? "anonymous"}]`
    }
    return v
  }
  try {
    return JSON.stringify(value, replacer)
  } catch {
    return undefined
  }
}

/**
 * Minimal YAML-frontmatter field extractor (ticket-gate scan, DIA-063).
 * Supports the constrained YAML subset the ticket schema uses
 * (docs/dev-infra-audit/tickets/_TEMPLATE.md): `key: value` pairs only — no
 * lists/maps/multi-line values. Robustness rules (finding E):
 *  - Locates the FIRST `---` delimiter line anywhere in the file (tickets
 *    carry an HTML comment header before the frontmatter, e.g. DIA-071) and
 *    parses until the next `---` delimiter.
 *  - Lines starting with `#` are comments and ignored (e.g. the
 *    "# --- Session Attribution" divider in every ticket).
 *  - Values may be single- or double-quoted; surrounding quotes are stripped.
 *    Quoted values may carry an inline ` # comment` suffix (as in _TEMPLATE.md)
 *    — the comment is dropped.
 *  - Unknown fields are ignored — the gate only reads status, session_id,
 *    discovered, title.
 * Returns {} when the file has no frontmatter block.
 */
function parseFrontmatterFields(raw: string): Record<string, string> {
  const fields: Record<string, string> = {}
  const lines = raw.split(/\r?\n/)
  let start = -1
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].trim() === "---") {
      start = i
      break
    }
  }
  if (start === -1) return fields
  for (let i = start + 1; i < lines.length; i++) {
    const line = lines[i]
    if (line.trim() === "---") break
    const trimmed = line.trim()
    if (!trimmed || trimmed.startsWith("#")) continue
    const m = /^([A-Za-z_][A-Za-z0-9_-]*)\s*:\s*(.*)$/.exec(trimmed)
    if (!m) continue
    let value = m[2].trim()
    if (value.startsWith('"') || value.startsWith("'")) {
      const quote = value[0]
      const close = value.indexOf(quote, 1)
      if (close !== -1) value = value.slice(1, close).trim()
    }
    fields[m[1]] = value
  }
  return fields
}

/**
 * Robust ticket-date parsing (DIA-063 finding C): accepts date-only
 * (`YYYY-MM-DD`, anchored at LOCAL midnight — a date means "that day") and
 * full ISO timestamps (values containing `T` or `Z`, parsed verbatim via
 * Date.parse). Unparseable input returns null — callers treat null as "does
 * NOT satisfy the recency check", never as a throw.
 */
function parseTicketDate(raw: string): number | null {
  const value = raw.trim()
  if (!value) return null
  const ts = /[TZ]/.test(value)
    ? Date.parse(value)
    : Date.parse(`${value}T00:00:00`)
  return Number.isFinite(ts) ? ts : null
}

/** Flat ticket model built by scanTickets (DIA-063). */
interface ScannedTicket {
  id: string
  status: string
  sessionId: string
  discoveredMs: number | null
  title: string
  filename: string
}

/**
 * Statuses the ticket gate accepts as "work in progress" (DIA-063). Compared
 * case-insensitively (scanTickets upper-cases the frontmatter value first).
 */
const OPEN_TICKET_STATUSES = new Set([
  "OPEN",
  "IN-PROGRESS",
  "DISPATCHED",
])

/**
 * Stopwords excluded from ticket-title keyword correlation (DIA-063 finding B
 * fallback). Deliberately small — the correlation is a conservative
 * best-effort signal, not NLP.
 */
const TICKET_KEYWORD_STOPWORDS = new Set([
  "the", "a", "an", "for", "with", "and", "or", "of", "to", "in", "on",
  "by", "from", "at", "this", "that", "these", "those", "it", "is", "are",
  "ticket", "dia", "work", "create", "new", "implement", "dispatch",
  "please", "gate", "phase", "fix", "research", "add", "update",
])

/**
 * Loose keyword overlap between the dispatch text and a ticket title
 * (DIA-063 finding B path-3): true when any significant word from the
 * dispatch text appears in the title. Ambiguity (no overlap) returns false —
 * the caller then BLOCKS (the whole point is to force a ticket). The
 * latest-session escape hatch was removed in the cycle-2 rework.
 */
function keywordsCorrelate(dispatchText: string, title: string): boolean {
  if (!title) return false
  const titleLower = title.toLowerCase()
  const words = dispatchText.toLowerCase().match(/[a-z0-9][a-z0-9-]{2,}/g) ?? []
  return words.some(
    (w) => !TICKET_KEYWORD_STOPWORDS.has(w) && titleLower.includes(w)
  )
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
 * row_id entirely, so this returns 0 for them — appendMessageRow's write-time
 * recompute then falls back to the messages.md row numbering (see the
 * row_id allocation comment at the top of the plugin body).
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
  // DIA-123 boot row fields (event: "session_boot"): boot_id links the row
  // to .opencode/session/boot.json; process_started_at is the plugin-load
  // (process start) time captured before any file I/O — the deterministic T1
  // a verifier compares against config file mtimes (T0).
  boot_id?: string
  process_started_at?: string
  [key: string]: unknown
}

const TERMINAL_STATES = new Set(["completed", "failed"])
const NON_TERMINAL_STATES = new Set(["invoked", "running"])

// === DIA-098 R2: proactive stall detection thresholds ===
// Env-configurable stall thresholds (minutes) for the 60s sweep; values come
// from the ana016 section 4.2 table + section 6.4 pseudocode. The ana011
// claim-staleness protocol (15-min stale, 60-min dead) aligns with the
// 60-min dead deadline. Fall back to the analysis defaults when the env var
// is absent or unparseable (never let a bad env value disable detection).
function stallThresholdMinutes(envName: string, fallback: number): number {
  const raw = process.env[envName]
  if (!raw) return fallback
  const parsed = Number.parseInt(raw, 10)
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback
}
const STALL_SWEEP_INTERVAL_MS = 60_000
const stallSubagentMinutes = stallThresholdMinutes("STALL_SUBAGENT_MINUTES", 10)
const stallOrchestratorMinutes = stallThresholdMinutes("STALL_ORCHESTRATOR_MINUTES", 20)
const stallDeadMinutes = stallThresholdMinutes("STALL_DEAD_MINUTES", 60)

// Synthetic group-key prefix for task_no_id rows (the expected abort/cancel
// path — task_id absent because PR #13958 is unmerged, so no session/task id
// exists to group by). jsonl-stats.sh excludes this prefix from its
// dangling/orphan checks so the expected path is not flagged as noise (RR-5a);
// `cancelled` stays reserved for real cancel_task events.
const TASK_NO_ID_GROUP_KEY = "__task_no_id__"

// === DIA-105 edit-time formatter hook (PostToolUse pattern) ===
//
// The repo enforces formatting only at COMMIT time (husky pre-commit DIA-094
// runs lint-staged: prettier --write + eslint --fix inside the dev container).
// This hook adds EDIT-time enforcement: when an agent edits a file, run the
// repo formatter immediately after the edit tool returns, so formatting diffs
// stop accumulating until commit. The commit gate REMAINS (DIA-094): this hook
// supplements, never replaces it.
//
// Design rules (DIA-105):
//  - NON-FATAL: a missing formatter, spawn error, or prettier error NEVER
//    breaks the agent's edit or the session. A format_warn registry row +
//    console.warn is the worst case (never a throw from the hook).
//  - Deterministic formatter: `npx --no-install prettier --write <file>`
//    (--no-install forces the LOCAL prettier 3.8.3 from node_modules — never
//    a network fetch, so behavior is identical to the DIA-094 lint-staged
//    path). prettier honors .prettierrc.json (singleQuote, printWidth 100)
//    and .prettierignore natively.
//  - Ignore set: paths under FORMATTER_IGNORE_PREFIXES are skipped entirely.
//    .opencode/session/, knowledge/, docs/dev-infra-audit/tickets/ and
//    openspec/changes/archive/ are EXPLICITLY out of scope (session artifacts,
//    research artifacts, hand-controlled ledger, archived specs). prettier's
//    own .prettierignore (node_modules/, dist/, .opencode/, tools/, etc.) is
//    additionally honored by prettier itself — belt and braces.
//  - Extension allow-list: prettier-parseable extensions ONLY (.ts, .tsx, .js,
//    .jsx, .mjs, .cjs, .vue, .css, .scss, .html, .md, .json, .jsonc, .yaml,
//    .yml). .py/.sh are EXCLUDED on purpose: prettier cannot parse them
//    ("No parser could be inferred"), and the repo formats those at commit
//    time via scripts/lint-python-files.sh (ruff) and `bash -n` (lint-staged
//    *.sh rule) — running prettier on them would guarantee a format_warn row
//    on every python/shell edit.
//  - Performance: files larger than FORMATTER_MAX_BYTES are skipped (binary /
//    generated blobs are never worth reformatting).
//  - Scope: only files the agent ACTUALLY touched (edit/write filePath,
//    apply_patch paths extracted from the patch). No whole-tree passes.
const FORMATTER_EXTENSIONS = new Set([
  ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".vue",
  ".css", ".scss", ".html", ".md", ".json", ".jsonc", ".yaml", ".yml",
])
const FORMATTER_IGNORE_PREFIXES = [
  ".opencode/session/",
  "knowledge/",
  "docs/dev-infra-audit/tickets/",
  "openspec/changes/archive/",
]
const FORMATTER_MAX_BYTES = 1024 * 1024 // 1 MiB — bigger = generated/binary
const FORMATTER_TIMEOUT_MS = 30_000 // prettier on one file is <1s; 30s is generous

/**
 * True when `filePath` (absolute or relative) is under a no-format prefix.
 * Resolves against `workspaceRoot` (caller passes ctx.directory — the plugin
 * directory discipline prefers PluginInput.directory over process.cwd() so the
 * check survives invocations started from other directories).
 */
function isFormatterIgnoredPath(
  filePath: string,
  workspaceRoot: string
): boolean {
  const absolute = isAbsolute(filePath)
    ? filePath
    : resolve(workspaceRoot, filePath)
  const rel = relative(workspaceRoot, absolute)
  return FORMATTER_IGNORE_PREFIXES.some(
    (prefix) => rel === prefix.slice(0, -1) || rel.startsWith(prefix)
  )
}

/**
 * Extract EVERY touched path from an apply_patch payload (DIA-105 formatter
 * hook). Mirrors the §10 gate marker scan (DIA-059 hardening — Index: /
 * diff --git / +++ b/ / *** Add File: / *** Update File: / *** Delete File:
 * / *** Move to: markers, including the omo rewritePatch forms) but returns
 * ALL matched paths, not just the first protected one: the formatter must
 * consider every file the patch touched. Deleted files are filtered
 * downstream by the existsSync scope check in runEditTimeFormatter.
 */
function extractPatchPaths(patchText: string): string[] {
  const paths: string[] = []
  for (const line of patchText.split(/\r?\n/)) {
    const indexMatch = /^Index:\s*(\S+)/i.exec(line)
    const diffMatch = /^diff\s+--git\s+a\/\S+\s+b\/(\S+)/.exec(line)
    const plusPlusMatch = /^\+\+\+\s+b\/(\S+)/.exec(line)
    const addFileMatch = /^\*\*\*\s+Add File:\s*(.+)/.exec(line)
    const updateFileMatch = /^\*\*\*\s+Update File:\s*(.+)/.exec(line)
    const deleteFileMatch = /^\*\*\*\s+Delete File:\s*(.+)/.exec(line)
    const moveToMatch = /^\*\*\*\s+Move to:\s*(.+)/.exec(line)
    const matchedPath =
      indexMatch?.[1] ??
      diffMatch?.[1] ??
      plusPlusMatch?.[1] ??
      addFileMatch?.[1]?.trim() ??
      updateFileMatch?.[1]?.trim() ??
      deleteFileMatch?.[1]?.trim() ??
      moveToMatch?.[1]?.trim()
    if (matchedPath && !paths.includes(matchedPath)) paths.push(matchedPath)
  }
  return paths
}

// DIA-144: approved conflict-free parallel task() batch patterns (mirror of
// the BATCH-DISPATCH rule in oh-my-opencode-slim.jsonc). READ_ONLY_LANES
// never write project files; WRITER_LANES write memory-shelf.yaml / knowledge
// artifacts — at most ONE writer may appear in a batch (rule B).
const READ_ONLY_LANES = new Set([
  "researcher",
  "ai-specialist",
  "ai-auditor",
  "code-navigator",
  "observer",
])
const WRITER_LANES = new Set(["analyzer", "conspecter", "memory-manager"])

/**
 * DIA-144: classify a parallel task() batch (the subagent_types of the task()
 * calls in one assistant turn) as SAFE or UNSAFE. Approved batches:
 *   (A) read-only fan-out — every agent in READ_ONLY_LANES;
 *   (B) single-writer + readers — at most one WRITER_LANES agent present and
 *       all other agents read-only;
 *   (C) post-fix review — exactly the pair reviewer + ai-auditor.
 * Everything else (two coders, writer pairs, coder+reviewer, unknown lanes)
 * is UNSAFE — when in doubt, warn.
 */
function isSafeTaskBatch(agents: string[]): boolean {
  if (agents.length === 0) return false
  // (A) read-only fan-out.
  if (agents.every((a) => READ_ONLY_LANES.has(a))) return true
  // (B) single-writer + read-only readers.
  const writers = agents.filter((a) => WRITER_LANES.has(a))
  if (
    writers.length <= 1 &&
    agents.every((a) => READ_ONLY_LANES.has(a) || WRITER_LANES.has(a))
  ) {
    return true
  }
  // (C) post-fix review pair.
  if (
    agents.length === 2 &&
    agents.includes("reviewer") &&
    agents.includes("ai-auditor")
  ) {
    return true
  }
  return false
}

const delegationObserver: Plugin = async (ctx) => {
  // DIA-123: capture the process-start timestamp FIRST — before any file I/O —
  // so the boot event carries the plugin-load (≈ process start) time, not the
  // row-write time. The registry row's auto `timestamp` field is the write
  // time; `process_started_at` is the deterministic process-start signal.
  const processStartedAt = new Date().toISOString()
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

  // DIA-123 boot marker paths — a dedicated boot marker file under
  // .opencode/session/ (NOT ticker.json, which needs-input-observer owns).
  // Written once per process start, atomically, carrying boot_id +
  // process_started_at so a later verifier can prove "process started at T1
  // AFTER config mtime T0" without relying on registry seq (known
  // non-monotonic per DIA-123 findings) or ticker.json updated_at (indistin-
  // guishable from a periodic rewrite).
  const bootPath = join(handoffDir, "boot.json")
  const bootTmpPath = join(handoffDir, ".boot.json.tmp")

  /** Paths (relative to workspace root) that require @ai-specialist gate review. */
  const protectedPaths = [".opencode/", "AGENTS.md"]

  // row_id allocation (READER rule — "continue from the last row # across
  // sessions, never restart"): appendMessageRow recomputes
  // row_id = MAX(max row_id in messages.jsonl, last messages.md row #) + 1
  // at write time (DIA-098 ai-auditor finding 1 — no cached counter, so the
  // id cannot collide with needs-input-observer's messages rows). The
  // messages.md floor is the legacy migration safeguard: legacy jsonl rows
  // LACK row_id, so the authoritative series was the messages.md row
  // numbering (last row = 601 at implementation time); the MAX keeps the
  // series correct even if messages.md was regenerated with fewer rows. Once
  // plugin rows carry row_id, messages.md is derived from messages.jsonl and
  // the two sources converge. The floor never affects uniqueness: every
  // write lands in messages.jsonl synchronously before the next writer's
  // read, so MAX+1 over the current file is always strictly greater than
  // every existing row_id.

  // Orchestrator session -> number of task() delegations dispatched since the
  // last handoff row. Used for decision #3 (one handoff row per orchestrator
  // idle turn that follows delegations) — reset on each handoff write so
  // repeated orchestrator idles without new delegations stay silent.
  const delegationsSinceHandoff = new Map<string, number>()

  // DIA-080 (Option A): in-memory per-session counters powering the
  // context_usage estimate, keyed by the session that triggers the activity.
  // The estimate must scope to the CURRENT orchestrator session - reading all
  // registry/messages rows since project start summed every session and
  // always returned ~100%. Non-persistent by design: a plugin restart resets
  // the counters, and the estimate is a proxy signal anyway (not
  // token-accurate).
  const sessionDelegationCount = new Map<string, number>()
  const sessionMessageCount = new Map<string, number>()

  // Child session id (task_id) -> agent name captured at dispatch. Enriches
  // completion/failure messages rows with the actual delegated agent.
  const childSessionAgent = new Map<string, string>()

  // Seed the gated-session set from existing registry rows (RR-2: the
  // per-idle gate check stays O(1) instead of re-reading the whole registry
  // on every orchestrator idle). Registry seq is deliberately NOT seeded
  // here — appendRow recomputes it from the CURRENT file state at write
  // time (DIA-098 ai-auditor finding 1) so the counter cannot drift from
  // rows written by other plugins.
  const gatedSessions = new Set<string>()
  if (existsSync(registryPath)) {
    for (const line of readFileSync(registryPath, "utf-8").trim().split("\n")) {
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

  // ===== DIA-123: deterministic boot evidence (emitted at plugin load) =====
  // The plugin body top-level runs once per process start — the ONLY point
  // where a boot event can fire before any session activity. Two artifacts,
  // one boot_id:
  //   1. registry.jsonl `session_boot` row (appendRow — the SAME stream as
  //      all activity evidence; satisfies the unify-event-writer concern).
  //   2. .opencode/session/boot.json marker (a dedicated boot marker, NOT
  //      ticker.json — that file is owned by needs-input-observer and its
  //      updated_at is indistinguishable from a periodic rewrite, DIA-123
  //      finding b2). The marker carries boot_id + process_started_at +
  //      config mtimes so a later verifier proves "process started at T1
  //      AFTER config mtime T0" without seq or ticker reasoning.
  // Determinism: `process_started_at` is the plugin-load time captured before
  // ANY file I/O; `timestamp` (auto-added by appendRow) is the row-write
  // time — both recorded so the sub-millisecond difference is explicit. The
  // marker does NOT rely on seq alone (registry seq is known non-monotonic
  // per DIA-123 findings): boot_id + process_started_at are the authoritative
  // identity; seq is an informational cross-reference to the registry row.
  // Best-effort opencode version: the @opencode-ai/plugin input exposes no
  // version getter, so we fall back to the OPENCODE_VERSION env var when the
  // runtime sets it; the field is omitted when unavailable.
  const opencodeVersion = process.env.OPENCODE_VERSION
  const bootId = randomUUID()
  const configSignal = captureConfigLoadSignal()
  // Registry seq for the current write; set by appendRow from the CURRENT
  // file state (MAX+1 — DIA-098 ai-auditor finding 1), never from a cached
  // counter. bootSeq below captures the session_boot row's value.
  let seq = 0
  appendRow({
    event: "session_boot",
    boot_id: bootId,
    process_started_at: processStartedAt,
    ...(opencodeVersion ? { opencode_version: opencodeVersion } : {}),
    config_load_signal: configSignal,
    writer: "plugin",
  })
  // seq is set by appendRow to the session_boot row's value (recomputed from
  // the current file state at write time — DIA-098 ai-auditor finding 1).
  const bootSeq = seq
  atomicWriteBootMarker({ bootId, bootSeq, configSignal })

  // Capture the config files' mtimes AT LOAD as the "config load signal":
  // this is the config state the process actually saw at boot. A verifier
  // compares the recorded mtimes against the current files: if the current
  // mtime is NEWER than the recorded one, the config was written AFTER boot
  // and a restart is required. Combined with process_started_at, this proves
  // "booted after config write T0" iff process_started_at >= recorded mtime.
  function captureConfigLoadSignal(): Record<string, string | null> {
    const mtime = (p: string): string | null => {
      try {
        return existsSync(p) ? new Date(statSync(p).mtimeMs).toISOString() : null
      } catch {
        return null // unreadable config — signal absent, never a crash
      }
    }
    return {
      opencode_jsonc_mtime: mtime(join(ctx.directory, ".opencode/opencode.jsonc")),
      omo_jsonc_mtime: mtime(
        join(ctx.directory, ".opencode/oh-my-opencode-slim.jsonc")
      ),
    }
  }

  /**
   * Atomic write of the boot marker (.opencode/session/boot.json). Same
   * pattern as atomicWriteHandoff: temp file -> fsync -> atomic rename ->
   * fsync directory. Fail-soft by construction — a lost marker never crashes
   * the plugin; the registry `session_boot` row remains the canonical boot
   * evidence.
   */
  function atomicWriteBootMarker(marker: {
    bootId: string
    bootSeq: number
    configSignal: Record<string, string | null>
  }): void {
    try {
      mkdirSync(handoffDir, { recursive: true })
      const content = {
        version: 1,
        event: "session_boot",
        boot_id: marker.bootId,
        seq: marker.bootSeq,
        process_started_at: processStartedAt,
        timestamp: new Date().toISOString(),
        ...(opencodeVersion ? { opencode_version: opencodeVersion } : {}),
        config_load_signal: marker.configSignal,
        writer: "plugin",
      }
      const json = JSON.stringify(content, null, 2) + "\n"
      writeFileSync(bootTmpPath, json)
      const tmpFd = openSync(bootTmpPath, "r+")
      fsyncSync(tmpFd)
      closeSync(tmpFd)
      renameSync(bootTmpPath, bootPath)
      const dirFd = openSync(handoffDir, "r")
      fsyncSync(dirFd)
      closeSync(dirFd)
    } catch (err) {
      // Best-effort cleanup: unlink tmp if it still exists (rename failed).
      try {
        if (existsSync(bootTmpPath)) unlinkSync(bootTmpPath)
      } catch {
        // Secondary failure — nothing more we can do.
      }
      console.warn(
        `[delegation-observer] boot.json write failed: ${errorMessage(err)}`
      )
    }
  }

  // sessionID -> tool calls executed in the current assistant turn (A1
  // heuristic). There is no message_id in the hook input, so we group by
  // session and reset on tool.execute.after. Parallel tool calls fire all
  // `before` hooks before any `after` hook, so task()+other tools in one
  // message is still detected. Each entry also carries the task()
  // subagent_type (DIA-144) so the A1 batch check can classify the parallel
  // task() lanes against the approved BATCH-DISPATCH patterns.
  const turnToolCalls = new Map<
    string,
    Array<{ tool: string; subagent_type?: string }>
  >()

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

  /**
   * Highest registry id allocated so far: max over (existing seq values,
   * non-empty line count). Mirrors the old boot-seed formula (DIA-123: the
   * line-count floor survives external row removal/reordering; legacy rows
   * WITHOUT a seq field still advance the counter past the line count).
   * Returns 0 for an absent/empty registry. O(n) per call — acceptable at
   * the observed volume (registry ~4K rows, writes per session are few);
   * needs-input-observer already scans per write with the same cost.
   */
  function maxRegistrySeq(): number {
    if (!existsSync(registryPath)) return 0
    let maxSeq = 0
    let lineCount = 0
    for (const line of readFileSync(registryPath, "utf-8").split("\n")) {
      if (!line) continue
      lineCount++
      try {
        const row = JSON.parse(line) as RegistryRow
        if (typeof row.seq === "number" && row.seq > maxSeq) maxSeq = row.seq
      } catch {
        // Malformed line — skip (same policy as readRegistryRows).
      }
    }
    return Math.max(maxSeq, lineCount)
  }

  function appendRow(row: Record<string, unknown>): void {
    // DIA-098 ai-auditor finding 1 (Critical): seq is recomputed from the
    // CURRENT file state (MAX over existing seq AND line count, +1) — never
    // from a cached in-memory counter. Both registry writers (this plugin
    // and needs-input-observer) share one server process and append
    // synchronously (appendFileSync), so read-compute-append is atomic in
    // the JS thread: no write can interleave between another writer's read
    // and its append, and MAX+1 is therefore provably collision-free under
    // mixed-plugin interleaving.
    seq = maxRegistrySeq() + 1
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
   * Scan the tickets directory into a flat ticket model (DIA-063). THROWS on
   * scan errors — including a MISSING directory (finding D) — so the caller's
   * fail-soft wrapper treats them as "broken gate → warn + allow + scan-failed
   * row" rather than "no valid ticket → block".
   */
  function scanTickets(ticketsDir: string): ScannedTicket[] {
    if (!existsSync(ticketsDir)) {
      throw new Error(`tickets directory missing: ${ticketsDir}`)
    }
    const tickets: ScannedTicket[] = []
    for (const entry of readdirSync(ticketsDir)) {
      if (!entry.endsWith(".md")) continue
      if (entry === "README.md" || entry === "_TEMPLATE.md") continue
      const ticketPath = join(ticketsDir, entry)
      if (!statSync(ticketPath).isFile()) continue
      const fm = parseFrontmatterFields(readFileSync(ticketPath, "utf-8"))
      const idMatch = /^DIA-(\d+)/.exec(entry)
      tickets.push({
        id: idMatch ? `DIA-${idMatch[1]}` : "",
        status: (fm.status ?? "").trim().toUpperCase(),
        sessionId: (fm.session_id ?? "").trim(),
        discoveredMs: parseTicketDate((fm.discovered ?? "").trim()),
        title: (fm.title ?? "").trim(),
        filename: entry,
      })
    }
    return tickets
  }

  /**
   * Work-to-ticket correlation (DIA-063 finding B). Returns true when the
   * dispatch has a credible ticket backing. Path order (first match wins):
   *   1. A DIA-id is mentioned in the dispatch → gate passes immediately when
   *      a ticket with that exact id exists AND is open (strongest signal; no
   *      recency/session-ownership requirement — DIA-076 A1). STRICT
   *      tri-state (DIA-076 C1): when an explicit DIA-id is present,
   *      resolution happens ONLY against it — a referenced id matching NO
   *      open ticket FAILS here and never falls through to Path-2/Path-3.
   *   2. No DIA-id mentioned → an open ticket owned by the current session
   *      (any recency).
   *   3. No DIA-id + no session-owned → a recent (≤24h) open ticket whose
   *      title keywords correlate with the dispatch (via keywordsCorrelate).
   *      The latest-registry-session heuristic was REMOVED (cycle-2 rework):
   *      an unrelated recent ticket from a previous session must NOT unlock a
   *      dispatch it has nothing to do with.
   *   Otherwise → return false → caller BLOCKS (the whole point is to force a
   *   ticket).
   */
  function evaluateTicketCorrelation(
    tickets: ScannedTicket[],
    sessionID: string,
    dispatchText: string,
    diaIds: string[]
  ): boolean {
    const open = tickets.filter((t) => OPEN_TICKET_STATUSES.has(t.status))
    const now = Date.now()
    const dayMs = 24 * 60 * 60 * 1000
    const isRecent = (t: ScannedTicket): boolean =>
      t.discoveredMs !== null &&
      t.discoveredMs <= now &&
      now - t.discoveredMs <= dayMs
    const isSessionOwned = (t: ScannedTicket): boolean =>
      t.sessionId === sessionID

    // Path 1 — explicit DIA-id correlation (STRICT tri-state, DIA-076 C1).
    // OPEN ticket is the STRONGEST correlation signal — an explicit DIA-id
    // matching an OPEN ticket suffices on its own, no recency/session-
    // ownership requirement. The old guard protected a hypothetical
    // stale-ticket-abuse scenario never observed in practice, and its
    // time-dependence (date-only `discovered` parses to LOCAL midnight →
    // sharp 24h cliff in parseTicketDate) made the gate non-deterministic
    // across the same nominal dispatch. Tri-state: when an explicit DIA-id is
    // present, resolution happens ONLY against it — referenced ids matching
    // NO open ticket FAIL here; Path-2/Path-3 are reached only when NO
    // explicit DIA-id is present.
    if (diaIds.length > 0) {
      const mentioned = open.filter((t) => diaIds.includes(t.id))
      // Tri-state (C1, DIA-076): when an explicit DIA-id is present, resolve
      // ONLY against it — any referenced id matching an OPEN ticket passes;
      // referenced ids matching NO open ticket FAIL here (never fall through
      // to Path-2/Path-3, which would mask an explicit citation that does not
      // resolve to live work). Path-2/3 are only for dispatches with NO
      // explicit DIA-id.
      return mentioned.length > 0
    }

    // Path 2 — session-owned open ticket (recency irrelevant).
    if (open.some(isSessionOwned)) return true

    // Path 3 — genuinely-new-work fallback: a recent open ticket whose title
    // keyword-correlates with the dispatch. No latest-session escape hatch.
    const recentOpen = open.filter(isRecent)
    return recentOpen.some((t) => keywordsCorrelate(dispatchText, t.title))
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
  function appendMessageRow(
    row: Record<string, unknown>,
    sessionID?: string
  ): void {
    // DIA-098 ai-auditor finding 1: row_id is recomputed from the CURRENT
    // file state at write time (MAX over messages.jsonl row_id and the
    // legacy messages.md floor, +1) — never from a cached counter. Same
    // collision-freedom argument as appendRow: synchronous appends in one
    // process make read-compute-append atomic, so MAX+1 is unique across
    // this plugin AND needs-input-observer's messages rows.
    const rowId =
      Math.max(
        maxRowIdInJsonl(messagesPath),
        lastMessagesMdRowNumber(messagesMdPath)
      ) + 1
    const entry: Record<string, unknown> = {
      row_id: rowId,
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
        `[delegation-observer] messages.jsonl write failed (row_id=${rowId}): ${errorMessage(err)}`
      )
    }
    // DIA-080: per-session message counter for the context_usage estimate.
    // Keyed by the session that triggers the row - callers pass the CURRENT
    // session id (input.sessionID for task() dispatch, context.sessionID for
    // log_decision, the lifecycle sessionID or its parent orchestrator for
    // idle/error rows). NOT the sticky parentSessionId: that single
    // process-level capture would attribute every row of a
    // multi-orchestrator-session process to the FIRST orchestrator, making
    // context_usage report the wrong session (DIA-080 review nit). Fallbacks:
    // parentSessionId (best effort before tool context) then "unknown", which
    // is the same key context_usage reads when called that early.
    const writerSession = sessionID ?? parentSessionId ?? "unknown"
    sessionMessageCount.set(
      writerSession,
      (sessionMessageCount.get(writerSession) ?? 0) + 1
    )
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
   * DIA-105: run the repo formatter (prettier) on file(s) an agent just
   * edited, immediately after the edit tool returns — the PostToolUse
   * pattern. The commit-time gate (DIA-094 husky/lint-staged) REMAINS
   * authoritative; this hook only stops formatting diffs from accumulating
   * between edits.
   *
   * NON-FATAL by construction: the worst outcome is a format_warn registry
   * row + console.warn. This function NEVER throws and NEVER modifies the
   * edit result — a formatter failure cannot break the agent's edit or the
   * session.
   *
   * Scope resolution (each step may short-circuit):
   *   1. Touched paths: edit/write -> args.filePath; apply_patch -> every
   *      path extracted from the patch markers (extractPatchPaths).
   *   2. Ignore set (FORMATTER_IGNORE_PREFIXES): silent skip — session
   *      artifacts, research artifacts, hand-controlled ticket ledger and
   *      archived specs are explicitly out of the formatter's scope.
   *   3. Extension allow-list: silent skip for non-prettier extensions
   *      (.py/.sh are deliberately absent — prettier cannot parse them, so
   *      attempting would ALWAYS warn; the repo formats python/shell at
   *      commit via scripts/lint-python-files.sh / `bash -n`).
   *   4. Perf guard: missing file or > FORMATTER_MAX_BYTES -> silent skip.
   *   5. Spawn `npx --no-install prettier --write <abs>` with cwd = workspace
   *      root (so .prettierrc/.prettierignore resolve like the DIA-094 gate).
   *      --no-install forces the LOCAL prettier (never a network fetch) —
   *      deterministic, identical formatter config to lint-staged.
   *   6. exit 0 -> format_applied row; spawn error / non-zero exit / timeout
   *      -> format_warn row (non-fatal).
   *
   * Row conventions mirror every other plugin row: appendRow adds seq +
   * timestamp; the row carries event/status/session_id + writer provenance.
   * file_path is stored relative to the workspace root for readability.
   */
  function runEditTimeFormatter(input: {
    tool: string
    sessionID: string
    args?: unknown
  }): void {
    const args = (input.args ?? {}) as Record<string, unknown>

    // Step 1 — resolve the paths the edit touched.
    let touchedPaths: string[] = []
    if (input.tool === "edit" || input.tool === "write") {
      if (typeof args.filePath === "string" && args.filePath) {
        touchedPaths = [args.filePath]
      }
    } else if (input.tool === "apply_patch") {
      touchedPaths = extractPatchPaths(
        typeof args.patchText === "string" ? args.patchText : ""
      )
    }
    if (touchedPaths.length === 0) return

    for (const rawPath of touchedPaths) {
      const absPath = isAbsolute(rawPath)
        ? rawPath
        : resolve(ctx.directory, rawPath)
      const relPath = relative(ctx.directory, absPath)

      // Step 2 — ignore set (silent: expected scope exclusion, not a failure).
      if (isFormatterIgnoredPath(absPath, ctx.directory)) continue

      // Step 3 — extension allow-list (silent; prettier cannot parse the rest).
      if (!FORMATTER_EXTENSIONS.has(extname(absPath).toLowerCase())) continue

      // Step 4 — perf guard: missing file (e.g. patch-deleted) or too large.
      try {
        if (!existsSync(absPath)) continue
        if (statSync(absPath).size > FORMATTER_MAX_BYTES) continue
      } catch {
        continue
      }

      // Step 5-6 — deterministic formatter invocation.
      let result
      try {
        result = spawnSync(
          "npx",
          ["--no-install", "prettier", "--write", absPath],
          {
            cwd: ctx.directory,
            encoding: "utf-8",
            timeout: FORMATTER_TIMEOUT_MS,
          }
        )
      } catch (err) {
        appendRow({
          event: "format_warn",
          session_id: input.sessionID,
          tool: input.tool,
          file_path: relPath,
          status: "WARN",
          note: `prettier spawn failed: ${errorMessage(err)}`,
          writer: "plugin",
        })
        console.warn(
          `[DIA-105] formatter spawn failed for ${relPath}: ${errorMessage(err)}`
        )
        continue
      }

      if (result.error || result.status !== 0) {
        const why = result.error
          ? (errorMessage(result.error) ?? "spawn error")
          : `prettier exit ${result.status}${
              result.signal ? ` (${result.signal})` : ""
            }`
        appendRow({
          event: "format_warn",
          session_id: input.sessionID,
          tool: input.tool,
          file_path: relPath,
          status: "WARN",
          note: why,
          writer: "plugin",
        })
        console.warn(`[DIA-105] formatter failed for ${relPath}: ${why}`)
        continue
      }

      appendRow({
        event: "format_applied",
        session_id: input.sessionID,
        tool: input.tool,
        file_path: relPath,
        status: "FORMATTED",
        formatter: "prettier",
        writer: "plugin",
      })
    }
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

  /**
   * DIA-098 R2 identity heuristic: is a delegation key the orchestrator's own
   * session or a subagent child? Mirrors the lifecycle handlers' role
   * attribution (sessionMeta role + parentSessionId match) PLUS persistent
   * row-level identity (role / parent_session fields) so sessions spawned in
   * a previous process — where sessionMeta is empty — resolve the same way.
   * Resolution order: parentSessionId match wins (resumed/child orchestrator
   * scenario), then any row carrying role:"orchestrator", then any subagent
   * signal (role:"subagent" or a parent_session on a spawn row).
   * Unidentifiable keys resolve "unknown" — the sweep treats them with the
   * subagent threshold (safe default: an earlier alert costs a re-check, a
   * missed stall costs a session).
   */
  function sessionRoleFromRows(
    key: string,
    rows: RegistryRow[]
  ): "subagent" | "orchestrator" | "unknown" {
    if (key === parentSessionId) return "orchestrator"
    const meta = sessionMeta.get(key)
    if (meta?.role === "orchestrator") return "orchestrator"
    let sawSubagent = false
    for (const r of rows) {
      if ((r.session_id ?? r.task_id) !== key) continue
      if (r.role === "orchestrator") return "orchestrator"
      if (r.role === "subagent") sawSubagent = true
      if (r.parent_session && r.parent_session !== r.session_id) sawSubagent = true
    }
    return sawSubagent ? "subagent" : "unknown"
  }

  /**
   * DIA-098 R2: emit one stall_detected registry row + one crisis messages
   * row (ana016 section 6.4 a/b). The registry row stays schema-stable
   * (event "stall_detected" + stall_duration_seconds / last_status /
   * detected_at); the dead escalation adds escalation:"dead" + note. NO
   * auto-resume (ana016 section 6.5 fail-fast): the crisis row is the
   * orchestrator's prompt to investigate and re-dispatch.
   */
  function emitStall(
    key: string,
    row: RegistryRow,
    ageSec: number,
    thresholdMin: number,
    escalation: "dead" | undefined
  ): void {
    appendRow({
      event: "stall_detected",
      session_id: row.session_id,
      task_id: row.task_id,
      stall_duration_seconds: ageSec,
      last_status: row.status,
      detected_at: new Date().toISOString(),
      ...(escalation === "dead"
        ? {
            escalation: "dead",
            note: "assumed dead - still non-terminal past STALL_DEAD_MINUTES (ana011 claim-staleness protocol)",
          }
        : {}),
      writer: "plugin",
    })
    appendMessageRow(
      {
        "gen_ai.operation.name": "invoke_workflow",
        from: "orchestrator",
        event_type: "crisis",
        task_ref: key,
        resolution_status: "in-flight",
        content_ref:
          escalation === "dead"
            ? "session_assumed_dead_after_60_min"
            : `stall_detected_after_${thresholdMin}_min`,
        next_action: "investigate and re-dispatch",
      },
      key
    )
  }

  /**
   * DIA-098 R2: proactive stall sweep (ana016 section 4.2 primary signal +
   * section 6.4 pseudocode). Runs on a 60s interval (STALL_SWEEP_INTERVAL_MS)
   * instead of the REACTIVE checkSilentFailures() boundary scan. For every
   * delegation key (session_id ?? task_id — the same id space as
   * checkSilentFailures) whose LATEST dispatch_state row is still
   * non-terminal (status RUNNING / DISPATCHED), age is measured from that
   * row's timestamp and stall_detected fires once the session's role
   * threshold is crossed:
   *   - subagent -> stallSubagentMinutes (10)
   *   - orchestrator -> stallOrchestratorMinutes (20)
   *   - unidentifiable -> the 10-min subagent threshold (safe default —
   *     see sessionRoleFromRows)
   * Sessions that already carry a silent_failure_alert row are SKIPPED —
   * the reactive alert is the existing detection for that class (ana016 F1).
   * Dedup (section 6.4 d): skip a session that already has a stall_detected
   * row within its own threshold window. Escalation: a session still stuck
   * past stallDeadMinutes (60) is assumed dead (ana011 claim-staleness
   * protocol) and gets a second stall_detected row with escalation:"dead".
   * Fail-fast by design (section 6.5): never auto-resumes.
   */
  function sweepStalledSessions(): void {
    const rows = readRegistryRows()
    // Latest dispatch_state-carrying row per delegation key. Rows without a
    // dispatch_state (a1_violation, format_applied, gate rows) share the
    // session_id namespace but are not delegations — excluded (RR-3 pattern,
    // same as checkSilentFailures).
    const latestByKey = new Map<string, RegistryRow>()
    for (const r of rows) {
      if (typeof r.dispatch_state !== "string") continue
      const key = r.session_id ?? r.task_id
      if (!key) continue
      const prev = latestByKey.get(key)
      if (!prev || (r.timestamp ?? "") >= (prev.timestamp ?? "")) {
        latestByKey.set(key, r)
      }
    }
    if (latestByKey.size === 0) return

    // Dedup windows from existing stall_detected rows (section 6.4 d):
    // per-key latest detection per tier (plain stall vs dead escalation).
    const lastStallByKey = new Map<string, number>()
    const lastDeadByKey = new Map<string, number>()
    for (const r of rows) {
      if (r.event !== "stall_detected") continue
      const key = r.session_id ?? r.task_id
      if (!key) continue
      const ts = Date.parse(r.timestamp ?? "")
      if (Number.isNaN(ts)) continue
      const tier = r.escalation === "dead" ? lastDeadByKey : lastStallByKey
      const prev = tier.get(key)
      if (prev === undefined || ts > prev) tier.set(key, ts)
    }

    const now = Date.now()
    for (const [key, row] of latestByKey) {
      if (TERMINAL_STATES.has(row.dispatch_state ?? "")) continue
      if (row.event === "silent_failure_alert") continue
      if (!NON_TERMINAL_STATES.has(row.dispatch_state ?? "")) continue
      const ts = Date.parse(row.timestamp ?? "")
      if (Number.isNaN(ts)) continue
      const ageSec = Math.max(0, Math.floor((now - ts) / 1000))
      const role = sessionRoleFromRows(key, rows)
      const thresholdMin =
        role === "orchestrator" ? stallOrchestratorMinutes : stallSubagentMinutes

      // Dead escalation: ANY session still non-terminal past the 60-min
      // deadline is assumed dead regardless of role (ana011 protocol).
      if (ageSec >= stallDeadMinutes * 60) {
        const lastDead = lastDeadByKey.get(key)
        if (lastDead !== undefined && now - lastDead < stallDeadMinutes * 60_000) {
          continue
        }
        emitStall(key, row, ageSec, stallDeadMinutes, "dead")
        continue
      }
      // Level-1 stall: role threshold crossed.
      if (ageSec < thresholdMin * 60) continue
      const lastStall = lastStallByKey.get(key)
      if (lastStall !== undefined && now - lastStall < thresholdMin * 60_000) {
        continue
      }
      emitStall(key, row, ageSec, thresholdMin, undefined)
    }
  }

  /**
   * DIA-098 R2: terminal-event resolution bookkeeping. The sweep derives its
   * watch list from RUNNING/DISPATCHED rows, so a FAILED/COMPLETE row already
   * drops the session automatically on the next tick — this function only
   * records WHY a previously-stalled delegation ended (ana016 section 6.4:
   * "if it was stalled, log resolution"). No-op when the session has no
   * stall_detected rows yet.
   */
  function logStallResolutionIfStalled(
    sessionID: string,
    resolution: string
  ): void {
    const rows = readRegistryRows()
    const stalled = rows.some(
      (r) =>
        r.event === "stall_detected" && (r.session_id ?? r.task_id) === sessionID
    )
    if (!stalled) return
    appendRow({
      event: "stall_resolved",
      session_id: sessionID,
      resolution,
      resolved_at: new Date().toISOString(),
      writer: "plugin",
    })
  }

  // DIA-098 R2: proactive stall sweep — 60s interval. The handle is stored
  // so the dispose hook (hooks cleanup) can clear it on plugin unload. A
  // throwing tick is caught and warned, never crashes the plugin (same
  // fail-soft policy as the registry writes).
  const stallSweepInterval = setInterval(() => {
    try {
      sweepStalledSessions()
    } catch (err) {
      console.warn(
        `[delegation-observer] stall sweep failed: ${errorMessage(err)}`
      )
    }
  }, STALL_SWEEP_INTERVAL_MS)

  const hooks: Hooks = {
    // A1: warn on task() calls sharing a message when the parallel task()
    // batch is not an approved conflict-free pattern (DIA-144; BATCH-DISPATCH
    // rule A/B/C). Grouped per session (message_id does not exist in the
    // input); the per-session list is reset on tool.execute.after.
    "tool.execute.before": async (input, output) => {
      const calls = turnToolCalls.get(input.sessionID) ?? []
      // Capture subagent_type alongside the tool name — same runtime args
      // contract as the ticket-gate block below (task args live in
      // output.args, read through unknown) — so the DIA-144 batch check can
      // classify the parallel task() lanes. Non-task tools carry no agent.
      const taskArgs =
        input.tool === "task"
          ? ((output as unknown as { args?: unknown }).args ?? {})
          : {}
      const taskSubagent =
        typeof (taskArgs as Record<string, unknown>).subagent_type === "string"
          ? ((taskArgs as Record<string, unknown>).subagent_type as string)
          : undefined
      calls.push({ tool: input.tool, subagent_type: taskSubagent })
      turnToolCalls.set(input.sessionID, calls)
      if (input.tool === "task" && calls.length > 1) {
        // DIA-144: warn only when the parallel task() batch is UNSAFE.
        // Approved conflict-free batches (BATCH-DISPATCH rule A/B/C) pass
        // silently; unrecognized/unknown lanes keep the default warn.
        const taskAgents = calls
          .filter((c) => c.tool === "task")
          .map((c) => c.subagent_type ?? "")
        if (!isSafeTaskBatch(taskAgents)) {
          ctx.client.app.log({
            body: {
              service: "delegation-observer",
              level: "warn",
              message: `[delegation-observer] A1 VIOLATION: task() called alongside ${calls.length - 1} other tool(s) in session ${input.sessionID}`,
            },
          })
          appendRow({
            event: "a1_violation",
            session_id: input.sessionID,
            call_id: input.callID,
            tools: calls.map((c) => c.tool),
            writer: "plugin",
          })
        }
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

      // §10 TICKET GATE (DIA-063): before §10-scoped lanes are dispatched, a
      // DIA ticket must exist in docs/dev-infra-audit/tickets/ tracking the
      // work (the "create a ticket before starting work" process rule). Scope:
      // primary trigger = ai-specialist (Phase-1 research lane); robustness
      // trigger = any lane whose description/prompt signals .opencode/ config
      // work (conservative heuristic — when in doubt, do NOT fire). Exempt:
      // explicit ticket-CREATION dispatches only (description/prompt ask to
      // create/author/write a ticket — a bare DIA-id mention is NOT exempt;
      // it is the correlation signal, finding A).
      // Fail-soft: any scan error (missing dir included, finding D) allows the
      // dispatch — a broken gate is worse than no gate (mirrors the §10
      // edit-gate fail-soft pattern above).
      if (input.tool === "task") {
        let subagentType = ""
        let description = ""
        try {
          // Same runtime args contract as the §10 edit-gate block above:
          // tool args live in output.args, accessed through unknown.
          const args =
            ((output as unknown as { args?: unknown }).args ??
              {}) as Record<string, unknown>
          subagentType =
            typeof args.subagent_type === "string" ? args.subagent_type : ""
          description =
            typeof args.description === "string" ? args.description : ""
          const prompt =
            typeof args.prompt === "string" ? args.prompt : ""
          const dispatchText = `${description}\n${prompt}`

          // Scope gate: fire for ai-specialist, or for any lane describing
          // config work (config-file pattern AND config-work words).
          // Conservative: routine lanes (code-navigator recon, researcher
          // lookup, coder implementation, reviewer, etc.) do not match unless
          // they explicitly describe config work. The first regex
          // deliberately EXCLUDES `.opencode\/`: .opencode/session/* and
          // .opencode/learnings/* are runtime artifacts, not config —
          // referencing them is not §10 work (DIA-076 A3).
          const configWorkHint =
            /opencode\.jsonc|AGENTS\.md|skill|plugin/i.test(
              dispatchText
            ) &&
            /config|edit|change|implement|modify|update|gate|review|fix/i.test(
              dispatchText
            )
          if (subagentType !== "ai-specialist" && !configWorkHint) return

          // Exempt ticket-CREATION dispatches ONLY (README "How to add a
          // ticket" flows): the dispatch must ask to create/author/write a
          // ticket. A bare DIA-id mention is NOT exempt — it is the
          // work-to-ticket correlation signal below (finding A: the old
          // /DIA-\d+/ exemption was a direct bypass).
          // ALSO exempt mechanical boot-gate checksum verification (DIA-061/
          // DIA-075): the canonical `bash -c "jq ..."` passthrough checksum
          // comparison is a mechanical BOOT task, not §10 work. Without this
          // exemption it creates a circular deadlock: the boot gate requires
          // verification → the §10 ticket gate blocks the verification lane →
          // ticket creation is itself forbidden before batch approval.
          // Boot-gate verification dispatches phrase the task as "handoff
          // checksum verification" (canonical Layer-3 brief), which
          // `checksum\s+verif` matches; the bare `sha256\b` arm was dropped
          // (DIA-076 M1) because a bare keyword is too easy to trigger in
          // unrelated §10 text.
          if (
            /create\s+(a\s+)?ticket\b|new\s+ticket\b|ticket\s+creation|author\s+ticket\b|checksum\s+verif|handoff\s*integrit/i.test(
              dispatchText
            )
          ) {
            return
          }

          // Work-to-ticket correlation (finding B): the dispatch must
          // reference a valid open ticket by DIA-id, or be owned by this
          // session, or (genuinely-new work) correlate with a recent open
          // ticket. scanTickets THROWS on scan errors — including a missing
          // tickets directory (finding D) — and the catch below converts any
          // non-gate throw into warn + allow + ticket_gate_scan_failed
          // (fail-soft: a broken gate is worse than no gate).
          const ticketsDir = join(
            ctx.directory,
            "docs/dev-infra-audit/tickets"
          )
          const diaIds =
            dispatchText.match(/DIA-\d+/gi)?.map((s) => s.toUpperCase()) ?? []
          const tickets = scanTickets(ticketsDir)
          const hasValidTicket = evaluateTicketCorrelation(
            tickets,
            input.sessionID,
            dispatchText,
            diaIds
          )
          if (hasValidTicket) return

          // No correlating ticket → decide block vs warn based on whether the
          // dispatch carried an explicit DIA-id (DIA-076 A4):
          if (diaIds.length === 0) {
            // Path-3-only failure (no DIA-id mentioned anywhere): keyword
            // correlation is weak by nature — blocking on it produced false
            // positives. Warn + allow + log a registry row; do NOT throw.
            appendRow({
              event: "ticket_gate_weak_correlation",
              session_id: input.sessionID,
              subagent_type: subagentType,
              description: description.slice(0, 300),
              writer: "plugin",
            })
            console.warn(
              `[DIA-063] §10 ticket gate: no DIA-id in dispatch and no keyword correlation — allowing ${subagentType || "unknown lane"} (weak-correlation pass)`
            )
            return
          }

          // diaIds.length > 0 but NONE matched an OPEN ticket: an explicit
          // citation that does not resolve to live work is a clear §10
          // violation — keep the hard throw (registry row follows the
          // appendRow pattern).
          appendRow({
            event: "ticket_gate_blocked",
            session_id: input.sessionID,
            subagent_type: subagentType,
            description: description.slice(0, 300),
            writer: "plugin",
          })
          throw new Error(
            "§10 TICKET GATE: No correlating DIA ticket found for this §10 work.\n" +
              "Before §10 engineering work begins, a DIA ticket must exist in " +
              "docs/dev-infra-audit/tickets/ tracking the work.\n" +
              "Action: create a DIA ticket (via @coder docs lane — see " +
              "docs/dev-infra-audit/tickets/README.md \"How to add a ticket\": " +
              "copy _TEMPLATE.md to DIA-<NNN>-<slug>.md, fill the frontmatter, " +
              "add an index row), reference the ticket ID in the dispatch, " +
              "then re-dispatch."
          )
        } catch (err) {
          // Re-throw §10 TICKET GATE errors; all other errors (fs error,
          // malformed frontmatter, missing dir) are fail-soft — a broken gate
          // is worse than no gate.
          if (
            err instanceof Error &&
            err.message.startsWith("§10 TICKET GATE:")
          ) {
            throw err
          }
          console.warn(
            `[DIA-063] ticket-gate scan failed, allowing dispatch: ${errorMessage(err)}`
          )
          appendRow({
            event: "ticket_gate_scan_failed",
            session_id: input.sessionID,
            subagent_type: subagentType,
            description: description.slice(0, 300),
            writer: "plugin",
          })
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

      // DIA-105 edit-time formatter (PostToolUse pattern): after an agent
      // edits/writes/patch-applies file(s), run the repo formatter on the
      // touched files so formatting diffs do not accumulate until the
      // DIA-094 commit gate. Non-fatal by construction — runEditTimeFormatter
      // never throws; a formatter failure writes a format_warn row and the
      // edit result is untouched.
      if (
        input.tool === "edit" ||
        input.tool === "write" ||
        input.tool === "apply_patch"
      ) {
        try {
          runEditTimeFormatter(input)
        } catch (err) {
          // Absolute last resort — never let a formatter defect reach the
          // tool result / session. warn + continue is the DIA-105 contract.
          console.warn(
            `[DIA-105] formatter hook error: ${errorMessage(err)}`
          )
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
      // DIA-080: per-session delegation counter for the context_usage
      // estimate. input.sessionID is the session that calls task() - the
      // orchestrator session (parentSessionId is captured from it above).
      sessionDelegationCount.set(
        input.sessionID,
        (sessionDelegationCount.get(input.sessionID) ?? 0) + 1
      )
      appendMessageRow(
        {
          "gen_ai.operation.name": "invoke_agent",
          "gen_ai.agent.name": agentName,
          ...(laneId ? { lane_id: laneId } : {}),
          from: "orchestrator",
          event_type: "delegation",
          task_ref: taskRef,
          resolution_status: "in-flight",
          ...(taskId ? { "gen_ai.agent.id": taskId } : {}),
        },
        input.sessionID
      )

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
          // TUI-safe logging (res007 / external-patterns/2026-08-09-tui-plugin-
          // stdout-corruption.md): raw console.* writes from plugins interleave
          // with the TUI render surface (no alt-screen buffer +
          // disableStdoutInterception). Use the SDK logger ctx.client.app.log()
          // instead. The @opencode-ai/sdk v1 client (createOpencodeClient from
          // the sdk root, which @opencode-ai/plugin exposes as ctx.client)
          // takes the payload inside `body` (Options<AppLogData>). Fail-soft:
          // default ThrowOnError=false returns errors in the result shape
          // rather than throwing, so an unawaited call cannot crash the plugin.
          ctx.client.app.log({
            body: {
              service: "delegation-observer",
              level: "info",
              message: `[delegation-observer] persistence flag: ${taskId}`,
            },
          })
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
            // DIA-124 (handoff-before-final-summary): a plugin-enforced
            // missing_handoff warning gate was ASSESSED and deliberately NOT
            // built here. Reasons: (1) session.idle fires after EVERY
            // orchestrator turn, so "final summary" cannot be distinguished
            // from a mid-cycle turn without content analysis (a heavy
            // mechanism, out of scope); (2) the decision-#3 row below is an
            // event_type:'handoff' MESSAGES row that does NOT write the
            // handoff FILE, so any "no handoff event this session" scan of
            // messages.jsonl false-positives on it; (3) the reliable cheap
            // signal is BOOT-TIME - a missing/stale current-handoff.json at
            // the next session start proves the prior session ended without
            // a terminal handoff. That is the existing batch-approval gate
            // behavior (NEXT-RUN.md 7.3), annotated as the DIA-124
            // self-check. Enforcement lives in the NEXT-RUN.md 7.2 HARD RULE
            // + the boot gate, not here.
            // Handoff row (decision #3, approved): write ONE event_type
            // "handoff" row (operation invoke_workflow) on the orchestrator's
            // own idle when the session has performed delegations since the
            // last handoff — a single row per orchestrator idle turn, then
            // reset so subsequent idles without new delegations stay silent.
            const pending = delegationsSinceHandoff.get(sessionID) ?? 0
            if (pending > 0) {
              delegationsSinceHandoff.set(sessionID, 0)
              appendMessageRow(
                {
                  "gen_ai.operation.name": "invoke_workflow",
                  from: "orchestrator",
                  event_type: "handoff",
                  task_ref: "orchestrator idle turn — delegations complete",
                  resolution_status: "done",
                  "gen_ai.agent.id": sessionID,
                },
                sessionID
              )
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
          // (childSessionAgent) when available. Message counter key: the
          // child's parent orchestrator (the session that spawned it), so the
          // row counts under the orchestrator that triggered it, not the
          // sticky first-captured parentSessionId.
          appendMessageRow(
            {
              "gen_ai.operation.name": "invoke_agent",
              "gen_ai.agent.name": childSessionAgent.get(sessionID) ?? "subagent",
              from: "orchestrator",
              event_type: "delegation",
              task_ref: "subagent session completed",
              resolution_status: "done",
              "gen_ai.agent.id": sessionID,
            },
            sessionMeta.get(sessionID)?.parentID
          )
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
          // Message counter key: the parent orchestrator for subagent rows
          // (the session that spawned the child), the session itself for
          // orchestrator rows — never the sticky first-captured
          // parentSessionId.
          appendMessageRow(
            {
              "gen_ai.operation.name": "invoke_agent",
              "gen_ai.agent.name": childSessionAgent.get(sessionID) ?? role,
              from: "orchestrator",
              event_type: "delegation",
              task_ref: "session error — delegation failed",
              resolution_status: "escalated",
              "gen_ai.agent.id": sessionID,
            },
            role === "subagent"
              ? sessionMeta.get(sessionID)?.parentID
              : sessionID
          )
          checkSilentFailures()
          // DIA-098 R2: the session errored out — record how a previously
          // stalled delegation ended (the next sweep drops it automatically).
          logStallResolutionIfStalled(sessionID, "resolved_by_error")
          return
        }

        case "session.deleted": {
          // DIA-098 R2: a deleted session is gone — record how a previously
          // stalled delegation ended. The event carries the session in
          // properties.info (v1 SDK type), with sessionID as a runtime
          // fallback — read both.
          const sessionID =
            event.properties?.sessionID ?? event.properties?.info?.id
          if (!sessionID) return
          logStallResolutionIfStalled(sessionID, "resolved_by_deleted")
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
          "Log a semantic orchestrator event (decision/handoff/crisis) to the session messages.jsonl log. COMPACT replacement for manual messages.md/jsonl edits: use for owner decisions, handoffs, and crisis declarations; mechanical delegation events are captured automatically by hooks and must NOT be logged via this tool. IMPORTANT: when event_type='handoff' and prognosis is provided, prognosis MUST be JSON.stringify()'d (the plugin parses it via JSON.parse to write the handoff file).",
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
        async execute(args, context) {
          // Parse prognosis defensively: the orchestrator LLM may pass plain
          // text instead of a JSON-stringified object (no JSON contract hint
          // reaches it). Fall back to a plain-text wrapper instead of failing.
          function parsePrognosis(raw: string | undefined): Record<string, unknown> {
            if (!raw) return {};
            try {
              return JSON.parse(raw);
            } catch {
              console.warn("[delegation-observer] prognosis parse failed — falling back to plain-text wrapper");
              return {
                session_summary: { note: raw },
                fixes_applied: [],
                open_tickets: [],
                verification_request: [],
                resume_instructions: ""
              };
            }
          }
          // Terminal handoff statuses: only these may trigger the handoff
          // writer. Non-terminal events (e.g. 'in-flight') are progress
          // observations, not cycle ends - writing them would clobber a valid
          // handoff file with a statusMap-default fallback wrapper (DIA-120).
          const TERMINAL_HANDOFF_STATUSES = new Set([
            "done",
            "escalated",
            "pending-owner",
          ])
          // When event_type is "handoff" and prognosis is provided, write the
          // atomic handoff JSON to .opencode/session/current-handoff.json so the
          // successor session can detect it via a deterministic read() — no
          // glob needed (eliminates the fast-glob dot:false footgun). Only
          // terminal resolution_status events write (DIA-120).
          if (
            args.event_type === "handoff" &&
            typeof args.prognosis === "string" &&
            args.prognosis &&
            TERMINAL_HANDOFF_STATUSES.has(args.resolution_status)
          ) {
            try {
              const prognosis = parsePrognosis(args.prognosis) as Record<
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
          } else if (
            args.event_type === "handoff" &&
            typeof args.prognosis === "string" &&
            args.prognosis
          ) {
            // Non-terminal handoff event (e.g. 'in-flight' detection log):
            // observation only, must NOT touch the handoff file (DIA-120).
            console.warn(
              `[delegation-observer] handoff-writer skipped: non-terminal resolution_status '${args.resolution_status}'`
            )
          }
          appendMessageRow(
            {
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
            },
            // context.sessionID is the CURRENT session invoking the tool (the
            // orchestrator), so the row counts under that session - not the
            // sticky first-captured parentSessionId (DIA-080 review nit).
            context?.sessionID
          )
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
        async execute(args, context) {
          const scope = args.scope ?? "session"

          // DIA-080 (Option A): the session scope estimates from in-memory
          // per-session counters instead of reading every registry/messages
          // row since project start (which summed all sessions and always
          // read ~100%). The counters are keyed by the orchestrator session -
          // the CURRENT calling session comes from the tool invocation
          // context (ToolContext.sessionID), NOT the sticky parentSessionId
          // captured at the first task() dispatch: with multiple orchestrator
          // sessions in one process, the sticky capture would report the
          // FIRST orchestrator's counts (DIA-080 review nit). parentSessionId
          // remains as a pre-context fallback, then "unknown" for pre-session
          // calls. The council scope keeps the file-derived path: agent
          // attribution lives only in the logs / childSessionAgent, so it
          // cannot come from counters.
          const callingSession =
            context?.sessionID ?? parentSessionId ?? "unknown"

          let delegationCount: number
          let messageCount = 0
          let sessionCount: number

          if (scope === "council") {
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

            // Council scope needs agent attribution, but registry rows carry
            // no agent field (the plugin never writes one). Attribute via the
            // dispatch capture (childSessionAgent: task_id -> agent) enriched
            // with the messages log's gen_ai.agent.id -> gen_ai.agent.name
            // mapping so pre-boot dispatches (ids not in the in-memory map)
            // are still attributed. Last row wins (append-only log;
            // completion rows repeat the same agent, so the overwrite is
            // idempotent in practice).
            const isCouncilAgent = (agent: string | undefined): boolean =>
              agent === "council" || agent === "councillor"
            const attribution = new Map<string, string>()
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
            const isCouncilRow = (r: RegistryRow): boolean =>
              isCouncilAgent(attribution.get(r.session_id ?? r.task_id ?? ""))

            delegationCount = delegationRows.filter(isCouncilRow).length

            // Signal 3 (council) - distinct council-attributed delegation ids
            // (the council child sessions).
            const councilIds = new Set<string>()
            for (const r of delegationRows) {
              if (isCouncilRow(r)) {
                const key = r.session_id ?? r.task_id
                if (key) councilIds.add(key)
              }
            }
            sessionCount = councilIds.size
          } else {
            // Session scope - in-memory per-session counters (DIA-080).
            delegationCount = sessionDelegationCount.get(callingSession) ?? 0
            messageCount = sessionMessageCount.get(callingSession) ?? 0

            // Signal 3 - session count scoped to the calling session: the
            // orchestrator's own session plus its direct children
            // (sessionMeta entries whose parentID is the calling session).
            let scopedSessions = 0
            for (const meta of sessionMeta.values()) {
              if (meta.parentID === callingSession) scopedSessions++
            }
            if (sessionMeta.has(callingSession)) scopedSessions++
            sessionCount = scopedSessions
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
              "If this seems inaccurate, the estimate covers only in-session activity of the current orchestrator session",
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

    // DIA-098 R2: hooks cleanup — stop the periodic stall sweep when the
    // plugin is unloaded so no orphaned interval keeps scanning the registry.
    dispose: async () => {
      clearInterval(stallSweepInterval)
    },
  }

  return hooks
}

export default delegationObserver
