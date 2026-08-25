/**
 * DIA-217 test harness (test-author lane, DIA-175 instance separation).
 *
 * Seam under test: the universal ticket gate in the delegation-observer
 * plugin's tool.execute.before hook. Every task() dispatch must resolve to a
 * valid ticket_id (DIA-\d+ format). Four scenarios:
 *   1. No field and no literal DIA ID -> blocked
 *   2. No field and one literal DIA ID -> materialized and proceeds
 *   3. ticket_id present, ticket found -> proceeds
 *   4. ticket_id present, ticket not found -> warns and proceeds
 *
 * The tests invoke the REAL plugin (dynamic import) and drive its
 * tool.execute.before path via mocked hook inputs, exactly like the
 * DIA-085/DIA-189 harness pattern. The only external module is
 * @opencode-ai/plugin: mocked before the plugin import (ESM hoisting).
 *
 * Hermetic: every harness gets a fresh mkdtemp workspace with a
 * .opencode/session/ directory. Tests that need a ticket file create a
 * minimal ticket in docs/dev-infra-audit/tickets/. The REAL tickets
 * directory is never touched.
 *
 * DIA-079: this file is ASCII-only (no em-dashes, no smart quotes).
 *
 * RUN COMMAND (verified on bun in the poetry-dev container):
 *   docker compose exec dev bash -lc \
 *     'cd /workspace/.opencode/plugins/__tests__ && \
 *      bun test dia217-ticket-gate.test.mjs'
 */
import { mock, test, expect } from "bun:test"
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
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
  const directory = mkdtempSync(join(tmpdir(), "dia217-tg-"))
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
 * Drive the real tool.execute.before hook with a task() call.
 * Returns { error?, registryRows } where error is the thrown Error (if any)
 * and registryRows are the rows appended to registry.jsonl during the call.
 */
async function runTaskDispatch(hooks, ctx, taskArgs) {
  const registryPath = join(ctx.directory, ".opencode/session/registry.jsonl")
  const rowsBefore = existsSync(registryPath)
    ? readFileSync(registryPath, "utf-8").trim().split("\n").filter(Boolean).length
    : 0

  let error = null
  try {
    await hooks["tool.execute.before"](
      {
        tool: "task",
        sessionID: "ses_dia217_test",
        callID: "call_dia217",
      },
      { args: taskArgs }
    )
  } catch (err) {
    error = err instanceof Error ? err : new Error(String(err))
  }

  // Read any new registry rows appended during the call.
  let newRows = []
  if (existsSync(registryPath)) {
    const allLines = readFileSync(registryPath, "utf-8").trim().split("\n").filter(Boolean)
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

async function runTaskDispatchWithCallID(hooks, ctx, taskArgs, callID) {
  let error = null
  try {
    await hooks["tool.execute.before"](
      {
        tool: "task",
        sessionID: "ses_dia217_retry",
        callID,
      },
      { args: taskArgs }
    )
  } catch (err) {
    error = err instanceof Error ? err : new Error(String(err))
  }
  return error
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test("DIA-217: dispatch without ticket_id -> blocked (gate_blocked + error)", async () => {
  const { hooks, ctx } = await makeHarness()

  const { error, registryRows } = await runTaskDispatch(hooks, ctx, {
    subagent_type: "coder",
    prompt: "implement something",
    description: "test dispatch without ticket",
  })

  // Must throw an error blocking the dispatch.
  expect(error).not.toBeNull()
  expect(error.message).toContain("DIA-217 GATE:")
  expect(error.message).toContain("requires an unambiguous governing DIA ticket ID")

  // Registry must carry a gate_blocked row.
  const blocked = registryRows.find((r) => r.event === "gate_blocked")
  expect(blocked).toBeDefined()
  expect(blocked.dispatch_state).toBe("gate_blocked")
  expect(blocked.session_id).toBe("ses_dia217_test")
  expect(blocked.subagent_type).toBe("coder")
})

test("DIA-260824-p3hf: literal DIA ID is materialized when native task schema omits ticket_id", async () => {
  const { hooks, ctx } = await makeHarness()
  const ticketsDir = join(ctx.directory, "docs/dev-infra-audit/tickets")
  mkdirSync(ticketsDir, { recursive: true })
  writeFileSync(
    join(ticketsDir, "DIA-260824-p3hf-schema-pass-through.md"),
    "---\nid: DIA-260824-p3hf\ntitle: Schema pass-through\nstatus: OPEN\n---\n"
  )
  const taskArgs = {
    subagent_type: "coder",
    prompt: "DIA-260824-p3hf. Verify the lane-0 checksum only.",
    description: "Lane-0 checksum verification",
  }

  const { error, registryRows } = await runTaskDispatch(hooks, ctx, taskArgs)

  expect(error).toBeNull()
  expect(taskArgs.ticket_id).toBe("DIA-260824-p3hf")
  expect(registryRows.find((row) => row.event === "gate_blocked")).toBeUndefined()
})

test("DIA-260824-p3hf: campaign ticket marker disambiguates reference DIA IDs", async () => {
  const { hooks, ctx } = await makeHarness()
  const taskArgs = {
    subagent_type: "coder",
    prompt:
      "LANE-0 CHECKSUM VERIFICATION (DIA-093 / DIA-120 / DIA-061) - campaign ticket DIA-260824-p3hf.",
    description: "Lane-0 checksum verification",
  }

  const { error } = await runTaskDispatch(hooks, ctx, taskArgs)

  expect(error).toBeNull()
  expect(taskArgs.ticket_id).toBe("DIA-260824-p3hf")
})

test("DIA-217: dispatch with invalid ticket_id format -> blocked", async () => {
  const { hooks, ctx } = await makeHarness()

  const { error, registryRows } = await runTaskDispatch(hooks, ctx, {
    subagent_type: "coder",
    prompt: "implement something",
    description: "test dispatch with bad format",
    ticket_id: "NOT-A-DIA-ID",
  })

  expect(error).not.toBeNull()
  expect(error.message).toContain("DIA-217 GATE:")
  expect(error.message).toContain("invalid ticket_id format")

  const blocked = registryRows.find((r) => r.event === "gate_blocked")
  expect(blocked).toBeDefined()
  expect(blocked.dispatch_state).toBe("gate_blocked")
  expect(blocked.ticket_id).toBe("NOT-A-DIA-ID")
})

test("DIA-217: dispatch with valid ticket_id, ticket found -> proceeds (no error)", async () => {
  const { hooks, ctx } = await makeHarness()

  // Create a minimal ticket file so the gate finds it.
  const ticketsDir = join(ctx.directory, "docs/dev-infra-audit/tickets")
  mkdirSync(ticketsDir, { recursive: true })
  writeFileSync(
    join(ticketsDir, "DIA-999-test-ticket.md"),
    "---\nid: DIA-999\ntitle: Test ticket\nstatus: OPEN\n---\n"
  )

  const { error, registryRows } = await runTaskDispatch(hooks, ctx, {
    subagent_type: "coder",
    prompt: "implement something",
    description: "test dispatch with valid ticket",
    ticket_id: "DIA-999",
  })

  // Must NOT throw.
  expect(error).toBeNull()

  // Must NOT have gate_blocked or gate_warn rows.
  const blocked = registryRows.find((r) => r.event === "gate_blocked")
  const warned = registryRows.find((r) => r.event === "gate_warn")
  expect(blocked).toBeUndefined()
  expect(warned).toBeUndefined()
})

test("DIA-217: dispatch with valid ticket_id, ticket not found -> warn (no error)", async () => {
  const { hooks, ctx } = await makeHarness()

  // No ticket file exists for DIA-888.
  const { error, registryRows } = await runTaskDispatch(hooks, ctx, {
    subagent_type: "coder",
    prompt: "implement something",
    description: "test dispatch with missing ticket",
    ticket_id: "DIA-888",
  })

  // Must NOT throw (warn only).
  expect(error).toBeNull()

  // Registry must carry a gate_warn row.
  const warned = registryRows.find((r) => r.event === "gate_warn")
  expect(warned).toBeDefined()
  expect(warned.ticket_id).toBe("DIA-888")
  expect(warned.session_id).toBe("ses_dia217_test")
})

test("DIA-217: ticket_id is case-insensitive for file lookup", async () => {
  const { hooks, ctx } = await makeHarness()

  // Create ticket with lowercase in filename.
  const ticketsDir = join(ctx.directory, "docs/dev-infra-audit/tickets")
  mkdirSync(ticketsDir, { recursive: true })
  writeFileSync(
    join(ticketsDir, "DIA-777-case-test.md"),
    "---\nid: DIA-777\ntitle: Case test\nstatus: OPEN\n---\n"
  )

  // Dispatch with uppercase ticket_id should still find the file.
  const { error } = await runTaskDispatch(hooks, ctx, {
    subagent_type: "coder",
    prompt: "implement something",
    description: "test case-insensitive lookup",
    ticket_id: "DIA-777",
  })

  expect(error).toBeNull()
})

test("DIA-260825-lro1: rejected preflight does not poison corrected retry", async () => {
  const { hooks, ctx } = await makeHarness()
  const dispatch = {
    subagent_type: "coder",
    prompt: "implement one bounded slice",
    description: "retry after corrected task arguments",
  }

  const rejected = await runTaskDispatchWithCallID(
    hooks,
    ctx,
    dispatch,
    "call_missing_ticket"
  )
  expect(rejected).not.toBeNull()
  expect(rejected.message).toContain("requires an unambiguous governing DIA ticket ID")

  const corrected = await runTaskDispatchWithCallID(
    hooks,
    ctx,
    { ...dispatch, ticket_id: "DIA-260825-lro1" },
    "call_corrected_retry"
  )
  expect(corrected).toBeNull()

  const duplicate = await runTaskDispatchWithCallID(
    hooks,
    ctx,
    { ...dispatch, ticket_id: "DIA-260825-lro1" },
    "call_true_duplicate"
  )
  expect(duplicate).not.toBeNull()
  expect(duplicate.message).toContain("Idempotent duplicate dispatch blocked")
})
