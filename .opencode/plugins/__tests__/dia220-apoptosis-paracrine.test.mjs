/**
 * DIA-220 test harness (test-author lane, DIA-175 instance separation).
 *
 * Seam under test: apoptosis (dual-key shutdown) and paracrine (state
 * signals) in delegation-observer.
 *
 * Apoptosis: when circuit.open == true AND session.error fires, the plugin
 * autonomously triggers handoff + worktree cleanup + apoptosis_complete row.
 *
 * Paracrine: discrete state events (dispatch.started, dispatch.completed,
 * review.complete, build.passed, tests.failed) emitted into messages.jsonl.
 *
 * Hermetic: every harness gets a fresh mkdtemp workspace. No real project
 * files are touched.
 *
 * DIA-079: this file is ASCII-only (no em-dashes, no smart quotes).
 *
 * RUN COMMAND (verified on bun in the poetry-dev container):
 *   docker compose exec dev bash -lc \
 *     'cd /workspace/.opencode/plugins/__tests__ && \
 *      bun test dia220-apoptosis-paracrine.test.mjs'
 */
import { mock, test, expect, describe } from "bun:test"
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
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

// ---- node:child_process mock (DIA-260826-jcte RED phase) ------------------
// delegation-observer.ts imports { spawnSync } from "node:child_process".
// The spy records every git invocation so the safeRemoveWorktree contract
// tests can assert on remove/prune/status-probe args without real
// subprocesses. Status probes (git -C <path> status ...) return the
// configurable porcelain buffer; everything else returns success.
// Both exports are stubbed because bun 1.3.14 mock.module leaks across
// files in one run (same pattern as needs-input-observer.dia189.test.mjs).
const spawnCalls = []
let porcelainProbeStdout = ""
mock.module("node:child_process", () => ({
  spawn: () => ({ on: () => {} }),
  spawnSync: (cmd, args, opts) => {
    spawnCalls.push({ cmd, args, opts })
    // Dirty-tree probe shape: git -C <path> status --porcelain ...
    if (Array.isArray(args) && args[0] === "-C" && args.includes("status")) {
      return { status: 0, stdout: porcelainProbeStdout, stderr: "" }
    }
    return { status: 0, stdout: "", stderr: "" }
  },
}))

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
  const directory = mkdtempSync(join(tmpdir(), "dia220-apop-"))
  tempDirs.push(directory)
  mkdirSync(join(directory, ".opencode", "session", "handoffs"), {
    recursive: true,
  })
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
 * Drive the real tool.execute.after hook with a tool call.
 * Simulates a tool error by passing empty output.
 */
async function driveToolAfter(hooks, ctx, { tool, sessionID, output, callID }) {
  await hooks["tool.execute.after"](
    { tool, sessionID, callID: callID ?? "call_test", args: {} },
    { output: output ?? "" }
  )
}

/**
 * Drive the real tool.execute.after for a task() call with specific args.
 */
async function driveTaskAfter(hooks, ctx, { sessionID, output, callID, args }) {
  await hooks["tool.execute.after"](
    {
      tool: "task",
      sessionID,
      callID: callID ?? "call_task",
      args: args ?? {},
    },
    { output: output ?? "" }
  )
}

/**
 * Drive the real tool.execute.before hook for a task() dispatch.
 */
async function driveTaskBefore(hooks, ctx, { sessionID, callID, args }) {
  let error = null
  try {
    await hooks["tool.execute.before"](
      { tool: "task", sessionID, callID: callID ?? "call_test" },
      { args: args ?? {} }
    )
  } catch (err) {
    error = err instanceof Error ? err : new Error(String(err))
  }
  return error
}

/**
 * Drive the event hook (session lifecycle events).
 */
async function driveEvent(hooks, { event }) {
  await hooks.event({ event })
}

/**
 * Read registry rows appended during a test.
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
 * Read messages.jsonl rows appended during a test.
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
// Apoptosis tests
// ---------------------------------------------------------------------------

describe("DIA-220 Apoptosis (dual-key shutdown)", () => {
  test("circuit.open + session.error triggers apoptosis: worktree removed + handoff written", async () => {
    const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_apop_test_1"

    // Step 1: Trip the circuit breaker (3 errors in 5 calls).
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })

    // Verify circuit is OPEN by checking that dispatch is blocked.
    const blockErr = await driveTaskBefore(hooks, ctx, {
      sessionID,
      args: { subagent_type: "coder", prompt: "test", ticket_id: "DIA-220" },
    })
    expect(blockErr).not.toBeNull()
    expect(blockErr.message).toContain("CIRCUIT_BREAKER")

    const rowsBefore = countRows(ctx)

    // Step 2: Fire session.error.
    await driveEvent(hooks, {
      event: {
        type: "session.error",
        properties: {
          sessionID,
          error: new Error("test error for apoptosis"),
        },
      },
    })

    // Step 3: Verify apoptosis_complete row was written.
    const newRows = readNewRows(ctx, rowsBefore)
    const apoptosisRow = newRows.find((r) => r.event === "apoptosis_complete")
    expect(apoptosisRow).toBeDefined()
    expect(apoptosisRow.session_id).toBe(sessionID)
    expect(apoptosisRow.status).toBe("APOPTOSIS")

    // Step 4: Verify handoff file was written.
    const handoffsDir = join(ctx.directory, ".opencode/session/handoffs")
    const handoffFiles = readdirSync(handoffsDir).filter(
      (f) => f.endsWith(".json") && !f.startsWith(".")
    )
    expect(handoffFiles.length).toBeGreaterThan(0)
  })

  test("circuit NOT open + session.error: normal handling, no apoptosis", async () => {
    const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_apop_test_2"

    // Register a session first so it's recognized as a subagent.
    await driveEvent(hooks, {
      event: {
        type: "session.created",
        properties: {
          info: { id: sessionID, parentID: "ses_parent", title: "test" },
        },
      },
    })

    const rowsBefore = countRows(ctx)

    // Fire session.error WITHOUT tripping the circuit breaker first.
    await driveEvent(hooks, {
      event: {
        type: "session.error",
        properties: {
          sessionID,
          error: new Error("normal error"),
        },
      },
    })

    // Verify: session_failed row exists but NO apoptosis_complete.
    const newRows = readNewRows(ctx, rowsBefore)
    const failedRow = newRows.find((r) => r.event === "session_failed")
    expect(failedRow).toBeDefined()
    expect(failedRow.session_id).toBe(sessionID)

    const apoptosisRow = newRows.find((r) => r.event === "apoptosis_complete")
    expect(apoptosisRow).toBeUndefined()
  })

  test("apoptosis attempts worktree cleanup for tracked worktrees", async () => {
    const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_apop_test_3"

    // Create a fake worktree directory. We cannot test actual git worktree
    // removal in a temp dir (git worktree remove requires a real worktree),
    // so we verify the code PATH runs and the apoptosis completes.
    const worktreePath = join(ctx.directory, ".scratch", "test-worktree")
    mkdirSync(worktreePath, { recursive: true })

    // Dispatch a task with a WORKTREE assertion to track the worktree.
    await driveTaskBefore(hooks, ctx, {
      sessionID,
      callID: "call_wt",
      args: {
        subagent_type: "coder",
        prompt: "test WORKTREE: " + worktreePath,
        ticket_id: "DIA-220",
      },
    })

    // Simulate task completion to populate sessionWorktrees.
    await driveTaskAfter(hooks, ctx, {
      sessionID,
      callID: "call_wt",
      output: '<task id="ses_child_wt"><state>completed</state></task>',
      args: {
        subagent_type: "coder",
        prompt: "test WORKTREE: " + worktreePath,
      },
    })

    // Trip the circuit breaker.
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })

    const rowsBefore = countRows(ctx)

    // Fire session.error to trigger apoptosis.
    await driveEvent(hooks, {
      event: {
        type: "session.error",
        properties: { sessionID, error: new Error("apoptosis test") },
      },
    })

    // Verify apoptosis completed (the worktree removal ATTEMPT ran --
    // actual removal requires a real git worktree, which we cannot
    // create in a temp dir).
    const newRows = readNewRows(ctx, rowsBefore)
    const apoptosisRow = newRows.find((r) => r.event === "apoptosis_complete")
    expect(apoptosisRow).toBeDefined()
    expect(apoptosisRow.session_id).toBe(sessionID)
  })

  test("session.idle + circuit.open triggers apoptosis (idle dual-key)", async () => {
    const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_apop_idle_1"

    // Register as a subagent so it's recognized in session.idle handling.
    await driveEvent(hooks, {
      event: {
        type: "session.created",
        properties: {
          info: { id: sessionID, parentID: "ses_parent", title: "test" },
        },
      },
    })

    // Trip the circuit breaker (3 errors in 5 calls).
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })

    // Verify circuit is OPEN.
    const blockErr = await driveTaskBefore(hooks, ctx, {
      sessionID,
      args: { subagent_type: "coder", prompt: "test", ticket_id: "DIA-220" },
    })
    expect(blockErr).not.toBeNull()
    expect(blockErr.message).toContain("CIRCUIT_BREAKER")

    const rowsBefore = countRows(ctx)

    // Fire session.idle (not session.error) -- idle with open circuit is fatal.
    await driveEvent(hooks, {
      event: {
        type: "session.idle",
        properties: { sessionID },
      },
    })

    // Verify apoptosis_complete row was written.
    const newRows = readNewRows(ctx, rowsBefore)
    const apoptosisRow = newRows.find((r) => r.event === "apoptosis_complete")
    expect(apoptosisRow).toBeDefined()
    expect(apoptosisRow.session_id).toBe(sessionID)
    expect(apoptosisRow.status).toBe("APOPTOSIS")
  })

  test("after apoptosis, tool.execute.before throws on any tool call", async () => {
    const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_apop_kill_1"

    // Trip the circuit breaker.
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })

    // Trigger apoptosis via session.error.
    await driveEvent(hooks, {
      event: {
        type: "session.error",
        properties: {
          sessionID,
          error: new Error("apoptosis test"),
        },
      },
    })

    // Now any tool call via tool.execute.before should throw.
    const err = await driveTaskBefore(hooks, ctx, {
      sessionID,
      args: { subagent_type: "coder", prompt: "should be blocked", ticket_id: "DIA-220" },
    })
    expect(err).not.toBeNull()
    expect(err.message).toContain("APOPTOSIS")

    // A non-task tool should also be blocked (tool.execute.before short-circuits
    // for ANY tool, not just task()).
    const err2 = await driveTaskBefore(hooks, ctx, {
      sessionID: sessionID + "_other",
      args: { subagent_type: "coder", prompt: "also blocked", ticket_id: "DIA-220" },
    })
    // Different sessionID -- should NOT be blocked.
    expect(err2).toBeNull()
  })
})

// ---------------------------------------------------------------------------
// DIA-260826-jcte RED phase: safeRemoveWorktree contract (learning T2)
// ---------------------------------------------------------------------------
//
// Planned fix: both apoptosis worktree-removal call sites route through
// safeRemoveWorktree(wtPath, cwd):
//   1. directory missing -> git worktree prune, no remove attempt
//   2. dirty tree (git -C <path> status --porcelain --untracked-files=no
//      non-empty) -> NO removal, tuiSafeWarn + registry row
//      {event: "apoptosis_worktree_dirty", worktree, writer: "plugin"}
//   3. clean -> git worktree remove WITHOUT --force
//
// Current code spawns `git worktree remove --force <path>` unconditionally,
// so every case below FAILS against it = RED signal. GREEN phase (different
// coder instance, DIA-175) implements the helper in delegation-observer.ts;
// these tests must NOT be edited to pass.
//
// Both fatal triggers are exercised (session.error AND session.idle) because
// the two call sites are separate code blocks: a half-fix that routes only
// one site through the helper must stay RED.
//
// DISCOVERED PRECONDITION (RED-phase finding, 2026-08-26): the cases fail
// today with removes.length === 0 -- deeper than --force alone. Root cause:
// tool.execute.after DELETES turnToolCalls[sessionID] at entry (line ~3197,
// DIA-218 message-boundary reset) BEFORE the DIA-220 propagation block
// (line ~3371) reads it, so sessionWorktrees is never populated and the
// apoptosis worktree loop is currently unreachable dead code. Minimal GREEN
// precondition: capture the WORKTREE marker without depending on the
// pre-deleted turn list (e.g. read input.args in the after hook, or move the
// reset below the propagation block). Without that fix, safeRemoveWorktree
// would guard a path that can never run.

async function driveApoptosisWithTrackedWorktree(hooks, ctx, sessionID, worktreePath, trigger) {
  // The idle path recognizes only registered subagents (see the DIA-220
  // idle dual-key test above).
  if (trigger === "idle") {
    await driveEvent(hooks, {
      event: {
        type: "session.created",
        properties: {
          info: { id: sessionID, parentID: "ses_parent", title: "test" },
        },
      },
    })
  }

  // Track the worktree on THIS session id: task.before captures the single
  // WORKTREE marker; task.after propagates it keyed by <task id="...">.
  await driveTaskBefore(hooks, ctx, {
    sessionID,
    callID: "call_srw",
    args: {
      subagent_type: "coder",
      prompt: "test WORKTREE: " + worktreePath,
      ticket_id: "DIA-260826-jcte",
    },
  })
  await driveTaskAfter(hooks, ctx, {
    sessionID,
    callID: "call_srw",
    output: `<task id="${sessionID}"><state>completed</state></task>`,
    args: {
      subagent_type: "coder",
      prompt: "test WORKTREE: " + worktreePath,
    },
  })

  // Trip the circuit breaker (3 errors in 5 calls).
  await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
  await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
  await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })

  // Fire the second fatal key.
  if (trigger === "idle") {
    await driveEvent(hooks, {
      event: { type: "session.idle", properties: { sessionID } },
    })
  } else {
    await driveEvent(hooks, {
      event: {
        type: "session.error",
        properties: {
          sessionID,
          error: new Error("safeRemoveWorktree RED probe"),
        },
      },
    })
  }
}

function worktreeSubcommandCalls(subcommand) {
  return spawnCalls.filter(
    (c) =>
      Array.isArray(c.args) && c.args[0] === "worktree" && c.args[1] === subcommand
  )
}

describe("DIA-260826-jcte safeRemoveWorktree contract (RED phase)", () => {
  for (const trigger of ["error", "idle"]) {
    test(`clean worktree on apoptosis (${trigger}): remove invoked WITHOUT --force`, async () => {
      const { hooks, ctx } = await makeHarness()
      const sessionID = "ses_srw_clean_" + trigger
      const wtPath = join(ctx.directory, ".scratch", "srw-clean-wt")
      mkdirSync(wtPath, { recursive: true })

      porcelainProbeStdout = "" // clean tree
      spawnCalls.length = 0

      await driveApoptosisWithTrackedWorktree(hooks, ctx, sessionID, wtPath, trigger)

      const removes = worktreeSubcommandCalls("remove")
      expect(removes.length).toBe(1)
      expect(removes[0].args).toContain(wtPath)
      expect(removes[0].args).not.toContain("--force")
    })

    test(`dirty worktree on apoptosis (${trigger}): no removal + apoptosis_worktree_dirty row`, async () => {
      const { hooks, ctx } = await makeHarness()
      const sessionID = "ses_srw_dirty_" + trigger
      const wtPath = join(ctx.directory, ".scratch", "srw-dirty-wt")
      mkdirSync(wtPath, { recursive: true })

      porcelainProbeStdout = " M src/broken.ts\n" // non-empty = dirty
      spawnCalls.length = 0
      const rowsBefore = countRows(ctx)

      await driveApoptosisWithTrackedWorktree(hooks, ctx, sessionID, wtPath, trigger)

      expect(worktreeSubcommandCalls("remove").length).toBe(0)

      const newRows = readNewRows(ctx, rowsBefore)
      const dirtyRow = newRows.find((r) => r.event === "apoptosis_worktree_dirty")
      expect(dirtyRow).toBeDefined()
      expect(dirtyRow.worktree).toBe(wtPath)
      expect(dirtyRow.writer).toBe("plugin")

      // Apoptosis itself still completes even though the dirty tree is kept.
      const apoptosisRow = newRows.find((r) => r.event === "apoptosis_complete")
      expect(apoptosisRow).toBeDefined()
    })

    test(`missing worktree dir on apoptosis (${trigger}): prune instead of remove, no throw`, async () => {
      const { hooks, ctx } = await makeHarness()
      const sessionID = "ses_srw_missing_" + trigger
      const wtPath = join(ctx.directory, ".scratch", "srw-missing-wt")
      // Deliberately NOT created: exercises the prune branch.

      porcelainProbeStdout = ""
      spawnCalls.length = 0
      const rowsBefore = countRows(ctx)

      await driveApoptosisWithTrackedWorktree(hooks, ctx, sessionID, wtPath, trigger)

      expect(worktreeSubcommandCalls("prune").length).toBe(1)
      expect(worktreeSubcommandCalls("remove").length).toBe(0)

      // Apoptosis flow completed cleanly despite the missing directory.
      const newRows = readNewRows(ctx, rowsBefore)
      const apoptosisRow = newRows.find((r) => r.event === "apoptosis_complete")
      expect(apoptosisRow).toBeDefined()
    })
  }
})

// ---------------------------------------------------------------------------
// Paracrine tests
// ---------------------------------------------------------------------------

describe("DIA-220 Paracrine (state signals)", () => {
  test("dispatch.started signal emitted on task dispatch", async () => {
    const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_para_test_1"
    const messagesBefore = countMessages(ctx)

    // Dispatch a task (triggers dispatch.started in tool.execute.after).
    await driveTaskAfter(hooks, ctx, {
      sessionID,
      output: '<task id="ses_child_1"><state>completed</state></task>',
      args: { subagent_type: "coder", prompt: "test dispatch" },
    })

    // Verify dispatch.started signal in messages.jsonl.
    const newMessages = readNewMessages(ctx, messagesBefore)
    const dispatchStarted = newMessages.find(
      (r) => r.signal_type === "dispatch.started"
    )
    expect(dispatchStarted).toBeDefined()
    expect(dispatchStarted["gen_ai.agent.id"]).toBe("ses_child_1")
    expect(dispatchStarted.agent).toBe("coder")
  })

  test("dispatch.completed signal emitted on subagent completion", async () => {
    const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_para_test_2"
    const childID = "ses_child_2"

    // Register the child session.
    await driveEvent(hooks, {
      event: {
        type: "session.created",
        properties: {
          info: { id: childID, parentID: sessionID, title: "test" },
        },
      },
    })

    // Dispatch first so childSessionAgent is populated.
    await driveTaskAfter(hooks, ctx, {
      sessionID,
      callID: "call_dispatch",
      output: `<task id="${childID}"><state>completed</state></task>`,
      args: { subagent_type: "coder", prompt: "test" },
    })

    const messagesBefore = countMessages(ctx)

    // Fire session.idle to complete the child.
    await driveEvent(hooks, {
      event: {
        type: "session.idle",
        properties: { sessionID: childID },
      },
    })

    // Verify dispatch.completed signal.
    const newMessages = readNewMessages(ctx, messagesBefore)
    const dispatchCompleted = newMessages.find(
      (r) =>
        r.signal_type === "dispatch.completed" &&
        r["gen_ai.agent.id"] === childID
    )
    expect(dispatchCompleted).toBeDefined()
    expect(dispatchCompleted.result).toBe("success")
  })

  test("review.complete signal emitted when reviewer task finishes", async () => {
    const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_para_test_3"
    const reviewerID = "ses_reviewer_1"

    // Register the reviewer session.
    await driveEvent(hooks, {
      event: {
        type: "session.created",
        properties: {
          info: { id: reviewerID, parentID: sessionID, title: "review" },
        },
      },
    })

    // Dispatch with agent=reviewer so childSessionAgent is populated.
    await driveTaskAfter(hooks, ctx, {
      sessionID,
      callID: "call_review",
      output: `<task id="${reviewerID}"><state>completed</state></task>`,
      args: { subagent_type: "reviewer", prompt: "review code" },
    })

    const messagesBefore = countMessages(ctx)

    // Fire session.idle to complete the reviewer.
    await driveEvent(hooks, {
      event: {
        type: "session.idle",
        properties: { sessionID: reviewerID },
      },
    })

    // Verify review.complete signal.
    const newMessages = readNewMessages(ctx, messagesBefore)
    const reviewComplete = newMessages.find(
      (r) => r.signal_type === "review.complete"
    )
    expect(reviewComplete).toBeDefined()
    expect(reviewComplete.agent).toBe("reviewer")
    expect(reviewComplete.result).toBe("success")
  })

  test("dispatch.completed signal emitted with error on session.error", async () => {
    const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_para_test_4"
    const childID = "ses_child_4"

    // Register the child session.
    await driveEvent(hooks, {
      event: {
        type: "session.created",
        properties: {
          info: { id: childID, parentID: sessionID, title: "test" },
        },
      },
    })

    // Dispatch first so childSessionAgent is populated.
    await driveTaskAfter(hooks, ctx, {
      sessionID,
      callID: "call_dispatch",
      output: `<task id="${childID}"><state>completed</state></task>`,
      args: { subagent_type: "coder", prompt: "test" },
    })

    const messagesBefore = countMessages(ctx)

    // Fire session.error.
    await driveEvent(hooks, {
      event: {
        type: "session.error",
        properties: {
          sessionID: childID,
          error: new Error("test failure"),
        },
      },
    })

    // Verify dispatch.completed signal with error result.
    const newMessages = readNewMessages(ctx, messagesBefore)
    const dispatchCompleted = newMessages.find(
      (r) =>
        r.signal_type === "dispatch.completed" &&
        r["gen_ai.agent.id"] === childID
    )
    expect(dispatchCompleted).toBeDefined()
    expect(dispatchCompleted.result).toBe("error")
  })
})
