/**
 * C5 scenario-1 (DIA-130 class): empty-result SILENT_FAILURE detection.
 *
 * Regression: coder-escalated returns empty result. The plugin's session.idle
 * handler must detect zero file edits and emit a SILENT_FAILURE row in
 * registry.jsonl.
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

  // ---- Scenario: empty-result SILENT_FAILURE ----
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

  // Fire session.idle with NO file edits -> should detect empty result.
  await hooks.event({
    event: {
      type: "session.idle",
      properties: { sessionID },
    },
  })

  const rows = readRegistry().slice(rowsBefore)
  const silentRow = rows.find(
    (r) =>
      r.event === "empty_result_detected" &&
      r.dispatch_state === "SILENT_FAILURE"
  )

  if (!silentRow) fail(`no SILENT_FAILURE row in registry after empty idle; rows: ${JSON.stringify(rows)}`)
  if (silentRow.session_id !== sessionID) fail(`SILENT_FAILURE session_id=${silentRow.session_id}, expected ${sessionID}`)
  if (silentRow.file_edit_count !== 0) fail(`SILENT_FAILURE file_edit_count=${silentRow.file_edit_count}, expected 0`)
})
