/**
 * DIA-085 T4.2 test harness (test-author lane, DIA-175 instance separation).
 *
 * Seam under test: S1 (design.md section 6) - the delegation-observer plugin
 * WRITER flow for the parallel-handoff-slots change:
 *   atomicWriteHandoff(content, sessionId)
 *     -> archive_prior (best-effort rename of a same-session prior slot)
 *     -> write_slot (temp -> fsync -> rename -> fsync dir)
 *     -> write_pointer (active.json, written AFTER the slot)
 *   plus the log_decision terminal-handoff integration that drives it
 *   (design.md section 2 / tasks.md T1.1, implemented by a DIFFERENT
 *   instance per DIA-175).
 *
 * The tests invoke the REAL plugin (dynamic import) and drive its
 * tool.execute path via the mocked tool registry, exactly like the DIA-189
 * harness pattern. The only external module is @opencode-ai/plugin: unlike
 * needs-input-observer (type-only import), delegation-observer imports the
 * `tool` factory as a RUNTIME value, so it is mocked here (mock.module
 * registered BEFORE the plugin import - ESM hoisting defeats a later
 * registration). The mock returns the tool definition unchanged, so
 * hooks.tool.log_decision.execute(args, context) runs the real writer code.
 *
 * Hermetic: every harness gets a fresh mkdtemp workspace; the plugin writes
 * ONLY under <workspace>/.opencode/session/ (registry.jsonl boot row,
 * boot.json, messages.jsonl, handoffs/). The REAL .opencode/session/ of this
 * repo is never touched. All temp workspaces are removed on process exit.
 *
 * DIA-079: this file is ASCII-only (no em-dashes, no smart quotes).
 *
 * Canonical checksum (DIA-061): the in-test recompute mirrors the plugin and
 * scripts/validate-handoff.sh exactly - top-level prognosis keys byte-sorted
 * (jq `to_entries | sort_by(.key) | from_entries`), compact JSON.stringify,
 * SHA256 hex, no trailing newline. Fixture prognoses deliberately use a
 * NON-alphabetical key insertion order so a missing sort in the writer would
 * make the checksums diverge and the test fail loudly.
 *
 * RUN COMMAND (verified on bun 1.3.14 in the poetry-dev container; bun is
 * not installed on the host). `bun test` skips dot-directories in its
 * default file discovery, so a path filter like
 * `.opencode/plugins/__tests__/parallel-handoff.test.mjs` does NOT match -
 * run FROM inside the __tests__ directory:
 *
 *   docker compose exec dev bash -lc \
 *     'cd /workspace/.opencode/plugins/__tests__ && \
 *      bun test parallel-handoff.test.mjs'
 */
import { mock, test, expect } from "bun:test"
import { createHash } from "node:crypto"
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
} from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

// ---- @opencode-ai/plugin mock (registered BEFORE the plugin import) ----
// The plugin only uses `tool({...})` and `tool.schema.*` (args builders) at
// runtime. The mock returns the tool definition object unchanged, so the
// real `execute` function is what the tests call. Chainable schema stubs
// cover `.optional().describe(...)` used in the args construction.
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
      // Best-effort cleanup - a leaked temp dir must never fail the run.
    }
  }
})

function freshCtx() {
  const directory = mkdtempSync(join(tmpdir(), "dia085-t42-"))
  tempDirs.push(directory)
  // Mirror the real runtime: OpenCode pre-creates .opencode/session/ (the
  // plugin's registry.jsonl boot row lives there). Without it the boot-row
  // append fails ENOENT before atomicWriteBootMarker creates the dir - a
  // harmless pre-existing plugin behavior in a bare workspace, but the
  // harness should simulate the runtime layout anyway.
  const sessionDir = join(directory, ".opencode", "session")
  mkdirSync(sessionDir, { recursive: true })
  // DIA-192/193: the log_decision execute path reports benign/recovered
  // conditions via the TUI-safe SDK app log (ctx.client.app.log) instead of
  // raw console.warn (which surfaced as high-severity TUI notifications).
  // DIA-233: all plugin diagnostics now use tuiSafeWarn (app.log channel),
  // so the logs array captures all warning/error output from the plugin.
  const logs = []
  return {
    directory,
    logs,
    client: { app: { log: async (entry) => logs.push(entry) } },
  }
}

function sessionPaths(directory) {
  const sessionDir = join(directory, ".opencode/session")
  return {
    sessionDir,
    handoffsDir: join(sessionDir, "handoffs"),
    archiveDir: join(sessionDir, "handoffs", "archive"),
    pointerPath: join(sessionDir, "handoffs", "active.json"),
    slotPath: (sessionId) => join(sessionDir, "handoffs", `${sessionId}.json`),
    messagesPath: join(sessionDir, "messages.jsonl"),
  }
}

async function makeHarness() {
  const ctx = freshCtx()
  // Plugin init is hermetic: it writes the registry.jsonl session_boot row
  // and boot.json marker under <workspace>/.opencode/session/.
  const hooks = await createDelegationObserver(ctx)
  return { hooks, ctx, logs: ctx.logs, paths: sessionPaths(ctx.directory) }
}

/**
 * Drive the real log_decision tool.execute with a log_decision args record.
 * Collects app.log output (the writer reports archive FAILURES and
 * pointer-write failures through tuiSafeWarn - design.md section 5; the benign
 * archive event itself moved to the TUI-safe app.log channel, DIA-204).
 */
async function runLogDecision(hooks, args, logs, sessionID) {
  const beforeCount = logs.length
  // DIA-260827-y9n9: the slot identity now comes from the TRUSTED per-request
  // context.sessionID, so a test that writes "for session X" must present X as
  // the calling session. Default: the lane under test (each lane in these
  // tests models one orchestrator session), else the neutral harness session.
  const result = await hooks.tool.log_decision.execute(args, {
    sessionID: sessionID ?? args.lane_id ?? "ses_harness",
  })
  const newLogs = logs.slice(beforeCount)
  return { result, warnings: newLogs.map((l) => l?.body?.message ?? "") }
}

/** Terminal handoff write (resolution_status 'done') for a session lane. */
function terminalHandoffArgs(laneId, prognosis, taskRef = "DIA-085-test") {
  return {
    event_type: "handoff",
    task_ref: taskRef,
    resolution_status: "done",
    lane_id: laneId,
    cycle_id: `c-${laneId}`,
    prognosis: JSON.stringify(prognosis),
  }
}

async function writeTerminalHandoff(hooks, laneId, prognosis, logs) {
  return runLogDecision(hooks, terminalHandoffArgs(laneId, prognosis), logs)
}

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, "utf-8"))
}

const ISO_TS_RE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/
const ARCHIVE_NAME_RE = /^ses_A\.\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.\d{3}Z\.[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.json$/

/** Canonical DIA-061 checksum: sorted top-level keys, compact JSON, SHA256. */
function canonicalChecksum(prognosis) {
  const canonical = {}
  for (const key of Object.keys(prognosis).sort()) {
    canonical[key] = prognosis[key]
  }
  return createHash("sha256").update(JSON.stringify(canonical)).digest("hex")
}

/**
 * Prognosis fixtures. Deliberately NON-alphabetical key insertion order
 * (resume_instructions first, session_summary last) so the checksum test
 * proves the writer sorts keys before hashing.
 */
function prognosisA() {
  return {
    resume_instructions: "resume from session A",
    open_tickets: ["DIA-085"],
    fixes_applied: ["fix-a"],
    verification_request: ["bun test"],
    session_summary: { note: "session A summary", completed: ["T1.1"] },
  }
}

function prognosisB() {
  return {
    resume_instructions: "resume from session B",
    open_tickets: ["DIA-085"],
    fixes_applied: ["fix-b"],
    verification_request: ["bun test"],
    session_summary: { note: "session B summary", completed: ["T4.1"] },
  }
}

// ---------------------------------------------------------------------------
// S1 writer seam tests
// ---------------------------------------------------------------------------

test("S1 slot write: terminal handoff creates <session-id>.json with correct schema", async () => {
  const { hooks, paths, logs } = await makeHarness()
  const pA = prognosisA()
  const { result } = await writeTerminalHandoff(hooks, "ses_A", pA, logs)

  // Tool contract: execute resolves with the human-readable log line.
  expect(result.startsWith("Logged: handoff")).toBe(true)

  // Slot file exists with the full schema.
  const slotPath = paths.slotPath("ses_A")
  expect(existsSync(slotPath)).toBe(true)
  const slot = readJson(slotPath)
  expect(slot.status).toBe("done")
  expect(slot.session_id).toBe("ses_A")
  expect(slot.cycle_id).toBe("c-ses_A")
  expect(typeof slot.timestamp).toBe("string")
  expect(ISO_TS_RE.test(slot.timestamp)).toBe(true)
  expect(slot.checksum).toMatch(/^[0-9a-f]{64}$/)
  expect(slot.prognosis).toEqual(pA)

  // Pointer file exists with the pointer schema (design.md section 1).
  const pointer = readJson(paths.pointerPath)
  expect(pointer.active_session_id).toBe("ses_A")
  expect(pointer.pointer_version).toBe(1)
  expect(typeof pointer.timestamp).toBe("string")
  expect(ISO_TS_RE.test(pointer.timestamp)).toBe(true)

  // Pointer is written AFTER the slot (design.md section 2 step 3): the
  // slot file's mtime must not be newer than the pointer's.
  expect(statSync(paths.pointerPath).mtimeMs).toBeGreaterThanOrEqual(
    statSync(slotPath).mtimeMs
  )

  // Archive skipped when no prior slot exists: archive/ is empty after the
  // first write, and no archive event was emitted on either channel
  // (console.warn historically; the TUI-safe app.log since DIA-204).
  expect(readdirSync(paths.archiveDir)).toHaveLength(0)
  expect(
    logs.some(
      (l) =>
        l?.body?.level === "info" &&
        l?.body?.message?.includes("handoff archived")
    )
  ).toBe(false)
})

test("S1 checksum: slot checksum equals the canonical DIA-061 SHA256 over the prognosis", async () => {
  const { hooks, paths, logs } = await makeHarness()
  const pA = prognosisA()
  const pB = prognosisB()

  await writeTerminalHandoff(hooks, "ses_A", pA, logs)
  const slotA = readJson(paths.slotPath("ses_A"))
  // Recompute by the canonical pipeline (jq to_entries|sort_by(.key)|
  // from_entries + printf %s + sha256) and compare.
  expect(slotA.checksum).toBe(canonicalChecksum(pA))
  // The slot's stored checksum must be independent of the wrapper fields:
  // rehash the parsed prognosis and it must still match.
  expect(canonicalChecksum(slotA.prognosis)).toBe(slotA.checksum)

  // A different prognosis must hash to a different checksum.
  await writeTerminalHandoff(hooks, "ses_B", pB, logs)
  const slotB = readJson(paths.slotPath("ses_B"))
  expect(slotB.checksum).toBe(canonicalChecksum(pB))
  expect(slotB.checksum).not.toBe(slotA.checksum)
})

test("S1 archive-on-overwrite: same-session rewrite archives the prior slot and replaces the slot", async () => {
  const { hooks, paths, logs } = await makeHarness()
  const pA = prognosisA()
  const pB = prognosisB()

  await writeTerminalHandoff(hooks, "ses_A", pA, logs)
  const pointerAfterFirst = readJson(paths.pointerPath)

  // Second terminal write for the SAME session with different prognosis.
  await writeTerminalHandoff(hooks, "ses_A", pB, logs)

  // Archive holds exactly one file with the documented naming convention
  // <session-id>.<iso-ts-hyphenated>.<uuid>.json (DIA-222: UUID suffix for collision safety).
  const archiveFiles = readdirSync(paths.archiveDir)
  expect(archiveFiles).toHaveLength(1)
  expect(ARCHIVE_NAME_RE.test(archiveFiles[0])).toBe(true)

  // The archived file preserves the OLD prognosis and its checksum still
  // matches the OLD prognosis (design.md section 6: archive integrity).
  const archived = readJson(join(paths.archiveDir, archiveFiles[0]))
  expect(archived.session_id).toBe("ses_A")
  expect(archived.prognosis).toEqual(pA)
  expect(archived.checksum).toBe(canonicalChecksum(pA))

  // The slot is replaced: new prognosis + new checksum.
  const slot = readJson(paths.slotPath("ses_A"))
  expect(slot.prognosis).toEqual(pB)
  expect(slot.checksum).toBe(canonicalChecksum(pB))

  // Pointer unchanged in identity (active_session_id stays ses_A) and still
  // pointer_version 1; only its timestamp refreshes.
  const pointerAfterSecond = readJson(paths.pointerPath)
  expect(pointerAfterSecond.active_session_id).toBe(
    pointerAfterFirst.active_session_id
  )
  expect(pointerAfterSecond.pointer_version).toBe(1)

  // The archive event is observable on the TUI-safe app-log channel at info
  // level (DIA-204: demoted from console.warn, which surfaced as a
  // high-severity TUI notification; design.md section 5 observability).
  expect(
    logs.some(
      (l) =>
        l?.body?.level === "info" &&
        l?.body?.message?.includes("handoff archived: ses_A") &&
        l?.body?.message?.includes("archive/")
    )
  ).toBe(true)

  // Registry-row enrichment: the second terminal row carries archived_prior
  // (relative path), the first row does not (design.md section 5).
  const rows = readFileSync(paths.messagesPath, "utf-8")
    .trim()
    .split("\n")
    .map((line) => JSON.parse(line))
    .filter((r) => r.event_type === "handoff")
  expect(rows).toHaveLength(2)
  expect("archived_prior" in rows[0]).toBe(false)
  expect(rows[1].archived_prior).toBe(`archive/${archiveFiles[0]}`)
})

test("S1 two-session coexistence: ses_A then ses_B - both slots survive, pointer points to ses_B", async () => {
  const { hooks, paths, logs } = await makeHarness()
  const pA = prognosisA()
  const pB = prognosisB()

  await writeTerminalHandoff(hooks, "ses_A", pA, logs)
  await writeTerminalHandoff(hooks, "ses_B", pB, logs)

  // Both slots exist; each carries its own prognosis (no clobber).
  const slotA = readJson(paths.slotPath("ses_A"))
  const slotB = readJson(paths.slotPath("ses_B"))
  expect(slotA.session_id).toBe("ses_A")
  expect(slotA.prognosis).toEqual(pA)
  expect(slotA.checksum).toBe(canonicalChecksum(pA))
  expect(slotB.session_id).toBe("ses_B")
  expect(slotB.prognosis).toEqual(pB)
  expect(slotB.checksum).toBe(canonicalChecksum(pB))

  // Pointer points to the most recent writer (ses_B).
  const pointer = readJson(paths.pointerPath)
  expect(pointer.active_session_id).toBe("ses_B")

  // First-writes never archive: archive/ stays empty.
  expect(readdirSync(paths.archiveDir)).toHaveLength(0)
})

test("S1 directory creation: first write creates handoffs/ and handoffs/archive/", async () => {
  const { hooks, paths, logs } = await makeHarness()

  // Precondition: plugin init creates only .opencode/session/ (boot.json +
  // registry.jsonl); handoffs/ must NOT exist yet.
  expect(existsSync(paths.handoffsDir)).toBe(false)

  await writeTerminalHandoff(hooks, "ses_A", prognosisA(), logs)

  // Postcondition: both handoffs/ and handoffs/archive/ exist.
  expect(existsSync(paths.handoffsDir)).toBe(true)
  expect(existsSync(paths.archiveDir)).toBe(true)
})

test("S1 DIA-192 parse-fallback: malformed prognosis logs at debug level and writes the plain-text wrapper (no crash)", async () => {
  const { hooks, paths, logs } = await makeHarness()

  // A prognosis string that genuinely fails JSON.parse (not double-encoded
  // JSON - that path recovers the structured object via the DIA-192
  // double-decode retry and never reaches the fallback).
  const malformed = '{not-valid-json: '
  const { result } = await runLogDecision(hooks, {
    event_type: "handoff",
    task_ref: "DIA-192-malformed",
    resolution_status: "done",
    lane_id: "ses_parse_fallback",
    prognosis: malformed,
  }, logs)

  // The recovered error is reported on the TUI-safe app-log channel at
  // debug level (DIA-192: info-level was still too loud for a recovered
  // error - 2026-08-16 re-open downgraded to debug). It must NOT be info.
  expect(
    logs.some(
      (l) =>
        l?.body?.level === "debug" &&
        l?.body?.message?.includes("prognosis parse failed")
    )
  ).toBe(true)
  expect(
    logs.some(
      (l) =>
        l?.body?.level === "info" &&
        l?.body?.message?.includes("prognosis parse failed")
    )
  ).toBe(false)

  // The handoff slot is still written with the plain-text wrapper shape
  // (session_summary.note = raw string; structured fields empty) - the
  // fallback must not crash the writer, and the slot carries a valid
  // checksum over that wrapper.
  const slotPath = paths.slotPath("ses_parse_fallback")
  expect(existsSync(slotPath)).toBe(true)
  const slot = readJson(slotPath)
  expect(slot.status).toBe("done")
  expect(slot.prognosis).toEqual({
    session_summary: { note: malformed },
    fixes_applied: [],
    open_tickets: [],
    verification_request: [],
    resume_instructions: "",
  })
  expect(slot.checksum).toMatch(/^[0-9a-f]{64}$/)
  expect(slot.checksum).toBe(canonicalChecksum(slot.prognosis))

  // Tool contract: the call still resolves (no crash on malformed input).
  expect(result.startsWith("Logged: handoff")).toBe(true)
})

test("S1 DIA-231 warn branch: literal JSON.stringify(...) text logs at warn and wraps in fallback (no crash)", async () => {
  const { hooks, paths, logs } = await makeHarness()

  // Simulate the LLM passing the literal text "JSON.stringify(...)" instead
  // of the actual stringified result. The raw string starts with
  // "JSON.stringify(" so the warn branch fires; JSON.parse then fails
  // because the literal text is not valid JSON, triggering the catch-only
  // fallback to the plain-text wrapper.
  const literalStringify =
    "JSON.stringify({session_summary: 'test'})"
  const { result } = await runLogDecision(hooks, {
    event_type: "handoff",
    task_ref: "DIA-231-warn",
    resolution_status: "done",
    lane_id: "ses_dia231",
    prognosis: literalStringify,
  }, logs)

  // The warn branch fires: app.log receives a warn-level entry whose
  // message mentions the literal JSON.stringify pattern.
  expect(
    logs.some(
      (l) =>
        l?.body?.level === "warn" &&
        l?.body?.message?.includes("JSON.stringify(")
    )
  ).toBe(true)

  // The handoff slot is still written with the plain-text wrapper shape
  // (the catch block handles the parse failure after the warn fires).
  const slotPath = paths.slotPath("ses_dia231")
  expect(existsSync(slotPath)).toBe(true)
  const slot = readJson(slotPath)
  expect(slot.status).toBe("done")
  expect(slot.prognosis).toEqual({
    session_summary: { note: literalStringify },
    fixes_applied: [],
    open_tickets: [],
    verification_request: [],
    resume_instructions: "",
  })
  expect(slot.checksum).toMatch(/^[0-9a-f]{64}$/)
  expect(slot.checksum).toBe(canonicalChecksum(slot.prognosis))

  // Tool contract: the call still resolves (no crash on literal input).
  expect(result.startsWith("Logged: handoff")).toBe(true)
})

test("S1 DIA-120 filter: non-terminal 'in-flight' first write creates NO slot and NO pointer", async () => {
  const { hooks, paths, logs } = await makeHarness()

  await runLogDecision(hooks, {
    event_type: "handoff",
    task_ref: "DIA-085-inflight",
    resolution_status: "in-flight",
    lane_id: "ses_A",
    prognosis: JSON.stringify(prognosisA()),
  }, logs)

  // The writer is never reached: no handoffs/ dir, no slot, no pointer.
  expect(existsSync(paths.handoffsDir)).toBe(false)
  expect(existsSync(paths.pointerPath)).toBe(false)
  // The skip is observable on the TUI-safe app-log channel at debug level
  // (DIA-193: demoted from console.warn to info 2026-08-15, then to debug on
  // the 2026-08-16 re-open - a benign guard must never read as alarming;
  // the guard behavior itself is unchanged - no slot/pointer).
  expect(
    logs.some(
      (l) =>
        l?.body?.level === "debug" &&
        l?.body?.message?.includes("handoff-writer skipped")
    )
  ).toBe(true)
  // The event is still logged as an observation (audit row survives).
  const rows = readFileSync(paths.messagesPath, "utf-8")
    .trim()
    .split("\n")
    .map((line) => JSON.parse(line))
  expect(rows.some((r) => r.resolution_status === "in-flight")).toBe(true)
})

test("S1 DIA-120 filter: non-terminal event does NOT touch an existing slot or pointer", async () => {
  const { hooks, paths, logs } = await makeHarness()

  await writeTerminalHandoff(hooks, "ses_A", prognosisA(), logs)
  const slotBefore = readFileSync(paths.slotPath("ses_A"), "utf-8")
  const pointerBefore = readFileSync(paths.pointerPath, "utf-8")
  const archiveBefore = readdirSync(paths.archiveDir)

  // Non-terminal handoff for the same session with a DIFFERENT prognosis.
  await runLogDecision(hooks, {
    event_type: "handoff",
    task_ref: "DIA-085-inflight",
    resolution_status: "in-flight",
    lane_id: "ses_A",
    prognosis: JSON.stringify(prognosisB()),
  }, logs)

  // Slot and pointer byte-identical; no archive was created.
  expect(readFileSync(paths.slotPath("ses_A"), "utf-8")).toBe(slotBefore)
  expect(readFileSync(paths.pointerPath, "utf-8")).toBe(pointerBefore)
  expect(readdirSync(paths.archiveDir)).toEqual(archiveBefore)
  // The skip is observable on the TUI-safe app-log channel at debug level
  // (DIA-193; same demotion rationale as the first-write filter test).
  expect(
    logs.some(
      (l) =>
        l?.body?.level === "debug" &&
        l?.body?.message?.includes("handoff-writer skipped")
    )
  ).toBe(true)
})

test("S1 reserved-path guard: session id 'active' cannot clobber active.json", async () => {
  const { hooks, paths, logs } = await makeHarness()

  // Establish a REAL pointer first so the guard's protection is observable:
  // an attempted write for lane 'active' must leave it intact.
  await writeTerminalHandoff(hooks, "ses_A", prognosisA(), logs)
  const pointerBefore = readFileSync(paths.pointerPath, "utf-8")
  const slotABefore = readFileSync(paths.slotPath("ses_A"), "utf-8")

  await runLogDecision(hooks, {
    event_type: "handoff",
    task_ref: "DIA-085-guard",
    resolution_status: "done",
    lane_id: "active",
    prognosis: JSON.stringify(prognosisB()),
  }, logs)

  // The guard rejects the write before ANY file mutation: the real pointer
  // and the existing slot are byte-identical afterwards.
  expect(readFileSync(paths.pointerPath, "utf-8")).toBe(pointerBefore)
  expect(readFileSync(paths.slotPath("ses_A"), "utf-8")).toBe(slotABefore)
  // No archive happened and the slot dir holds exactly the pointer + ses_A
  // (.json files only - the archive/ subdirectory also lives in handoffs/).
  expect(readdirSync(paths.archiveDir)).toHaveLength(0)
  const slotFiles = readdirSync(paths.handoffsDir).filter((f) =>
    f.endsWith(".json")
  )
  expect(slotFiles.sort()).toEqual(["active.json", "ses_A.json"])
  // The collision is surfaced on the TUI-safe app-log channel at error level
  // (DIA-192 pattern: the atomic-write catch logs via app.log instead of raw
  // console.warn; severity preserved - this is a genuine failure, not a
  // benign skip). The call still RESOLVES (the audit row below is the
  // non-negotiable trail - design.md section 4).
  expect(
    logs.some(
      (l) =>
        l?.body?.level === "error" &&
        l?.body?.message?.includes("slot path collision")
    )
  ).toBe(true)
  const rows = readFileSync(paths.messagesPath, "utf-8")
    .trim()
    .split("\n")
    .map((line) => JSON.parse(line))
  expect(rows[rows.length - 1].event_type).toBe("handoff")
  expect(rows[rows.length - 1].lane_id).toBe("active")
})

/** Simulate a session's first task() dispatch (the root-session capture). */
async function driveTaskDispatch(hooks, sessionID, callID = "call_1") {
  await hooks["tool.execute.after"](
    {
      tool: "task",
      sessionID,
      callID,
      args: {
        subagent_type: "coder",
        task_id: `${sessionID}_child`,
        description: "DIA-085 test dispatch",
      },
    },
    { output: `task_id: ${sessionID}_child` }
  )
}

test("DIA-260827-y9n9: trusted context.sessionID wins over the task()-captured session and over lane_id", async () => {
  const { hooks, paths, logs } = await makeHarness()

  // Session A dispatches first: the plugin registers it as a root session.
  // Before the fix this capture was a process-global that OUTRANKED the
  // trusted per-request identity, so any later session's handoff was filed
  // under A.
  await driveTaskDispatch(hooks, "ses_parent")

  // Session B (the trusted context.sessionID) writes a terminal handoff and
  // supplies yet another lane_id. Slot identity must be B - not the captured
  // ses_parent, not the model-supplied lane_id.
  await runLogDecision(
    hooks,
    terminalHandoffArgs("ses_lane", prognosisA()),
    logs,
    "ses_B"
  )

  expect(existsSync(paths.slotPath("ses_B"))).toBe(true)
  expect(existsSync(paths.slotPath("ses_parent"))).toBe(false)
  expect(existsSync(paths.slotPath("ses_lane"))).toBe(false)
  const slot = readJson(paths.slotPath("ses_B"))
  expect(slot.session_id).toBe("ses_B")
  const pointer = readJson(paths.pointerPath)
  expect(pointer.active_session_id).toBe("ses_B")
})

test("DIA-260827-y9n9: a second parallel session's terminal handoff does not clobber the first session's slot or pointer", async () => {
  const { hooks, paths, logs } = await makeHarness()

  // Session A dispatches first (root capture), then writes its own handoff.
  await driveTaskDispatch(hooks, "ses_A")
  await runLogDecision(
    hooks,
    terminalHandoffArgs("ses_A", prognosisA()),
    logs,
    "ses_A"
  )
  const slotABefore = readFileSync(paths.slotPath("ses_A"), "utf-8")
  expect(readJson(paths.pointerPath).active_session_id).toBe("ses_A")

  // Session B (parallel orchestrator in the SAME plugin process) writes its
  // terminal handoff. Before the fix this wrote into ses_A.json, archived A's
  // valid handoff, and left active.json naming ses_A while carrying B's
  // prognosis.
  await driveTaskDispatch(hooks, "ses_B", "call_2")
  await runLogDecision(
    hooks,
    terminalHandoffArgs("ses_B", prognosisB()),
    logs,
    "ses_B"
  )

  // A's slot is byte-identical and was never archived.
  expect(readFileSync(paths.slotPath("ses_A"), "utf-8")).toBe(slotABefore)
  expect(readdirSync(paths.archiveDir)).toHaveLength(0)

  // B got its OWN slot with its own prognosis and checksum.
  const slotB = readJson(paths.slotPath("ses_B"))
  expect(slotB.session_id).toBe("ses_B")
  expect(slotB.prognosis).toEqual(prognosisB())
  expect(slotB.checksum).toBe(canonicalChecksum(prognosisB()))

  // The pointer names the ACTUAL writer (B), so a successor session reads B's
  // prognosis under B's identity - no cross-session misattribution.
  expect(readJson(paths.pointerPath).active_session_id).toBe("ses_B")
})
