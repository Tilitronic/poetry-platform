/**
 * DIA-225 C4 regression test: failure cap for consecutive empty results.
 *
 * Verifies the D4 failure cap: after 3 consecutive empty-result detections
 * within a 10-minute cooldown window, a failure_cap_reached warning event is
 * emitted to messages.jsonl. Counter resets on a non-empty result or cooldown
 * expiry. WARNING ONLY -- never auto-dispatch or auto-block.
 *
 * DIA-260926-ch1d: the cap contract is unchanged, but the detection it counts
 * is now the ABSENT-TEXT predicate, so each idle cycle drives a task()
 * dispatch whose <task_result> body is captured (empty -> counts, text ->
 * resets). The capture is consumed on idle, hence one dispatch per cycle.
 * The DIA-225 3-consecutive-failure cap and the DIA-260826-zvu4 exemptions
 * are re-anchored here, never weakened.
 *
 * Hermetic: every harness gets a fresh mkdtemp workspace. No real project
 * files are touched.
 *
 * DIA-079: this file is ASCII-only (no em-dashes, no smart quotes).
 *
 * RUN COMMAND (bun in poetry-dev container):
 *   docker compose exec dev bash -lc \
 *     'cd /workspace/.opencode/plugins/__tests__ && \
 *      bun test failure-cap.test.mjs'
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


function freshCtx() { const { directory, cleanup } = createTempWorkspace("dia225-c4-")
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
 * Drive a task() dispatch whose <task_result> BODY is `resultBody`
 * (DIA-260926-ch1d: that body is the only signal the empty-result predicate
 * reads). The child session id is parsed from the task output, which is the
 * key the session.idle lookup uses.
 */
async function driveResultDispatch(hooks, sessionID, resultBody = "") { await hooks["tool.execute.after"](
    { tool: "task",
      sessionID: "ses_parent",
      callID: "call_cap_" + sessionID,
      args: { subagent_type: "coder",
        prompt: "implement feature X against tasks.md", }, },
    { output: `<task id="${sessionID}"><state>completed</state><task_result>${resultBody}</task_result></task>` }
  ) }

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

/**
 * Register a child session via session.created.
 */
async function registerChild(hooks, sessionID) { await driveEvent(hooks, { event: { type: "session.created",
      properties: { info: { id: sessionID, parentID: "ses_parent", title: "test" }, }, }, }) }

/**
 * Fire session.idle on an EMPTY result: dispatch first so the zero-length
 * <task_result> body is captured, then idle (the capture is consumed there).
 */
async function idleEmpty(hooks, sessionID) { await driveResultDispatch(hooks, sessionID)
  await driveEvent(hooks, { event: { type: "session.idle",
      properties: { sessionID }, }, }) }

/**
 * Fire session.idle on a NON-EMPTY result: the returned text is what resets
 * the DIA-225 counter under the DIA-260926-ch1d text predicate.
 */
async function idleWithResultText(hooks, sessionID) { await driveResultDispatch(
    hooks,
    sessionID,
    "Done: implemented feature X, all tests pass."
  )
  await driveEvent(hooks, { event: { type: "session.idle",
      properties: { sessionID }, }, }) }

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("DIA-225 C4: failure cap", () => { test("3 consecutive empty results within 10 min triggers failure_cap_reached", async () => { // The failure cap is keyed by session_id. Verify the cap works with
    // repeated idle on the SAME session_id (multi-idle edge case).
    const h2 = await makeHarness()
    const sid = "ses_c4_repeat"
    await registerChild(h2.hooks, sid)

    const msgsBefore2 = countMessages(h2.ctx)

    // Fire 3 consecutive empty idles on the same session.
    await idleEmpty(h2.hooks, sid)
    await idleEmpty(h2.hooks, sid)
    await idleEmpty(h2.hooks, sid)

    // The 3rd idle should trigger failure_cap_reached.
    const newMsgs = readNewMessages(h2.ctx, msgsBefore2)
    const capMsg = newMsgs.find(
      (m) => m["gen_ai.operation.name"] === "failure_cap_reached"
    )
    expect(capMsg).toBeDefined()
    expect(capMsg["gen_ai.agent.id"]).toBe(sid)
    expect(capMsg.task_ref).toContain("failure cap reached") })

  test("non-empty result resets the counter (no cap after 2+1+2 pattern)", async () => { const { hooks, ctx } = await makeHarness()
    const sid = "ses_c4_reset"
    await registerChild(hooks, sid)

    const msgsBefore = countMessages(ctx)

    // 2 empty results.
    await idleEmpty(hooks, sid)
    await idleEmpty(hooks, sid)

    // 1 non-empty result (<task_result> body carries text).
    await idleWithResultText(hooks, sid)

    // 2 more empty results -- counter was reset, so only 2 consecutive
    // failures, below the 3 threshold.
    await idleEmpty(hooks, sid)
    await idleEmpty(hooks, sid)

    const newMsgs = readNewMessages(ctx, msgsBefore)
    const capMsg = newMsgs.find(
      (m) => m["gen_ai.operation.name"] === "failure_cap_reached"
    )
    expect(capMsg).toBeUndefined() })

  test("cooldown expiry resets the counter (no cap after 11 min gap)", async () => { const { hooks, ctx } = await makeHarness()
    const sid = "ses_c4_cooldown"
    await registerChild(hooks, sid)

    const msgsBefore = countMessages(ctx)

    // 2 empty results.
    await idleEmpty(hooks, sid)
    await idleEmpty(hooks, sid)

    // Simulate 11 minutes passing by patching Date.now.
    const realDateNow = Date.now
    const futureTime = realDateNow() + 11 * 60 * 1000
    Date.now = () => futureTime

    try { // 1 more empty result -- cooldown expired, counter reset, only 1
      // consecutive failure, below the 3 threshold.
      await idleEmpty(hooks, sid) } finally { Date.now = realDateNow }

    const newMsgs = readNewMessages(ctx, msgsBefore)
    const capMsg = newMsgs.find(
      (m) => m["gen_ai.operation.name"] === "failure_cap_reached"
    )
    expect(capMsg).toBeUndefined() }) })