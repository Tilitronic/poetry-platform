/**
 * lib/registry — SRP extraction from delegation-observer.ts (DIA-260902-eqgg Slice 4).
 *
 * SINGLE writer of registry.jsonl / messages.jsonl / boot.json.
 * Pure/DI'd: all fs/path/clock/randomUUID injected via createRegistry deps.
 */

import {
  appendFileSync as nodeAppendFileSync,
  closeSync as nodeCloseSync,
  existsSync as nodeExistsSync,
  fsyncSync as nodeFsyncSync,
  mkdirSync as nodeMkdirSync,
  openSync as nodeOpenSync,
  readFileSync as nodeReadFileSync,
  renameSync as nodeRenameSync,
  rmdirSync as nodeRmdirSync,
  statSync as nodeStatSync,
  unlinkSync as nodeUnlinkSync,
  writeFileSync as nodeWriteFileSync,
} from "node:fs"
import { dirname as nodeDirname, join as nodeJoin } from "node:path"
import { randomUUID as nodeRandomUUID } from "node:crypto"
import { readFileSync as nodeReadProcFileSync } from "node:fs"
import { createJournalPersistence } from "./journal-persistence.ts"
import type { JournalResult } from "./journal-persistence.ts"

const TASK_NO_ID_GROUP_KEY = "__task_no_id__"

type FsDeps = {
  appendFileSync(path: string, data: string): void
  readFileSync(path: string, enc: string): string
  existsSync(path: string): boolean
  writeFileSync(path: string, data: string): void
  openSync(path: string, flags: string): number
  fsyncSync(fd: number): void
  closeSync(fd: number): void
  renameSync(src: string, dst: string): void
  mkdirSync(path: string, opts?: object): void
  unlinkSync(path: string): void
  rmdirSync?: (path: string) => void
  statSync(path: string): { mtimeMs: number; size: number; isFile(): boolean }
}

type PathDeps = {
  join(...parts: string[]): string
  dirname(p: string): string
}

type ClockDeps = { now?: () => number; isoNow?: () => string }

type RegistryDeps = {
  fs?: FsDeps
  path?: PathDeps
  randomUUID?: () => string
  clock?: ClockDeps
  directory?: string
  registryPath?: string
  messagesPath?: string
  messagesMdPath?: string
  bootPath?: string
  bootTmpPath?: string
  handoffDir?: string
  processStartedAt?: string
  opencodeVersion?: string
  onWarn?: (msg: string, opts?: unknown) => void
  sessionMessageCount?: Map<string, number>
  registrySeqPath?: string
  messagesRowIdPath?: string
  journalLockPath?: string
  processIdentity?: { pid: number; startedAt: string }
  isProcessAlive?: (owner: { pid: number; startedAt: string }) => boolean | { alive: boolean; startedAt?: string }
}

type LifecycleRow = Record<string, unknown> & {
  seq?: number
  timestamp?: string
  _offset?: number
  session_id?: string
  task_id?: string
  event?: string
  dispatch_state?: string
  lifecycle_generation?: number
}

type ActiveLifecycleEntry = LifecycleRow & {
  session_id: string
  lifecycle_generation: number
}

function lifecycleRowOrder(row: LifecycleRow, position: number): [number, number, number] {
  const seq = typeof row.seq === "number" && Number.isFinite(row.seq) ? row.seq : -1
  const time = typeof row.timestamp === "string" ? Date.parse(row.timestamp) : Number.NaN
  const timestamp = Number.isFinite(time) ? time : -1
  const offset = typeof row._offset === "number" ? row._offset : position
  return [seq, timestamp, offset]
}

function compareLifecycleRows(a: { row: LifecycleRow; position: number }, b: { row: LifecycleRow; position: number }): number {
  const left = lifecycleRowOrder(a.row, a.position)
  const right = lifecycleRowOrder(b.row, b.position)
  for (let index = 0; index < left.length; index += 1) {
    if (left[index] !== right[index]) return left[index] - right[index]
  }
  return a.position - b.position
}

function lifecycleIdentity(row: LifecycleRow): string | undefined {
  const value = row.session_id ?? row.task_id
  return typeof value === "string" && value.length > 0 ? value : undefined
}

function lifecycleEvent(row: LifecycleRow): string {
  return typeof row.event === "string" ? row.event.toLowerCase() : ""
}

function lifecycleState(row: LifecycleRow): string {
  return typeof row.dispatch_state === "string" ? row.dispatch_state.toLowerCase() : ""
}

function isAuthoritativeOpen(row: LifecycleRow): boolean {
  const event = lifecycleEvent(row)
  const state = lifecycleState(row)
  return (event === "dispatch" || event === "invocation" || event === "invoked" || event === "resume" || event === "recovery") &&
    state !== "completed" && state !== "failed" && state !== "error" && state !== "cancelled" && state !== "terminal"
}

function isExplicitRecovery(row: LifecycleRow): boolean {
  const event = lifecycleEvent(row)
  return event === "resume" || event === "recovery" || row.recovery === "exact-session" || row.recovery_method === "exact-session"
}

function isTerminalLifecycleRow(row: LifecycleRow): boolean {
  const event = lifecycleEvent(row)
  const state = lifecycleState(row)
  return event === "task_success" || event === "task_completed" || event === "completed" || event === "task_error" ||
    event === "task_failed" || event === "failed" || event === "error" || event === "cancelled" ||
    state === "completed" || state === "failed" || state === "error" || state === "cancelled"
}

/**
 * Project registry rows into the small lifecycle state consumed by the sweep.
 * This is deliberately functional: the returned closure owns only projection
 * state and does not read or write journals.
 */
export function createActiveLifecycleIndex({ rows = [] }: { rows?: LifecycleRow[] } = {}) {
  const active = new Map<string, ActiveLifecycleEntry>()
  const generations = new Map<string, number>()
  const closed = new Set<string>()
  const history: LifecycleRow[] = []
  const ordered = rows.map((row, position) => ({ row, position })).sort(compareLifecycleRows)

  for (const item of ordered) {
    const row = { ...item.row }
    const identity = lifecycleIdentity(row)
    if (!identity) continue
    const current = active.get(identity)
    const knownGeneration = generations.get(identity)

    if (!current && (isAuthoritativeOpen(row) || typeof row.lifecycle_generation === "number")) {
      const generation = typeof row.lifecycle_generation === "number" && !isExplicitRecovery(row) ? row.lifecycle_generation :
        (isExplicitRecovery(row) || knownGeneration === undefined || closed.has(identity) ?
          (typeof row.seq === "number" && Number.isFinite(row.seq) ? row.seq : undefined) : knownGeneration)
      if (generation === undefined) continue
      const entry = { ...row, session_id: identity, lifecycle_generation: generation }
      active.set(identity, entry)
      generations.set(identity, generation)
      continue
    }

    if (!current) continue

    if (isExplicitRecovery(row)) {
      const generation = typeof row.seq === "number" && Number.isFinite(row.seq) ? row.seq : current.lifecycle_generation
      history.push({ ...row, session_id: identity, lifecycle_generation: generation })
      active.set(identity, { ...row, session_id: identity, lifecycle_generation: generation })
      generations.set(identity, generation)
      continue
    }

    const attached = { ...row, session_id: identity, lifecycle_generation: current.lifecycle_generation }
    history.push(attached)
    if (isTerminalLifecycleRow(row)) {
      active.delete(identity)
      closed.add(identity)
      continue
    }
    active.set(identity, { ...current, ...attached, lifecycle_generation: current.lifecycle_generation })
  }

  return {
    entries: (): ActiveLifecycleEntry[] => Array.from(active.values()),
    generationFor: (identity: string): number | undefined => active.get(identity)?.lifecycle_generation ?? generations.get(identity),
    history: (): LifecycleRow[] => history.slice(),
    exportRows: (): LifecycleRow[] => Array.from(active.values()).map((entry) => ({ ...entry })),
  }
}

function resolveFs(deps: RegistryDeps): FsDeps {
  if (deps.fs && typeof deps.fs.appendFileSync === "function") return deps.fs
  return {
    appendFileSync: nodeAppendFileSync,
    readFileSync: nodeReadFileSync as unknown as FsDeps["readFileSync"],
    existsSync: nodeExistsSync,
    writeFileSync: nodeWriteFileSync,
    openSync: nodeOpenSync as unknown as FsDeps["openSync"],
    fsyncSync: nodeFsyncSync,
    closeSync: nodeCloseSync,
    renameSync: nodeRenameSync,
    mkdirSync: nodeMkdirSync as unknown as FsDeps["mkdirSync"],
    unlinkSync: nodeUnlinkSync,
    rmdirSync: nodeRmdirSync,
    statSync: nodeStatSync as unknown as FsDeps["statSync"],
  }
}

function resolvePath(deps: RegistryDeps): PathDeps {
  if (deps.path && typeof deps.path.join === "function") return deps.path
  return { join: nodeJoin, dirname: nodeDirname }
}

function resolveRandomUUID(deps: RegistryDeps): () => string {
  if (typeof deps.randomUUID === "function") return deps.randomUUID
  return nodeRandomUUID
}

function isoNow(deps: RegistryDeps): string {
  const c = deps.clock
  if (c) {
    if (typeof c.isoNow === "function") return c.isoNow()
    if (typeof c.now === "function") return new Date(c.now()).toISOString()
  }
  return new Date().toISOString()
}

function resolveDirectory(deps: RegistryDeps): string {
  return deps.directory ?? "/workspace"
}

function resolveRegistryPath(deps: RegistryDeps, path: PathDeps): string {
  if (deps.registryPath) return deps.registryPath
  return path.join(resolveDirectory(deps), ".opencode/session/registry.jsonl")
}

function resolveMessagesPath(deps: RegistryDeps, path: PathDeps): string {
  if (deps.messagesPath) return deps.messagesPath
  return path.join(resolveDirectory(deps), ".opencode/session/messages.jsonl")
}

function resolveMessagesMdPath(deps: RegistryDeps, path: PathDeps): string {
  if (deps.messagesMdPath) return deps.messagesMdPath
  return path.join(resolveDirectory(deps), ".opencode/session/messages.md")
}

function resolveBootPath(deps: RegistryDeps, path: PathDeps): string {
  if (deps.bootPath) return deps.bootPath
  return path.join(resolveDirectory(deps), ".opencode/session/boot.json")
}

function resolveBootTmpPath(deps: RegistryDeps, path: PathDeps): string {
  if (deps.bootTmpPath) return deps.bootTmpPath
  return path.join(resolveDirectory(deps), ".opencode/session/.boot.json.tmp")
}

function resolveHandoffDir(deps: RegistryDeps, path: PathDeps): string {
  if (deps.handoffDir) return deps.handoffDir
  return path.join(resolveDirectory(deps), ".opencode/session")
}

function resolveProcessStartedAt(deps: RegistryDeps): string {
  return deps.processStartedAt ?? new Date().toISOString()
}

function linuxProcessStartToken(pid: number): string | undefined {
  if (process.platform !== "linux") return undefined
  try {
    const stat = nodeReadProcFileSync(`/proc/${pid}/stat`, "utf-8")
    const close = stat.lastIndexOf(")")
    return stat.slice(close + 2).split(" ")[19]
  } catch { return undefined }
}

function resolveWarn(deps: RegistryDeps): ((msg: string, opts?: unknown) => void) | undefined {
  if (typeof deps.onWarn === "function") return deps.onWarn
  return undefined
}

function resolveSessionMessageCount(deps: RegistryDeps): Map<string, number> {
  if (deps.sessionMessageCount instanceof Map) return deps.sessionMessageCount
  return new Map<string, number>()
}

// ---------------------------------------------------------------------------
// Factory
// ---------------------------------------------------------------------------

export function createRegistry(deps: RegistryDeps = {}) {
  const fs = resolveFs(deps)
  const path = resolvePath(deps)
  const rand = resolveRandomUUID(deps)
  const warn = resolveWarn(deps)
  const sessionMessageCount = resolveSessionMessageCount(deps)

  const registryPath = resolveRegistryPath(deps, path)
  const messagesPath = resolveMessagesPath(deps, path)
  const messagesMdPath = resolveMessagesMdPath(deps, path)
  const bootPath = resolveBootPath(deps, path)
  const bootTmpPath = resolveBootTmpPath(deps, path)
  const handoffDir = resolveHandoffDir(deps, path)
  const processStartedAt = resolveProcessStartedAt(deps)
  const registrySeqPath = deps.registrySeqPath ?? path.join(resolveDirectory(deps), ".opencode/session/registry.seq")
  const messagesRowIdPath = deps.messagesRowIdPath ?? path.join(resolveDirectory(deps), ".opencode/session/messages.row-id")
  const journalLockPath = deps.journalLockPath ?? path.join(resolveDirectory(deps), ".opencode/session/journal.lock")
  const processIdentity = deps.processIdentity ?? { pid: process.pid, startedAt: linuxProcessStartToken(process.pid) ?? processStartedAt }
  const isProcessAlive = deps.isProcessAlive ?? ((owner: { pid: number; startedAt: string }) => {
    const token = linuxProcessStartToken(owner.pid)
    if (process.platform === "linux" && !nodeExistsSync(`/proc/${owner.pid}`)) return false
    return token === undefined ? { alive: true, startedAt: owner.startedAt } : { alive: true, startedAt: token }
  })
  const opencodeVersion: string | undefined = deps.opencodeVersion ?? (process.env.OPENCODE_VERSION as string | undefined)

  type AppendResult = JournalResult
  let registryCounter: number | undefined
  let messagesCounter: number | undefined
  const journal = createJournalPersistence({
    fs,
    path,
    lockPath: journalLockPath,
    processIdentity,
    isProcessAlive,
    randomUUID: rand,
    now: deps.clock?.now ?? Date.now,
  })

  function lastMessagesMdRowNumber(mdPath: string = messagesMdPath): number {
    if (!fs.existsSync(mdPath)) return 0
    let max = 0
    let content: string
    try {
      content = fs.readFileSync(mdPath, "utf-8")
    } catch {
      return 0
    }
    for (const line of content.split("\n")) {
      const m = /^\|\s*(\d+)\s*\|/.exec(line)
      if (m) {
        const n = Number.parseInt(m[1], 10)
        if (n > max) max = n
      }
    }
    return max
  }

  function maxRowIdInJsonl(jsonlPath: string = messagesPath): number {
    if (!fs.existsSync(jsonlPath)) return 0
    let max = 0
    let content: string
    try {
      content = fs.readFileSync(jsonlPath, "utf-8")
    } catch {
      return 0
    }
    for (const line of content.split("\n")) {
      if (!line) continue
      try {
        const row = JSON.parse(line) as { row_id?: number }
        if (typeof row.row_id === "number" && row.row_id > max) {
          max = row.row_id
        }
      } catch {
        // Malformed line — skip
      }
    }
    return max
  }

  function maxRegistrySeq(): number {
    if (!fs.existsSync(registryPath)) return 0
    let maxSeq = 0
    let lineCount = 0
    let hasSeq = false
    let content: string
    try {
      content = fs.readFileSync(registryPath, "utf-8")
    } catch {
      return 0
    }
    for (const line of content.split("\n")) {
      if (!line) continue
      lineCount++
      try {
        const row = JSON.parse(line) as { seq?: number }
        if (typeof row.seq === "number") { hasSeq = true; if (row.seq > maxSeq) maxSeq = row.seq }
      } catch {
        // Malformed line — skip
      }
    }
    return hasSeq ? Math.max(maxSeq, lineCount) : lineCount
  }

  function appendRow(row: Record<string, unknown>): AppendResult {
    const acquired = journal.acquireJournalLock()
    if (acquired.ok === false) return acquired
    let seq = 0
    let stage: "counter" | "append" = "counter"
    const entry: Record<string, unknown> = {
      ...row,
    }
    try {
      seq = journal.reserveCounter(registrySeqPath, maxRegistrySeq, registryCounter) + 1
      registryCounter = seq
      journal.publishCounter(registrySeqPath, seq)
      entry.seq = seq
      entry.timestamp = isoNow(deps)
      if (entry.group_key === TASK_NO_ID_GROUP_KEY) entry.group_key = `${TASK_NO_ID_GROUP_KEY}${seq}`
      stage = "append"
      journal.appendChecked(registryPath, JSON.stringify(entry) + "\n")
      journal.releaseJournalLock(acquired.token)
      return { ok: true, id: seq, entry }
    } catch (err) {
      journal.releaseJournalLock(acquired.token)
      if (warn) {
        const msg = err instanceof Error ? err.message : String(err)
        try { warn(`[registry] appendRow failed seq=${seq}: ${msg}`, { seq, error: msg }) } catch { /* noop */ }
      }
      return { ok: false, stage, retryable: false, error: err instanceof Error ? err.message : String(err), reserved_id: seq || undefined }
    }
  }

  /** Explicit, operator-invoked repair for absent/corrupt/lower sidecars. */
  function recoverCounters(): { ok: true; registry: number; messages: number } | { ok: false; stage: "lock" | "counter"; retryable: boolean; error: string } {
    const acquired = journal.acquireJournalLock()
    if (acquired.ok === false) return acquired
    try {
      const registry = maxRegistrySeq()
      const messages = Math.max(maxRowIdInJsonl(messagesPath), lastMessagesMdRowNumber(messagesMdPath))
      journal.publishCounter(registrySeqPath, registry)
      journal.publishCounter(messagesRowIdPath, messages)
      registryCounter = registry
      messagesCounter = messages
      journal.releaseJournalLock(acquired.token)
      return { ok: true, registry, messages }
    } catch (err) {
      journal.releaseJournalLock(acquired.token)
      return { ok: false, stage: "counter", retryable: false, error: err instanceof Error ? err.message : String(err) }
    }
  }

  function appendMessageRow(row: Record<string, unknown>, _sessionID?: string): AppendResult {
    const acquired = journal.acquireJournalLock()
    if (acquired.ok === false) return acquired
    let rowId = 0
    let stage: "counter" | "append" = "counter"
    const entry: Record<string, unknown> = {
      ...row,
    }
    try {
      rowId = journal.reserveCounter(
        messagesRowIdPath,
        () => Math.max(maxRowIdInJsonl(messagesPath), lastMessagesMdRowNumber(messagesMdPath)),
        messagesCounter,
      ) + 1
      messagesCounter = rowId
      journal.publishCounter(messagesRowIdPath, rowId)
      entry.row_id = rowId
      entry.event_uuid = rand()
      entry.timestamp = isoNow(deps)
      entry["gen_ai.provider.name"] = "opencode-go"
      entry.writer = "plugin"
      stage = "append"
      journal.appendChecked(messagesPath, JSON.stringify(entry) + "\n")
      if (_sessionID) {
        const prev = sessionMessageCount.get(_sessionID) ?? 0
        sessionMessageCount.set(_sessionID, prev + 1)
      }
      journal.releaseJournalLock(acquired.token)
      return { ok: true, id: rowId, entry }
    } catch (err) {
      journal.releaseJournalLock(acquired.token)
      if (warn) {
        const msg = err instanceof Error ? err.message : String(err)
        try { warn(`[registry] appendMessageRow failed row_id=${rowId}: ${msg}`, { row_id: rowId, error: msg }) } catch { /* noop */ }
      }
      return { ok: false, stage, retryable: false, error: err instanceof Error ? err.message : String(err), reserved_id: rowId || undefined }
    }
  }

  function getSessionMessageCount(sessionID: string): number {
    return sessionMessageCount.get(sessionID) ?? 0
  }

  function captureConfigLoadSignal(directory?: string): Record<string, string | null> {
    const dir = directory ?? resolveDirectory(deps)
    const mtime = (p: string): string | null => {
      try {
        return fs.existsSync(p) ? new Date(fs.statSync(p).mtimeMs).toISOString() : null
      } catch {
        return null
      }
    }
    return {
      opencode_jsonc_mtime: mtime(path.join(dir, ".opencode/opencode.jsonc")),
      omo_jsonc_mtime: mtime(path.join(dir, ".opencode/oh-my-opencode-slim.jsonc")),
    }
  }

  function atomicWriteBootMarker(marker: {
    bootId?: string
    boot_id?: string
    bootSeq?: number
    seq?: number
    boot_seq?: number
    configSignal?: Record<string, string | null>
    config_signal?: Record<string, string | null>
    configLoadSignal?: Record<string, string | null>
  }): { ok: boolean; error?: string } {
    const bootId = marker.bootId ?? marker.boot_id ?? ""
    const bootSeq = marker.bootSeq ?? marker.seq ?? marker.boot_seq ?? 0
    const configSignal = marker.configSignal ?? marker.config_signal ?? marker.configLoadSignal ?? {}
    try {
      fs.mkdirSync(handoffDir, { recursive: true })
      const content: Record<string, unknown> = {
        version: 1,
        event: "session_boot",
        boot_id: bootId,
        seq: bootSeq,
        process_started_at: processStartedAt,
        timestamp: isoNow(deps),
        ...(opencodeVersion ? { opencode_version: opencodeVersion } : {}),
        config_load_signal: configSignal,
        writer: "plugin",
      }
      const json = JSON.stringify(content, null, 2) + "\n"
      fs.writeFileSync(bootTmpPath, json)
      const tmpFd = fs.openSync(bootTmpPath, "r+")
      fs.fsyncSync(tmpFd)
      fs.closeSync(tmpFd)
      fs.renameSync(bootTmpPath, bootPath)
      const dirFd = fs.openSync(handoffDir, "r")
      fs.fsyncSync(dirFd)
      fs.closeSync(dirFd)
      return { ok: true }
    } catch (err) {
      try {
        if (fs.existsSync(bootTmpPath)) fs.unlinkSync(bootTmpPath)
      } catch {
        // secondary failure
      }
      const msg = err instanceof Error ? err.message : String(err)
      return { ok: false, error: msg }
    }
  }

  return {
    appendRow,
    appendMessageRow,
    recoverCounters,
    captureConfigLoadSignal,
    atomicWriteBootMarker,
    maxRowIdInJsonl,
    lastMessagesMdRowNumber,
    maxRegistrySeq,
    getSessionMessageCount,
    sessionMessageCount,
  }
}
