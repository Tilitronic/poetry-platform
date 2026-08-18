/**
 * DIA-218 test harness (test-author lane, DIA-175 instance separation).
 *
 * Seam under test: the ToolCircuitBreaker module in delegation-observer.
 * Tests the 3-state circuit breaker (CLOSED/OPEN/HALF_OPEN) that stops
 * infinite agent error loops by tracking tool.execute.error events.
 *
 * The tests invoke the REAL plugin (dynamic import) and drive its
 * tool.execute.after path via mocked hook inputs, following the
 * DIA-085/DIA-189/DIA-217 harness pattern.
 *
 * Hermetic: every harness gets a fresh mkdtemp workspace. No real
 * project files are touched.
 *
 * DIA-079: this file is ASCII-only (no em-dashes, no smart quotes).
 *
 * RUN COMMAND (verified on bun in the poetry-dev container):
 *   docker compose exec dev bash -lc \
 *     'cd /workspace/.opencode/plugins/__tests__ && \
 *      bun test circuit-breaker.test.mjs'
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
  const directory = mkdtempSync(join(tmpdir(), "dia218-cb-"))
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
 * Drive the real tool.execute.after hook with a tool call.
 * Simulates a tool error by passing empty output or error-like output.
 */
async function driveToolAfter(hooks, ctx, { tool, sessionID, output, callID }) {
  const origWarn = console.warn
  console.warn = () => {}
  try {
    await hooks["tool.execute.after"](
      { tool, sessionID, callID: callID ?? "call_test", args: {} },
      { output: output ?? "" }
    )
  } finally {
    console.warn = origWarn
  }
}

/**
 * Drive the real tool.execute.before hook to check if a dispatch is blocked.
 * Returns { error } - the thrown Error if the circuit blocked, null otherwise.
 */
async function driveToolBefore(hooks, ctx, { tool, sessionID, callID, args }) {
  const origWarn = console.warn
  console.warn = () => {}
  let error = null
  try {
    await hooks["tool.execute.before"](
      { tool, sessionID, callID: callID ?? "call_test" },
      { args: args ?? {} }
    )
  } catch (err) {
    error = err instanceof Error ? err : new Error(String(err))
  } finally {
    console.warn = origWarn
  }
  return error
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("DIA-218 Circuit Breaker", () => {
  test("starts in CLOSED state - tool errors are tracked but circuit stays closed", async () => {
    const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_cb_test_1"

    // 2 errors (below threshold of 3) - circuit should stay CLOSED.
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })

    // Dispatching should still work (no block).
    const error = await driveToolBefore(hooks, ctx, {
      tool: "task",
      sessionID,
      args: { subagent_type: "coder", prompt: "test", ticket_id: "DIA-218" },
    })
    expect(error).toBeNull()
  })

  test("3 errors in sliding window trips circuit to OPEN", async () => {
    const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_cb_test_2"

    // 3 errors should trip the circuit.
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })

    // Dispatching should be blocked (circuit OPEN).
    const error = await driveToolBefore(hooks, ctx, {
      tool: "task",
      sessionID,
      args: { subagent_type: "coder", prompt: "test", ticket_id: "DIA-218" },
    })
    expect(error).not.toBeNull()
    expect(error.message).toContain("CIRCUIT_BREAKER")
  })

  test("success resets error count in sliding window", async () => {
    const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_cb_test_3"

    // 2 errors + 1 success + 1 error = 3 errors in window -> trips OPEN.
    // The success reduces the count but 3 errors still meet the threshold.
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "ok" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })

    // Circuit should OPEN (3 errors in 4 calls).
    const error = await driveToolBefore(hooks, ctx, {
      tool: "task",
      sessionID,
      args: { subagent_type: "coder", prompt: "test", ticket_id: "DIA-218" },
    })
    expect(error).not.toBeNull()
    expect(error.message).toContain("CIRCUIT_BREAKER")
  })

  test("success after errors can keep circuit closed if below threshold", async () => {
    const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_cb_test_3b"

    // 2 errors + 1 success + 1 error = 3 errors -> trips OPEN.
    // Then add 2 more successes -> window shifts, errors age out.
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "ok" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    // Now add 2 successes to push errors out of the 5-call window.
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "ok" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "ok" })
    // Window is now [false, true, false, false, false] = 1 error.
    // But we already tripped OPEN on call 4. The circuit stays OPEN
    // until cooldown expires. This test verifies the window counting
    // is correct -- a fresh session with the same pattern stays closed.
    const { hooks: hooks2, ctx: ctx2 } = await makeHarness()
    const sessionID2 = "ses_cb_test_3c"
    await driveToolAfter(hooks2, ctx2, { tool: "bash", sessionID: sessionID2, output: "" })
    await driveToolAfter(hooks2, ctx2, { tool: "bash", sessionID: sessionID2, output: "" })
    await driveToolAfter(hooks2, ctx2, { tool: "bash", sessionID: sessionID2, output: "ok" })
    await driveToolAfter(hooks2, ctx2, { tool: "bash", sessionID: sessionID2, output: "ok" })
    await driveToolAfter(hooks2, ctx2, { tool: "bash", sessionID: sessionID2, output: "ok" })
    // Window: [true, true, false, false, false] = 2 errors < threshold.
    const err2 = await driveToolBefore(hooks2, ctx2, {
      tool: "task",
      sessionID: sessionID2,
      args: { subagent_type: "coder", prompt: "test", ticket_id: "DIA-218" },
    })
    expect(err2).toBeNull()
  })

  test("OPEN state emits circuit.open registry row", async () => {
    const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_cb_test_4"
    const rowsBefore = countRows(ctx)

    // Trip the circuit.
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })

    // Check registry for circuit.open event.
    const newRows = readNewRows(ctx, rowsBefore)
    const circuitOpen = newRows.find((r) => r.event === "circuit_open")
    expect(circuitOpen).toBeDefined()
    expect(circuitOpen.session_id).toBe(sessionID)
    expect(circuitOpen.status).toBe("OPEN")
  })

  test("errors are tracked per session - different sessions are independent", async () => {
    const { hooks, ctx } = await makeHarness()
    const sessionA = "ses_cb_session_a"
    const sessionB = "ses_cb_session_b"

    // Trip circuit for session A only.
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID: sessionA, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID: sessionA, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID: sessionA, output: "" })

    // Session B should still be CLOSED.
    const error = await driveToolBefore(hooks, ctx, {
      tool: "task",
      sessionID: sessionB,
      args: { subagent_type: "coder", prompt: "test", ticket_id: "DIA-218" },
    })
    expect(error).toBeNull()
  })

  test("sliding window keeps only last 5 calls", async () => {
    const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_cb_test_5"

    // 2 errors + 1 success (3 calls) - circuit should be CLOSED.
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "ok" })

    // Add 2 more successes (5 calls total, only 2 errors).
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "ok" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "ok" })

    // Now add 2 more errors (7 calls total, window = last 5: ok, ok, ok, err, err = 2 errors).
    // Circuit should stay CLOSED.
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })

    const error = await driveToolBefore(hooks, ctx, {
      tool: "task",
      sessionID,
      args: { subagent_type: "coder", prompt: "test", ticket_id: "DIA-218" },
    })
    expect(error).toBeNull()
  })

  test("HALF_OPEN -> CLOSED: cooldown expires, test call succeeds, circuit closes", async () => {
    const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_cb_test_recovery"
    const now = Date.now()

    // Trip the circuit with 3 errors.
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })

    // Circuit is OPEN -- dispatch blocked.
    const err1 = await driveToolBefore(hooks, ctx, {
      tool: "task",
      sessionID,
      args: { subagent_type: "coder", prompt: "test", ticket_id: "DIA-218" },
    })
    expect(err1).not.toBeNull()
    expect(err1.message).toContain("CIRCUIT_BREAKER")

    // Mock Date.now to advance past the 5-minute cooldown.
    const realDateNow = Date.now
    Date.now = () => now + 300_000 + 1

    // After cooldown, isBlocking should return false (HALF_OPEN).
    // driveToolBefore calls tryPass which transitions OPEN -> HALF_OPEN.
    const err2 = await driveToolBefore(hooks, ctx, {
      tool: "task",
      sessionID,
      args: { subagent_type: "coder", prompt: "test after cooldown", ticket_id: "DIA-218" },
    })
    // tryPass returns false in HALF_OPEN (allows the test call).
    expect(err2).toBeNull()

    // Record a success for the test call.
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "ok" })

    // Circuit should now be CLOSED -- dispatch allowed.
    const err3 = await driveToolBefore(hooks, ctx, {
      tool: "task",
      sessionID,
      args: { subagent_type: "coder", prompt: "test after recovery", ticket_id: "DIA-218" },
    })
    expect(err3).toBeNull()

    // Restore real Date.now.
    Date.now = realDateNow
  })

  test("HALF_OPEN -> OPEN: test call fails, circuit reopens", async () => {
    const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_cb_test_halfopen_fail"
    const now = Date.now()

    // Trip the circuit.
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })

    // Advance past cooldown.
    const realDateNow = Date.now
    Date.now = () => now + 300_000 + 1

    // Allow the test call (HALF_OPEN).
    const err1 = await driveToolBefore(hooks, ctx, {
      tool: "task",
      sessionID,
      args: { subagent_type: "coder", prompt: "test", ticket_id: "DIA-218" },
    })
    expect(err1).toBeNull()

    // Record a failure for the test call.
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })

    // Circuit should be back to OPEN -- dispatch blocked.
    // Still within the mocked cooldown window.
    const err2 = await driveToolBefore(hooks, ctx, {
      tool: "task",
      sessionID,
      args: { subagent_type: "coder", prompt: "test", ticket_id: "DIA-218" },
    })
    expect(err2).not.toBeNull()
    expect(err2.message).toContain("CIRCUIT_BREAKER")

    Date.now = realDateNow
  })

  test("HALF_OPEN parallel dispatches: only one test call allowed", async () => {
    const { hooks, ctx } = await makeHarness()
    const sessionID = "ses_cb_test_halfopen_parallel"
    const now = Date.now()

    // Trip the circuit.
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })
    await driveToolAfter(hooks, ctx, { tool: "bash", sessionID, output: "" })

    // Advance past cooldown.
    const realDateNow = Date.now
    Date.now = () => now + 300_000 + 1

    // First dispatch: HALF_OPEN, test call allowed.
    const err1 = await driveToolBefore(hooks, ctx, {
      tool: "task",
      sessionID,
      callID: "call_1",
      args: { subagent_type: "coder", prompt: "first", ticket_id: "DIA-218" },
    })
    expect(err1).toBeNull()

    // Second dispatch in same HALF_OPEN: should be BLOCKED (testCallMade = true).
    const err2 = await driveToolBefore(hooks, ctx, {
      tool: "task",
      sessionID,
      callID: "call_2",
      args: { subagent_type: "coder", prompt: "second", ticket_id: "DIA-218" },
    })
    expect(err2).not.toBeNull()
    expect(err2.message).toContain("CIRCUIT_BREAKER")

    Date.now = realDateNow
  })
})
