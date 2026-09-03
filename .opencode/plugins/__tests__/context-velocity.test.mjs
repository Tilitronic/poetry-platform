/**
 * DIA-219 test harness (test-author lane, DIA-175 instance separation).
 *
 * Seam under test: the context_usage tool's velocity tracking in
 * delegation-observer. Tests the delta computation (velocity_percent_per_cycle)
 * and the crisis (>15%/cycle) / emergency (>25%/cycle) event thresholds.
 *
 * The tests invoke the REAL plugin (dynamic import) and drive its
 * context_usage tool via mocked hook inputs, following the DIA-218 harness
 * pattern.
 *
 * Hermetic: every harness gets a fresh mkdtemp workspace. No real
 * project files are touched.
 *
 * DIA-079: this file is ASCII-only (no em-dashes, no smart quotes).
 *
 * RUN COMMAND (verified on bun in the poetry-dev container):
 *   docker compose exec dev bash -lc \
 *     'cd /workspace/.opencode/plugins/__tests__ && \
 *      bun test context-velocity.test.mjs'
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
  const directory = mkdtempSync(join(tmpdir(), "dia219-vel-"))
  tempDirs.push(directory)
  mkdirSync(join(directory, ".opencode", "session"), { recursive: true })
  return {
    directory,
    client: { app: { log: async () => {} } },
  }
}

/**
 * Build a mock session.messages response with a single assistant message
 * carrying the given token counts. provider.list() returns a provider with
 * a 1M context window.
 */
function mockSessionMessages(directTokens) {
  return async () => ({
    data: [
      {
        info: {
          role: "assistant",
          providerID: "test-provider",
          modelID: "test-model",
          tokens: {
            input: directTokens.input ?? 0,
            output: directTokens.output ?? 0,
            reasoning: directTokens.reasoning ?? 0,
            cache: {
              read: directTokens.cacheRead ?? 0,
              write: directTokens.cacheWrite ?? 0,
            },
          },
        },
      },
    ],
  })
}

function mockProviderList() {
  return async () => ({
    data: {
      all: [
        {
          id: "test-provider",
          models: {
            "test-model": {
              limit: { context: 1_000_000 },
            },
          },
        },
      ],
    },
  })
}

async function makeHarness(sessionMessagesMock, providerListMock) {
  const ctx = freshCtx()
  const hooks = await createDelegationObserver(ctx)

  // Wire up client mocks after plugin creation so the plugin's own
  // boot-time calls (session.messages for compaction, etc.) don't need them.
  ctx.client.session = { messages: sessionMessagesMock ?? (async () => ({ data: [] })) }
  ctx.client.provider = { list: providerListMock ?? mockProviderList() }

  return { hooks, ctx }
}

/**
 * Drive the context_usage tool and return the parsed JSON result.
 */
async function callContextUsage(hooks, { scope, sessionID }) {
  const result = await hooks.tool.context_usage.execute(
    { scope: scope ?? "session" },
    { sessionID: sessionID ?? "ses_velocity_test" }
  )
  return JSON.parse(result)
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

describe("DIA-219 Context Velocity Tracking", () => {
  test("first call returns velocity_percent_per_cycle = 0 (no prior measurement)", async () => {
    // Small token count -> low usage.
    const msgs = mockSessionMessages({ input: 10000, output: 5000 })
    const { hooks } = await makeHarness(msgs)

    const result = await callContextUsage(hooks, { sessionID: "ses_vel_first" })

    expect(result.velocity_percent_per_cycle).toBe(0)
    expect(result.velocity_crisis).toBe(false)
    expect(result.velocity_emergency).toBe(false)
  })

  test("small consecutive reads stay below crisis threshold", async () => {
    const sessionID = "ses_vel_small"
    // First call: 10K tokens -> 1% usage.
    const msgs1 = mockSessionMessages({ input: 10000, output: 0 })
    const { hooks, ctx } = await makeHarness(msgs1)

    const r1 = await callContextUsage(hooks, { sessionID })
    expect(r1.velocity_percent_per_cycle).toBe(0) // first call

    // Second call: 20K tokens -> 2% usage. Delta = 1%.
    ctx.client.session.messages = mockSessionMessages({ input: 20000, output: 0 })
    const r2 = await callContextUsage(hooks, { sessionID })
    expect(r2.velocity_percent_per_cycle).toBe(1)
    expect(r2.velocity_crisis).toBe(false)
    expect(r2.velocity_emergency).toBe(false)
  })

  test("large jump triggers crisis event (>15% per cycle)", async () => {
    const sessionID = "ses_vel_crisis"

    // First call: 10K tokens -> 1% usage.
    const msgs1 = mockSessionMessages({ input: 10000, output: 0 })
    const { hooks, ctx } = await makeHarness(msgs1)
    const rowsStart = countRows(ctx)

    await callContextUsage(hooks, { sessionID })

    // Second call: 200K tokens -> 20% usage. Delta = 19% (crisis).
    ctx.client.session.messages = mockSessionMessages({ input: 200000, output: 0 })
    const r2 = await callContextUsage(hooks, { sessionID })

    expect(r2.velocity_percent_per_cycle).toBe(19)
    expect(r2.velocity_crisis).toBe(true)
    expect(r2.velocity_emergency).toBe(false)

    // Check registry for context_crisis event.
    const newRows = readNewRows(ctx, rowsStart)
    const crisisRow = newRows.find((r) => r.event === "context_crisis")
    expect(crisisRow).toBeDefined()
    expect(crisisRow.session_id).toBe(sessionID)
    expect(crisisRow.velocity_pct).toBe(19)
  })

  test("massive jump triggers emergency event (>25% per cycle)", async () => {
    const sessionID = "ses_vel_emergency"

    // First call: 10K tokens -> 1% usage.
    const msgs1 = mockSessionMessages({ input: 10000, output: 0 })
    const { hooks, ctx } = await makeHarness(msgs1)
    const rowsStart = countRows(ctx)

    await callContextUsage(hooks, { sessionID })

    // Second call: 300K tokens -> 30% usage. Delta = 29% (emergency).
    ctx.client.session.messages = mockSessionMessages({ input: 300000, output: 0 })
    const r2 = await callContextUsage(hooks, { sessionID })

    expect(r2.velocity_percent_per_cycle).toBe(29)
    expect(r2.velocity_crisis).toBe(true) // emergency implies crisis
    expect(r2.velocity_emergency).toBe(true)

    // Check registry for context_emergency event.
    const newRows = readNewRows(ctx, rowsStart)
    const emergencyRow = newRows.find((r) => r.event === "context_emergency")
    expect(emergencyRow).toBeDefined()
    expect(emergencyRow.session_id).toBe(sessionID)
    expect(emergencyRow.velocity_pct).toBe(29)
  })

  test("velocity is tracked per session - different sessions are independent", async () => {
    const sessionA = "ses_vel_indep_a"
    const sessionB = "ses_vel_indep_b"

    // First call for session A: 10K tokens.
    const msgs1 = mockSessionMessages({ input: 10000, output: 0 })
    const { hooks, ctx } = await makeHarness(msgs1)

    await callContextUsage(hooks, { sessionID: sessionA })

    // Second call for session B (different session): also 10K tokens.
    // Should have velocity 0 (first call for B), not depend on A's state.
    const r2 = await callContextUsage(hooks, { sessionID: sessionB })
    expect(r2.velocity_percent_per_cycle).toBe(0)

    // Session A second call: 200K tokens -> crisis.
    ctx.client.session.messages = mockSessionMessages({ input: 200000, output: 0 })
    const rA2 = await callContextUsage(hooks, { sessionID: sessionA })
    expect(rA2.velocity_crisis).toBe(true)

    // Session B still independent - third call: 20K tokens -> small delta.
    ctx.client.session.messages = mockSessionMessages({ input: 20000, output: 0 })
    const rB2 = await callContextUsage(hooks, { sessionID: sessionB })
    expect(rB2.velocity_crisis).toBe(false)
  })

  test("velocity resets on plugin restart (non-persistent by design)", async () => {
    const sessionID = "ses_vel_restart"

    // First plugin instance: build up some usage.
    const msgs1 = mockSessionMessages({ input: 200000, output: 0 })
    const { hooks: hooks1 } = await makeHarness(msgs1)
    await callContextUsage(hooks1, { sessionID })

    // Second plugin instance (simulates restart): fresh memory.
    const msgs2 = mockSessionMessages({ input: 200000, output: 0 })
    const { hooks: hooks2 } = await makeHarness(msgs2)
    const r = await callContextUsage(hooks2, { sessionID })

    // First call on fresh plugin: velocity should be 0 (no prior measurement).
    expect(r.velocity_percent_per_cycle).toBe(0)
  })
})
