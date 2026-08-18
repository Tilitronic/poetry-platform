/**
 * DIA-223 C2 regression test: slot identity never falls back to "unknown".
 *
 * Verifies F-3 fix from DIA-222: when there is no parentSessionId (the sticky
 * orchestrator capture), the slot identity must resolve to the actual sessionID
 * from context, not the literal string "unknown". Before the fix, five
 * fallback chains used `"unknown"` as the last resort, causing parallel
 * pre-dispatch sessions to collapse onto a single "unknown.json" slot.
 *
 * After the fix:
 *   - log_decision handoff path: parentSessionId ?? lane_id ?? context?.sessionID ?? "unidentified-session"
 *   - The literal "unknown" is never used as a slot key
 *
 * RUN COMMAND (bun in poetry-dev container):
 *   docker compose exec dev bash -lc \
 *     'cd /workspace/.opencode/plugins/__tests__ && \
 *      bun test handoff-slot-identity.test.mjs'
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
  const directory = mkdtempSync(join(tmpdir(), "dia223-c2-"))
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
    unknownPath: join(sessionDir, "handoffs", "unknown.json"),
    messagesPath: join(sessionDir, "messages.jsonl"),
  }
}

async function makeHarness() {
  const ctx = freshCtx()
  const hooks = await createDelegationObserver(ctx)
  return { hooks, ctx, logs: ctx.logs, paths: sessionPaths(ctx.directory) }
}

async function runLogDecision(hooks, args, sessionID) {
  return hooks.tool.log_decision.execute(args, {
    sessionID: sessionID ?? "ses_harness",
  })
}

function terminalHandoffArgs(laneId, prognosis, taskRef = "DIA-223-c2-test") {
  return {
    event_type: "handoff",
    task_ref: taskRef,
    resolution_status: "done",
    lane_id: laneId,
    cycle_id: `c-${laneId}`,
    prognosis: JSON.stringify(prognosis),
  }
}

async function writeTerminalHandoff(hooks, laneId, prognosis, sessionID) {
  return runLogDecision(hooks, terminalHandoffArgs(laneId, prognosis), sessionID)
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
// C2: Slot identity regression tests
// ---------------------------------------------------------------------------

test("C2 single session: slot is named by actual sessionID, not 'unknown'", async () => {
  const { hooks, paths } = await makeHarness()

  const prognosis = {
    resume_instructions: "C2 test",
    open_tickets: ["DIA-223"],
    fixes_applied: [],
    verification_request: [],
    session_summary: { note: "C2 single", completed: [] },
  }

  // Write a terminal handoff from a session with no parentSessionId.
  // The slot identity must resolve to the actual sessionID from context.
  await writeTerminalHandoff(hooks, "ses_c2_alpha", prognosis, "ses_c2_alpha")

  // The slot file is named after the real sessionID.
  expect(existsSync(paths.slotPath("ses_c2_alpha"))).toBe(true)

  // There must be NO "unknown.json" slot file -- the F-3 fix eliminates
  // the "unknown" fallback entirely.
  expect(existsSync(paths.unknownPath)).toBe(false)

  // The slot content carries the correct session_id.
  const slot = readJson(paths.slotPath("ses_c2_alpha"))
  expect(slot.session_id).toBe("ses_c2_alpha")
  expect(slot.prognosis).toEqual(prognosis)
  expect(slot.checksum).toBe(canonicalChecksum(prognosis))

  // Pointer points to the real session.
  const pointer = readJson(paths.pointerPath)
  expect(pointer.active_session_id).toBe("ses_c2_alpha")
})

test("C2 two sessions without parentSessionId: distinct slot files, no 'unknown' clobber", async () => {
  const { hooks, paths } = await makeHarness()

  const prognosisAlpha = {
    resume_instructions: "from alpha",
    open_tickets: [],
    fixes_applied: [],
    verification_request: [],
    session_summary: { note: "alpha", completed: [] },
  }
  const prognosisBeta = {
    resume_instructions: "from beta",
    open_tickets: [],
    fixes_applied: [],
    verification_request: [],
    session_summary: { note: "beta", completed: [] },
  }

  // Two sessions, each with a different sessionID and no parentSessionId.
  // Before F-3, both would have collapsed to "unknown.json" and the second
  // would overwrite the first.
  await writeTerminalHandoff(hooks, "ses_c2_beta", prognosisAlpha, "ses_c2_beta")
  await writeTerminalHandoff(hooks, "ses_c2_gamma", prognosisBeta, "ses_c2_gamma")

  // Both slot files exist with distinct names.
  expect(existsSync(paths.slotPath("ses_c2_beta"))).toBe(true)
  expect(existsSync(paths.slotPath("ses_c2_gamma"))).toBe(true)

  // No "unknown.json" was ever created.
  expect(existsSync(paths.unknownPath)).toBe(false)

  // Each slot carries its own prognosis (no clobber).
  const slotBeta = readJson(paths.slotPath("ses_c2_beta"))
  const slotGamma = readJson(paths.slotPath("ses_c2_gamma"))
  expect(slotBeta.session_id).toBe("ses_c2_beta")
  expect(slotBeta.prognosis).toEqual(prognosisAlpha)
  expect(slotBeta.checksum).toBe(canonicalChecksum(prognosisAlpha))
  expect(slotGamma.session_id).toBe("ses_c2_gamma")
  expect(slotGamma.prognosis).toEqual(prognosisBeta)
  expect(slotGamma.checksum).toBe(canonicalChecksum(prognosisBeta))

  // Pointer points to the most recent writer (gamma).
  const pointer = readJson(paths.pointerPath)
  expect(pointer.active_session_id).toBe("ses_c2_gamma")

  // No archive -- both are first writes.
  expect(readdirSync(paths.archiveDir)).toHaveLength(0)
})
