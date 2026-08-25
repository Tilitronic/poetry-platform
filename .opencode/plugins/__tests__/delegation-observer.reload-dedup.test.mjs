/**
 * DIA-260822-oldn RED tests: plugin-reload boot-sweep dedup (process-scoped).
 *
 * Deterministic regressions for the VALIDATED OpenSpec change
 * plugin-reload-boot-sweep-dedup (tasks.md 4.2 / 4.3, design.md D1/D3/D4).
 * The earlier 30s boot.json/mtime policy tests (tasks 1.1-1.4 as originally
 * specced) were REJECTED after a live 26s stop/start smoke test proved they
 * conflate a real process restart with an in-process reload (design.md
 * "Design evolution"). These tests pin the revised process-scoped design:
 *
 *   (1) invoking the plugin factory twice in ONE process emits exactly one
 *       session_boot row, sets the process-scoped boot flag, and preserves the
 *       first boot.json marker (Boot Dedup Guard, tasks 1.1-1.4 / D1 / D3).
 *   (2) clearing ONLY the process-scoped boot flag simulates a full new process
 *       and emits a NEW session_boot even when boot.json remains fresh — the
 *       exact failure the 30s policy had (a restart within the window wrongly
 *       suppressed the new boot). This is the RED anchor vs the current
 *       time/mtime implementation, which reads boot.json mtime and would skip.
 *   (3) factory re-invocation replaces the stall-sweep interval singleton and
 *       dispose clears it (Interval Singleton + Dispose, tasks 2.1-3.2). This
 *       regression is already satisfied by the current globalThis singleton and
 *       is retained unchanged in behavior.
 *
 * DIA-079: ASCII-only.
 *
 * RUN (bun in poetry-dev container):
 *   docker compose exec dev bash -lc \
 *     'cd /workspace/.opencode/plugins/__tests__ && \
 *      bun test delegation-observer.reload-dedup.test.mjs'
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
// Chain must satisfy tool.schema.enum([...]).optional().describe(...) used by
// the plugin's tool definitions (see failure-cap.test.mjs for the same shape).
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
  const directory = mkdtempSync(join(tmpdir(), "dia260822-oldn-"))
  tempDirs.push(directory)
  mkdirSync(join(directory, ".opencode", "session"), { recursive: true })
  return {
    directory,
    client: { app: { log: async () => {} } },
  }
}

// The well-known symbol the implementation must use as the stall-sweep
// interval singleton key (tasks.md 2.1 / 2.4). Referenced directly so the
// test fails deterministically until the implementation sets it.
const STALL_SWEEP_KEY = Symbol.for("delegation-observer.stallSweepInterval")

// The well-known symbol the implementation must use as the process-scoped boot
// identity flag (design.md D1 / D3, tasks 1.1-1.4). Referenced directly so the
// boot-identity tests fail deterministically against the CURRENT time/mtime
// implementation, which never sets or reads this flag.
const BOOT_EMITTED_KEY = Symbol.for("delegation-observer.bootEmitted")

function countSessionBootRows(directory) {
  const registryPath = join(directory, ".opencode/session/registry.jsonl")
  if (!existsSync(registryPath)) return 0
  return readFileSync(registryPath, "utf-8")
    .trim()
    .split("\n")
    .filter(Boolean)
    .filter((line) => {
      try {
        return JSON.parse(line).event === "session_boot"
      } catch {
        return false
      }
    }).length
}

function readBootJson(directory) {
  const bootPath = join(directory, ".opencode/session/boot.json")
  if (!existsSync(bootPath)) return null
  try {
    return JSON.parse(readFileSync(bootPath, "utf-8"))
  } catch {
    return null
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("DIA-260822-oldn: plugin-reload boot-sweep dedup (process-scoped, RED)", () => {
  test("factory invoked twice in one process emits one session_boot and preserves first marker", async () => {
    const ctx = freshCtx()
    // Isolate the process-scoped boot flag: bun shares globalThis across tests
    // in one file, so clear it so this test starts from a clean process state.
    globalThis[BOOT_EMITTED_KEY] = false

    const before = countSessionBootRows(ctx.directory)

    // First invocation in this process.
    await createDelegationObserver(ctx)
    const afterFirst = countSessionBootRows(ctx.directory)
    const bootFirst = readBootJson(ctx.directory)

    // (1a) First invocation emits exactly one session_boot row.
    expect(afterFirst).toBe(before + 1)
    // (1b) The process-scoped boot flag is the deterministic dedup signal and
    //      MUST be set after a real boot emission. The current time/mtime
    //      implementation never sets it -> this is the RED anchor.
    expect(globalThis[BOOT_EMITTED_KEY]).toBe(true)
    // (1c) First marker carries a boot_id.
    expect(bootFirst).not.toBeNull()
    const firstBootId = bootFirst.boot_id
    expect(typeof firstBootId).toBe("string")

    // Second invocation in the SAME process (in-process reload).
    await createDelegationObserver(ctx)
    const afterSecond = countSessionBootRows(ctx.directory)
    const bootSecond = readBootJson(ctx.directory)

    // (1d) No new session_boot row on in-process reload.
    expect(afterSecond).toBe(afterFirst)
    // (1e) Flag still set (not cleared by the suppressed reload).
    expect(globalThis[BOOT_EMITTED_KEY]).toBe(true)
    // (1f) First marker preserved — boot_id is unchanged, not overwritten with
    //      a fresh randomUUID.
    expect(bootSecond).not.toBeNull()
    expect(bootSecond.boot_id).toBe(firstBootId)
  })

  test("clearing only the process-scoped boot flag simulates full new process and emits a new session_boot even if boot.json remains fresh", async () => {
    const ctx = freshCtx()
    // Isolate the process-scoped boot flag (bun shares globalThis across tests).
    globalThis[BOOT_EMITTED_KEY] = false

    // First (real) process boot.
    await createDelegationObserver(ctx)
    const afterFirst = countSessionBootRows(ctx.directory)
    const bootFirst = readBootJson(ctx.directory)
    expect(afterFirst).toBeGreaterThan(0)
    expect(bootFirst).not.toBeNull()
    const firstBootId = bootFirst.boot_id

    // Simulate a FULL process restart: ONLY the process-scoped flag is cleared.
    // boot.json is left exactly as the first process wrote it — fresh and
    // recent. The 30s time/mtime policy would wrongly treat this as a reload
    // and skip; the process-scoped design must treat it as a new boot.
    globalThis[BOOT_EMITTED_KEY] = false

    const beforeSecond = countSessionBootRows(ctx.directory)
    await createDelegationObserver(ctx)
    const afterSecond = countSessionBootRows(ctx.directory)
    const bootSecond = readBootJson(ctx.directory)

    // (2a) A full new process emits a NEW session_boot even though boot.json is
    //      fresh. Against the current time/mtime implementation this fails
    //      (shouldSkipBootDedup returns true because boot.json mtime is recent).
    expect(afterSecond).toBe(beforeSecond + 1)
    // (2b) The new boot gets a distinct boot_id.
    expect(bootSecond).not.toBeNull()
    expect(bootSecond.boot_id).not.toBe(firstBootId)
    // (2c) Flag is re-armed for the new process.
    expect(globalThis[BOOT_EMITTED_KEY]).toBe(true)
  })

  test("factory re-invocation replaces stall-sweep singleton; dispose clears it", async () => {
    const ctx1 = freshCtx()
    const ctx2 = freshCtx()

    const h1 = await createDelegationObserver(ctx1)
    const handle1 = globalThis[STALL_SWEEP_KEY]
    const h2 = await createDelegationObserver(ctx2)
    const handle2 = globalThis[STALL_SWEEP_KEY]

    try {
      // (3a) Each factory invocation must register its stall-sweep interval
      // under the globalThis singleton key, replacing any prior handle so
      // stacked intervals cannot accumulate across in-process reloads.
      expect(handle1).toBeDefined()
      expect(handle2).toBeDefined()
      expect(handle2).not.toBe(handle1)

      // (3b) dispose must clear the singleton so a later reload starts clean.
      await h2.dispose()
      expect(globalThis[STALL_SWEEP_KEY]).toBeUndefined()
    } finally {
      // Best-effort cleanup of any intervals created during this RED run so
      // the test process does not hang on pending timers.
      try {
        await h1.dispose()
      } catch { /* best-effort dispose; ignore */ }
      try {
        await h2.dispose()
      } catch { /* best-effort dispose; ignore */ }
    }
  })
})
