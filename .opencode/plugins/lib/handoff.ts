/**
 * lib/handoff — SRP extraction from delegation-observer.ts (DIA-260902-eqgg S3).
 *
 * Verbatim move of handoff seam: computeChecksum, atomicWriteHandoff,
 * handoff path constants, archive best-effort per DIA-085, legacy
 * current-handoff.json READ-ONLY, pointer last-writer-wins,
 * tmp->fsync->rename->fsync-dir ordering.
 *
 * DI of fs fakes via injected deps (design.md Q4/Q9). No ctx capture, no shell import.
 * One canonical interface: computeChecksum + atomicWriteHandoff + createHandoff factory.
 */

import { createHash, randomUUID as _randomUUID } from "node:crypto"
import {
  closeSync as fsCloseSync,
  existsSync as fsExistsSync,
  fsyncSync as fsFsyncSync,
  mkdirSync as fsMkdirSync,
  openSync as fsOpenSync,
  readFileSync as fsReadFileSync,
  renameSync as fsRenameSync,
  unlinkSync as fsUnlinkSync,
  writeFileSync as fsWriteFileSync,
} from "node:fs"
import { join } from "node:path"

// ---------------------------------------------------------------------------
// computeChecksum — verbatim (jq -c stable order, top-level sort only)
// ---------------------------------------------------------------------------
export function computeChecksum(prognosis: object): string {
  const canonical: Record<string, unknown> = {}
  for (const key of Object.keys(prognosis).sort()) {
    canonical[key] = (prognosis as Record<string, unknown>)[key]
  }
  return createHash("sha256").update(JSON.stringify(canonical)).digest("hex")
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------
export type HandoffPaths = {
  slotsDir: string
  archiveDir: string
  pointerPath: string
  legacyPath: string
  reconciledPath?: string
}

export type HandoffDeps = {
  writeFileSync?: (p: string, d: string) => void
  openSync?: (p: string, flags: string) => number
  fsyncSync?: (fd: number) => void
  closeSync?: (fd: number) => void
  renameSync?: (src: string, dst: string) => void
  mkdirSync?: (p: string, opts?: { recursive: boolean }) => void
  existsSync?: (p: string) => boolean
  readFileSync?: (p: string, enc: string) => string
  unlinkSync?: (p: string) => void
  randomUUID?: () => string
  now?: () => number
  statSync?: (p: string) => unknown
}

type NormalizedDeps = Required<Pick<HandoffDeps, "writeFileSync" | "openSync" | "fsyncSync" | "closeSync" | "renameSync" | "mkdirSync" | "existsSync" | "randomUUID" | "now">> &
  Pick<HandoffDeps, "readFileSync" | "unlinkSync" | "statSync">

function resolveDeps(partial?: HandoffDeps | null): NormalizedDeps {
  return {
    writeFileSync: partial?.writeFileSync ?? (fsWriteFileSync as unknown as (p: string, d: string) => void),
    openSync: partial?.openSync ?? (fsOpenSync as unknown as (p: string, f: string) => number),
    fsyncSync: partial?.fsyncSync ?? (fsFsyncSync as unknown as (fd: number) => void),
    closeSync: partial?.closeSync ?? (fsCloseSync as unknown as (fd: number) => void),
    renameSync: partial?.renameSync ?? (fsRenameSync as unknown as (s: string, d: string) => void),
    mkdirSync: partial?.mkdirSync ?? (fsMkdirSync as unknown as (p: string, o?: { recursive: boolean }) => void),
    existsSync: partial?.existsSync ?? (fsExistsSync as unknown as (p: string) => boolean),
    readFileSync: partial?.readFileSync ?? (fsReadFileSync as unknown as (p: string, e: string) => string),
    unlinkSync: partial?.unlinkSync ?? (fsUnlinkSync as unknown as (p: string) => void),
    randomUUID: partial?.randomUUID ?? _randomUUID,
    now: partial?.now ?? Date.now,
    statSync: partial?.statSync,
  }
}

// ---------------------------------------------------------------------------
// Core atomic write — DIA-085 best-effort: archive attempted, failure warns, new handoff still lands (D5 rescinded)
// ---------------------------------------------------------------------------
function coreAtomicWrite(
  paths: HandoffPaths,
  sessionId: string,
  content: Record<string, unknown>,
  deps: NormalizedDeps,
): { ok: boolean; archived_prior: string | null; error?: string } {
  deps.mkdirSync(paths.slotsDir, { recursive: true })
  deps.mkdirSync(paths.archiveDir, { recursive: true })

  const slotPath = join(paths.slotsDir, `${sessionId}.json`)

  if (
    (paths.legacyPath && slotPath === paths.legacyPath) ||
    (paths.pointerPath && slotPath === paths.pointerPath) ||
    (paths.reconciledPath && slotPath === paths.reconciledPath)
  ) {
    throw new Error(`[handoff] slot path collision: '${slotPath}' is a reserved handoff path`)
  }

  let archivedPrior: string | null = null
  if (deps.existsSync(slotPath)) {
    const iso = new Date(deps.now()).toISOString().replace(/:/g, "-")
    const uuid = deps.randomUUID()
    const archiveName = `${sessionId}.${iso}.${uuid}.json`
    const archivePath = join(paths.archiveDir, archiveName)
    try {
      deps.renameSync(slotPath, archivePath)
      archivedPrior = `archive/${archiveName}`
    } catch {
      // best-effort: do not abort — new slot will still overwrite prior
    }
  }

  const slotTmpPath = join(paths.slotsDir, `.${sessionId}.json.tmp`)
  try {
    const json = JSON.stringify(content, null, 2) + "\n"
    deps.writeFileSync(slotTmpPath, json)
    const tmpFd = deps.openSync(slotTmpPath, "r+")
    deps.fsyncSync(tmpFd)
    deps.closeSync(tmpFd)
    deps.renameSync(slotTmpPath, slotPath)
    const dirFd = deps.openSync(paths.slotsDir, "r")
    deps.fsyncSync(dirFd)
    deps.closeSync(dirFd)
  } catch (err) {
    try {
      if (deps.unlinkSync) {
        try { deps.unlinkSync(slotTmpPath) } catch { /* ignore */ }
      }
    } catch { /* ignore */ }
    const msg = err instanceof Error ? err.message : String(err)
    return { ok: false, archived_prior: archivedPrior, error: msg }
  }

  const pointerContent = {
    active_session_id: sessionId,
    timestamp: new Date(deps.now()).toISOString(),
    pointer_version: 1,
  }
  const pointerTmpPath = join(paths.slotsDir, ".active.json.tmp")
  try {
    const json = JSON.stringify(pointerContent, null, 2) + "\n"
    deps.writeFileSync(pointerTmpPath, json)
    const tmpFd = deps.openSync(pointerTmpPath, "r+")
    deps.fsyncSync(tmpFd)
    deps.closeSync(tmpFd)
    deps.renameSync(pointerTmpPath, paths.pointerPath)
    const dirFd = deps.openSync(paths.slotsDir, "r")
    deps.fsyncSync(dirFd)
    deps.closeSync(dirFd)
  } catch (err) {
    try {
      if (deps.unlinkSync) {
        try { deps.unlinkSync(pointerTmpPath) } catch { /* ignore */ }
      }
    } catch { /* ignore */ }
    const msg = err instanceof Error ? err.message : String(err)
    return { ok: true, archived_prior: archivedPrior, error: msg }
  }

  return { ok: true, archived_prior: archivedPrior }
}

// Canonical public API — production factory arity only: (paths, sessionId, content, deps?)
export function atomicWriteHandoff(
  paths: HandoffPaths,
  sessionId: string,
  content: Record<string, unknown>,
  depsIn?: HandoffDeps,
): { ok: boolean; archived_prior: string | null; error?: string } {
  if (content === undefined || content === null || typeof content !== "object" || Array.isArray(content)) {
    throw new Error("atomicWriteHandoff: content must be object")
  }
  const deps = resolveDeps(depsIn ?? null)
  return coreAtomicWrite(paths, sessionId, content, deps)
}

// Factory DI seam — one canonical factory
export function createHandoff(depsIn: HandoffDeps = {}): {
  computeChecksum: typeof computeChecksum
  atomicWriteHandoff: (paths: HandoffPaths, sessionId: string, content: Record<string, unknown>, depsIn?: HandoffDeps) => { ok: boolean; archived_prior: string | null; error?: string }
} {
  const bound = resolveDeps(depsIn)
  return {
    computeChecksum,
    atomicWriteHandoff: (paths: HandoffPaths, sessionId: string, content: Record<string, unknown>, depsIn2?: HandoffDeps) => {
      if (content === undefined || content === null || typeof content !== "object" || Array.isArray(content)) {
        throw new Error("atomicWriteHandoff: content must be object")
      }
      const effective = depsIn2 !== undefined ? resolveDeps(depsIn2) : bound
      return coreAtomicWrite(paths, sessionId, content, effective)
    },
  }
}
