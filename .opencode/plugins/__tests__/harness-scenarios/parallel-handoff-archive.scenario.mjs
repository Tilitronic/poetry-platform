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
import { createHash } from "node:crypto"
import {
  existsSync,
  readdirSync,
  readFileSync,
} from "node:fs"
import { join } from "node:path"
import { mockOpencodePlugin, createHarness } from "../helpers/plugin-harness.mjs"
import { runScenario } from "./scenario-runner.mjs"

// ---- @opencode-ai/plugin mock (registered BEFORE the plugin import) ----
mockOpencodePlugin()

// Dynamic import AFTER mock.module registration (defeats ESM hoisting).

// ---- Harness: runScenario owns the temp workspace and single cleanup path ----
await runScenario("c5-s2-", async ({ directory, fail }) => {
  const hooks = await createHarness(directory)

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
      { sessionID: laneId }
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
  if (!existsSync(slotPath("ses_c2"))) fail("first write did not create slot ses_c2.json")

  // Second write: archives the first slot, creates new slot.
  // Before F-1 fix, this would produce an archive name identical to the first
  // write's timestamp-based name, causing an overwrite.
  await writeTerminalHandoff("ses_c2", prognosis2)

  // Exactly one archive file exists (first write has no prior slot to archive;
  // only the second write archives the first slot).
  const archiveFiles = readdirSync(archiveDir)
  if (archiveFiles.length !== 1) fail(`expected 1 archive file, got ${archiveFiles.length}: ${archiveFiles.join(", ")}`)

  // Archive filename includes UUID suffix (F-1 fix).
  const UUID_RE =
    /^ses_c2\.\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.\d{3}Z\.[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.json$/
  if (!UUID_RE.test(archiveFiles[0])) fail(`archive name does not match UUID pattern: ${archiveFiles[0]}`)

  // Each archived file preserves the original prognosis with a valid checksum.
  for (const f of archiveFiles) {
    const archived = readJson(join(archiveDir, f))
    if (archived.session_id !== "ses_c2") fail(`archived session_id=${archived.session_id}, expected ses_c2`)
    const expectedChecksum = canonicalChecksum(archived.prognosis)
    if (archived.checksum !== expectedChecksum) fail(`archived checksum mismatch in ${f}`)
  }

  // The slot now holds the second prognosis.
  const slot = readJson(slotPath("ses_c2"))
  if (slot.prognosis.resume_instructions !== "second write") fail(`slot prognosis.resume_instructions=${slot.prognosis.resume_instructions}, expected "second write"`)
  if (slot.checksum !== canonicalChecksum(slot.prognosis)) fail("slot checksum mismatch")
})
