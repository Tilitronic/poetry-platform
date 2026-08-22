/**
 * DIA-260822-medh RED-phase test harness (test-author lane, DIA-175 instance
 * separation). RED ONLY: these tests MUST fail until a separate GREEN coder
 * implements the adaptive session-compaction policy in
 * .opencode/plugins/delegation-observer.ts.
 *
 * Seam under test: the adaptive context-management policy (spec
 * openspec/changes/adaptive-session-compaction/specs/context-management-policy/
 * spec.md). The policy is driven by an OpenCode session lifecycle event and
 * measures context via the SAME token-accurate path the context_usage tool
 * uses (context_usage.usage_fraction). It emits semantic events to
 * registry.jsonl and shows the user advisory messages via ctx.client.app.log.
 *
 * Contract (resolves design.md open question "session.status vs
 * session.updated"): the policy is wired into the plugin's generic `event`
 * catch-all hook as a new `case`. The driver below fires `session.status`
 * and, only if that produces no policy effect, falls back to `session.updated`
 * -- so the GREEN coder may register the policy under EITHER event type
 * without this harness double-firing or failing. The driver passes both
 * `properties.sessionID` and `properties.info.id` so the policy can read the
 * session id from whichever shape OpenCode delivers.
 *
 * Observable assertions (faithful to spec, not over-constrained on wording):
 *   - registry.jsonl rows with event in
 *     {context-warning-60, context-compact-85, context-new-session-post-compact,
 *      context-policy-error}
 *   - ctx.client.app.log was called (proves a user message was shown)
 *
 * Hermetic: every harness gets a fresh mkdtemp workspace. No real project
 * files are touched.
 *
 * DIA-079: this file is ASCII-only (no em-dashes, no smart quotes).
 *
 * RUN COMMAND (verified on bun in the poetry-dev container):
 *   docker compose exec dev bash -lc \
 *     'cd /workspace/.opencode/plugins/__tests__ && \
 *      bun test adaptive-session-compaction.test.mjs'
 */

import { mock, test, expect, describe } from "bun:test"
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

// Policy event names (contract from spec.md / proposal.md Data section).
const POLICY_EVENTS = new Set([
  "context-warning-60",
  "context-compact-85",
  "context-new-session-post-compact",
  "context-policy-error",
])

function freshCtx() {
  const directory = mkdtempSync(join(tmpdir(), "dia260822-asc-"))
  tempDirs.push(directory)
  mkdirSync(join(directory, ".opencode", "session"), { recursive: true })
  const logs = []
  return {
    directory,
    logs,
    client: {
      app: {
        // TUI-safe recorder: captures every user-facing advisory message.
        log: async (entry) => {
          logs.push(entry)
        },
      },
    },
  }
}

/**
 * Build a mock session.messages response with a single assistant message
 * carrying the given token counts. provider.list() returns a provider with
 * a 1M context window, so usage_fraction = totalTokens / 1_000_000.
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

async function makeHarness(sessionMessagesMock, providerListMock, { seedRegistry } = {}) {
  const ctx = freshCtx()
  if (seedRegistry) {
    // Pre-populate registry.jsonl so boot seeding can reconstruct state.
    writeFileSync(
      join(ctx.directory, ".opencode/session/registry.jsonl"),
      seedRegistry.map((row) => JSON.stringify(row)).join("\n") + "\n"
    )
  }
  const hooks = await createDelegationObserver(ctx)
  // Wire up client mocks after plugin creation so the plugin's own boot-time
  // calls don't need them.
  ctx.client.session = { messages: sessionMessagesMock ?? (async () => ({ data: [] })) }
  ctx.client.provider = { list: providerListMock ?? mockProviderList() }
  return { hooks, ctx }
}

/**
 * Drive the policy via the session lifecycle event. Resilient to the
 * session.status vs session.updated choice: fire session.status; if it
 * produces no policy event, fire session.updated instead. Never fires both.
 */
async function drivePolicy(hooks, ctx, sessionID) {
  const candidates = ["session.status", "session.updated"]
  for (const type of candidates) {
    const before = countPolicyRows(ctx)
    await hooks.event({
      event: {
        type,
        properties: { sessionID, info: { id: sessionID } },
      },
    })
    if (countPolicyRows(ctx) > before) return type
  }
  return null
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

function countPolicyRows(ctx) {
  return readNewRows(ctx, 0).filter((r) => POLICY_EVENTS.has(r.event)).length
}

function policyRows(ctx, rowsBefore) {
  return readNewRows(ctx, rowsBefore).filter((r) => POLICY_EVENTS.has(r.event))
}

// Token counts that produce a given usage fraction against a 1M window.
function tokensForFraction(frac) {
  const total = Math.round(frac * 1_000_000)
  return { input: total, output: 0, reasoning: 0, cacheRead: 0, cacheWrite: 0 }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("DIA-260822-medh Adaptive Session Compaction Policy (RED)", () => {
  // 1. Token-accurate shared async measurement path.
  test("measures token-accurately via the context_usage path on session status update", async () => {
    const sessionID = "ses_measure_shared"
    // 70% usage: 700K tokens / 1M window. If the policy used the broken
    // getContextPressure() (returns 0) this would NOT cross 60%.
    const msgs = mockSessionMessages(tokensForFraction(0.70))
    const { hooks, ctx } = await makeHarness(msgs)

    const rowsBefore = countRows(ctx)
    await drivePolicy(hooks, ctx, sessionID)

    const rows = policyRows(ctx, rowsBefore)
    const warnRow = rows.find((r) => r.event === "context-warning-60")
    // Token-accurate: 70% crosses the 60% threshold, so the warning fires.
    expect(warnRow).toBeDefined()

    // Shared path: the context_usage tool, given the SAME mocked session,
    // reports the same ~0.70 usage_fraction. Agreement proves the policy
    // reuses the token-accurate measurement, not a separate proxy.
    const toolResult = JSON.parse(
      await hooks.tool.context_usage.execute(
        { scope: "session" },
        { sessionID }
      )
    )
    expect(Math.abs(toolResult.usage_fraction - 0.70)).toBeLessThan(0.01)
  })

  // 2. Rate-limited upward 60% warning.
  test("60% warning is rate-limited: re-warns only after a drop and re-cross", async () => {
    const sessionID = "ses_rate_limit_60"
    const { hooks, ctx } = await makeHarness(mockSessionMessages(tokensForFraction(0.50)))

    const rowsBefore = countRows(ctx)

    // Prime below threshold (no warning).
    await drivePolicy(hooks, ctx, sessionID)
    // First upward crossing of 60% -> warning.
    ctx.client.session.messages = mockSessionMessages(tokensForFraction(0.70))
    await drivePolicy(hooks, ctx, sessionID)
    // Still >60% (no drop) -> no second warning.
    ctx.client.session.messages = mockSessionMessages(tokensForFraction(0.75))
    await drivePolicy(hooks, ctx, sessionID)
    // Drop to <=60% -> resets the rate limit (no event, but state clears).
    ctx.client.session.messages = mockSessionMessages(tokensForFraction(0.50))
    await drivePolicy(hooks, ctx, sessionID)
    // Re-cross >60% -> warning fires again (rate limit reset).
    ctx.client.session.messages = mockSessionMessages(tokensForFraction(0.70))
    await drivePolicy(hooks, ctx, sessionID)

    const warns = policyRows(ctx, rowsBefore).filter(
      (r) => r.event === "context-warning-60"
    )
    expect(warns.length).toBe(2)
  })

  // 3. Initial 85% manual /compact recommendation with continuation.
  test("first 85% crossing recommends manual /compact (not a new session)", async () => {
    const sessionID = "ses_initial_85"
    const { hooks, ctx } = await makeHarness(mockSessionMessages(tokensForFraction(0.50)))

    const rowsBefore = countRows(ctx)
    // Prime below 85%, then cross upward to 90%.
    ctx.client.session.messages = mockSessionMessages(tokensForFraction(0.90))
    await drivePolicy(hooks, ctx, sessionID)

    const rows = policyRows(ctx, rowsBefore)
    const compactRow = rows.find((r) => r.event === "context-compact-85")
    expect(compactRow).toBeDefined()
    // No post-compaction handoff on the FIRST 85% crossing.
    const handoffRow = rows.find(
      (r) => r.event === "context-new-session-post-compact"
    )
    expect(handoffRow).toBeUndefined()
    // A user-facing advisory message was shown.
    expect(ctx.logs.length).toBeGreaterThan(0)
  })

  // 4. After observed first compaction, next 85% handoff/new-session
  //    recommendation instead of a second /compact.
  test("after compaction, next 85% crossing recommends a new session (not second /compact)", async () => {
    const sessionID = "ses_post_compact"
    // Boot seeding: a prior session.compacted event marks this session as
    // already compacted.
    const seed = [
      {
        event: "session.compacted",
        session_id: sessionID,
        writer: "plugin",
      },
    ]
    const { hooks, ctx } = await makeHarness(
      mockSessionMessages(tokensForFraction(0.50)),
      mockProviderList(),
      { seedRegistry: seed }
    )

    const rowsBefore = countRows(ctx)
    // Prime below 85%, then cross upward to 90%.
    ctx.client.session.messages = mockSessionMessages(tokensForFraction(0.90))
    await drivePolicy(hooks, ctx, sessionID)

    const rows = policyRows(ctx, rowsBefore)
    const handoffRow = rows.find(
      (r) => r.event === "context-new-session-post-compact"
    )
    expect(handoffRow).toBeDefined()
    // The post-compaction path must NOT emit the initial-compaction event.
    const compactRow = rows.find((r) => r.event === "context-compact-85")
    expect(compactRow).toBeUndefined()
    expect(ctx.logs.length).toBeGreaterThan(0)
  })

  // 5. Fail-soft behavior.
  test("measurement error fails soft: emits context-policy-error, continues, no threshold events", async () => {
    const sessionID = "ses_fail_soft"
    // session.messages throws -> the policy's measurement must fail soft.
    const throwingMessages = async () => {
      throw new Error("simulated context_usage failure")
    }
    const { hooks, ctx } = await makeHarness(throwingMessages)

    const rowsBefore = countRows(ctx)
    // Must not throw / crash the session.
    await drivePolicy(hooks, ctx, sessionID)

    const rows = policyRows(ctx, rowsBefore)
    const errRow = rows.find((r) => r.event === "context-policy-error")
    expect(errRow).toBeDefined()
    // No threshold events fired despite the error.
    const thresholdRows = rows.filter(
      (r) =>
        r.event === "context-warning-60" ||
        r.event === "context-compact-85" ||
        r.event === "context-new-session-post-compact"
    )
    expect(thresholdRows.length).toBe(0)
  })
})
