/**
 * DIA-225 C4 regression test: failure cap for consecutive empty results.
 *
 * Verifies the D4 failure cap: after 3 consecutive SILENT_FAILURE detections
 * within a 10-minute cooldown window, a failure_cap_reached warning event is
 * emitted to messages.jsonl. Counter resets on non-empty result or cooldown
 * expiry. WARNING ONLY -- never auto-dispatch or auto-block.
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
  const directory = mkdtempSync(join(tmpdir(), "dia225-c4-"))
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
 * Drive the event hook (session lifecycle events).
 */
async function driveEvent(hooks, { event }) {
  const origWarn = console.warn
  console.warn = () => {}
  try {
    await hooks.event({ event })
  } finally {
    console.warn = origWarn
  }
}

/**
 * Drive tool.execute.after to register a file edit for a session.
 */
async function driveToolEdit(hooks, ctx, { sessionID, tool, callID }) {
  const origWarn = console.warn
  console.warn = () => {}
  try {
    await hooks["tool.execute.after"](
      {
        tool: tool ?? "edit",
        sessionID,
        callID: callID ?? "call_edit",
        args: {},
      },
      { output: "ok" }
    )
  } finally {
    console.warn = origWarn
  }
}

/**
 * Read messages.jsonl rows appended after a given count.
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

/**
 * Register a child session via session.created.
 */
async function registerChild(hooks, sessionID) {
  await driveEvent(hooks, {
    event: {
      type: "session.created",
      properties: {
        info: { id: sessionID, parentID: "ses_parent", title: "test" },
      },
    },
  })
}

/**
 * Fire session.idle with zero file edits (empty result).
 */
async function idleEmpty(hooks, sessionID) {
  await driveEvent(hooks, {
    event: {
      type: "session.idle",
      properties: { sessionID },
    },
  })
}

/**
 * Fire session.idle after a file edit was made (non-empty result).
 */
async function idleWithEdit(hooks, ctx, sessionID) {
  await driveToolEdit(hooks, ctx, { sessionID })
  await driveEvent(hooks, {
    event: {
      type: "session.idle",
      properties: { sessionID },
    },
  })
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("DIA-225 C4: failure cap", () => {
  test("3 consecutive empty results within 10 min triggers failure_cap_reached", async () => {
    // The failure cap is keyed by session_id. Verify the cap works with
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
    expect(capMsg.task_ref).toContain("failure cap reached")
  })

  test("non-empty result resets the counter (no cap after 2+1+2 pattern)", async () => {
    const { hooks, ctx } = await makeHarness()
    const sid = "ses_c4_reset"
    await registerChild(hooks, sid)

    const msgsBefore = countMessages(ctx)

    // 2 empty results.
    await idleEmpty(hooks, sid)
    await idleEmpty(hooks, sid)

    // 1 non-empty result (file edit made).
    await idleWithEdit(hooks, ctx, sid)

    // 2 more empty results -- counter was reset, so only 2 consecutive
    // failures, below the 3 threshold.
    await idleEmpty(hooks, sid)
    await idleEmpty(hooks, sid)

    const newMsgs = readNewMessages(ctx, msgsBefore)
    const capMsg = newMsgs.find(
      (m) => m["gen_ai.operation.name"] === "failure_cap_reached"
    )
    expect(capMsg).toBeUndefined()
  })

  test("cooldown expiry resets the counter (no cap after 11 min gap)", async () => {
    const { hooks, ctx } = await makeHarness()
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

    try {
      // 1 more empty result -- cooldown expired, counter reset, only 1
      // consecutive failure, below the 3 threshold.
      await idleEmpty(hooks, sid)
    } finally {
      Date.now = realDateNow
    }

    const newMsgs = readNewMessages(ctx, msgsBefore)
    const capMsg = newMsgs.find(
      (m) => m["gen_ai.operation.name"] === "failure_cap_reached"
    )
    expect(capMsg).toBeUndefined()
  })
})
