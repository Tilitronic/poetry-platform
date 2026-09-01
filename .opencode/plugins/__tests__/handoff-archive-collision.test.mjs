/**
 * DIA-223 C1 regression test: handoff archive collision.
 *
 * Verifies F-1 fix from DIA-222: same-millisecond archive writes produce
 * distinct archive names (UUID suffix). Before the fix, two successive writes
 * for the same session within the same millisecond produced identical archive
 * names like `ses_A.2026-08-18T12-00-00.000Z.json`, causing the second archive
 * to overwrite the first. After the fix, the UUID suffix ensures distinct
 * filenames even when the ISO timestamp is identical.
 *
 * RUN COMMAND (bun in poetry-dev container):
 *   docker compose exec dev bash -lc \
 *     'cd /workspace/.opencode/plugins/__tests__ && \
 *      bun test handoff-archive-collision.test.mjs'
 */
import { mock, test, expect } from "bun:test"
import { createHash } from "node:crypto"
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
} from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

// ---- @opencode-ai/plugin mock (registered BEFORE the plugin import) ----
const desc = { describe: () => desc }
const withOptional = { optional: () => desc }
const schema = { enum: () => withOptional, string: () => withOptional }
const toolFn = (def) => def
toolFn.schema = schema
mock.module("@opencode-ai/plugin", () => ({ tool: toolFn }))

// Dynamic import AFTER mock.module registration.
const { default: createDelegationObserver } = await import(
  "../delegation-observer.ts"
)

// ---------------------------------------------------------------------------
// Harness plumbing (mirrors parallel-handoff.test.mjs)
// ---------------------------------------------------------------------------

const tempDirs = []
process.on("exit", () => {
  for (const dir of tempDirs) {
    try {
      rmSync(dir, { recursive: true, force: true })
    } catch {
      // Best-effort cleanup.
    }
  }
})

function freshCtx() {
  const directory = mkdtempSync(join(tmpdir(), "dia223-c1-"))
  tempDirs.push(directory)
  const sessionDir = join(directory, ".opencode", "session")
  mkdirSync(sessionDir, { recursive: true })
  const logs = []
  return {
    directory,
    logs,
    client: { app: { log: async (entry) => logs.push(entry) } },
  }
}

function sessionPaths(directory) {
  const sessionDir = join(directory, ".opencode/session")
  return {
    sessionDir,
    handoffsDir: join(sessionDir, "handoffs"),
    archiveDir: join(sessionDir, "handoffs", "archive"),
    pointerPath: join(sessionDir, "handoffs", "active.json"),
    slotPath: (sessionId) => join(sessionDir, "handoffs", `${sessionId}.json`),
    messagesPath: join(sessionDir, "messages.jsonl"),
  }
}

async function makeHarness() {
  const ctx = freshCtx()
  const hooks = await createDelegationObserver(ctx)
  return { hooks, ctx, logs: ctx.logs, paths: sessionPaths(ctx.directory) }
}

async function runLogDecision(hooks, args) {
  // DIA-260827-y9n9: slot identity now comes from trusted context.sessionID,
  // falling back to lane_id. Use lane_id so each lane's slot is distinct and
  // matches the test's slotPath expectations (ses_c1, ses_c1_diff, etc.).
  return hooks.tool.log_decision.execute(args, {
    sessionID: args.lane_id ?? "ses_harness",
  })
}

function terminalHandoffArgs(laneId, prognosis, taskRef = "DIA-223-c1-test") {
  return {
    event_type: "handoff",
    task_ref: taskRef,
    resolution_status: "done",
    lane_id: laneId,
    cycle_id: `c-${laneId}`,
    prognosis: JSON.stringify(prognosis),
  }
}

async function writeTerminalHandoff(hooks, laneId, prognosis) {
  return runLogDecision(hooks, terminalHandoffArgs(laneId, prognosis))
}

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, "utf-8"))
}

function canonicalChecksum(prognosis) {
  const canonical = {}
  for (const key of Object.keys(prognosis).sort()) {
    canonical[key] = prognosis[key]
  }
  return createHash("sha256").update(JSON.stringify(canonical)).digest("hex")
}

// ---------------------------------------------------------------------------
// C1: Archive collision regression test
// ---------------------------------------------------------------------------

test("C1 same-millisecond archive: two successive writes for the same session produce distinct archive files", async () => {
  const { hooks, paths } = await makeHarness()

  const prognosis1 = {
    resume_instructions: "first write",
    open_tickets: ["DIA-223"],
    fixes_applied: [],
    verification_request: [],
    session_summary: { note: "first", completed: [] },
  }
  const prognosis2 = {
    resume_instructions: "second write",
    open_tickets: ["DIA-223"],
    fixes_applied: [],
    verification_request: [],
    session_summary: { note: "second", completed: [] },
  }

  // First write: creates the slot (no prior, no archive).
  await writeTerminalHandoff(hooks, "ses_c1", prognosis1)
  expect(existsSync(paths.slotPath("ses_c1"))).toBe(true)
  expect(readdirSync(paths.archiveDir)).toHaveLength(0)

  // Second write: archives the first slot, creates new slot.
  // Before F-1 fix, this would produce an archive name identical to the first
  // write's timestamp-based name, causing an overwrite.
  await writeTerminalHandoff(hooks, "ses_c1", prognosis2)

  // Exactly one archive file exists.
  const archiveFiles = readdirSync(paths.archiveDir)
  expect(archiveFiles).toHaveLength(1)

  // Archive filename includes UUID suffix (F-1 fix: `<session>.<iso>.<uuid>.json`).
  // The UUID part is 36 chars: 8-4-4-4-12 hex pattern.
  const archiveName = archiveFiles[0]
  expect(archiveName).toMatch(/^ses_c1\.\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.\d{3}Z\.[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.json$/)

  // The archived file preserves the FIRST prognosis (the one that was overwritten).
  const archived = readJson(join(paths.archiveDir, archiveName))
  expect(archived.session_id).toBe("ses_c1")
  expect(archived.prognosis).toEqual(prognosis1)
  expect(archived.checksum).toBe(canonicalChecksum(prognosis1))

  // The slot now holds the SECOND prognosis.
  const slot = readJson(paths.slotPath("ses_c1"))
  expect(slot.prognosis).toEqual(prognosis2)
  expect(slot.checksum).toBe(canonicalChecksum(prognosis2))
})

test("C1 unique archive names: even without UUID, two rapid writes for different sessions produce non-colliding archives", async () => {
  const { hooks, paths } = await makeHarness()

  const prognosisA = {
    resume_instructions: "session A",
    open_tickets: [],
    fixes_applied: [],
    verification_request: [],
    session_summary: { note: "A", completed: [] },
  }
  const prognosisB = {
    resume_instructions: "session B",
    open_tickets: [],
    fixes_applied: [],
    verification_request: [],
    session_summary: { note: "B", completed: [] },
  }

  // Write ses_A, then ses_B -- both are first writes, no archives.
  await writeTerminalHandoff(hooks, "ses_c1_diff", prognosisA)
  await writeTerminalHandoff(hooks, "ses_c1_other", prognosisB)

  // Both slots survive; no archives (first writes never archive).
  expect(existsSync(paths.slotPath("ses_c1_diff"))).toBe(true)
  expect(existsSync(paths.slotPath("ses_c1_other"))).toBe(true)
  expect(readdirSync(paths.archiveDir)).toHaveLength(0)
})
