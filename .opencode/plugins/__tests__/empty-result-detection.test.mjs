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
 * DIA-260826-zvu4 extends coverage: coder lanes dispatched with a
 * verification-only marker phrase in the prompt must NOT trip SILENT_FAILURE
 * on zero edits (RED phase -- these tests fail against current code until a
 * separate implementer adds the verificationOnlySessions exemption).
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
  await hooks.event({ event })
}

/**
 * Drive tool.execute.after to register a file edit for a session.
 */
async function driveToolEdit(hooks, ctx, { sessionID, tool, callID }) {
  await hooks["tool.execute.after"](
    {
      tool: tool ?? "edit",
      sessionID,
      callID: callID ?? "call_edit",
      args: {},
    },
    { output: "ok" }
  )
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

// ---------------------------------------------------------------------------
// DIA-260826-zvu4: verification-only coder exemption (RED phase tests)
// ---------------------------------------------------------------------------

/**
 * Drive a task() dispatch through tool.execute.after: registers the child
 * lane in childSessionAgent and links the child session id parsed from the
 * task output. Mirrors the proven driveTaskAfter pattern from
 * dia220-apoptosis-paracrine.test.mjs.
 */
async function driveTaskDispatch(hooks, { parentID, childID, agent, prompt }) {
  await hooks["tool.execute.after"](
    {
      tool: "task",
      sessionID: parentID,
      callID: "call_dispatch_" + childID,
      args: { subagent_type: agent, prompt },
    },
    { output: `<task id="${childID}"><state>completed</state></task>` }
  )
}

function findSilentRow(rows) {
  return rows.find(
    (r) =>
      r.event === "empty_result_detected" &&
      r.dispatch_state === "SILENT_FAILURE"
  )
}

describe("DIA-260826-zvu4: verification-only coder exemption", () => {
  test("coder dispatch with 'verification-only' marker + zero edits -> NO SILENT_FAILURE", async () => {
    const { hooks, ctx } = await makeHarness()
    const parentID = "ses_zvu4_parent_1"
    const childID = "ses_zvu4_verif_1"

    // Register child session via session.created.
    await driveEvent(hooks, {
      event: {
        type: "session.created",
        properties: {
          info: { id: childID, parentID, title: "verification-only recon" },
        },
      },
    })

    // Dispatch a coder with the marker phrase in the prompt.
    await driveTaskDispatch(hooks, {
      parentID,
      childID,
      agent: "coder",
      prompt:
        "campaign ticket DIA-260826-zvu4 - verification-only: confirm writability, report findings. Do NOT modify implementation code.",
    })

    const rowsBefore = countRows(ctx)
    const msgsBefore = countMessages(ctx)

    // Fire session.idle -- zero edits, but marker exempts the session.
    await driveEvent(hooks, {
      event: {
        type: "session.idle",
        properties: { sessionID: childID },
      },
    })

    const newRows = readNewRows(ctx, rowsBefore)
    expect(findSilentRow(newRows)).toBeUndefined()

    const newMsgs = readNewMessages(ctx, msgsBefore)
    const crisisMsg = newMsgs.find(
      (m) => m["gen_ai.operation.name"] === "empty_result_detected"
    )
    expect(crisisMsg).toBeUndefined()
  })

  test("coder dispatch WITHOUT marker + zero edits -> SILENT_FAILURE preserved", async () => {
    const { hooks, ctx } = await makeHarness()
    const parentID = "ses_zvu4_parent_2"
    const childID = "ses_zvu4_impl_1"

    await driveEvent(hooks, {
      event: {
        type: "session.created",
        properties: {
          info: { id: childID, parentID, title: "implementation" },
        },
      },
    })

    // Dispatch a coder WITHOUT any marker phrase.
    await driveTaskDispatch(hooks, {
      parentID,
      childID,
      agent: "coder",
      prompt: "implement feature X against tasks.md",
    })

    const rowsBefore = countRows(ctx)
    const msgsBefore = countMessages(ctx)

    await driveEvent(hooks, {
      event: {
        type: "session.idle",
        properties: { sessionID: childID },
      },
    })

    // Existing behavior must be preserved: zero-edit coder -> SILENT_FAILURE.
    const newRows = readNewRows(ctx, rowsBefore)
    const silentRow = findSilentRow(newRows)
    expect(silentRow).toBeDefined()
    expect(silentRow.session_id).toBe(childID)
    expect(silentRow.file_edit_count).toBe(0)

    const newMsgs = readNewMessages(ctx, msgsBefore)
    const crisisMsg = newMsgs.find(
      (m) =>
        m["gen_ai.operation.name"] === "empty_result_detected" &&
        m["gen_ai.agent.id"] === childID
    )
    expect(crisisMsg).toBeDefined()
  })

  test("coder dispatch with marker + file edits -> NO SILENT_FAILURE", async () => {
    const { hooks, ctx } = await makeHarness()
    const parentID = "ses_zvu4_parent_3"
    const childID = "ses_zvu4_verif_edits_1"

    await driveEvent(hooks, {
      event: {
        type: "session.created",
        properties: {
          info: { id: childID, parentID, title: "verification-only + edits" },
        },
      },
    })

    await driveTaskDispatch(hooks, {
      parentID,
      childID,
      agent: "coder",
      prompt: "verification-only: extend the test file, run bun test",
    })

    // The session DID produce edits (test files are edits too).
    await driveToolEdit(hooks, ctx, { sessionID: childID })

    const rowsBefore = countRows(ctx)

    await driveEvent(hooks, {
      event: {
        type: "session.idle",
        properties: { sessionID: childID },
      },
    })

    const newRows = readNewRows(ctx, rowsBefore)
    expect(findSilentRow(newRows)).toBeUndefined()
  })

  test("marker variants 'read-only verification' and 'verify-only' are exempt", async () => {
    for (const [label, prompt] of [
      [
        "read-only verification",
        "read-only verification of the plugin behavior, report only",
      ],
      ["verify-only", "verify-only: run the suite and summarize results"],
    ]) {
      const { hooks, ctx } = await makeHarness()
      const parentID = "ses_zvu4_parent_v_" + label.replace(/[^a-z]+/g, "_")
      const childID = "ses_zvu4_variant_" + label.replace(/[^a-z]+/g, "_")

      await driveEvent(hooks, {
        event: {
          type: "session.created",
          properties: {
            info: { id: childID, parentID, title: label },
          },
        },
      })

      await driveTaskDispatch(hooks, {
        parentID,
        childID,
        agent: "coder",
        prompt,
      })

      const rowsBefore = countRows(ctx)
      const msgsBefore = countMessages(ctx)

      await driveEvent(hooks, {
        event: {
          type: "session.idle",
          properties: { sessionID: childID },
        },
      })

      const newRows = readNewRows(ctx, rowsBefore)
      expect(findSilentRow(newRows)).toBeUndefined()

      const newMsgs = readNewMessages(ctx, msgsBefore)
      const crisisMsg = newMsgs.find(
        (m) => m["gen_ai.operation.name"] === "empty_result_detected"
      )
      expect(crisisMsg).toBeUndefined()
    }
  })

  test("uppercase 'VERIFICATION-ONLY' marker is exempt (case-insensitive match)", async () => {
    const { hooks, ctx } = await makeHarness()
    const parentID = "ses_zvu4_parent_upper"
    const childID = "ses_zvu4_verif_upper"

    await driveEvent(hooks, {
      event: {
        type: "session.created",
        properties: {
          info: { id: childID, parentID, title: "UPPERCASE marker" },
        },
      },
    })

    await driveTaskDispatch(hooks, {
      parentID,
      childID,
      agent: "coder",
      prompt: "VERIFICATION-ONLY: confirm writability, report findings.",
    })

    const rowsBefore = countRows(ctx)
    const msgsBefore = countMessages(ctx)

    await driveEvent(hooks, {
      event: { type: "session.idle", properties: { sessionID: childID } },
    })

    const newRows = readNewRows(ctx, rowsBefore)
    expect(findSilentRow(newRows)).toBeUndefined()

    const newMsgs = readNewMessages(ctx, msgsBefore)
    const crisisMsg = newMsgs.find(
      (m) => m["gen_ai.operation.name"] === "empty_result_detected"
    )
    expect(crisisMsg).toBeUndefined()
  })

  test("marker in args.description (not prompt) is exempt", async () => {
    const { hooks, ctx } = await makeHarness()
    const parentID = "ses_zvu4_parent_desc"
    const childID = "ses_zvu4_verif_desc"

    await driveEvent(hooks, {
      event: {
        type: "session.created",
        properties: {
          info: { id: childID, parentID, title: "marker via description" },
        },
      },
    })

    // Marker lives ONLY in the description channel; prompt is marker-free.
    // Mirrors driveTaskDispatch but passes description instead of prompt.
    await hooks["tool.execute.after"](
      {
        tool: "task",
        sessionID: parentID,
        callID: "call_dispatch_" + childID,
        args: {
          subagent_type: "coder",
          description: "verification-only recon",
          prompt: "implement feature X against tasks.md",
        },
      },
      { output: `<task id="${childID}"><state>completed</state></task>` }
    )

    const rowsBefore = countRows(ctx)
    const msgsBefore = countMessages(ctx)

    await driveEvent(hooks, {
      event: { type: "session.idle", properties: { sessionID: childID } },
    })

    const newRows = readNewRows(ctx, rowsBefore)
    expect(findSilentRow(newRows)).toBeUndefined()

    const newMsgs = readNewMessages(ctx, msgsBefore)
    const crisisMsg = newMsgs.find(
      (m) => m["gen_ai.operation.name"] === "empty_result_detected"
    )
    expect(crisisMsg).toBeUndefined()
  })

  // Cleanup-on-completion (Set entry removed when the session completes):
  // SKIPPED -- not observable through the public hook surface.
  //
  // Why the harness cannot simulate session reuse: firing session.idle twice
  // for the same child hits the S2 forward-only transition guard
  // (delegation-observer.ts ~3713-3724): after the first idle writes the
  // terminal `completed` row, the second idle short-circuits with an
  // anomaly_backward_transition row and RETURNS before reaching the
  // empty-result check. So a stale Set entry can never change observable
  // behavior via re-idle, and the plugin currently exports no set-inspection
  // hook to assert cleanup directly.
  //
  // Revisit IF the implementer exposes one (e.g. export
  // verificationOnlySessions or a __getVerificationOnlySessions() test hook):
  // then dispatch with marker, idle once, and assert the session id is no
  // longer in the set. Until then this stays skipped rather than testing an
  // internal that has no observable effect.
  test.skip("cleanup-on-completion removes the exemption entry (needs exported set-inspection hook)", () => {})
})
