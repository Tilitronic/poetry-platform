/**
 * DIA-225 C3 regression test: empty-result detection in session.idle handler.
 *
 * Verifies DIA-224 D3 empty-result detection: when a child session completes
 * with an EMPTY <task_result> body, an empty_result_detected row is emitted
 * with dispatch_state EMPTY_RESULT / status NO_TEXT_RESULT (DIA-260926-ch1d
 * label split from the shared SILENT_FAILURE status).
 *
 * DIA-260926-ch1d re-anchors this suite from the old ZERO-FILE-EDIT proxy to
 * the ABSENT-TEXT predicate:
 *   - the detector measures the <task_result> BODY, so every fire case must
 *     dispatch a task() whose body trims to zero;
 *   - a lane that returned text does NOT fire (the old proxy fired on 263 of
 *     265 sessions that had returned real reports);
 *   - read-only lanes stay exempt via READ_ONLY_LANES, and file edits are no
 *     longer a suppression signal (an editing lane with no result text fires).
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
import { test, expect, describe, afterEach } from "bun:test"
import { existsSync, readFileSync } from "node:fs"
import { join } from "node:path"
import { createTempWorkspace, mockOpencodePlugin, createHarness } from "./helpers/plugin-harness.mjs"

const workspaceCleanups = []
afterEach(() => {
  while (workspaceCleanups.length) {
    const fn = workspaceCleanups.pop()
    try {
      fn()
    } catch (err) {
      console.error(`[cleanup] temp workspace cleanup failed: ${err?.message ?? err}`)
      // bounded retry: one immediate retry to surface ENOTEMPTY/EBUSY races without flaking
      try {
        fn()
      } catch (retryErr) {
        console.error(`[cleanup] retry failed: ${retryErr?.message ?? retryErr}`)
      }
    }
  }
})


// ---- @opencode-ai/plugin mock (registered BEFORE the plugin import) ----
mockOpencodePlugin()

// Dynamic import AFTER mock.module registration (defeats ESM hoisting).

// ---------------------------------------------------------------------------
// Harness plumbing
// ---------------------------------------------------------------------------


function freshCtx() { const { directory, cleanup } = createTempWorkspace("dia225-c3-")
  workspaceCleanups.push(cleanup)
  return { directory,
    client: { app: { log: async () => {} } }, } }

async function makeHarness() { const ctx = freshCtx()
  const hooks = await createHarness(ctx.directory)
  return { hooks, ctx } }

/**
 * Drive the event hook (session lifecycle events).
 */
async function driveEvent(hooks, { event }) { await hooks.event({ event }) }

/**
 * Drive tool.execute.after to register a file edit for a session.
 */
async function driveToolEdit(hooks, ctx, { sessionID, tool, callID }) { await hooks["tool.execute.after"](
    { tool: tool ?? "edit",
      sessionID,
      callID: callID ?? "call_edit",
      args: {}, },
    { output: "ok" }
  ) }

/**
 * Read registry rows appended after a given count.
 */
function readNewRows(ctx, rowsBefore) { const registryPath = join(ctx.directory, ".opencode/session/registry.jsonl")
  if (!existsSync(registryPath)) return []
  const allLines = readFileSync(registryPath, "utf-8").trim().split("\n").filter(Boolean)
  return allLines.slice(rowsBefore).map((line) => { try { return JSON.parse(line) } catch { return null } }).filter(Boolean) }

function countRows(ctx) { const registryPath = join(ctx.directory, ".opencode/session/registry.jsonl")
  if (!existsSync(registryPath)) return 0
  return readFileSync(registryPath, "utf-8").trim().split("\n").filter(Boolean).length }

/**
 * Read messages.jsonl rows appended after a given count.
 */
function readNewMessages(ctx, rowsBefore) { const messagesPath = join(ctx.directory, ".opencode/session/messages.jsonl")
  if (!existsSync(messagesPath)) return []
  const allLines = readFileSync(messagesPath, "utf-8").trim().split("\n").filter(Boolean)
  return allLines.slice(rowsBefore).map((line) => { try { return JSON.parse(line) } catch { return null } }).filter(Boolean) }

function countMessages(ctx) { const messagesPath = join(ctx.directory, ".opencode/session/messages.jsonl")
  if (!existsSync(messagesPath)) return 0
  return readFileSync(messagesPath, "utf-8").trim().split("\n").filter(Boolean).length }

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("DIA-225 C3: empty-result detection", () => { test("empty <task_result> body -> EMPTY_RESULT row with NO_TEXT_RESULT status", async () => { const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_c3_empty_1"

    // Register child session via session.created.
    await driveEvent(hooks, { event: { type: "session.created",
        properties: { info: { id: sessionID, parentID: "ses_parent", title: "test" }, }, }, })

    // DIA-260926-ch1d: the detector measures the <task_result> BODY, so the
    // dispatch that records a zero-length body must precede the idle.
    await driveTaskDispatch(hooks, { parentID: "ses_parent",
      childID: sessionID,
      agent: "coder",
      prompt: "implement feature X against tasks.md", })

    const rowsBefore = countRows(ctx)
    const msgsBefore = countMessages(ctx)

    // Fire session.idle -- the captured body trims to zero, so detection fires.
    await driveEvent(hooks, { event: { type: "session.idle",
        properties: { sessionID }, }, })

    // Registry should contain an empty_result_detected row under the new
    // label pair (event name unchanged -- scripts/lane-resume keys on it).
    const newRows = readNewRows(ctx, rowsBefore)
    const emptyRow = findEmptyResultRow(newRows)
    expect(emptyRow).toBeDefined()
    expect(emptyRow.session_id).toBe(sessionID)
    expect(emptyRow.status).toBe("NO_TEXT_RESULT")
    expect(emptyRow.file_edit_count).toBe(0)

    // Messages should contain the empty_result_detected warning.
    const newMsgs = readNewMessages(ctx, msgsBefore)
    const warningMsg = newMsgs.find(
      (m) => m["gen_ai.operation.name"] === "empty_result_detected"
    )
    expect(warningMsg).toBeDefined()
    expect(warningMsg["gen_ai.agent.id"]).toBe(sessionID) })

  test("lane that returned <task_result> text does NOT emit empty_result_detected", async () => { const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_c3_report_1"

    // Register child session.
    await driveEvent(hooks, { event: { type: "session.created",
        properties: { info: { id: sessionID, parentID: "ses_parent", title: "report" }, }, }, })

    // analyzer is the reported false-positive lane: it returns a full report
    // and edits no implementation files, so the zero-edit proxy flagged it.
    await driveTaskDispatch(hooks, { parentID: "ses_parent",
      childID: sessionID,
      agent: "analyzer",
      prompt: "produce the analysis report",
      resultBody: "Full analysis: 12 findings, 3 critical. See knowledge/ana-x.", })

    const rowsBefore = countRows(ctx)
    const msgsBefore = countMessages(ctx)

    await driveEvent(hooks, { event: { type: "session.idle",
        properties: { sessionID }, }, })

    const newRows = readNewRows(ctx, rowsBefore)
    expect(findEmptyResultRow(newRows)).toBeUndefined()

    const newMsgs = readNewMessages(ctx, msgsBefore)
    const warningMsg = newMsgs.find(
      (m) => m["gen_ai.operation.name"] === "empty_result_detected"
    )
    expect(warningMsg).toBeUndefined() })

  test("read-only lane with an empty <task_result> body is exempt (READ_ONLY_LANES)", async () => { const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_c3_readonly_1"

    await driveEvent(hooks, { event: { type: "session.created",
        properties: { info: { id: sessionID, parentID: "ses_parent", title: "readonly" }, }, }, })

    await driveTaskDispatch(hooks, { parentID: "ses_parent",
      childID: sessionID,
      agent: "researcher",
      prompt: "research topic X", })

    const rowsBefore = countRows(ctx)
    const msgsBefore = countMessages(ctx)

    await driveEvent(hooks, { event: { type: "session.idle",
        properties: { sessionID }, }, })

    const newRows = readNewRows(ctx, rowsBefore)
    expect(findEmptyResultRow(newRows)).toBeUndefined()

    const newMsgs = readNewMessages(ctx, msgsBefore)
    const warningMsg = newMsgs.find(
      (m) => m["gen_ai.operation.name"] === "empty_result_detected"
    )
    expect(warningMsg).toBeUndefined() })

  test("file edits no longer suppress: edits + empty <task_result> body -> fires", async () => { const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_c3_edit_empty_1"

    await driveEvent(hooks, { event: { type: "session.created",
        properties: { info: { id: sessionID, parentID: "ses_parent", title: "edits+no text" }, }, }, })

    // Accepted consequence of DIA-260926-ch1d (owner-recorded): edits and
    // result text are independent quantities, so a lane that touched files
    // but returned nothing to read still fires.
    await driveToolEdit(hooks, ctx, { sessionID })
    await driveTaskDispatch(hooks, { parentID: "ses_parent",
      childID: sessionID,
      agent: "coder",
      prompt: "implement feature X against tasks.md", })

    const rowsBefore = countRows(ctx)

    await driveEvent(hooks, { event: { type: "session.idle",
        properties: { sessionID }, }, })

    const newRows = readNewRows(ctx, rowsBefore)
    const emptyRow = findEmptyResultRow(newRows)
    expect(emptyRow).toBeDefined()
    // The row reports the REAL edit count -- it is telemetry, not the gate.
    expect(emptyRow.file_edit_count).toBe(1) }) })

// ---------------------------------------------------------------------------
// DIA-260826-zvu4: verification-only coder exemption (RED phase tests)
// ---------------------------------------------------------------------------

/**
 * Drive a task() dispatch through tool.execute.after: registers the child
 * lane in childSessionAgent and links the child session id parsed from the
 * task output. Mirrors the proven driveTaskAfter pattern from
 * dia220-apoptosis-paracrine.test.mjs.
 *
 * DIA-260926-ch1d: the output carries a <task_result> envelope whose BODY is
 * `resultBody` (default: empty, i.e. the 98-char empty-envelope case). The
 * detector measures that body, so this parameter is what arms/suppresses it.
 */
async function driveTaskDispatch(hooks, { parentID, childID, agent, prompt, resultBody = "" }) { await hooks["tool.execute.after"](
    { tool: "task",
      sessionID: parentID,
      callID: "call_dispatch_" + childID,
      args: { subagent_type: agent, prompt }, },
    { output: `<task id="${childID}"><state>completed</state><task_result>${resultBody}</task_result></task>` }
  ) }

function findEmptyResultRow(rows) { return rows.find(
    (r) =>
      r.event === "empty_result_detected" &&
      r.dispatch_state === "EMPTY_RESULT"
  ) }

describe("DIA-260826-zvu4: verification-only coder exemption", () => { // DIA-260926-ch1d: every case below now dispatches an EMPTY
  // <task_result> body, so each "NO detection" assertion is anchored to the
  // verification-only exemption rather than to the retired zero-edit proxy.
  test("coder dispatch with 'verification-only' marker + empty result -> NO empty_result_detected", async () => { const { hooks, ctx } = await makeHarness()
    const parentID = "ses_zvu4_parent_1"
    const childID = "ses_zvu4_verif_1"

    // Register child session via session.created.
    await driveEvent(hooks, { event: { type: "session.created",
        properties: { info: { id: childID, parentID, title: "verification-only recon" }, }, }, })

    // Dispatch a coder with the marker phrase in the prompt.
    await driveTaskDispatch(hooks, { parentID,
      childID,
      agent: "coder",
      prompt:
        "campaign ticket DIA-260826-zvu4 - verification-only: confirm writability, report findings. Do NOT modify implementation code.", })

    const rowsBefore = countRows(ctx)
    const msgsBefore = countMessages(ctx)

    // Fire session.idle -- the result body is empty, but the marker exempts
    // the session (without the exemption this case WOULD fire).
    await driveEvent(hooks, { event: { type: "session.idle",
        properties: { sessionID: childID }, }, })

    const newRows = readNewRows(ctx, rowsBefore)
    expect(findEmptyResultRow(newRows)).toBeUndefined()

    const newMsgs = readNewMessages(ctx, msgsBefore)
    const crisisMsg = newMsgs.find(
      (m) => m["gen_ai.operation.name"] === "empty_result_detected"
    )
    expect(crisisMsg).toBeUndefined() })

  test("coder dispatch WITHOUT marker + empty result -> EMPTY_RESULT preserved", async () => { const { hooks, ctx } = await makeHarness()
    const parentID = "ses_zvu4_parent_2"
    const childID = "ses_zvu4_impl_1"

    await driveEvent(hooks, { event: { type: "session.created",
        properties: { info: { id: childID, parentID, title: "implementation" }, }, }, })

    // Dispatch a coder WITHOUT any marker phrase.
    await driveTaskDispatch(hooks, { parentID,
      childID,
      agent: "coder",
      prompt: "implement feature X against tasks.md", })

    const rowsBefore = countRows(ctx)
    const msgsBefore = countMessages(ctx)

    await driveEvent(hooks, { event: { type: "session.idle",
        properties: { sessionID: childID }, }, })

    // Existing behavior must be preserved: a coder whose <task_result> body
    // is empty still raises the detection, now under the new label pair.
    const newRows = readNewRows(ctx, rowsBefore)
    const emptyRow = findEmptyResultRow(newRows)
    expect(emptyRow).toBeDefined()
    expect(emptyRow.session_id).toBe(childID)
    expect(emptyRow.status).toBe("NO_TEXT_RESULT")
    expect(emptyRow.file_edit_count).toBe(0)

    const newMsgs = readNewMessages(ctx, msgsBefore)
    const crisisMsg = newMsgs.find(
      (m) =>
        m["gen_ai.operation.name"] === "empty_result_detected" &&
        m["gen_ai.agent.id"] === childID
    )
    expect(crisisMsg).toBeDefined() })

  test("coder dispatch with marker + file edits -> NO empty_result_detected", async () => { const { hooks, ctx } = await makeHarness()
    const parentID = "ses_zvu4_parent_3"
    const childID = "ses_zvu4_verif_edits_1"

    await driveEvent(hooks, { event: { type: "session.created",
        properties: { info: { id: childID, parentID, title: "verification-only + edits" }, }, }, })

    await driveTaskDispatch(hooks, { parentID,
      childID,
      agent: "coder",
      prompt: "verification-only: extend the test file, run bun test", })

    // The session DID produce edits (test files are edits too). DIA-260926-ch1d
    // made edits irrelevant to the gate -- the MARKER is what exempts here,
    // and the empty result body is what would otherwise fire.
    await driveToolEdit(hooks, ctx, { sessionID: childID })

    const rowsBefore = countRows(ctx)

    await driveEvent(hooks, { event: { type: "session.idle",
        properties: { sessionID: childID }, }, })

    const newRows = readNewRows(ctx, rowsBefore)
    expect(findEmptyResultRow(newRows)).toBeUndefined() })

  test("marker variants 'read-only verification' and 'verify-only' are exempt", async () => { for (const [label, prompt] of [
      [
        "read-only verification",
        "read-only verification of the plugin behavior, report only",
      ],
      ["verify-only", "verify-only: run the suite and summarize results"],
    ]) { const { hooks, ctx } = await makeHarness()
      const parentID = "ses_zvu4_parent_v_" + label.replace(/[^a-z]+/g, "_")
      const childID = "ses_zvu4_variant_" + label.replace(/[^a-z]+/g, "_")

      await driveEvent(hooks, { event: { type: "session.created",
          properties: { info: { id: childID, parentID, title: label }, }, }, })

      await driveTaskDispatch(hooks, { parentID,
        childID,
        agent: "coder",
        prompt, })

      const rowsBefore = countRows(ctx)
      const msgsBefore = countMessages(ctx)

      await driveEvent(hooks, { event: { type: "session.idle",
          properties: { sessionID: childID }, }, })

      const newRows = readNewRows(ctx, rowsBefore)
      expect(findEmptyResultRow(newRows)).toBeUndefined()

      const newMsgs = readNewMessages(ctx, msgsBefore)
      const crisisMsg = newMsgs.find(
        (m) => m["gen_ai.operation.name"] === "empty_result_detected"
      )
      expect(crisisMsg).toBeUndefined() } })

  test("uppercase 'VERIFICATION-ONLY' marker is exempt (case-insensitive match)", async () => { const { hooks, ctx } = await makeHarness()
    const parentID = "ses_zvu4_parent_upper"
    const childID = "ses_zvu4_verif_upper"

    await driveEvent(hooks, { event: { type: "session.created",
        properties: { info: { id: childID, parentID, title: "UPPERCASE marker" }, }, }, })

    await driveTaskDispatch(hooks, { parentID,
      childID,
      agent: "coder",
      prompt: "VERIFICATION-ONLY: confirm writability, report findings.", })

    const rowsBefore = countRows(ctx)
    const msgsBefore = countMessages(ctx)

    await driveEvent(hooks, { event: { type: "session.idle", properties: { sessionID: childID } }, })

    const newRows = readNewRows(ctx, rowsBefore)
    expect(findEmptyResultRow(newRows)).toBeUndefined()

    const newMsgs = readNewMessages(ctx, msgsBefore)
    const crisisMsg = newMsgs.find(
      (m) => m["gen_ai.operation.name"] === "empty_result_detected"
    )
    expect(crisisMsg).toBeUndefined() })

  test("marker in args.description (not prompt) is exempt", async () => { const { hooks, ctx } = await makeHarness()
    const parentID = "ses_zvu4_parent_desc"
    const childID = "ses_zvu4_verif_desc"

    await driveEvent(hooks, { event: { type: "session.created",
        properties: { info: { id: childID, parentID, title: "marker via description" }, }, }, })

    // Marker lives ONLY in the description channel; prompt is marker-free.
    // Mirrors driveTaskDispatch but passes description instead of prompt.
    // DIA-260926-ch1d F2: the envelope must be present and EMPTY, otherwise
    // the fail-open fallback (no captured envelope -> never fire) would make
    // this assertion pass regardless of the marker exemption.
    await hooks["tool.execute.after"](
      { tool: "task",
        sessionID: parentID,
        callID: "call_dispatch_" + childID,
        args: { subagent_type: "coder",
          description: "verification-only recon",
          prompt: "implement feature X against tasks.md", }, },
      { output: `<task id="${childID}"><state>completed</state><task_result></task_result></task>` }
    )

    const rowsBefore = countRows(ctx)
    const msgsBefore = countMessages(ctx)

    await driveEvent(hooks, { event: { type: "session.idle", properties: { sessionID: childID } }, })

    const newRows = readNewRows(ctx, rowsBefore)
    expect(findEmptyResultRow(newRows)).toBeUndefined()

    const newMsgs = readNewMessages(ctx, msgsBefore)
    const crisisMsg = newMsgs.find(
      (m) => m["gen_ai.operation.name"] === "empty_result_detected"
    )
    expect(crisisMsg).toBeUndefined() })

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
  test.skip("cleanup-on-completion removes the exemption entry (needs exported set-inspection hook)", () => {}) })