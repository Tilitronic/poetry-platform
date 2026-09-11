/**
 * DIA-260827-4q3h test harness (implement lane, serialized lane 2 of 4).
 *
 * Seam under test: the reviewer-only immutable git envelope branch in the
 * delegation-observer plugin's tool.execute.before hook (right after
 * taskSubagent is derived). The reviewer lane runs bash-denied, so the hook
 * pins the review range and appends a fenced IMMUTABLE_GIT_ENVELOPE to the
 * reviewer prompt in-memory. Scenarios:
 *   1. Valid reviewer dispatch with one FIXED_POINT marker -> envelope
 *      injected (fence, OIDs, three-dot diff, double-dot log, --no-color).
 *   2. Missing marker -> hard-block, prompt unchanged.
 *   3. Multiple markers -> hard-block, prompt unchanged.
 *   4. Unresolvable ref -> hard-block, prompt unchanged.
 *   5. Empty range (base == HEAD) -> hard-block, prompt unchanged.
 *   6. Non-reviewer lane (coder, with and without marker) -> inert.
 *   7. ctx.directory not a git repo -> hard-block (unresolvable).
 *   8. Post-injection branch change -> injected envelope is immutable
 *      (still carries the original OIDs, not the moved HEAD).
 *
 * The tests drive the REAL plugin (dynamic import) via mocked hook inputs,
 * exactly like the dia217-ticket-gate harness. Two mocks are registered
 * BEFORE the plugin import (ESM hoisting): @opencode-ai/plugin (same helper
 * as dia217) and node:child_process (recording wrapper delegating to the
 * REAL implementation, so git runs for real against temp repos while spawn
 * args stay observable for the --no-color assertion).
 *
 * Hermetic: every repo lives in a fresh mkdtemp workspace; the REAL tickets
 * directory and the REAL workspace repo are never touched.
 *
 * DIA-079: this file is ASCII-only (no em-dashes, no smart quotes).
 *
 * RUN COMMAND (bun 1.3.14, host or poetry-dev container):
 *   cd /workspace/.opencode/plugins/__tests__ && bun test reviewer-immutable-git-envelope.test.mjs
 */
import { test, expect, mock, afterEach } from "bun:test"
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { join } from "node:path"
import {
  createTempWorkspace,
  mockOpencodePlugin,
  createHarness,
} from "./helpers/plugin-harness.mjs"

// Real child_process fns, snapshotted BEFORE mock.module registration.
// Spread-copy (not the live namespace): mock.module patches the live
// namespace object in place, so a direct namespace ref would self-recurse
// through the recording wrapper. Matches helpers/plugin-harness.mjs.
const realCp = { ...(await import("node:child_process")) }

// Recording wrapper: every spawnSync call is logged, then delegated to the
// real implementation so git operates on real temp repos.
const spawnCalls = []
mock.module("node:child_process", () => ({
  ...realCp,
  spawnSync: (cmd, args, opts) => {
    spawnCalls.push({ cmd, args: Array.isArray(args) ? [...args] : args })
    return realCp.spawnSync(cmd, args, opts)
  },
}))

// ---- @opencode-ai/plugin mock (registered BEFORE the plugin import) ----
mockOpencodePlugin()

const workspaceCleanups = []
afterEach(() => {
  spawnCalls.length = 0
  while (workspaceCleanups.length) {
    const fn = workspaceCleanups.pop()
    try {
      fn()
    } catch {
      try {
        fn()
      } catch {
        // best-effort fail-safe only
      }
    }
  }
})

// ---------------------------------------------------------------------------
// Git helpers (real git against temp repos)
// ---------------------------------------------------------------------------

function git(cwd, ...args) {
  const res = realCp.spawnSync("git", args, {
    cwd,
    encoding: "utf-8",
    timeout: 15_000,
  })
  if (res.error || res.status !== 0) {
    throw new Error(`git ${args.join(" ")} failed: ${res.stderr ?? res.error}`)
  }
  return ((res.stdout ?? "").toString()).trim()
}

/** Fresh temp git repo with two commits; returns { directory, baseOid, headOid }. */
function initTwoCommitRepo() {
  const { directory, cleanup } = createTempWorkspace("4q3h-")
  workspaceCleanups.push(cleanup)
  git(directory, "init", "-q", "-b", "main")
  git(directory, "config", "user.email", "t@t.t")
  git(directory, "config", "user.name", "t")
  writeFileSync(join(directory, "notes.txt"), "hello\n")
  git(directory, "add", "notes.txt")
  git(directory, "commit", "-q", "-m", "first note")
  const baseOid = git(directory, "rev-parse", "HEAD")
  writeFileSync(join(directory, "notes.txt"), "hello world\n")
  git(directory, "add", "notes.txt")
  git(directory, "commit", "-q", "-m", "second note")
  const headOid = git(directory, "rev-parse", "HEAD")
  return { directory, baseOid, headOid }
}

function writeOpenTicket(directory, id) {
  const ticketsDir = join(directory, "docs/dev-infra-audit/tickets")
  mkdirSync(ticketsDir, { recursive: true })
  writeFileSync(
    join(ticketsDir, `${id}.md`),
    `---\nid: ${id}\ntitle: envelope test ticket\nstatus: OPEN\n---\n`
  )
}

async function makeHarnessAt(directory) {
  return createHarness(directory)
}

/**
 * Drive the real tool.execute.before hook with a task() call.
 * Returns { error, registryRows }. taskArgs.prompt is read back after the
 * call so the test can assert injection (in-memory mutation) or invariance.
 */
async function runTaskDispatch(hooks, ctx, taskArgs, sessionID, callID) {
  const registryPath = join(ctx.directory, ".opencode/session/registry.jsonl")
  mkdirSync(join(ctx.directory, ".opencode/session"), { recursive: true })
  const rowsBefore = existsSync(registryPath)
    ? readFileSync(registryPath, "utf-8").trim().split("\n").filter(Boolean)
        .length
    : 0
  let error = null
  try {
    await hooks["tool.execute.before"](
      { tool: "task", sessionID, callID },
      { args: taskArgs }
    )
  } catch (err) {
    error = err instanceof Error ? err : new Error(String(err))
  }
  let newRows = []
  if (existsSync(registryPath)) {
    const allLines = readFileSync(registryPath, "utf-8")
      .trim()
      .split("\n")
      .filter(Boolean)
    newRows = allLines.slice(rowsBefore).map((line) => {
      try {
        return JSON.parse(line)
      } catch {
        return null
      }
    }).filter(Boolean)
  }
  return { error, registryRows: newRows }
}

let sessionSeq = 0
function freshSession() {
  sessionSeq += 1
  return {
    sessionID: `ses_4q3h_${sessionSeq}`,
    callID: `call_4q3h_${sessionSeq}`,
  }
}

const TICKET_ID = "DIA-260827-4q3h"

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test("4q3h valid: reviewer + one FIXED_POINT marker receives the fenced envelope", async () => {
  const { directory, baseOid, headOid } = initTwoCommitRepo()
  writeOpenTicket(directory, TICKET_ID)
  const hooks = await makeHarnessAt(directory)
  const ctx = { directory }
  const { sessionID, callID } = freshSession()
  const originalPrompt = `Review the delta. FIXED_POINT: ${baseOid}`
  const taskArgs = {
    subagent_type: "reviewer",
    description: "reviewer delta check",
    prompt: originalPrompt,
    ticket_id: TICKET_ID,
  }

  const { error, registryRows } = await runTaskDispatch(
    hooks,
    ctx,
    taskArgs,
    sessionID,
    callID
  )

  expect(error).toBeNull()
  // Fenced envelope appended in-memory to the prompt.
  expect(taskArgs.prompt).toContain("```IMMUTABLE_GIT_ENVELOPE")
  expect(taskArgs.prompt.startsWith(originalPrompt)).toBe(true)
  expect(taskArgs.prompt).toContain(`base_oid: ${baseOid}`)
  expect(taskArgs.prompt).toContain(`head_oid: ${headOid}`)
  expect(taskArgs.prompt).toContain(`base_ref: ${baseOid}`)
  // Three-dot diff captured (the changed line) + double-dot log (subjects).
  expect(taskArgs.prompt).toContain("hello world")
  expect(taskArgs.prompt).toContain("second note")
  // Registry evidence row.
  const attached = registryRows.find(
    (r) => r.event === "reviewer_envelope_attached"
  )
  expect(attached).toBeDefined()
  expect(attached.base_oid).toBe(baseOid)
  expect(attached.head_oid).toBe(headOid)
  // No-color flags on the capture commands (not on rev-parse/merge-base).
  const diffCall = spawnCalls.find(
    (c) => c.cmd === "git" && c.args[0] === "diff"
  )
  const logCall = spawnCalls.find((c) => c.cmd === "git" && c.args[0] === "log")
  expect(diffCall).toBeDefined()
  expect(logCall).toBeDefined()
  expect(diffCall.args).toContain("--no-color")
  expect(logCall.args).toContain("--no-color")
})

test("4q3h missing: reviewer without FIXED_POINT hard-blocks, prompt unchanged", async () => {
  const { directory } = initTwoCommitRepo()
  writeOpenTicket(directory, TICKET_ID)
  const hooks = await makeHarnessAt(directory)
  const ctx = { directory }
  const { sessionID, callID } = freshSession()
  const taskArgs = {
    subagent_type: "reviewer",
    description: "reviewer delta check",
    prompt: "Review the delta.",
    ticket_id: TICKET_ID,
  }

  const { error, registryRows } = await runTaskDispatch(
    hooks,
    ctx,
    taskArgs,
    sessionID,
    callID
  )

  expect(error).not.toBeNull()
  expect(error.message).toContain("REVIEWER ENVELOPE:")
  expect(error.message).toContain("FIXED_POINT")
  expect(taskArgs.prompt).toBe("Review the delta.")
  expect(
    registryRows.find((r) => r.event === "reviewer_envelope_blocked")
  ).toBeDefined()
  expect(
    registryRows.find((r) => r.event === "reviewer_envelope_attached")
  ).toBeUndefined()
})

test("4q3h multiple: reviewer with two FIXED_POINT markers hard-blocks, prompt unchanged", async () => {
  const { directory, baseOid } = initTwoCommitRepo()
  writeOpenTicket(directory, TICKET_ID)
  const hooks = await makeHarnessAt(directory)
  const ctx = { directory }
  const { sessionID, callID } = freshSession()
  const originalPrompt = `Review. FIXED_POINT: ${baseOid} plus FIXED_POINT: HEAD`
  const taskArgs = {
    subagent_type: "reviewer",
    description: "reviewer delta check",
    prompt: originalPrompt,
    ticket_id: TICKET_ID,
  }

  const { error, registryRows } = await runTaskDispatch(
    hooks,
    ctx,
    taskArgs,
    sessionID,
    callID
  )

  expect(error).not.toBeNull()
  expect(error.message).toContain("REVIEWER ENVELOPE:")
  expect(error.message).toContain("2 FIXED_POINT markers")
  expect(taskArgs.prompt).toBe(originalPrompt)
  expect(
    registryRows.find((r) => r.event === "reviewer_envelope_blocked")
  ).toBeDefined()
})

test("4q3h unresolvable: bad base ref hard-blocks, prompt unchanged", async () => {
  const { directory } = initTwoCommitRepo()
  writeOpenTicket(directory, TICKET_ID)
  const hooks = await makeHarnessAt(directory)
  const ctx = { directory }
  const { sessionID, callID } = freshSession()
  const originalPrompt = "Review. FIXED_POINT: nope-not-a-ref"
  const taskArgs = {
    subagent_type: "reviewer",
    description: "reviewer delta check",
    prompt: originalPrompt,
    ticket_id: TICKET_ID,
  }

  const { error, registryRows } = await runTaskDispatch(
    hooks,
    ctx,
    taskArgs,
    sessionID,
    callID
  )

  expect(error).not.toBeNull()
  expect(error.message).toContain("REVIEWER ENVELOPE:")
  expect(error.message).toContain("cannot resolve range")
  expect(taskArgs.prompt).toBe(originalPrompt)
  expect(
    registryRows.find((r) => r.event === "reviewer_envelope_blocked")
  ).toBeDefined()
})

test("4q3h empty: base == HEAD hard-blocks (nothing to review), prompt unchanged", async () => {
  const { directory, headOid } = initTwoCommitRepo()
  writeOpenTicket(directory, TICKET_ID)
  const hooks = await makeHarnessAt(directory)
  const ctx = { directory }
  const { sessionID, callID } = freshSession()
  const originalPrompt = `Review. FIXED_POINT: ${headOid}`
  const taskArgs = {
    subagent_type: "reviewer",
    description: "reviewer delta check",
    prompt: originalPrompt,
    ticket_id: TICKET_ID,
  }

  const { error, registryRows } = await runTaskDispatch(
    hooks,
    ctx,
    taskArgs,
    sessionID,
    callID
  )

  expect(error).not.toBeNull()
  expect(error.message).toContain("REVIEWER ENVELOPE:")
  expect(error.message).toContain("empty range")
  expect(taskArgs.prompt).toBe(originalPrompt)
  expect(
    registryRows.find((r) => r.event === "reviewer_envelope_blocked")
  ).toBeDefined()
})

test("4q3h inert: non-reviewer lanes skip the envelope (with and without marker)", async () => {
  const { directory, baseOid } = initTwoCommitRepo()
  writeOpenTicket(directory, TICKET_ID)
  const hooks = await makeHarnessAt(directory)
  const ctx = { directory }
  for (const prompt of [
    "Carry out the slice.",
    `Carry out the slice. FIXED_POINT: ${baseOid}`,
  ]) {
    const { sessionID, callID } = freshSession()
    const taskArgs = {
      subagent_type: "coder",
      description: "coder slice",
      prompt,
      ticket_id: TICKET_ID,
    }
    const { error, registryRows } = await runTaskDispatch(
      hooks,
      ctx,
      taskArgs,
      sessionID,
      callID
    )
    expect(error).toBeNull()
    expect(taskArgs.prompt).toBe(prompt)
    expect(
      registryRows.find((r) => r.event === "reviewer_envelope_attached")
    ).toBeUndefined()
    expect(
      registryRows.find((r) => r.event === "reviewer_envelope_blocked")
    ).toBeUndefined()
  }
})

test("4q3h non-git: ctx.directory outside any repo hard-blocks (unresolvable)", async () => {
  const { directory, cleanup } = createTempWorkspace("4q3h-nogit-")
  workspaceCleanups.push(cleanup)
  const hooks = await makeHarnessAt(directory)
  const ctx = { directory }
  const { sessionID, callID } = freshSession()
  const originalPrompt = "Review. FIXED_POINT: main"
  const taskArgs = {
    subagent_type: "reviewer",
    description: "reviewer delta check",
    prompt: originalPrompt,
    ticket_id: TICKET_ID,
  }

  const { error, registryRows } = await runTaskDispatch(
    hooks,
    ctx,
    taskArgs,
    sessionID,
    callID
  )

  expect(error).not.toBeNull()
  expect(error.message).toContain("REVIEWER ENVELOPE:")
  expect(taskArgs.prompt).toBe(originalPrompt)
  expect(
    registryRows.find((r) => r.event === "reviewer_envelope_blocked")
  ).toBeDefined()
})

test("4q3h immutability: envelope keeps original OIDs after the branch moves", async () => {
  const { directory, baseOid, headOid } = initTwoCommitRepo()
  writeOpenTicket(directory, TICKET_ID)
  const hooks = await makeHarnessAt(directory)
  const ctx = { directory }
  const { sessionID, callID } = freshSession()
  const taskArgs = {
    subagent_type: "reviewer",
    description: "reviewer delta check",
    prompt: `Review the delta. FIXED_POINT: ${baseOid}`,
    ticket_id: TICKET_ID,
  }

  const { error } = await runTaskDispatch(hooks, ctx, taskArgs, sessionID, callID)
  expect(error).toBeNull()
  const injectedPrompt = taskArgs.prompt

  // Move the branch after injection: new commit advances HEAD.
  writeFileSync(join(directory, "notes.txt"), "hello world again\n")
  git(directory, "add", "notes.txt")
  git(directory, "commit", "-q", "-m", "third note")
  const movedHead = git(directory, "rev-parse", "HEAD")
  expect(movedHead).not.toBe(headOid)

  // The already-injected prompt is a snapshot: original OIDs, no new content.
  expect(injectedPrompt).toContain(`head_oid: ${headOid}`)
  expect(injectedPrompt).not.toContain(movedHead)
  expect(injectedPrompt).not.toContain("third note")
  expect(injectedPrompt).not.toContain("hello world again")
})

test("regression: realCp snapshot does not self-recurse (one bounded git call)", () => {
  // WHY: realCp must be a spread-copy snapshot, not the live namespace.
  // mock.module patches the live namespace in place, so a live ref makes
  // realCp.spawnSync point at the recording wrapper itself -> unbounded
  // self-recursion (RAM/CPU exhaustion). A snapshot bypasses the wrapper.
  const before = spawnCalls.length
  const res = realCp.spawnSync("git", ["--version"], {
    encoding: "utf-8",
    timeout: 15_000,
  })
  expect(res.status).toBe(0)
  expect(String(res.stdout)).toContain("git version")
  // Direct snapshot call bypasses the wrapper: no new recording, bounded.
  expect(spawnCalls.length).toBe(before)
})
