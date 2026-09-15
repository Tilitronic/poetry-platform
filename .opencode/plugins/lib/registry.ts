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
  readdirSync as nodeReaddirSync,
  readSync as nodeReadSync,
  renameSync as nodeRenameSync,
  rmdirSync as nodeRmdirSync,
  statSync as nodeStatSync,
  unlinkSync as nodeUnlinkSync,
  writeFileSync as nodeWriteFileSync,
} from "node:fs"
import { dirname as nodeDirname, join as nodeJoin } from "node:path"
import { randomUUID as nodeRandomUUID } from "node:crypto"
import { createHash as nodeCreateHash } from "node:crypto"
import { readFileSync as nodeReadProcFileSync } from "node:fs"
import { createJournalPersistence } from "./journal-persistence.ts"
import type { JournalResult } from "./journal-persistence.ts"

const TASK_NO_ID_GROUP_KEY = "__task_no_id__"

type FsDeps = {
  appendFileSync(path: string, data: string): void
  readFileSync(path: string): Uint8Array | string
  readFileSync(path: string, enc: string): string
  existsSync(path: string): boolean
  writeFileSync(path: string, data: string | Uint8Array): void
  openSync(path: string, flags: string): number
  fsyncSync(fd: number): void
  closeSync(fd: number): void
  renameSync(src: string, dst: string): void
  mkdirSync(path: string, opts?: object): void
  unlinkSync(path: string): void
  rmdirSync?: (path: string) => void
  statSync(path: string): { mtimeMs: number; size: number; dev?: number; ino?: number; isFile(): boolean }
  readdirSync?: (path: string, opts?: { withFileTypes?: boolean }) => string[] | { name: string; isFile(): boolean }[]
  readSync?: (fd: number, buffer: Uint8Array, offset: number, length: number, position: number) => number
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
  archiveDir?: string
  /** Test-only fault injection for the operator maintenance boundary. */
  injectFailure?: string
  activeLifecycleMaxEntries?: number
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

type ActiveLifecycleIndexOptions = {
  rows?: LifecycleRow[]
  maxEntries?: number
  maxTransitionReceipts?: number
  sourceIdentity?: string | number
  byteOffset?: number
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

function projectLifecycleRow(row: LifecycleRow): LifecycleRow {
  const allowed = [
    "seq", "timestamp", "_offset", "session_id", "task_id", "event", "dispatch_state", "status",
    "role", "parent_session", "escalation", "lifecycle_generation", "terminalUnreconciled",
    "cancellationRequested", "recovery", "recovery_method", "stall_duration_seconds", "last_status",
    "last_stall_timestamp", "last_dead_timestamp",
  ] as const
  const projected: LifecycleRow = {}
  for (const key of allowed) {
    if (row[key] !== undefined) projected[key] = row[key]
  }
  return projected
}

function isAuthoritativeOpen(row: LifecycleRow): boolean {
  const event = lifecycleEvent(row)
  const state = lifecycleState(row)
  const childSpawn = event === "session_spawn" && typeof row.session_id === "string" && row.session_id.length > 0 &&
    typeof row.parent_session === "string" && row.parent_session.length > 0 && row.parent_session !== row.session_id
  return (event === "dispatch" || event === "invocation" || event === "invoked" || childSpawn) &&
    state.length > 0 &&
    state !== "completed" && state !== "failed" && state !== "error" && state !== "cancelled" && state !== "terminal"
}

function isExplicitRecovery(row: LifecycleRow): boolean {
  const event = lifecycleEvent(row)
  return event === "resume" || event === "recovery" || row.recovery === "exact-session" || row.recovery_method === "exact-session"
}

function isRecoverableLifecycle(row: LifecycleRow): boolean {
  const event = lifecycleEvent(row)
  const state = lifecycleState(row)
  return row.terminalUnreconciled === true || event === "stopped_without_result" || event === "stopped-without-result" ||
    event === "return_channel_pending" || event === "return-channel-pending" ||
    state === "stopped_without_result" || state === "stopped-without-result" ||
    state === "return_channel_pending" || state === "return-channel-pending"
}

function isTerminalLifecycleRow(row: LifecycleRow): boolean {
  const event = lifecycleEvent(row)
  const state = lifecycleState(row)
  return event === "task_success" || event === "task_completed" || event === "completed" || event === "task_error" ||
    event === "task_failed" || event === "session_complete" || event === "session_completed" || event === "session_error" ||
    event === "failed" || event === "error" || event === "cancelled" || event === "reconciled" ||
    state === "completed" || state === "failed" || state === "error" || state === "cancelled" || state === "reconciled"
}

/**
 * Project registry rows into the small lifecycle state consumed by the sweep.
 * This is deliberately functional: the returned closure owns only projection
 * state and does not read or write journals.
 */
export function createActiveLifecycleIndex({
  rows = [],
  maxEntries = 500,
  maxTransitionReceipts = 500,
  sourceIdentity: initialSourceIdentity,
  byteOffset: initialByteOffset = 0,
}: ActiveLifecycleIndexOptions = {}) {
  if (!Number.isSafeInteger(maxEntries) || maxEntries < 1) throw new Error("active projection bound must be a positive integer")
  if (!Number.isSafeInteger(maxTransitionReceipts) || maxTransitionReceipts < 1) {
    throw new Error("active projection transition bound must be a positive integer")
  }
  const active = new Map<string, ActiveLifecycleEntry>()
  const generations = new Map<string, number>()
  const closed = new Set<string>()
  const transitions: LifecycleRow[] = []
  let sourceIdentity = initialSourceIdentity
  let byteOffset = initialByteOffset
  let partialLine = ""
  const decoder = new TextDecoder()

  function rememberTransition(row: LifecycleRow): void {
    transitions.push(row)
    if (transitions.length > maxTransitionReceipts) transitions.splice(0, transitions.length - maxTransitionReceipts)
  }

  function rememberClosed(identity: string): void {
    closed.delete(identity)
    closed.add(identity)
    while (closed.size > maxTransitionReceipts) {
      const oldest = closed.values().next().value as string | undefined
      if (oldest === undefined) break
      closed.delete(oldest)
      if (!active.has(oldest)) generations.delete(oldest)
    }
  }

  function admit(identity: string, entry: ActiveLifecycleEntry): void {
    if (!active.has(identity) && active.size >= maxEntries) {
      throw new Error(`active projection bound ${maxEntries} reached; admission rejected`)
    }
    active.set(identity, entry)
  }

  function apply(input: LifecycleRow): void {
    const row = projectLifecycleRow(input)
    const identity = lifecycleIdentity(row)
    if (!identity) return
    const current = active.get(identity)
    const knownGeneration = generations.get(identity)

    if (!current && isExplicitRecovery(row)) return
    if (!current && !isTerminalLifecycleRow(row) && (isAuthoritativeOpen(row) || typeof row.lifecycle_generation === "number")) {
      const generation = typeof row.lifecycle_generation === "number" && !isExplicitRecovery(row) ? row.lifecycle_generation :
        (isExplicitRecovery(row) || knownGeneration === undefined || closed.has(identity) ?
          (typeof row.seq === "number" && Number.isFinite(row.seq) ? row.seq : undefined) : knownGeneration)
      if (generation === undefined) return
      const entry = { ...row, session_id: identity, lifecycle_generation: generation }
      admit(identity, entry)
      generations.set(identity, generation)
      closed.delete(identity)
      return
    }

    if (!current) return

    if (isExplicitRecovery(row)) {
      if (!isRecoverableLifecycle(current)) return
      const generation = typeof row.seq === "number" && Number.isFinite(row.seq) ? row.seq : current.lifecycle_generation
      const recovered = { ...current, ...row, session_id: identity, lifecycle_generation: generation }
      rememberTransition(recovered)
      admit(identity, recovered)
      generations.set(identity, generation)
      closed.delete(identity)
      return
    }

    const attached = { ...row, session_id: identity, lifecycle_generation: current.lifecycle_generation }
    if (isTerminalLifecycleRow(row)) {
      rememberTransition(attached)
      active.delete(identity)
      rememberClosed(identity)
      return
    }
    const stallMarker = lifecycleEvent(row) === "stall_detected" && typeof row.timestamp === "string" ?
      (row.escalation === "dead" ? { last_dead_timestamp: row.timestamp } : { last_stall_timestamp: row.timestamp }) : {}
    admit(identity, { ...current, ...attached, ...stallMarker, lifecycle_generation: current.lifecycle_generation })
  }

  const ordered = rows.map((row, position) => ({ row, position })).sort(compareLifecycleRows)
  for (const item of ordered) apply(item.row)

  function consumeAppendedBytes({
    bytes,
    inode,
    offset,
  }: {
    bytes: Uint8Array | string
    inode?: string | number
    offset?: number
    readFullRegistry?: () => unknown
  }): number {
    if (sourceIdentity !== undefined && inode !== undefined && inode !== sourceIdentity) {
      throw new Error("active projection source rotated; controlled rebuild required")
    }
    if (offset !== undefined && offset !== byteOffset) {
      throw new Error(`active projection offset mismatch: expected ${byteOffset}, received ${offset}`)
    }
    if (sourceIdentity === undefined && inode !== undefined) sourceIdentity = inode
    const chunk = typeof bytes === "string" ? bytes : decoder.decode(bytes, { stream: true })
    byteOffset += typeof bytes === "string" ? new TextEncoder().encode(bytes).byteLength : bytes.byteLength
    const lines = (partialLine + chunk).split("\n")
    partialLine = lines.pop() ?? ""
    let applied = 0
    for (const line of lines) {
      if (!line) continue
      try {
        apply(JSON.parse(line) as LifecycleRow)
        applied += 1
      } catch (error) {
        if (error instanceof SyntaxError) continue
        throw error
      }
    }
    return applied
  }

  return {
    entries: (): ActiveLifecycleEntry[] => Array.from(active.values()),
    generationFor: (identity: string): number | undefined => active.get(identity)?.lifecycle_generation ?? generations.get(identity),
    history: (): LifecycleRow[] => transitions.slice(),
    exportRows: (): LifecycleRow[] => Array.from(active.values()).map((entry) => ({ ...entry })),
    apply,
    consumeAppendedBytes,
    cursor: () => ({ inode: sourceIdentity, offset: byteOffset, partialBytes: new TextEncoder().encode(partialLine).byteLength }),
  }
}

function resolveFs(deps: RegistryDeps): FsDeps {
  if (deps.fs && typeof deps.fs.appendFileSync === "function") return deps.fs
  return {
    appendFileSync: nodeAppendFileSync,
    readFileSync: nodeReadFileSync as unknown as FsDeps["readFileSync"],
    readSync: nodeReadSync,
    existsSync: nodeExistsSync,
    writeFileSync: nodeWriteFileSync,
    openSync: nodeOpenSync as unknown as FsDeps["openSync"],
    fsyncSync: nodeFsyncSync,
    closeSync: nodeCloseSync,
    renameSync: nodeRenameSync,
    mkdirSync: nodeMkdirSync as unknown as FsDeps["mkdirSync"],
    unlinkSync: nodeUnlinkSync,
    rmdirSync: nodeRmdirSync,
    readdirSync: nodeReaddirSync as unknown as FsDeps["readdirSync"],
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

function resolveSessionParent(deps: RegistryDeps, path: PathDeps): string {
  const defaultParent = path.join(resolveDirectory(deps), ".opencode/session")
  const registryParent = deps.registryPath ? path.dirname(deps.registryPath) : undefined
  const messagesParent = deps.messagesPath ? path.dirname(deps.messagesPath) : undefined
  const archiveParent = deps.archiveDir ? path.dirname(deps.archiveDir) : undefined

  const explicitParents = [registryParent, messagesParent, archiveParent].filter((value): value is string => typeof value === "string")
  const sessionParent = explicitParents[0] ?? defaultParent
  for (const parent of explicitParents) {
    if (parent !== sessionParent) {
      throw new Error("split-parent registry configuration: explicit registry/messages/archive paths must share one session parent")
    }
  }
  return sessionParent
}

function resolveRegistryPath(deps: RegistryDeps, path: PathDeps): string {
  if (deps.registryPath) return deps.registryPath
  return path.join(resolveSessionParent(deps, path), "registry.jsonl")
}

function resolveMessagesPath(deps: RegistryDeps, path: PathDeps): string {
  if (deps.messagesPath) return deps.messagesPath
  return path.join(resolveSessionParent(deps, path), "messages.jsonl")
}

function resolveMessagesMdPath(deps: RegistryDeps, path: PathDeps): string {
  if (deps.messagesMdPath) return deps.messagesMdPath
  return path.join(resolveSessionParent(deps, path), "messages.md")
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
  const sessionParent = resolveSessionParent(deps, path)

  const registryPath = resolveRegistryPath(deps, path)
  const messagesPath = resolveMessagesPath(deps, path)
  const messagesMdPath = resolveMessagesMdPath(deps, path)
  const bootPath = resolveBootPath(deps, path)
  const bootTmpPath = resolveBootTmpPath(deps, path)
  const handoffDir = resolveHandoffDir(deps, path)
  const processStartedAt = resolveProcessStartedAt(deps)
  const registrySeqPath = deps.registrySeqPath ?? path.join(sessionParent, "registry.seq")
  const messagesRowIdPath = deps.messagesRowIdPath ?? path.join(sessionParent, "messages.row-id")
  const journalLockPath = deps.journalLockPath ?? path.join(sessionParent, "journal.lock")
  const archiveDir = deps.archiveDir ?? path.join(sessionParent, "registry-archive")
  const processIdentity = deps.processIdentity ?? { pid: process.pid, startedAt: linuxProcessStartToken(process.pid) ?? processStartedAt }
  const isProcessAlive = deps.isProcessAlive ?? ((owner: { pid: number; startedAt: string }) => {
    const token = linuxProcessStartToken(owner.pid)
    if (process.platform === "linux" && !nodeExistsSync(`/proc/${owner.pid}`)) return false
    return token === undefined ? { alive: true, startedAt: owner.startedAt } : { alive: true, startedAt: token }
  })
  const opencodeVersion: string | undefined = deps.opencodeVersion ?? (process.env.OPENCODE_VERSION as string | undefined)

  type AppendResult = JournalResult | {
    ok: false
    stage: "index"
    retryable: false
    error: string
    reserved_id: number
  }
  let registryCounter: number | undefined
  let messagesCounter: number | undefined
  let suppressedDuplicateCount = 0
  let activeIndexDirty = false
  const activeLifecycleMaxEntries = deps.activeLifecycleMaxEntries ?? 500
  let bootstrapContent = ""
  let bootstrapByteLength = 0
  let bootstrapIdentity: string | undefined
  if (fs.existsSync(registryPath)) {
    try {
      const before = fs.statSync(registryPath)
      const bootstrapBytes = fs.readFileSync(registryPath)
      bootstrapContent = typeof bootstrapBytes === "string" ? bootstrapBytes : Buffer.from(bootstrapBytes).toString("utf-8")
      bootstrapByteLength = typeof bootstrapBytes === "string" ? Buffer.byteLength(bootstrapBytes) : bootstrapBytes.byteLength
      const after = fs.statSync(registryPath)
      if (before.size !== after.size || before.dev !== after.dev || before.ino !== after.ino) throw new Error("registry changed during bootstrap")
      if (typeof after.dev === "number" && typeof after.ino === "number") bootstrapIdentity = `${after.dev}:${after.ino}`
    } catch {
      activeIndexDirty = true
    }
  }
  const bootstrapRows: LifecycleRow[] = []
  let bootstrapOffset = 0
  let bootstrapLineCount = 0
  let bootstrapMaxSeq = 0
  let bootstrapHasSeq = false
  for (const line of bootstrapContent.split("\n")) {
    const lineBytes = new TextEncoder().encode(`${line}\n`).byteLength
    if (line) {
      bootstrapLineCount += 1
      try {
        const parsed = JSON.parse(line) as LifecycleRow
        bootstrapRows.push({ ...parsed, _offset: bootstrapOffset })
        if (typeof parsed.seq === "number") {
          bootstrapHasSeq = true
          if (parsed.seq > bootstrapMaxSeq) bootstrapMaxSeq = parsed.seq
        }
      } catch { /* malformed history is not active */ }
    }
    bootstrapOffset += lineBytes
  }
  if (!bootstrapContent.endsWith("\n") && bootstrapContent.length > 0) {
    bootstrapOffset -= 1
  }
  let registryHistoryMax = bootstrapHasSeq ? Math.max(bootstrapMaxSeq, bootstrapLineCount) : bootstrapLineCount
  let activeLifecycleIndex: ReturnType<typeof createActiveLifecycleIndex>
  try {
    activeLifecycleIndex = createActiveLifecycleIndex({
      rows: bootstrapRows,
      maxEntries: activeLifecycleMaxEntries,
      sourceIdentity: bootstrapIdentity,
      byteOffset: bootstrapByteLength,
    })
  } catch {
    activeIndexDirty = true
    activeLifecycleIndex = createActiveLifecycleIndex({ maxEntries: activeLifecycleMaxEntries })
  }
  const journal = createJournalPersistence({
    fs,
    path,
    lockPath: journalLockPath,
    processIdentity,
    isProcessAlive,
    randomUUID: rand,
    now: deps.clock?.now ?? Date.now,
  })

  function refreshActiveLifecycleIndex(): { ok: true; applied: number } | { ok: false; error: string } {
    if (activeIndexDirty) return { ok: false, error: "active lifecycle index requires controlled rebuild" }
    if (!fs.existsSync(registryPath)) return { ok: true, applied: 0 }
    try {
      const stat = fs.statSync(registryPath)
      const cursor = activeLifecycleIndex.cursor()
      const identity = typeof stat.dev === "number" && typeof stat.ino === "number" ? `${stat.dev}:${stat.ino}` : undefined
      if (cursor.inode !== undefined && identity !== undefined && cursor.inode !== identity) {
        activeIndexDirty = true
        return { ok: false, error: "active lifecycle registry rotated; controlled rebuild required" }
      }
      if (stat.size < cursor.offset || !fs.readSync) {
        activeIndexDirty = true
        return { ok: false, error: "active lifecycle registry cursor is no longer readable" }
      }
      const remaining = stat.size - cursor.offset
      if (remaining === 0) return { ok: true, applied: 0 }
      const bytes = new Uint8Array(remaining)
      const fd = fs.openSync(registryPath, "r")
      let read = 0
      try {
        while (read < remaining) {
          const count = fs.readSync(fd, bytes, read, remaining - read, cursor.offset + read)
          if (count === 0) break
          read += count
        }
      } finally {
        fs.closeSync(fd)
      }
      const after = fs.statSync(registryPath)
      const afterIdentity = typeof after.dev === "number" && typeof after.ino === "number" ? `${after.dev}:${after.ino}` : undefined
      if (identity !== afterIdentity || after.size < cursor.offset + read) {
        activeIndexDirty = true
        return { ok: false, error: "active lifecycle registry changed during refresh; rebuild required" }
      }
      const applied = activeLifecycleIndex.consumeAppendedBytes({
        bytes: bytes.subarray(0, read),
        inode: identity,
        offset: cursor.offset,
      })
      return { ok: true, applied }
    } catch (error) {
      activeIndexDirty = true
      return { ok: false, error: error instanceof Error ? error.message : String(error) }
    }
  }

  function rebuildActiveLifecycleIndex(): { ok: true; applied: number } | { ok: false; error: string } {
    try {
      const before = fs.statSync(registryPath)
      const content = fs.readFileSync(registryPath, "utf-8")
      const after = fs.statSync(registryPath)
      if (before.size !== after.size || before.dev !== after.dev || before.ino !== after.ino) {
        throw new Error("active lifecycle registry changed during controlled rebuild")
      }
      const rows: LifecycleRow[] = []
      let offset = 0
      for (const line of content.split("\n")) {
        if (line) {
          try { rows.push({ ...(JSON.parse(line) as LifecycleRow), _offset: offset }) } catch { /* malformed row */ }
        }
        offset += new TextEncoder().encode(`${line}\n`).byteLength
      }
      const identity = typeof after.dev === "number" && typeof after.ino === "number" ? `${after.dev}:${after.ino}` : undefined
      const candidate = createActiveLifecycleIndex({
        rows,
        maxEntries: activeLifecycleMaxEntries,
        sourceIdentity: identity,
        byteOffset: new TextEncoder().encode(content).byteLength,
      })
      activeLifecycleIndex = candidate
      activeIndexDirty = false
      return { ok: true, applied: rows.length }
    } catch (error) {
      activeIndexDirty = true
      return { ok: false, error: error instanceof Error ? error.message : String(error) }
    }
  }

  function readActiveLifecycleEntries(): ActiveLifecycleEntry[] {
    const refreshed = refreshActiveLifecycleIndex()
    if (!refreshed.ok) throw new Error(refreshed.error)
    return activeLifecycleIndex.entries()
  }

  /**
   * Return bounded, privacy-safe health data for an operator or diagnostic
   * caller. This reads the active registry and archive directory only; it
   * never writes, exposes raw rows, or includes prompt/output content.
   */
  function getDiagnostics(): Record<string, unknown> {
    let activeBytes = 0
    let malformedExamples: Array<{ line: number; offset: number }> = []
    let lastRotation: Record<string, unknown> | null = null
    try {
      const raw = fs.readFileSync(registryPath)
      const bytes = typeof raw === "string" ? Buffer.from(raw) : Buffer.from(raw)
      activeBytes = bytes.byteLength
      const text = bytes.toString("utf-8")
      let offset = 0
      for (const [index, line] of text.split("\n").entries()) {
        if (line.trim()) {
          try {
            const row = JSON.parse(line) as Record<string, unknown>
            if (row.event === "registry_rotated") lastRotation = {
              timestamp: typeof row.timestamp === "string" ? row.timestamp : null,
              archive_path: typeof row.archive_path === "string" ? row.archive_path : null,
              archive_sha256: typeof row.archive_sha256 === "string" ? row.archive_sha256 : null,
            }
          } catch {
            if (malformedExamples.length < 5) malformedExamples.push({ line: index + 1, offset })
          }
        }
        offset += Buffer.byteLength(`${line}\n`)
      }
    } catch {
      // A read failure is represented by zeroed bounded diagnostics. The
      // operator command remains read-only and does not synthesize state.
    }
    let archiveCount = 0
    let archiveBytes = 0
    try {
      const names = fs.readdirSync?.(archiveDir) ?? []
      for (const item of names) {
        const name = typeof item === "string" ? item : item.name
        if (!name.endsWith(".jsonl")) continue
        archiveCount += 1
        try { archiveBytes += fs.statSync(path.join(archiveDir, name)).size } catch { /* diagnostic best effort */ }
      }
    } catch {
      // An absent archive directory is a valid pre-rotation state.
    }
    const active = activeLifecycleIndex.entries()
    const live = active.filter((entry) => lifecycleState(entry) === "running" || lifecycleState(entry) === "in_progress").length
    const recoverable = active.filter((entry) => isRecoverableLifecycle(entry)).length
    const tombstones = active.filter((entry) => entry.terminalUnreconciled === true ||
      lifecycleEvent(entry) === "stopped-without-result" || lifecycleEvent(entry) === "return-channel-pending").length
    return {
      active_bytes: activeBytes,
      active_count: active.length,
      live_count: live,
      recoverable_count: recoverable,
      tombstone_count: tombstones,
      last_registry_seq: Math.max(registryHistoryMax, registryCounter ?? 0),
      last_message_row_id: Math.max(messagesCounter ?? 0, maxRowIdInJsonl(messagesPath)),
      archive_count: archiveCount,
      archive_bytes: archiveBytes,
      index_dirty: activeIndexDirty,
      last_rotation: lastRotation,
      suppressed_duplicate_count: suppressedDuplicateCount,
      malformed_examples: malformedExamples,
    }
  }

  /**
   * Explicit operator-only registry rotation.  This is intentionally not
   * called by observers or periodic sweep code: rotation is a maintenance
   * boundary, not a hot-path lifecycle operation.
   */
  function rotateRegistry(): {
    ok: true
    archivePath: string
    manifestPath: string
    retainedActive: number
    malformedRows: number
    checksum: string
  } | { ok: false; stage: string; error: string } {
    let acquired = journal.acquireJournalLock()
    for (let attempt = 0; acquired.ok === false && attempt < 100; attempt += 1) {
      if (typeof Atomics?.wait === "function") {
        Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1)
      }
      acquired = journal.acquireJournalLock()
    }
    if (acquired.ok === false) return acquired
    let archivePath = ""
    let manifestPath = ""
    let sourceBytes: Uint8Array | undefined
    let activeReplaced = false
    let rotationStage = "lock"
    try {
      if (!fs.existsSync(registryPath)) {
        journal.releaseJournalLock(acquired.token)
        return { ok: true, archivePath: "", manifestPath: "", retainedActive: 0, malformedRows: 0, checksum: nodeCreateHash("sha256").update("").digest("hex") }
      }

      const refreshed = refreshActiveLifecycleIndex()
      if (!refreshed.ok) throw new Error(`index: ${refreshed.error}`)
      const before = fs.statSync(registryPath)
      const sourceRead = fs.readFileSync(registryPath)
      sourceBytes = typeof sourceRead === "string" ? Buffer.from(sourceRead) : sourceRead
      const source = Buffer.from(sourceBytes).toString("utf-8")
      const after = fs.statSync(registryPath)
      if (before.size !== after.size || before.dev !== after.dev || before.ino !== after.ino) {
        throw new Error("source registry changed during rotation snapshot")
      }

      let validRows = 0
      let malformedRows = 0
      let firstSeq: number | undefined
      let lastSeq: number | undefined
      for (const line of source.split("\n")) {
        if (!line) continue
        try {
          const row = JSON.parse(line) as LifecycleRow
          validRows += 1
          if (typeof row.seq === "number" && Number.isFinite(row.seq)) {
            firstSeq = firstSeq === undefined ? row.seq : Math.min(firstSeq, row.seq)
            lastSeq = lastSeq === undefined ? row.seq : Math.max(lastSeq, row.seq)
          }
        } catch { malformedRows += 1 }
      }

      rotationStage = "copy"
      fs.mkdirSync(archiveDir, { recursive: true })
      const stamp = isoNow(deps).replace(/[^0-9]/g, "").slice(0, 14) || String(Date.now())
      const archiveName = `registry-${stamp}-${rand()}.jsonl`
      archivePath = path.join(archiveDir, archiveName)
      const archiveTmp = `${archivePath}.tmp`
      manifestPath = path.join(archiveDir, `${archiveName}.manifest.json`)
      const manifestTmp = `${manifestPath}.tmp`
      const activeTmp = `${registryPath}.rotate-${rand()}.tmp`
      if (deps.injectFailure === "copy") throw new Error("injected copy failure")
      fs.writeFileSync(archiveTmp, sourceBytes)
      rotationStage = "archive fsync"
      fsyncPath(archiveTmp)
      if (deps.injectFailure === "checksum") throw new Error("injected checksum failure")
      const checksum = nodeCreateHash("sha256").update(fs.readFileSync(archiveTmp)).digest("hex")
      const manifest = {
        archive: archiveName,
        sha256: checksum,
        byte_count: sourceBytes.byteLength,
        row_count: validRows,
        malformed_row_count: malformedRows,
        first_seq: firstSeq ?? null,
        last_seq: lastSeq ?? null,
        created_at: isoNow(deps),
      }
      rotationStage = "manifest write"
      fs.writeFileSync(manifestTmp, `${JSON.stringify(manifest, null, 2)}\n`)
      rotationStage = "manifest fsync"
      fsyncPath(manifestTmp)
      rotationStage = "verification"
      const stagedArchive = fs.readFileSync(archiveTmp)
      const stagedManifest = JSON.parse(fs.readFileSync(manifestTmp, "utf-8")) as typeof manifest
      if (!Buffer.from(stagedArchive).equals(Buffer.from(sourceBytes)) || stagedManifest.sha256 !== checksum || stagedManifest.byte_count !== sourceBytes.byteLength) {
        throw new Error("rotation archive verification failed")
      }
      rotationStage = "archive publish"
      if (deps.injectFailure === "rename") {
        rotationStage = "rename"
        throw new Error("injected rename failure")
      }
      fs.renameSync(archiveTmp, archivePath)
      rotationStage = "manifest publish"
      fs.renameSync(manifestTmp, manifestPath)
      fsyncDirectory(archivePath)

      const retained = activeLifecycleIndex.exportRows()
      const compact = retained.length === 0 ? "" : retained.map((row) => JSON.stringify(row)).join("\n") + "\n"
      fs.writeFileSync(activeTmp, compact)
      fsyncPath(activeTmp)
      rotationStage = "active replacement"
      fs.renameSync(activeTmp, registryPath)
      activeReplaced = true
      fsyncDirectory(registryPath)
      rotationStage = "index rebuild"
      const rebuilt = rebuildActiveLifecycleIndex()
      if (!rebuilt.ok) throw new Error(`index rebuild: ${rebuilt.error}`)

      const rotationEntry: Record<string, unknown> = {
        event: "registry_rotated",
        archive_path: archivePath,
        archive_sha256: checksum,
        sequence_range: { first: firstSeq ?? null, last: lastSeq ?? null },
        retained_active_count: retained.length,
        malformed_row_count: malformedRows,
        seq: journal.reserveCounter(registrySeqPath, maxRegistrySeq, registryCounter) + 1,
        timestamp: isoNow(deps),
      }
      rotationStage = "counter publication"
      registryCounter = rotationEntry.seq as number
      journal.publishCounter(registrySeqPath, registryCounter)
      rotationStage = "rotation event append"
      journal.appendChecked(registryPath, `${JSON.stringify(rotationEntry)}\n`)
      registryHistoryMax = Math.max(registryHistoryMax, registryCounter)
      activeLifecycleIndex.apply(rotationEntry as LifecycleRow)
      journal.releaseJournalLock(acquired.token)
      return {
        ok: true, archivePath, manifestPath, retainedActive: retained.length, malformedRows, checksum,
        sourceBytes: sourceBytes.byteLength, archiveBytes: sourceBytes.byteLength,
        registrySeq: registryCounter, messageRowId: Math.max(messagesCounter ?? 0, maxRowIdInJsonl(messagesPath)),
      }
    } catch (error) {
      if (activeReplaced && sourceBytes !== undefined) {
        try {
          const rollbackTmp = `${registryPath}.rollback-${rand()}.tmp`
          fs.writeFileSync(rollbackTmp, sourceBytes)
          fsyncPath(rollbackTmp)
          fs.renameSync(rollbackTmp, registryPath)
          fsyncDirectory(registryPath)
          const restored = rebuildActiveLifecycleIndex()
          if (!restored.ok) activeIndexDirty = true
        } catch {
          activeIndexDirty = true
        }
      }
      journal.releaseJournalLock(acquired.token)
      return { ok: false, stage: rotationStage, error: error instanceof Error ? error.message : String(error) }
    }
  }

  function fsyncPath(filePath: string): void {
    const fd = fs.openSync(filePath, "r+")
    try { fs.fsyncSync(fd) } finally { fs.closeSync(fd) }
  }

  function fsyncDirectory(filePath: string): void {
    let fd: number
    try { fd = fs.openSync(path.dirname(filePath), "r") } catch { return }
    try { fs.fsyncSync(fd) } finally { fs.closeSync(fd) }
  }

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
    return registryHistoryMax
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
      registryHistoryMax = Math.max(registryHistoryMax, seq)
      journal.releaseJournalLock(acquired.token)
      if (activeIndexDirty) {
        return {
          ok: false,
          stage: "index",
          retryable: false,
          error: "registry row persisted but active lifecycle index requires controlled rebuild",
          reserved_id: seq,
        }
      }
      try {
        activeLifecycleIndex.apply(entry)
      } catch (error) {
        activeIndexDirty = true
        return {
          ok: false,
          stage: "index",
          retryable: false,
          error: error instanceof Error ? error.message : String(error),
          reserved_id: seq,
        }
      }
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

  /**
   * Atomically reserve and append one stall tier after checking the durable
   * active projection. The lock covers both the incremental ingest and the
   * compare, so separate plugin processes converge on one row.
   */
  function compareAndAppendStall(candidate: {
    session_id?: string
    task_id?: string
    lifecycle_generation?: number
    tier?: string
    row: Record<string, unknown>
  }): AppendResult | { ok: false; reason: "duplicate" } {
    let acquired = journal.acquireJournalLock()
    for (let attempt = 0; acquired.ok === false && attempt < 100; attempt += 1) {
      if (typeof Atomics?.wait === "function") {
        Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1)
      }
      acquired = journal.acquireJournalLock()
    }
    if (acquired.ok === false) return acquired
    let stage: "counter" | "append" = "counter"
    try {
      const refreshed = refreshActiveLifecycleIndex()
      if (!refreshed.ok) {
        journal.releaseJournalLock(acquired.token)
        return { ok: false, stage: "index", retryable: false, error: refreshed.error }
      }
      const identity = candidate.session_id ?? candidate.task_id
      const generation = candidate.lifecycle_generation
      const tier = candidate.tier ?? (candidate.row.escalation === "dead" ? "dead" : "stall")
      const existing = identity && typeof generation === "number"
        ? activeLifecycleIndex.entries().find((entry) =>
          entry.session_id === identity && entry.lifecycle_generation === generation &&
          (tier === "dead" ? typeof entry.last_dead_timestamp === "string" : typeof entry.last_stall_timestamp === "string"))
        : undefined
      if (existing) {
        suppressedDuplicateCount += 1
        journal.releaseJournalLock(acquired.token)
        return { ok: false, reason: "duplicate" }
      }

      let seq = 0
      const entry: Record<string, unknown> = { ...candidate.row }
      entry[tier === "dead" ? "last_dead_timestamp" : "last_stall_timestamp"] = isoNow(deps)
      seq = journal.reserveCounter(registrySeqPath, maxRegistrySeq, registryCounter) + 1
      registryCounter = seq
      journal.publishCounter(registrySeqPath, seq)
      entry.seq = seq
      entry.timestamp = entry[tier === "dead" ? "last_dead_timestamp" : "last_stall_timestamp"]
      stage = "append"
      journal.appendChecked(registryPath, JSON.stringify(entry) + "\n")
      registryHistoryMax = Math.max(registryHistoryMax, seq)
      try {
        activeLifecycleIndex.apply(entry)
      } catch (error) {
        activeIndexDirty = true
        journal.releaseJournalLock(acquired.token)
        return { ok: false, stage: "index", retryable: false,
          error: error instanceof Error ? error.message : String(error), reserved_id: seq }
      }
      journal.releaseJournalLock(acquired.token)
      return { ok: true, id: seq, entry }
    } catch (error) {
      journal.releaseJournalLock(acquired.token)
      return { ok: false, stage, retryable: false,
        error: error instanceof Error ? error.message : String(error) }
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
    compareAndAppendStall,
    appendMessageRow,
    recoverCounters,
    captureConfigLoadSignal,
    atomicWriteBootMarker,
    maxRowIdInJsonl,
    lastMessagesMdRowNumber,
    maxRegistrySeq,
    getSessionMessageCount,
    sessionMessageCount,
    activeLifecycleIndex,
    refreshActiveLifecycleIndex,
    rebuildActiveLifecycleIndex,
    readActiveLifecycleEntries,
    getDiagnostics,
    rotateRegistry,
  }
}
