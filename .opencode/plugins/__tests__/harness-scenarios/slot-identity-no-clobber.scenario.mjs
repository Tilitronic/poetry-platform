/**
 * C5 scenario-3 (DIA-085 F-3 class): pre-dispatch session slot identity.
 *
 * Regression: two pre-dispatch orchestrator sessions writing handoffs must
 * create two distinct slot files (ses_X.json, ses_Y.json), not a single
 * "unknown.json" clobber. Before the F-3 fix, five fallback chains used
 * "unknown" as the last resort, causing parallel sessions to collapse.
 *
 * Mirrors the DIA-223 C2 bun test but exercises the plugin from a standalone
 * bun script (bats scenario replay, DIA-226).
 *
 * RUN: bun run slot-identity-no-clobber.scenario.mjs (inside poetry-dev)
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
const directory = mkdtempSync(join(tmpdir(), "c5-s3-"))
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
const pointerPath = join(handoffsDir, "active.json")

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
      task_ref: "C5-scenario-3",
      resolution_status: "done",
      lane_id: laneId,
      cycle_id: `c-${laneId}`,
      prognosis: JSON.stringify(prognosis),
    },
    // DIA-260827-y9n9: slot identity comes from the trusted per-request
    // context.sessionID, so each lane presents itself as the calling session.
    { sessionID: laneId }
  )
}

// ---- Scenario: two pre-dispatch sessions, distinct slot files ----
const prognosisA = {
  resume_instructions: "resume from session A",
  open_tickets: ["DIA-085"],
  fixes_applied: ["fix-a"],
  verification_request: ["bun test"],
  session_summary: { note: "session A summary", completed: ["T1.1"] },
}
const prognosisB = {
  resume_instructions: "resume from session B",
  open_tickets: ["DIA-085"],
  fixes_applied: ["fix-b"],
  verification_request: ["bun test"],
  session_summary: { note: "session B summary", completed: ["T4.1"] },
}

// Write handoffs for two different sessions (distinct context.sessionID per
// write, so each lands in its own slot).
await writeTerminalHandoff("ses_pre_A", prognosisA)
await writeTerminalHandoff("ses_pre_B", prognosisB)

// Both slot files exist (no "unknown.json" clobber).
const slotAPath = join(handoffsDir, "ses_pre_A.json")
const slotBPath = join(handoffsDir, "ses_pre_B.json")
const unknownPath = join(handoffsDir, "unknown.json")

if (!existsSync(slotAPath)) {
  console.error("FAIL: ses_pre_A.json does not exist")
  process.exit(1)
}
if (!existsSync(slotBPath)) {
  console.error("FAIL: ses_pre_B.json does not exist")
  process.exit(1)
}
if (existsSync(unknownPath)) {
  console.error(
    "FAIL: unknown.json exists -- slot identity fell back to 'unknown'"
  )
  process.exit(1)
}

// Each slot carries its own prognosis and a valid checksum.
const slotA = readJson(slotAPath)
const slotB = readJson(slotBPath)

if (slotA.session_id !== "ses_pre_A") {
  console.error(
    `FAIL: ses_pre_A.json session_id=${slotA.session_id}, expected ses_pre_A`
  )
  process.exit(1)
}
if (slotA.prognosis.resume_instructions !== "resume from session A") {
  console.error("FAIL: ses_pre_A.json prognosis mismatch")
  process.exit(1)
}
if (slotA.checksum !== canonicalChecksum(slotA.prognosis)) {
  console.error("FAIL: ses_pre_A.json checksum mismatch")
  process.exit(1)
}

if (slotB.session_id !== "ses_pre_B") {
  console.error(
    `FAIL: ses_pre_B.json session_id=${slotB.session_id}, expected ses_pre_B`
  )
  process.exit(1)
}
if (slotB.prognosis.resume_instructions !== "resume from session B") {
  console.error("FAIL: ses_pre_B.json prognosis mismatch")
  process.exit(1)
}
if (slotB.checksum !== canonicalChecksum(slotB.prognosis)) {
  console.error("FAIL: ses_pre_B.json checksum mismatch")
  process.exit(1)
}

// Pointer points to the most recent writer (ses_pre_B).
const pointer = readJson(pointerPath)
if (pointer.active_session_id !== "ses_pre_B") {
  console.error(
    `FAIL: active.json active_session_id=${pointer.active_session_id}, expected ses_pre_B`
  )
  process.exit(1)
}

// Exactly 2 JSON slot files + active.json + archive/ in handoffs/.
const slotFiles = readdirSync(handoffsDir).filter((f) => f.endsWith(".json"))
if (slotFiles.length !== 3) {
  // active.json + ses_pre_A.json + ses_pre_B.json = 3
  console.error(
    `FAIL: expected 3 .json files in handoffs/, got ${slotFiles.length}: ${slotFiles.join(", ")}`
  )
  process.exit(1)
}

process.exit(0)
