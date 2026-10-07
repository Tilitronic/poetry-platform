/**
 * C5 scenario-1 (DIA-130 class): empty-result detection.
 *
 * Regression: coder-escalated returns an EMPTY <task_result> body. The
 * plugin's session.idle handler must detect the absent TEXT (DIA-260926-ch1d
 * replaced the zero-file-edit proxy) and emit an empty_result_detected row
 * with dispatch_state EMPTY_RESULT / status NO_TEXT_RESULT in registry.jsonl.
 *
 * Mirrors the DIA-225 C3 bun test but exercises the plugin from a standalone
 * bun script (bats scenario replay, DIA-226).
 *
 * RUN: bun run empty-result-silent-failure.scenario.mjs (inside poetry-dev)
 */
import {
  existsSync,
  readFileSync,
} from "node:fs"
import { join } from "node:path"
import { mockOpencodePlugin } from "../helpers/plugin-harness.mjs"
import { runScenario } from "./scenario-runner.mjs"

// ---- @opencode-ai/plugin mock (registered BEFORE the plugin import) ----
mockOpencodePlugin()

// Dynamic import AFTER mock.module registration (defeats ESM hoisting).
const { default: createDelegationObserver } = await import(
  "../../delegation-observer.ts"
)

// ---- Harness: runScenario owns the temp workspace and single cleanup path ----
await runScenario("c5-s1-", async ({ directory, fail }) => {
  const logs = []
  const hooks = await createDelegationObserver({
    directory,
    client: { app: { log: async (entry) => logs.push(entry) } },
  })

  function readRegistry() {
    const p = join(directory, ".opencode/session/registry.jsonl")
    if (!existsSync(p)) return []
    return readFileSync(p, "utf-8").trim().split("\n").filter(Boolean).map(
      (l) => JSON.parse(l)
    )
  }

  // ---- Scenario: empty-result detection ----
  const sessionID = "ses_c5_empty_1"
  const rowsBefore = readRegistry().length

  // Register child session.
  await hooks.event({
    event: {
      type: "session.created",
      properties: {
        info: { id: sessionID, parentID: "ses_parent", title: "test" },
      },
    },
  })

  // DIA-260926-ch1d: the detector measures the <task_result> BODY, so the
  // dispatch that records a zero-length body must precede the idle.
  await hooks["tool.execute.after"](
    {
      tool: "task",
      sessionID: "ses_parent",
      callID: "call_c5_empty",
      args: { subagent_type: "coder", prompt: "return the report" },
    },
    {
      output: `<task id="${sessionID}"><state>completed</state><task_result></task_result></task>`,
    }
  )

  // Fire session.idle with a captured-but-empty result body.
  await hooks.event({
    event: {
      type: "session.idle",
      properties: { sessionID },
    },
  })

  const rows = readRegistry().slice(rowsBefore)
  const emptyRow = rows.find(
    (r) =>
      r.event === "empty_result_detected" &&
      r.dispatch_state === "EMPTY_RESULT"
  )

  if (!emptyRow) fail(`no EMPTY_RESULT row in registry after empty idle; rows: ${JSON.stringify(rows)}`)
  if (emptyRow.status !== "NO_TEXT_RESULT") fail(`empty_result status=${emptyRow.status}, expected NO_TEXT_RESULT`)
  if (emptyRow.session_id !== sessionID) fail(`EMPTY_RESULT session_id=${emptyRow.session_id}, expected ${sessionID}`)
  if (emptyRow.file_edit_count !== 0) fail(`EMPTY_RESULT file_edit_count=${emptyRow.file_edit_count}, expected 0`)
})
