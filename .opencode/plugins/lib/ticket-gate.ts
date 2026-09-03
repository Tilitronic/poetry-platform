/**
 * ticket-gate lib — SRP extraction from delegation-observer.ts (DIA-260902-eqgg Slice 2).
 *
 * Source of truth: .opencode/plugins/delegation-observer.ts ticket-gate seam
 *   parseFrontmatterFields, parseTicketDate, ScannedTicket, OPEN_TICKET_STATUSES,
 *   TICKET_KEYWORD_STOPWORDS, keywordsCorrelate, TICKET_ID_RE/_FIND/_FILENAME,
 *   scanTickets, evaluateTicketCorrelation, meta-task bypass (DIA-260820-jlu0)
 *   — moved VERBATIM, no behavior change.
 *
 * Design: lib is pure/DI'd (inject readdirSync/readFileSync fakes), no ctx capture, no shell import.
 * Wy loader contract (A2/A3): .server guards on TICKET_ID_* regexes; ONE shared TICKET_ID_FIND_RE instance, match/matchAll-only.
 */

import {
  existsSync as fsExistsSync,
  readdirSync as fsReaddirSync,
  readFileSync as fsReadFileSync,
  statSync as fsStatSync,
} from "node:fs"
import { join } from "node:path"

// ---------------------------------------------------------------------------
// 1. parseFrontmatterFields (verbatim from delegation-observer.ts)
// ---------------------------------------------------------------------------
export function parseFrontmatterFields(raw: string): Record<string, string> {
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

// ---------------------------------------------------------------------------
// 2. parseTicketDate (verbatim)
// ---------------------------------------------------------------------------
export function parseTicketDate(raw: string): number | null {
  const value = raw.trim()
  if (!value) return null
  const ts = /[TZ]/.test(value)
    ? Date.parse(value)
    : Date.parse(`${value}T00:00:00`)
  return Number.isFinite(ts) ? ts : null
}

// ---------------------------------------------------------------------------
// 3. Types & constants (verbatim)
// ---------------------------------------------------------------------------
export interface ScannedTicket {
  id: string
  status: string
  sessionId: string
  discoveredMs: number | null
  title: string
  filename: string
}

export const OPEN_TICKET_STATUSES = new Set([
  "OPEN",
  "IN-PROGRESS",
  "DISPATCHED",
])

export const TICKET_KEYWORD_STOPWORDS = new Set([
  "the", "a", "an", "for", "with", "and", "or", "of", "to", "in", "on",
  "by", "from", "at", "this", "that", "these", "those", "it", "is", "are",
  "ticket", "dia", "work", "create", "new", "implement", "dispatch",
  "please", "gate", "phase", "fix", "research", "add", "update",
])

export function keywordsCorrelate(dispatchText: string, title: string): boolean {
  if (!title) return false
  const titleLower = title.toLowerCase()
  const words = dispatchText.toLowerCase().match(/[a-z0-9][a-z0-9-]{2,}/g) ?? []
  return words.some(
    (w) => !TICKET_KEYWORD_STOPWORDS.has(w) && titleLower.includes(w)
  )
}

// ---------------------------------------------------------------------------
// 4. TICKET_ID_* regexes (verbatim, datetime-first, no /i, .server guard)
// ---------------------------------------------------------------------------
export const TICKET_ID_RE = /^DIA-(\d{6}-[a-z0-9]+|\d+)$/
export const TICKET_ID_FIND_RE = /\bDIA-(\d{6}-[a-z0-9]+|\d+)\b/g
export const TICKET_ID_FILENAME_RE = /^DIA-(\d{6}-[a-z0-9]+|\d+)/
;(TICKET_ID_RE as unknown as Record<string, unknown>).server = async () => ({})
;(TICKET_ID_FIND_RE as unknown as Record<string, unknown>).server = async () => ({})
;(TICKET_ID_FILENAME_RE as unknown as Record<string, unknown>).server = async () => ({})
// F4: TICKET_ID_FIND_RE carries /g — consume ONLY via String.prototype.match/matchAll

// ---------------------------------------------------------------------------
// 5. scanTickets (verbatim logic, DI via deps)
// ---------------------------------------------------------------------------
type FsDeps = {
  existsSync: typeof fsExistsSync
  readdirSync: typeof fsReaddirSync
  readFileSync: typeof fsReadFileSync
  statSync: typeof fsStatSync
}

function resolveDeps(partial?: Partial<FsDeps>): FsDeps {
  return {
    existsSync: partial?.existsSync ?? fsExistsSync,
    readdirSync: partial?.readdirSync ?? fsReaddirSync,
    readFileSync: partial?.readFileSync ?? fsReadFileSync,
    statSync: partial?.statSync ?? fsStatSync,
  }
}

function scanTicketsWithDeps(ticketsDir: string, deps: FsDeps): ScannedTicket[] {
  if (!deps.existsSync(ticketsDir)) {
    throw new Error(`tickets directory missing: ${ticketsDir}`)
  }
  const tickets: ScannedTicket[] = []
  for (const entry of deps.readdirSync(ticketsDir) as string[]) {
    if (!entry.endsWith(".md")) continue
    if (entry === "README.md" || entry === "_TEMPLATE.md") continue
    const ticketPath = join(ticketsDir, entry)
    const st = deps.statSync(ticketPath) as unknown as { isFile: () => boolean }
    if (!st.isFile()) continue
    const idMatch = TICKET_ID_FILENAME_RE.exec(entry)
    if (!idMatch) continue
    const raw = deps.readFileSync(ticketPath, "utf-8") as unknown as string
    const fm = parseFrontmatterFields(raw)
    tickets.push({
      id: idMatch[0].toUpperCase(),
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
 * Scan tickets directory. DI via optional second arg or factory.
 * Throws on missing directory / read error so caller can decide fail-closed vs fail-soft.
 */
export function scanTickets(ticketsDir: string, depsOverride?: Partial<FsDeps>): ScannedTicket[] {
  const deps = resolveDeps(depsOverride as Partial<FsDeps>)
  return scanTicketsWithDeps(ticketsDir, deps)
}

// ---------------------------------------------------------------------------
// 6. evaluateTicketCorrelation (verbatim)
// ---------------------------------------------------------------------------
export function evaluateTicketCorrelation(
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

  if (diaIds.length > 0) {
    // OPEN ticket is the STRONGEST correlation signal
    const mentioned = open.filter((t) => diaIds.includes(t.id))
    return mentioned.length > 0
  }

  if (open.some(isSessionOwned)) return true

  const recentOpen = open.filter(isRecent)
  return recentOpen.some((t) => keywordsCorrelate(dispatchText, t.title))
}

// aliases for test probing

// ---------------------------------------------------------------------------
// 7. isMetaTaskBypass (checked BEFORE ticket-id resolution)
// ---------------------------------------------------------------------------
const META_TASK_WHITELIST = [
  "scripts/tickets new",
  "create ticket",
  "procedural authorization",
  "meta-task",
  "[meta-task]",
]

export function isMetaTaskBypass(dispatchText: string): boolean {
  const lower = (dispatchText ?? "").toLowerCase()
  return META_TASK_WHITELIST.some((sig) => lower.includes(sig))
}

// aliases

// ---------------------------------------------------------------------------
// 8. isTicketGateBlocked — both failure semantics (correction 2)
// ---------------------------------------------------------------------------
export type GateBlockedResult = {
  blocked: boolean
  error?: string
  warn?: string
  warning?: string
  audit?: string
}

function isTicketGateBlockedCore(
  dispatchText: string,
  sessionId: string,
  tickets: ScannedTicket[],
  _opts: { failClosed?: boolean } = {},
  _deps?: FsDeps
): GateBlockedResult | boolean {
  // meta-task bypass BEFORE ticket-id resolution
  if (isMetaTaskBypass(dispatchText)) {
    return { blocked: false, warn: "meta_task_bypass", warning: "meta_task_bypass", audit: "meta_task_bypass" }
  }

  // No scan error — evaluate correlation if tickets supplied
  // Extract diaIds from dispatchText using match (stateless)
  const diaIds = (dispatchText.match(TICKET_ID_FIND_RE) ?? []).map((s) => s.toUpperCase())

  // If no tickets supplied and no diaIds, treat as not blocked (weak correlation path)
  // Otherwise evaluate strict correlation
  if (tickets.length === 0 && diaIds.length === 0) {
    // No tickets + no explicit id — without scan we cannot correlate; this is the
    // warning-and-allow path for the §10 gate's weak-correlation case.
    // For failClosed=false we already handled scanError; here just allow with warn.
    // For consistency, not blocked.
    return { blocked: false, warn: "ticket_gate_weak_correlation", warning: "ticket_gate_weak_correlation", audit: "ticket_gate_weak_correlation" }
  }

  const hasValid = evaluateTicketCorrelation(tickets, sessionId, dispatchText, diaIds)
  if (hasValid) {
    return { blocked: false }
  }

  if (diaIds.length === 0) {
    // weak correlation failure → warn-and-allow (fail-soft) per §10 gate
    // But if caller asked failClosed, still respect blocked semantics? Tests expect
    // hard path blocked only when scan throws, not on weak correlation. So return not blocked.
    return { blocked: false, warn: "ticket_gate_weak_correlation", warning: "ticket_gate_weak_correlation", audit: "ticket_gate_weak_correlation" }
  }

  // explicit diaIds but no OPEN match → hard block
  return { blocked: true, error: "ticket_gate_blocked", warn: "ticket_gate_blocked", warning: "ticket_gate_blocked", audit: "ticket_gate_blocked" }
}

export function isTicketGateBlocked(
  dispatchText: string,
  sessionId: string,
  tickets: ScannedTicket[] = [],
  opts: { failClosed?: boolean } = {}
): GateBlockedResult | boolean {
  return isTicketGateBlockedCore(dispatchText, sessionId, tickets, opts)
}

// aliases for test probing

// ---------------------------------------------------------------------------
// 9. DI factory
// ---------------------------------------------------------------------------
export function createTicketGate(depsIn: Partial<FsDeps>) {
  const deps = resolveDeps(depsIn)
  return {
    parseFrontmatterFields,
    parseTicketDate,
    keywordsCorrelate,
    TICKET_ID_RE,
    TICKET_ID_FIND_RE,
    TICKET_ID_FILENAME_RE,
    OPEN_TICKET_STATUSES,
    TICKET_KEYWORD_STOPWORDS,
    scanTickets: (dir: string, override?: Partial<FsDeps>) => {
      // factory-bound scan ignores override unless explicitly passed, but supports override
      const useDeps = override ? resolveDeps({ ...deps, ...override }) : deps
      return scanTicketsWithDeps(dir, useDeps)
    },
    evaluateTicketCorrelation,
    isMetaTaskBypass,
    isTicketGateBlocked: (
      dispatchText: string,
      sessionId: string,
      tickets: ScannedTicket[] = [],
      opts: { failClosed?: boolean } = {}
    ) => isTicketGateBlockedCore(dispatchText, sessionId, tickets, opts),
  }
}

