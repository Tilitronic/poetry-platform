/**
 * DIA-225 C3 regression test: empty-result detection in session.idle handler.
 *
 * Verifies DIA-224 D3 empty-result detection: when a child session completes
 * with zero file edits, a SILENT_FAILURE registry row is emitted. Sessions
 * that produced file edits are excluded even if their text output was empty.
 *
 * Covers DIA-099 detection signals D1 (empty result), D2 (no file edits),
 * D5 (no meaningful output).
 *
 * Hermetic: every harness gets a fresh mkdtemp workspace. No real project
 * files are touched.
 *
 * DIA-079: this file is ASCII-only (no em-dashes, no smart quotes).
 *
 * RUN COMMAND (bun in poetry-dev container):
 *   docker compose exec dev bash -lc \
 *     'cd /workspace/.opencode/plugins/__tests__ && \
 *      bun test empty-result-detection.test.mjs'
 */
import { mock, test, expect, describe } from "bun:test"
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
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
  "../delegation-observer.ts"
)

// ---------------------------------------------------------------------------
// Harness plumbing
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
  const directory = mkdtempSync(join(tmpdir(), "dia225-c3-"))
  tempDirs.push(directory)
  mkdirSync(join(directory, ".opencode", "session"), { recursive: true })
  return {
    directory,
    client: { app: { log: async () => {} } },
  }
}

async function makeHarness() {
  const ctx = freshCtx()
  const hooks = await createDelegationObserver(ctx)
  return { hooks, ctx }
}

/**
 * Drive the event hook (session lifecycle events).
 */
async function driveEvent(hooks, { event }) {
  const origWarn = console.warn
  console.warn = () => {}
  try {
    await hooks.event({ event })
  } finally {
    console.warn = origWarn
  }
}

/**
 * Drive tool.execute.after to register a file edit for a session.
 */
async function driveToolEdit(hooks, ctx, { sessionID, tool, callID }) {
  const origWarn = console.warn
  console.warn = () => {}
  try {
    await hooks["tool.execute.after"](
      {
        tool: tool ?? "edit",
        sessionID,
        callID: callID ?? "call_edit",
        args: {},
      },
      { output: "ok" }
    )
  } finally {
    console.warn = origWarn
  }
}

/**
 * Read registry rows appended after a given count.
 */
function readNewRows(ctx, rowsBefore) {
  const registryPath = join(ctx.directory, ".opencode/session/registry.jsonl")
  if (!existsSync(registryPath)) return []
  const allLines = readFileSync(registryPath, "utf-8").trim().split("\n").filter(Boolean)
  return allLines.slice(rowsBefore).map((line) => {
    try {
      return JSON.parse(line)
    } catch {
      return null
    }
  }).filter(Boolean)
}

function countRows(ctx) {
  const registryPath = join(ctx.directory, ".opencode/session/registry.jsonl")
  if (!existsSync(registryPath)) return 0
  return readFileSync(registryPath, "utf-8").trim().split("\n").filter(Boolean).length
}

/**
 * Read messages.jsonl rows appended after a given count.
 */
function readNewMessages(ctx, rowsBefore) {
  const messagesPath = join(ctx.directory, ".opencode/session/messages.jsonl")
  if (!existsSync(messagesPath)) return []
  const allLines = readFileSync(messagesPath, "utf-8").trim().split("\n").filter(Boolean)
  return allLines.slice(rowsBefore).map((line) => {
    try {
      return JSON.parse(line)
    } catch {
      return null
    }
  }).filter(Boolean)
}

function countMessages(ctx) {
  const messagesPath = join(ctx.directory, ".opencode/session/messages.jsonl")
  if (!existsSync(messagesPath)) return 0
  return readFileSync(messagesPath, "utf-8").trim().split("\n").filter(Boolean).length
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("DIA-225 C3: empty-result detection", () => {
  test("session.idle with zero file edits emits SILENT_FAILURE", async () => {
    const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_c3_empty_1"

    // Register child session via session.created.
    await driveEvent(hooks, {
      event: {
        type: "session.created",
        properties: {
          info: { id: sessionID, parentID: "ses_parent", title: "test" },
        },
      },
    })

    const rowsBefore = countRows(ctx)
    const msgsBefore = countMessages(ctx)

    // Fire session.idle -- no edits were made, so detection should fire.
    await driveEvent(hooks, {
      event: {
        type: "session.idle",
        properties: { sessionID },
      },
    })

    // Registry should contain an empty_result_detected row with SILENT_FAILURE.
    const newRows = readNewRows(ctx, rowsBefore)
    const silentRow = newRows.find(
      (r) =>
        r.event === "empty_result_detected" &&
        r.dispatch_state === "SILENT_FAILURE"
    )
    expect(silentRow).toBeDefined()
    expect(silentRow.session_id).toBe(sessionID)
    expect(silentRow.file_edit_count).toBe(0)

    // Messages should contain the empty_result_detected warning.
    const newMsgs = readNewMessages(ctx, msgsBefore)
    const warningMsg = newMsgs.find(
      (m) => m["gen_ai.operation.name"] === "empty_result_detected"
    )
    expect(warningMsg).toBeDefined()
    expect(warningMsg["gen_ai.agent.id"]).toBe(sessionID)
  })

  test("session.idle with file edits does NOT emit SILENT_FAILURE", async () => {
    const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_c3_edits_1"

    // Register child session.
    await driveEvent(hooks, {
      event: {
        type: "session.created",
        properties: {
          info: { id: sessionID, parentID: "ses_parent", title: "test" },
        },
      },
    })

    // Simulate a file edit before idle.
    await driveToolEdit(hooks, ctx, { sessionID })

    const rowsBefore = countRows(ctx)
    const msgsBefore = countMessages(ctx)

    // Fire session.idle -- edits were made, so detection should NOT fire.
    await driveEvent(hooks, {
      event: {
        type: "session.idle",
        properties: { sessionID },
      },
    })

    // Registry should NOT contain an empty_result_detected SILENT_FAILURE row.
    const newRows = readNewRows(ctx, rowsBefore)
    const silentRow = newRows.find(
      (r) =>
        r.event === "empty_result_detected" &&
        r.dispatch_state === "SILENT_FAILURE"
    )
    expect(silentRow).toBeUndefined()

    // Messages should NOT contain the empty_result_detected warning.
    const newMsgs = readNewMessages(ctx, msgsBefore)
    const warningMsg = newMsgs.find(
      (m) => m["gen_ai.operation.name"] === "empty_result_detected"
    )
    expect(warningMsg).toBeUndefined()
  })
})
