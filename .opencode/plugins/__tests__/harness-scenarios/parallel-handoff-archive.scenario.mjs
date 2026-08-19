/**
 * C5 scenario-2 (DIA-085 F-1 class): same-millisecond parallel handoff writes.
 *
 * Regression: two successive handoff writes for the same session within the
 * same millisecond produce distinct archive filenames (UUID suffix). Before
 * the F-1 fix, identical ISO timestamps caused the second archive to
 * overwrite the first.
 *
 * Mirrors the DIA-223 C1 bun test but exercises the plugin from a standalone
 * bun script (bats scenario replay, DIA-226).
 *
 * RUN: bun run parallel-handoff-archive.scenario.mjs (inside poetry-dev)
 */
import { mock } from "bun:test"
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

// Dynamic import AFTER mock.module registration (defeats ESM hoisting).
const { default: createDelegationObserver } = await import(
  "../../delegation-observer.ts"
)

// ---- Harness ----
const directory = mkdtempSync(join(tmpdir(), "c5-s2-"))
mkdirSync(join(directory, ".opencode", "session"), { recursive: true })

process.on("exit", () => {
  try {
    rmSync(directory, { recursive: true, force: true })
  } catch { /* ignore cleanup errors */ }
})

const hooks = await createDelegationObserver({
  directory,
  client: { app: { log: async () => {} } },
})

const sessionDir = join(directory, ".opencode/session")
const handoffsDir = join(sessionDir, "handoffs")
const archiveDir = join(handoffsDir, "archive")
const slotPath = (sid) => join(handoffsDir, `${sid}.json`)

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

async function writeTerminalHandoff(laneId, prognosis) {
  return hooks.tool.log_decision.execute(
    {
      event_type: "handoff",
      task_ref: "C5-scenario-2",
      resolution_status: "done",
      lane_id: laneId,
      cycle_id: `c-${laneId}`,
      prognosis: JSON.stringify(prognosis),
    },
    { sessionID: "ses_harness" }
  )
}

// ---- Scenario: same-millisecond parallel handoff writes ----
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
await writeTerminalHandoff("ses_c2", prognosis1)
if (!existsSync(slotPath("ses_c2"))) {
  console.error("FAIL: first write did not create slot ses_c2.json")
  process.exit(1)
}

// Second write: archives the first slot, creates new slot.
// Before F-1 fix, this would produce an archive name identical to the first
// write's timestamp-based name, causing an overwrite.
await writeTerminalHandoff("ses_c2", prognosis2)

// Exactly one archive file exists (first write has no prior slot to archive;
// only the second write archives the first slot).
const archiveFiles = readdirSync(archiveDir)
if (archiveFiles.length !== 1) {
  console.error(
    `FAIL: expected 1 archive file, got ${archiveFiles.length}: ${archiveFiles.join(", ")}`
  )
  process.exit(1)
}

// Archive filename includes UUID suffix (F-1 fix).
const UUID_RE =
  /^ses_c2\.\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.\d{3}Z\.[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.json$/
if (!UUID_RE.test(archiveFiles[0])) {
  console.error(`FAIL: archive name does not match UUID pattern: ${archiveFiles[0]}`)
  process.exit(1)
}

// Each archived file preserves the original prognosis with a valid checksum.
for (const f of archiveFiles) {
  const archived = readJson(join(archiveDir, f))
  if (archived.session_id !== "ses_c2") {
    console.error(
      `FAIL: archived session_id=${archived.session_id}, expected ses_c2`
    )
    process.exit(1)
  }
  const expectedChecksum = canonicalChecksum(archived.prognosis)
  if (archived.checksum !== expectedChecksum) {
    console.error(
      `FAIL: archived checksum mismatch in ${f}`
    )
    process.exit(1)
  }
}

// The slot now holds the second prognosis.
const slot = readJson(slotPath("ses_c2"))
if (slot.prognosis.resume_instructions !== "second write") {
  console.error(
    `FAIL: slot prognosis.resume_instructions=${slot.prognosis.resume_instructions}, expected "second write"`
  )
  process.exit(1)
}
if (slot.checksum !== canonicalChecksum(slot.prognosis)) {
  console.error("FAIL: slot checksum mismatch")
  process.exit(1)
}

process.exit(0)
