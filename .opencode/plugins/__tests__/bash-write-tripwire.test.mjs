/**
 * DIA-260827-ft3z task 4.4: hook-level bash write-tripwire harness.
 *
 * Seam under test: the bash branch in the delegation-observer plugin's
 * tool.execute.before hook (design D5, tasks 4.2/4.3) - lane resolution
 * through childSessionAgent ?? sessionAgent plus the pure classifier in
 * .opencode/plugins/lib/bash-write-gate.ts. Scenarios (pre-authored in the
 * dispatch):
 *   1. redirection into .opencode/session/ with a coder lane -> throws
 *      before execution + a bash_write_denied row naming target and rule;
 *   2. tee into docs/dev-infra-audit/tickets/ -> throws + denial row;
 *   3. ordinary coder work passes unchanged: pnpm test, make test-config,
 *      git status, writes under packages/, apps/, scripts/, .opencode/
 *      (everything except .opencode/session/);
 *   4. a non-coder lane running the same protected write -> no throw
 *      (out of scope);
 *   5. an unresolvable session id -> no throw (documented fail-open);
 *   6. the primary lane leg: childSessionAgent populated from a parsed
 *      task() output (tool.execute.after) -> throws;
 *   7. task 4.3 control: the same protected write with NO session.created
 *      and NO task() id -> no throw (proves the backfill is what resolved
 *      cases 1/2, not some other signal).
 *
 * The tests drive the REAL plugin (dynamic import) through the real
 * tool.execute.before handler, exactly like the dia217-ticket-gate harness.
 * The only external module is @opencode-ai/plugin, mocked BEFORE the plugin
 * import (ESM hoisting).
 *
 * Hermetic: every harness gets a fresh mkdtemp workspace with a
 * .opencode/session/ directory; the REAL registry and tickets directory are
 * never touched.
 *
 * DIA-079: this file is ASCII-only (no em-dashes, no smart quotes).
 *
 * RUN COMMAND (bun, host or poetry-dev container):
 *   cd /workspace/.opencode/plugins/__tests__ && bun test bash-write-tripwire.test.mjs
 */
import { test, expect, afterEach } from "bun:test"
import { existsSync, readFileSync } from "node:fs"
import { join } from "node:path"
import {
  createTempWorkspace,
  mockOpencodePlugin,
  createHarness,
} from "./helpers/plugin-harness.mjs"

const workspaceCleanups = []
afterEach(() => {
  while (workspaceCleanups.length) {
    const fn = workspaceCleanups.pop()
    try {
      fn()
    } catch (err) {
      console.error(`[cleanup] temp workspace cleanup failed: ${err?.message ?? err}`)
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
await import("../delegation-observer.ts")

// ---------------------------------------------------------------------------
// Harness plumbing
// ---------------------------------------------------------------------------

function freshCtx() {
  const { directory, cleanup } = createTempWorkspace("ft3z-tripwire-")
  workspaceCleanups.push(cleanup)
  return {
    directory,
    client: { app: { log: async () => {} } },
  }
}

async function makeHarness() {
  const ctx = freshCtx()
  const hooks = await createHarness(ctx.directory)
  return { hooks, ctx }
}

/** Seed the sessionAgent backfill (task 4.3) from a real session.created. */
async function driveSessionCreated(hooks, { id, agent, parentID }) {
  await hooks.event({
    event: {
      type: "session.created",
      properties: { info: { id, agent, parentID } },
    },
  })
}

/**
 * Seed the primary lane leg (childSessionAgent): a task() result whose
 * output carries a parseable child session id, exactly as tool.execute.after
 * consumes it in production.
 */
async function driveTaskDispatch(hooks, { parentID, childID, agent }) {
  await hooks["tool.execute.after"](
    {
      tool: "task",
      sessionID: parentID,
      callID: `call_${childID}`,
      args: { subagent_type: agent, prompt: "implement campaign ticket DIA-260827-ft3z" },
    },
    {
      output:
        `<task id="${childID}"><state>completed</state>` +
        `<task_result>done</task_result></task>`,
    }
  )
}

/**
 * Drive the REAL tool.execute.before with a bash call.
 * Returns { error?, registryRows } where error is the thrown Error (if any)
 * and registryRows are the rows appended to registry.jsonl during the call.
 */
async function runBash(hooks, ctx, { sessionID, command, callID }) {
  const registryPath = join(ctx.directory, ".opencode/session/registry.jsonl")
  const rowsBefore = existsSync(registryPath)
    ? readFileSync(registryPath, "utf-8").trim().split("\n").filter(Boolean).length
    : 0

  let error = null
  try {
    await hooks["tool.execute.before"](
      { tool: "bash", sessionID, callID: callID ?? "call_bash" },
      { args: { command } }
    )
  } catch (err) {
    error = err instanceof Error ? err : new Error(String(err))
  }

  let newRows = []
  if (existsSync(registryPath)) {
    const allLines = readFileSync(registryPath, "utf-8").trim().split("\n").filter(Boolean)
    newRows = allLines
      .slice(rowsBefore)
      .map((line) => {
        try {
          return JSON.parse(line)
        } catch {
          return null
        }
      })
      .filter(Boolean)
  }
  return { error, registryRows: newRows }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test("coder + redirection into .opencode/session/ -> throws with a denial row", async () => {
  const { hooks, ctx } = await makeHarness()
  const sessionID = "ses_ft3z_coder_1"
  // Backfill only: no task() dispatch, so no parsed task id exists for this
  // session (task 4.3 acceptance - the sessionAgent map is what resolves).
  await driveSessionCreated(hooks, {
    id: sessionID,
    agent: "coder",
    parentID: "ses_ft3z_parent",
  })

  const { error, registryRows } = await runBash(hooks, ctx, {
    sessionID,
    command: "echo pwned > .opencode/session/pwned.txt",
  })

  expect(error).not.toBeNull()
  expect(String(error.message)).toContain("TRIPWIRE")
  expect(String(error.message)).toContain(".opencode/session/")

  const denial = registryRows.find((r) => r.event === "bash_write_denied")
  expect(denial).toBeDefined()
  expect(String(denial.target)).toContain(".opencode/session/")
  expect(denial.rule).toBe("redirection")
  expect(denial.subagent_type).toBe("coder")
  expect(denial.session_id).toBe(sessionID)
  expect(denial.writer).toBe("plugin")
})

test("coder + tee into docs/dev-infra-audit/tickets/ -> throws with a denial row", async () => {
  const { hooks, ctx } = await makeHarness()
  const sessionID = "ses_ft3z_coder_2"
  await driveSessionCreated(hooks, {
    id: sessionID,
    agent: "coder",
    parentID: "ses_ft3z_parent",
  })

  const { error, registryRows } = await runBash(hooks, ctx, {
    sessionID,
    command: "echo pwned | tee docs/dev-infra-audit/tickets/pwned.md",
  })

  expect(error).not.toBeNull()
  expect(String(error.message)).toContain("TRIPWIRE")
  expect(String(error.message)).toContain("docs/dev-infra-audit/tickets/")

  const denial = registryRows.find((r) => r.event === "bash_write_denied")
  expect(denial).toBeDefined()
  expect(String(denial.target)).toContain("docs/dev-infra-audit/tickets/")
  expect(denial.rule).toBe("tee")
  expect(denial.subagent_type).toBe("coder")
})

test("coder + ordinary work -> no throw (protected vs passthrough proof)", async () => {
  const { hooks, ctx } = await makeHarness()
  const sessionID = "ses_ft3z_coder_3"
  await driveSessionCreated(hooks, {
    id: sessionID,
    agent: "coder",
    parentID: "ses_ft3z_parent",
  })

  const passthrough = [
    "pnpm test",
    "make test-config",
    "git status",
    "echo ok > packages/demo/out.txt",
    "echo ok > apps/demo/out.txt",
    "echo ok > scripts/demo-out.txt",
    // .opencode/ is protected ONLY under .opencode/session/.
    "echo ok > .opencode/plugins/demo-out.txt",
  ]
  for (const command of passthrough) {
    const { error, registryRows } = await runBash(hooks, ctx, { sessionID, command })
    expect(error).toBeNull(`expected no throw for: ${command}`)
    expect(
      registryRows.filter((r) => r.event === "bash_write_denied").length
    ).toBe(0)
  }
})

test("non-coder lane + same protected write -> no throw (out of scope)", async () => {
  const { hooks, ctx } = await makeHarness()
  const sessionID = "ses_ft3z_researcher_1"
  await driveSessionCreated(hooks, {
    id: sessionID,
    agent: "researcher",
    parentID: "ses_ft3z_parent",
  })

  const { error, registryRows } = await runBash(hooks, ctx, {
    sessionID,
    command: "echo pwned > .opencode/session/pwned.txt",
  })

  expect(error).toBeNull()
  expect(registryRows.filter((r) => r.event === "bash_write_denied").length).toBe(0)
})

test("unresolvable session id -> no throw (documented fail-open)", async () => {
  const { hooks, ctx } = await makeHarness()

  // No session.created, no task() output: neither map holds this id.
  const { error, registryRows } = await runBash(hooks, ctx, {
    sessionID: "ses_ft3z_never_seen",
    command: "echo pwned > .opencode/session/pwned.txt",
  })

  expect(error).toBeNull()
  expect(registryRows.filter((r) => r.event === "bash_write_denied").length).toBe(0)
})

test("primary leg: childSessionAgent from a parsed task() id -> throws", async () => {
  const { hooks, ctx } = await makeHarness()
  const parentID = "ses_ft3z_parent_task"
  const childID = "ses_ft3z_child_task"
  await driveTaskDispatch(hooks, { parentID, childID, agent: "coder" })

  const { error, registryRows } = await runBash(hooks, ctx, {
    sessionID: childID,
    command: "echo pwned > docs/dev-infra-audit/tickets/pwned.md",
  })

  expect(error).not.toBeNull()
  const denial = registryRows.find((r) => r.event === "bash_write_denied")
  expect(denial).toBeDefined()
  expect(denial.subagent_type).toBe("coder")
  expect(String(denial.target)).toContain("docs/dev-infra-audit/tickets/")
})

test("retired coder-escalated lane + same protected write -> no throw (out of scope, DIA-261112-exon)", async () => {
  const { hooks, ctx } = await makeHarness()
  const parentID = "ses_ft3z_parent_retired"
  const childID = "ses_ft3z_child_retired"
  await driveTaskDispatch(hooks, { parentID, childID, agent: "coder-escalated" })

  const { error, registryRows } = await runBash(hooks, ctx, {
    sessionID: childID,
    command: "echo pwned > docs/dev-infra-audit/tickets/pwned.md",
  })

  expect(error).toBeNull()
  expect(registryRows.filter((r) => r.event === "bash_write_denied").length).toBe(0)
})

test("control: same protected write with no backfill and no task id -> no throw", async () => {
  const { hooks, ctx } = await makeHarness()

  // Counterpart to the two throwing cases above: nothing resolved the lane,
  // so the classifier fails open (design D5 honesty list, case 4 + case 1).
  const { error } = await runBash(hooks, ctx, {
    sessionID: "ses_ft3z_control",
    command: "echo pwned | tee docs/dev-infra-audit/tickets/pwned.md",
  })
  expect(error).toBeNull()
})
