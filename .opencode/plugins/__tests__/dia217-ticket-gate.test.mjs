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
import { test, expect, afterEach } from "bun:test"
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { join } from "node:path"
import { createHmac, randomUUID } from "node:crypto"
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
const {
  mintCapabilityToken,
  CAPABILITY_SECRET,
} = await import("../delegation-observer.ts")

// ---------------------------------------------------------------------------
// Harness plumbing
// ---------------------------------------------------------------------------


function freshCtx() {
  const { directory, cleanup } = createTempWorkspace("dia217-tg-")
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
  const ticketsDir = join(ctx.directory, "docs/dev-infra-audit/tickets")
  mkdirSync(ticketsDir, { recursive: true })
  writeFileSync(
    join(ticketsDir, "DIA-260824-p3hf-campaign-marker.md"),
    "---\nid: DIA-260824-p3hf\ntitle: Campaign marker\nstatus: OPEN\n---\n"
  )
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

test("DIA-260827-mgfv: dispatch with valid ticket_id, ticket not found -> FAIL CLOSED (blocked)", async () => {
  const { hooks, ctx } = await makeHarness()

  // No ticket file exists for DIA-888.
  const { error, registryRows } = await runTaskDispatch(hooks, ctx, {
    subagent_type: "coder",
    prompt: "implement something",
    description: "test dispatch with missing ticket",
    ticket_id: "DIA-888",
  })

  // Fabricated id must hard-block the dispatch (no warn-and-allow).
  expect(error).not.toBeNull()
  expect(error.message).toContain("DIA-217 GATE:")
  const blocked = registryRows.find((r) => r.event === "gate_blocked")
  expect(blocked).toBeDefined()
  expect(blocked.ticket_id).toBe("DIA-888")
  expect(registryRows.find((r) => r.event === "gate_warn")).toBeUndefined()
})

test("DIA-260827-mgfv: dispatch referencing a CLOSED ticket -> FAIL CLOSED (blocked)", async () => {
  const { hooks, ctx } = await makeHarness()

  const ticketsDir = join(ctx.directory, "docs/dev-infra-audit/tickets")
  mkdirSync(ticketsDir, { recursive: true })
  writeFileSync(
    join(ticketsDir, "DIA-888-closed-ticket.md"),
    "---\nid: DIA-888\ntitle: Closed ticket\nstatus: CLOSED\n---\n"
  )

  const { error, registryRows } = await runTaskDispatch(hooks, ctx, {
    subagent_type: "coder",
    prompt: "implement something",
    description: "test dispatch with closed ticket",
    ticket_id: "DIA-888",
  })

  // Non-OPEN ticket must hard-block the dispatch.
  expect(error).not.toBeNull()
  expect(error.message).toContain("DIA-217 GATE:")
  const blocked = registryRows.find((r) => r.event === "gate_blocked")
  expect(blocked).toBeDefined()
  expect(blocked.ticket_id).toBe("DIA-888")
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
  const ticketsDir = join(ctx.directory, "docs/dev-infra-audit/tickets")
  mkdirSync(ticketsDir, { recursive: true })
  writeFileSync(
    join(ticketsDir, "DIA-260825-lro1-retry.md"),
    "---\nid: DIA-260825-lro1\ntitle: Retry slice\nstatus: OPEN\n---\n"
  )
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

test("DIA-260826-pjm: datetime-format ticket file is recognized by the gate with its FULL id (no warn-and-allow truncation)", async () => {
  const { hooks, ctx } = await makeHarness()

  // Datetime-format ticket (DIA-234): DIA-YYMMDD-lowercase-suffix. The gate
  // must resolve the FULL id against this file - truncating to DIA-260825
  // would miss the file and degrade to the weak-correlation warn path.
  const ticketsDir = join(ctx.directory, "docs/dev-infra-audit/tickets")
  mkdirSync(ticketsDir, { recursive: true })
  writeFileSync(
    join(ticketsDir, "DIA-260825-test-datetime-gate-recognition.md"),
    "---\nid: DIA-260825-test\ntitle: Datetime gate recognition\nstatus: OPEN\n---\n"
  )

  const taskArgs = {
    subagent_type: "coder",
    prompt: "campaign ticket DIA-260825-test. Implement one bounded slice.",
    description: "Datetime-format gate recognition",
  }

  const { error, registryRows } = await runTaskDispatch(hooks, ctx, taskArgs)

  expect(error).toBeNull()
  // Materialized id must be the FULL datetime id, never DIA-260825.
  expect(taskArgs.ticket_id).toBe("DIA-260825-test")
  expect(registryRows.find((row) => row.event === "gate_blocked")).toBeUndefined()
  expect(registryRows.find((row) => row.event === "gate_warn")).toBeUndefined()
})

test("DIA-260826-pjm F1: datetime ticket correlates through section-10 Path 1 regardless of citation case (no hard block)", async () => {
  const { hooks, ctx } = await makeHarness()

  // Lowercase-suffix datetime ticket file (generator emits lowercase).
  const ticketsDir = join(ctx.directory, "docs/dev-infra-audit/tickets")
  mkdirSync(ticketsDir, { recursive: true })
  writeFileSync(
    join(ticketsDir, "DIA-260825-abcd-case-correlation.md"),
    "---\nid: DIA-260825-abcd\ntitle: Case correlation\nstatus: OPEN\n---\n"
  )

  // subagent_type ai-specialist arms the section-10 scope gate; text avoids
  // checksum phrases (exemption) and config paths (routing gate). The
  // dispatch cites the ticket in BOTH cases: canonical lowercase, plus an
  // uppercased variant (diaIds arrive UPPERCASED from the free-text scan at
  // the correlation site). Pre-fix this hard-blocked: diaIds were uppercased
  // while ScannedTicket.id kept raw filename case, so Path-1 includes()
  // missed every letter-suffix datetime citation. The uppercase variant
  // itself degrades to its digit prefix in extraction (pinned in
  // dia-ticket-id-parser.test.mjs F5a) - correlation must succeed via the
  // canonical lowercase citation either way.
  const taskArgs = {
    subagent_type: "ai-specialist",
    prompt:
      "Research gate options. Canonical ref: campaign ticket DIA-260825-abcd (uppercased in ledgers as DIA-260825-ABCD).",
    description: "Section-10 Path-1 case correlation",
    ticket_id: "DIA-260825-abcd",
  }

  const { error, registryRows } = await runTaskDispatch(hooks, ctx, taskArgs)

  // Unfixed behavior was a hard throw ("§10 TICKET GATE: No correlating DIA
  // ticket found") plus a ticket_gate_blocked row. Fixed: silent pass.
  expect(error).toBeNull()
  expect(registryRows.find((r) => r.event === "ticket_gate_blocked")).toBeUndefined()
  expect(registryRows.find((r) => r.event === "gate_blocked")).toBeUndefined()
  expect(registryRows.find((r) => r.event === "gate_warn")).toBeUndefined()
})

// ---------------------------------------------------------------------------
// DIA-260820-jlu0 carve-out, narrowed by DIA-260831-h3i4 F3: ONLY the
// literal `scripts/tickets new` invocation bypasses without a ticket_id.
// ---------------------------------------------------------------------------

test("DIA-260820-jlu0: 'scripts/tickets new' in dispatch bypasses gate without ticket_id", async () => {
  const { hooks, ctx } = await makeHarness()
  const taskArgs = {
    subagent_type: "coder",
    prompt: "Run scripts/tickets new --title 'New campaign ticket' to create it.",
    description: "Create the campaign ticket",
  }
  const { error, registryRows } = await runTaskDispatch(hooks, ctx, taskArgs)
  expect(error).toBeNull()
  expect(registryRows.find((r) => r.event === "meta_task_bypass")).toBeDefined()
  expect(registryRows.find((r) => r.event === "gate_blocked")).toBeUndefined()
  expect(taskArgs.ticket_id).toBeUndefined()
})

test("DIA-260831-h3i4: bare [META-TASK] marker without procedural signal is BLOCKED (no ticket_id)", async () => {
  const { hooks, ctx } = await makeHarness()
  const taskArgs = {
    subagent_type: "coder",
    prompt: "[META-TASK] bootstrap the new lane",
    description: "meta task bootstrap",
  }
  const { error, registryRows } = await runTaskDispatch(hooks, ctx, taskArgs)
  expect(error).not.toBeNull()
  expect(error.message).toContain("DIA-217 GATE:")
  expect(registryRows.find((r) => r.event === "gate_blocked")).toBeDefined()
  expect(registryRows.find((r) => r.event === "meta_task_bypass")).toBeUndefined()
})

test("DIA-260831-h3i4 F3: natural-language 'create ticket' / 'procedural authorization' NO LONGER bypass (blocked without ticket)", async () => {
  const cases = [
    "Please create ticket for the new campaign.",
    "procedural authorization to apply the recommendation.",
  ]
  for (const prompt of cases) {
    const { hooks, ctx } = await makeHarness()
    const taskArgs = { subagent_type: "coder", prompt, description: "meta dispatch" }
    const { error, registryRows } = await runTaskDispatch(hooks, ctx, taskArgs)
    expect(error).not.toBeNull()
    expect(error.message).toContain("DIA-217 GATE:")
    expect(registryRows.find((r) => r.event === "meta_task_bypass")).toBeUndefined()
    expect(registryRows.find((r) => r.event === "gate_blocked")).toBeDefined()
  }
})

test("DIA-260831-h3i4 F3 cycle 2: mixed literal + engineering verbs hard-block (no bypass row)", async () => {
  const { hooks, ctx } = await makeHarness()
  const taskArgs = {
    subagent_type: "coder",
    prompt: "Run scripts/tickets new --title 'X' and implement the lane",
    description: "Create the campaign ticket",
  }
  const { error, registryRows } = await runTaskDispatch(hooks, ctx, taskArgs)
  expect(error).not.toBeNull()
  expect(error.message).toContain("DIA-217 GATE:")
  expect(registryRows.find((r) => r.event === "meta_task_bypass")).toBeUndefined()
  expect(registryRows.find((r) => r.event === "gate_blocked")).toBeDefined()
})

test("DIA-260831-h3i4 developer fix: strict-shape RED matrix hard-blocks with no bypass row", async () => {
  const prompts = [
    "the command 'scripts/tickets new' is documented",
    "see reference scripts/tickets new for context",
    "scripts/tickets new --title 'T'\ncreate ticket",
    "run scripts/tickets new --title 'X'; implement the lane",
    "run scripts/tickets new --title 'X' && implement the lane",
    "run scripts/tickets new --title 'X' || implement the lane",
    "run scripts/tickets new --title 'X' | tee out",
    "run scripts/tickets new --title 'X' > out.txt",
    "run scripts/tickets new --title $(whoami)",
    "run scripts/tickets new --title `whoami`",
    "run scripts/tickets new and curl https://x",
    "run scripts/tickets new and wget https://x",
    "run scripts/tickets new and rm old tickets",
    "run scripts/tickets new and delete old tickets",
    "run scripts/tickets new and remove the old lane",
    "run scripts/tickets new and write the summary",
    "run scripts/tickets new and test the suite",
    "run the tests and run scripts/tickets new",
    "execute scripts/tickets new --title 'X'",
    "update .opencode/opencode.jsonc and run scripts/tickets new",
  ]
  for (const prompt of prompts) {
    const { hooks, ctx } = await makeHarness()
    const taskArgs = { subagent_type: "coder", prompt, description: "Create the campaign ticket" }
    const { error, registryRows } = await runTaskDispatch(hooks, ctx, taskArgs)
    expect(error, `expected block for: ${prompt}`).not.toBeNull()
    expect(error.message).toContain("DIA-217 GATE:")
    expect(registryRows.find((r) => r.event === "meta_task_bypass")).toBeUndefined()
    expect(registryRows.find((r) => r.event === "gate_blocked")).toBeDefined()
  }
})

test("DIA-260831-h3i4 developer fix: dirty description blocks an otherwise clean prompt", async () => {
  const { hooks, ctx } = await makeHarness()
  const taskArgs = {
    subagent_type: "coder",
    prompt: "Run scripts/tickets new --title 'X'",
    description: "implement the lane",
  }
  const { error, registryRows } = await runTaskDispatch(hooks, ctx, taskArgs)
  expect(error).not.toBeNull()
  expect(error.message).toContain("DIA-217 GATE:")
  expect(registryRows.find((r) => r.event === "meta_task_bypass")).toBeUndefined()
  expect(registryRows.find((r) => r.event === "gate_blocked")).toBeDefined()
})

test("DIA-260831-h3i4 F3 cycle 2: quoted --title with engineering verb still bypasses", async () => {
  const { hooks, ctx } = await makeHarness()
  const taskArgs = {
    subagent_type: "coder",
    prompt: "Run scripts/tickets new --title 'Fix login bug' to create it.",
    description: "Create the campaign ticket",
  }
  const { error, registryRows } = await runTaskDispatch(hooks, ctx, taskArgs)
  expect(error).toBeNull()
  expect(registryRows.find((r) => r.event === "meta_task_bypass")).toBeDefined()
  expect(registryRows.find((r) => r.event === "gate_blocked")).toBeUndefined()
  expect(taskArgs.ticket_id).toBeUndefined()
})

test("DIA-260831-h3i4 F3 cycle 2: verified closed-ticket bookkeeping pair bypasses", async () => {
  const { hooks, ctx } = await makeHarness()
  const taskArgs = {
    subagent_type: "coder",
    prompt: "bookkeeping for closed ticket DIA-260820-jlu0",
    description: "confirmed closed-ticket rollup",
  }
  const { error, registryRows } = await runTaskDispatch(hooks, ctx, taskArgs)
  expect(error).toBeNull()
  expect(registryRows.find((r) => r.event === "meta_task_bypass")).toBeDefined()
  expect(registryRows.find((r) => r.event === "gate_blocked")).toBeUndefined()
})
test("DIA-260831-h3i4 F3: mixed engineering + natural-language phrasing is BLOCKED", async () => {
  const { hooks, ctx } = await makeHarness()
  const taskArgs = {
    subagent_type: "coder",
    prompt: "implement the new lane and create ticket for tracking the rollout",
    description: "mixed engineering and procedural phrasing",
  }
  const { error, registryRows } = await runTaskDispatch(hooks, ctx, taskArgs)
  expect(error).not.toBeNull()
  expect(error.message).toContain("DIA-217 GATE:")
  expect(registryRows.find((r) => r.event === "meta_task_bypass")).toBeUndefined()
  expect(registryRows.find((r) => r.event === "gate_blocked")).toBeDefined()
})

test("DIA-260831-h3i4: bare 'meta-task' housekeeping text without procedural signal is BLOCKED", async () => {
  const { hooks, ctx } = await makeHarness()
  const taskArgs = {
    subagent_type: "coder",
    prompt: "This is a meta-task for housekeeping.",
    description: "meta dispatch",
  }
  const { error, registryRows } = await runTaskDispatch(hooks, ctx, taskArgs)
  expect(error).not.toBeNull()
  expect(error.message).toContain("DIA-217 GATE:")
  expect(registryRows.find((r) => r.event === "gate_blocked")).toBeDefined()
  expect(registryRows.find((r) => r.event === "meta_task_bypass")).toBeUndefined()
})

test("DIA-260831-h3i4 F3: case-insensitive literal STILL bypasses - 'Run SCRIPTS/TICKETS NEW now'", async () => {
  const { hooks, ctx } = await makeHarness()
  const taskArgs = {
    subagent_type: "coder",
    prompt: "Run SCRIPTS/TICKETS NEW --title 'New campaign ticket' now.",
    description: "Create the campaign ticket",
  }
  const { error, registryRows } = await runTaskDispatch(hooks, ctx, taskArgs)
  expect(error).toBeNull()
  expect(registryRows.find((r) => r.event === "meta_task_bypass")).toBeDefined()
  expect(registryRows.find((r) => r.event === "gate_blocked")).toBeUndefined()
})

test("DIA-260831-h3i4 F3: capitalized natural language does NOT bypass - 'Create Ticket' blocked", async () => {
  const { hooks, ctx } = await makeHarness()
  const taskArgs = {
    subagent_type: "coder",
    prompt: "Please Create Ticket for the new campaign.",
    description: "meta dispatch capitalized",
  }
  const { error, registryRows } = await runTaskDispatch(hooks, ctx, taskArgs)
  expect(error).not.toBeNull()
  expect(error.message).toContain("DIA-217 GATE:")
  expect(registryRows.find((r) => r.event === "meta_task_bypass")).toBeUndefined()
  expect(registryRows.find((r) => r.event === "gate_blocked")).toBeDefined()
})

test("DIA-260820-jlu0: carve-out returns BEFORE ticket_id resolution (stray DIA id not attributed)", async () => {
  const { hooks, ctx } = await makeHarness()
  const taskArgs = {
    subagent_type: "coder",
    prompt: "[META-TASK] run scripts/tickets new --title 'T' with reference DIA-260820-jlu0 for context.",
    description: "Create the campaign ticket",
  }
  const { error, registryRows } = await runTaskDispatch(hooks, ctx, taskArgs)
  expect(error).toBeNull()
  // No attribution to the stray literal id in the text.
  expect(taskArgs.ticket_id).toBeUndefined()
  expect(registryRows.find((r) => r.event === "gate_blocked")).toBeUndefined()
  expect(registryRows.find((r) => r.event === "gate_warn")).toBeUndefined()
  expect(registryRows.find((r) => r.event === "meta_task_bypass")).toBeDefined()
})

test("DIA-260820-jlu0: normal dispatch with no whitelist signal and no ticket_id still hard-blocked", async () => {
  const { hooks, ctx } = await makeHarness()
  const taskArgs = {
    subagent_type: "coder",
    prompt: "implement something ordinary",
    description: "no meta signal, no ticket",
  }
  const { error, registryRows } = await runTaskDispatch(hooks, ctx, taskArgs)
  expect(error).not.toBeNull()
  expect(error.message).toContain("DIA-217 GATE:")
  expect(registryRows.find((r) => r.event === "gate_blocked")).toBeDefined()
  expect(registryRows.find((r) => r.event === "meta_task_bypass")).toBeUndefined()
})

test("DIA-260831-h3i4: [META-TASK] marker on config-work is stopped at DIA-217 (marker never authorizes engineering)", async () => {
  const { hooks, ctx } = await makeHarness()
  // Marker-only config-work dispatch carries no procedural signal and no
  // ticket, so DIA-217 hard-blocks it before any routing gate is reached.
  const taskArgs = {
    subagent_type: "coder",
    prompt: "[META-TASK] update .opencode/plugins/delegation-observer.ts",
    description: "meta task touching config-work",
  }
  const { error, registryRows } = await runTaskDispatch(hooks, ctx, taskArgs)
  expect(error).not.toBeNull()
  expect(error.message).toContain("DIA-217 GATE:")
  expect(registryRows.find((r) => r.event === "gate_blocked")).toBeDefined()
  expect(registryRows.find((r) => r.event === "meta_task_bypass")).toBeUndefined()
})

test("DIA-260831-h3i4: marker-only dispatch citing an unresolved ticket is stopped at DIA-217 (explicit id, no OPEN match)", async () => {
  const { hooks, ctx } = await makeHarness()
  const ticketsDir = join(ctx.directory, "docs/dev-infra-audit/tickets")
  mkdirSync(ticketsDir, { recursive: true })
  const taskArgs = {
    subagent_type: "ai-specialist",
    prompt: "[META-TASK] review config; see DIA-260820-jlu0 for context.",
    description: "meta-task config review",
  }
  const { error, registryRows } = await runTaskDispatch(hooks, ctx, taskArgs)
  expect(error).not.toBeNull()
  expect(error.message).toContain("DIA-217 GATE:")
  expect(registryRows.find((r) => r.event === "gate_blocked")).toBeDefined()
  expect(registryRows.find((r) => r.event === "meta_task_bypass")).toBeUndefined()
})

// ---------------------------------------------------------------------------
// DIA-260820-jlu0 B1: capability-token scope tightening (REAL hook path)
// ---------------------------------------------------------------------------
// Driven through the actual gate (not a replica): mintCapabilityToken and
// CAPABILITY_SECRET are exported from the plugin so we can mint a validly-
// signed token WITHOUT a scope and assert the REAL gate rejects it.
function forgeCapabilityToken(payload) {
  const payloadB64 = Buffer.from(JSON.stringify(payload)).toString("base64url")
  const sig = Buffer.from(
    createHmac("sha256", CAPABILITY_SECRET).update(payloadB64).digest()
  ).toString("base64url")
  return `CAP-${payloadB64}.${sig}`
}

test("DIA-260820-jlu0 B1: valid capability token (real mint) bypasses the REAL gate", async () => {
  const { hooks, ctx } = await makeHarness()
  const token = mintCapabilityToken("ticket-creation", "test")
  const taskArgs = {
    subagent_type: "coder",
    prompt: `Apply the recommendation via [CAPABILITY: ${token}]`,
    description: "capability bypass dispatch",
  }
  const { error, registryRows } = await runTaskDispatch(hooks, ctx, taskArgs)
  expect(error).toBeNull()
  expect(registryRows.find((r) => r.event === "capability_used")).toBeDefined()
  expect(registryRows.find((r) => r.event === "gate_blocked")).toBeUndefined()
})

test("DIA-260820-jlu0 B1: validly-signed token WITHOUT scope is rejected by the REAL gate", async () => {
  const { hooks, ctx } = await makeHarness()
  // Forge a token with a valid HMAC (real secret) but no `scope` in the payload.
  const noScopeToken = forgeCapabilityToken({
    id: randomUUID(),
    reason: "test",
    exp: Date.now() + 5 * 60 * 1000,
  })
  const taskArgs = {
    subagent_type: "coder",
    prompt: `Apply via [CAPABILITY: ${noScopeToken}]`,
    description: "scope-leak attempt",
  }
  const { error, registryRows } = await runTaskDispatch(hooks, ctx, taskArgs)
  expect(error).not.toBeNull()
  expect(error.message).toContain("Capability token invalid")
  expect(registryRows.find((r) => r.event === "capability_used")).toBeUndefined()
})