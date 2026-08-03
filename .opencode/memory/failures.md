Failed-loop lessons & preventive actions

- Failure mode: Boss/orchestrator making direct code edits for dev-infra/config (scripts, Makefile, opencode configs). Root cause: cultural shortcut and lack of process enforcement.
  Preventive action: HARD RULE added to boss_append.md requiring the boss to dispatch @coder for dev-infra and config edits; Change Routing table added. Educate team on the rule during onboarding and code review.

- Failure mode: Non-hermetic shell tests that relied on host Docker or system state. Root cause: tests executed against live host services.
  Preventive action: Use the hermetic testing pattern (mock docker binary, user namespaces, tmpfs over /run, vendor bats-core). Document the pattern in tests/README and require reviewer verification of hermeticity during review.

- Failure mode: Double-/api base URL composition bug escaped mocked tests and caused live runs to 404. Root cause: mock-mode used a different base composition than real API. Preventive action: add a real-API smoke run (gated) and a URL-join helper for base + path to avoid double prefixing.

- Failure mode: MCP header-name mismatch risk (opencode.jsonc configured CONTEXT7_API_KEY header literal). Root cause: naming mismatch between env var and accepted server header names. Preventive action: update MCP mapping to Authorization: Bearer or X-Context7-API-Key and include an MCP integration smoke test.
 - Failure mode: MCP header-name mismatch risk (opencode.jsonc configured CONTEXT7_API_KEY header literal). Root cause: naming mismatch between env var and accepted server header names. Preventive action: update MCP mapping to Authorization: Bearer or X-Context7-API-Key and include an MCP integration smoke test.
   Resolution: Fixed by updating the Context7 MCP registration in .opencode/opencode.jsonc and tools/opencode-docker/config/opencode.json to use "Authorization: Bearer {env:CONTEXT7_API_KEY}", set "oauth": false to avoid false OAuth detection, and increase MCP timeout to 15000ms to accommodate remote latency. See .opencode/learnings/external-patterns/2026-08-02-context7-mcp-registration.md for source-verified details. Keep this failure entry for historical context; mark as resolved by the above config updates.

- Failure mode (2026-08-03): Premature SELF-RERUN/HANDOFF triggered by stale model-window lookup.
  Symptom: a handoff fired at 95,627 tokens and was interpreted as high-context pressure under the assumption of a 64k-window model.
  Root cause: NEXT-RUN.md's table listed `deepseek-v4-flash` as 64k (V3 value) while the real V4-Flash window is 1,000,000 tokens.
  Preventive action: when handoff thresholds are calculated from in-repo lookup tables, add a verify-on-use step that cross-checks models.dev (or the model vendor's model card) for current context windows. Record models.dev as the authoritative catalog near the threshold math to avoid future drift.
  Cross-reference: .opencode/memory/repo.md entry "Model context-window authoritative source (2026-08-03)".

- Failure mode (2026-08-03): Orchestrator resume loop / lost reviewer report due to malformed resume calls
  Symptom: the orchestrator attempted ~10 resume dispatches for a completed ai-specialist review session (ai--3). Each attempt spawned a fresh stateless session (ai--4..ai--13) which reported "no prior context". The background job board listed "Reusable Sessions: none". The final full report was missing because the original reviewer delivered only a summary verdict in the final message.
  Root cause:
    - Orchestrator omitted the required `task_id` parameter when calling the task tool to resume an existing subagent session, causing new sessions to be created instead of resuming.
    - Completed subagent sessions are not context-reusable by alias in this environment unless resumed correctly; the sentinel "reusable" label does not carry conversation payload.
    - The reviewer/agent delivered only a summary in the final message rather than the complete structured report, so the full deliverable could not be reconstructed from session fragments.
  Preventive action / operational guidance:
    1. Agents MUST include the complete structured deliverable (findings + evidence + compliance checklist) in their final message. Never leave the canonical report as a pointer or separate artifact that may be lost with ephemeral sessions.
    2. To resume a prior subagent session, the caller MUST pass `task_id` equal to the original session ID in the task tool call. Treat omission of `task_id` as a hard failure mode.
    3. Do not loop on malformed resume calls. After 3 failed resume attempts, escalate to human ownership and check the background job board for session reuse capabilities. Implement an automated 3-failure cap to avoid denial-of-service loop patterns.
    4. If a report is lost (final message contained only a summary), the honest recovery path is a fresh re-run of the reviewer/agent to regenerate the full report; document the rerun and its session ID in tracked artifacts.
  Cross-reference: messages.md row ~184 (session log), .opencode/memory/lessons.md entry about ephemeral session sidecars.
