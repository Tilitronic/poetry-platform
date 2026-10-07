/** Functional, dependency-injected persistence for local JSONL journals. */

export type JournalSuccess = { ok: true; id: number; entry: Record<string, unknown> }
export type JournalFailure = {
  ok: false
  stage: "lock" | "counter" | "append"
  retryable: boolean
  error: string
  reserved_id?: number
}
export type JournalResult = JournalSuccess | JournalFailure

export type JournalOwner = {
  pid: number
  startedAt: string
  nonce: string
  leaseDeadline: number
}

export type JournalFs = {
  appendFileSync(path: string, data: string): void
  closeSync(fd: number): void
  existsSync(path: string): boolean
  fsyncSync(fd: number): void
  mkdirSync(path: string, opts?: object): void
  openSync(path: string, flags: string): number
  readFileSync(path: string, enc: string): string
  renameSync(src: string, dst: string): void
  rmdirSync?(path: string): void
  unlinkSync(path: string): void
  writeFileSync(path: string, data: string): void
}

export type JournalPath = {
  dirname(path: string): string
  join(...parts: string[]): string
}

export type ProcessProbe = (
  owner: Pick<JournalOwner, "pid" | "startedAt">,
) => boolean | { alive: boolean; startedAt?: string }

type PersistenceDeps = {
  fs: JournalFs
  path: JournalPath
  lockPath: string
  processIdentity: Pick<JournalOwner, "pid" | "startedAt">
  isProcessAlive: ProcessProbe
  randomUUID: () => string
  now: () => number
}

export type LockToken = { nonce: string }

export function counterValue(sidecar: string | undefined, fallback = Number.NaN): number {
  const normalized = sidecar?.endsWith("\n") ? sidecar.slice(0, -1) : sidecar
  if (normalized === undefined || !/^(0|[1-9][0-9]*)$/.test(normalized)) return fallback
  const parsed = Number(normalized)
  return Number.isSafeInteger(parsed) && parsed >= 0 ? parsed : fallback
}

export function exactOwnerAlive(
  value: boolean | { alive: boolean; startedAt?: string },
  startedAt: string,
): boolean {
  if (typeof value === "boolean") return value
  return value.alive && value.startedAt === startedAt
}

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error)
}

export function createJournalPersistence(deps: PersistenceDeps) {
  const { fs, path, lockPath, processIdentity, isProcessAlive, randomUUID, now } = deps
  const directoryLock = typeof fs.rmdirSync === "function"

  function fsyncFile(filePath: string): void {
    const fd = fs.openSync(filePath, "r+")
    try { fs.fsyncSync(fd) } finally { fs.closeSync(fd) }
  }

  function fsyncDirectory(filePath: string): void {
    let fd: number
    try {
      fd = fs.openSync(path.dirname(filePath), "r")
    } catch (error) {
      const code = (error as { code?: string }).code
      if (code === "EISDIR" || code === "EINVAL" || code === "ENOTSUP") return
      throw error
    }
    try { fs.fsyncSync(fd) } finally { fs.closeSync(fd) }
  }

  function removeDirectory(directory: string): void {
    try {
      const ownerPath = path.join(directory, "owner.json")
      if (fs.existsSync(ownerPath)) fs.unlinkSync(ownerPath)
      fs.rmdirSync?.(directory)
    } catch { /* active path already moved; cleanup is best effort */ }
  }

  function ownerAt(directory: string): JournalOwner | undefined {
    const ownerPath = path.join(directory, "owner.json")
    if (!fs.existsSync(ownerPath)) return undefined
    try {
      const owner = JSON.parse(fs.readFileSync(ownerPath, "utf-8")) as JournalOwner
      if (!Number.isInteger(owner.pid) || typeof owner.startedAt !== "string" ||
          typeof owner.nonce !== "string" || !Number.isFinite(owner.leaseDeadline)) return undefined
      return owner
    } catch { return undefined }
  }

  function moveActive(kind: "orphan" | "quarantine", nonce = randomUUID()): void {
    fs.renameSync(lockPath, `${lockPath}.${kind}-${nonce}`)
    fsyncDirectory(lockPath)
  }

  function acquireJournalLock():
    | { ok: true; token: LockToken }
    | { ok: false; stage: "lock"; retryable: true; error: string } {
    const nonce = randomUUID()
    const staging = `${lockPath}.acquire-${nonce}`
    try {
      if (!directoryLock) {
        if (fs.existsSync(lockPath)) {
          const owner = JSON.parse(fs.readFileSync(lockPath, "utf-8")) as JournalOwner
          const alive = isProcessAlive(owner)
          if (exactOwnerAlive(alive, owner.startedAt) || owner.leaseDeadline > now()) {
            return { ok: false, stage: "lock", retryable: true, error: "journal lock owner is live" }
          }
          if (typeof alive === "object" && alive.alive) {
            return { ok: false, stage: "lock", retryable: true, error: "journal lock owner identity is ambiguous" }
          }
          fs.unlinkSync(lockPath)
        }
        const fd = fs.openSync(lockPath, "wx")
        const owner: JournalOwner = { ...processIdentity, nonce, leaseDeadline: now() + 30_000 }
        try {
          fs.writeFileSync(lockPath, `${JSON.stringify(owner)}\n`)
          fs.fsyncSync(fd)
        } finally {
          fs.closeSync(fd)
        }
        return { ok: true, token: { nonce } }
      }
      if (fs.existsSync(lockPath)) {
        const ownerPath = path.join(lockPath, "owner.json")
        const owner = ownerAt(lockPath)
        if (!owner) {
          // New acquisitions publish an already-populated staging directory,
          // so an empty active directory can only be a legacy release crash.
          if (!fs.existsSync(ownerPath)) moveActive("orphan")
          else {
            return {
              ok: false,
              stage: "lock",
              retryable: true,
              error: "journal lock owner metadata is unreadable",
            }
          }
        } else {
          const alive = isProcessAlive(owner)
          if (typeof alive === "object" && alive.alive) {
            return { ok: false, stage: "lock", retryable: true,
              error: exactOwnerAlive(alive, owner.startedAt)
                ? "journal lock owner is live"
                : "journal lock owner identity is ambiguous" }
          }
          if (alive === true) {
            return { ok: false, stage: "lock", retryable: true, error: "journal lock owner is live" }
          }
          if (owner.leaseDeadline > now()) {
            return { ok: false, stage: "lock", retryable: true, error: "journal lock lease has not expired" }
          }
          moveActive("quarantine", owner.nonce)
        }
      }

      fs.mkdirSync(path.dirname(lockPath), { recursive: true })
      fs.mkdirSync(staging)
      const owner: JournalOwner = { ...processIdentity, nonce, leaseDeadline: now() + 30_000 }
      const ownerPath = path.join(staging, "owner.json")
      fs.writeFileSync(ownerPath, `${JSON.stringify(owner)}\n`)
      fsyncFile(ownerPath)
      fsyncDirectory(ownerPath)
      fs.renameSync(staging, lockPath)
      fsyncDirectory(lockPath)
      return { ok: true, token: { nonce } }
    } catch (error) {
      removeDirectory(staging)
      return { ok: false, stage: "lock", retryable: true, error: message(error) }
    }
  }

  function releaseJournalLock(token: LockToken): void {
    try {
      if (!directoryLock) {
        const owner = JSON.parse(fs.readFileSync(lockPath, "utf-8")) as JournalOwner
        if (owner.nonce === token.nonce) fs.unlinkSync(lockPath)
        return
      }
      const owner = ownerAt(lockPath)
      if (!owner || owner.nonce !== token.nonce) return
      const released = `${lockPath}.release-${token.nonce}`
      fs.renameSync(lockPath, released)
      fsyncDirectory(lockPath)
      removeDirectory(released)
    } catch { /* never delete unverifiable ownership */ }
  }

  function reserveCounter(counterPath: string, fallback: () => number, current?: number): number {
    if (current !== undefined) {
      const published = counterValue(fs.readFileSync(counterPath, "utf-8"))
      if (!Number.isFinite(published)) throw new Error("invalid counter; explicit recovery required")
      return Math.max(current, published)
    }
    const durableFloor = fallback()
    if (!fs.existsSync(counterPath)) return durableFloor
    const raw = fs.readFileSync(counterPath, "utf-8")
    const value = counterValue(raw)
    if (Number.isFinite(value)) return Math.max(value, durableFloor)
    if (!/[0-9+-]/.test(raw)) return durableFloor
    throw new Error("invalid counter; explicit recovery required")
  }

  function publishCounter(counterPath: string, value: number): void {
    const temporary = `${counterPath}.tmp-${randomUUID()}`
    fs.mkdirSync(path.dirname(counterPath), { recursive: true })
    fs.writeFileSync(temporary, `${value}`)
    fsyncFile(temporary)
    fs.renameSync(temporary, counterPath)
    fsyncDirectory(counterPath)
  }

  function appendChecked(journalPath: string, data: string): void {
    fs.appendFileSync(journalPath, data)
    fsyncFile(journalPath)
  }

  return { acquireJournalLock, appendChecked, publishCounter, releaseJournalLock, reserveCounter }
}
