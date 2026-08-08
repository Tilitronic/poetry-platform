Failed-loop lessons & preventive actions

- Failure mode: Boss/orchestrator making direct code edits for dev-infra/config (scripts, Makefile, opencode configs). Root cause: cultural shortcut and lack of process enforcement.
  Preventive action: HARD RULE added to boss_append.md requiring the boss to dispatch @coder for dev-infra and config edits; Change Routing table added. Educate team on the rule during onboarding and code review.

- Failure mode: Non-hermetic shell tests that relied on host Docker or system state. Root cause: tests executed against live host services.
  Preventive action: Use the hermetic testing pattern (mock docker binary, user namespaces, tmpfs over /run, vendor bats-core). Document the pattern in tests/README and require reviewer verification of hermeticity during review.

- Failure mode: Double-/api base URL composition bug escaped mocked tests and caused live runs to 404. Root cause: mock-mode used a different base composition than real API. Preventive action: add a real-API smoke run (gated) and a URL-join helper for base + path to avoid double prefixing.

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

- Failure mode (2026-08-08): MAXIMUM_STEPS mid-protocol (cod-2)
  Symptom: a combined probe+test-config lane caused cod-2 to hit MAXIMUM STEPS mid-protocol and required resumption in cod-3. The combined lane shape made the step-cap more likely to be reached.
  Preventive action: split probe and verification lanes into smaller, single-responsibility lanes; keep per-lane step budgets conservative and prefer short-lived probe lanes.

- Failure mode (2026-08-08): ai-specialist stub-result returned without artifact
  Symptom: ai-specialist returned a stub summary message without the substantive findings artifact, violating the A4 artifact gate and requiring a resume/re-run to obtain the full deliverable.
  Preventive action: enforce artifact-content on ai-specialist results; treat stub-only results as non-deliverable and require resumption (task() with original task_id) or human escalation. Add a resume-cap (3 retries) before escalating.


- Failure mode: coder implementation sessions failing pre-write (DIA-066 observations)
  - Symptom: several coder/session implementations failed before writing any repo files: observed finish:unknown provider stream failures (0 output tokens) and finish:length context exhaustion after prolonged analysis (~10min). Examples: cod-5 finish:unknown, cod-7 finish:length, ope-2 finish:unknown mid-5th-edit.
  - Mitigation that worked: re-dispatch the task with the FULL task spec embedded in the prompt and an explicit 'WRITE EARLY' instruction (create a minimal skeleton or perform an early partial write, then iterate). This reduces the chance that large analysis or context pressure prevents early persistence.
  - Preventive action: for multi-slice implementation dispatches embed the complete task spec in the prompt (do not rely on the agent re-reading external artifacts) and mandate an early-write-first strategy in the brief ('WRITE EARLY — produce file skeletons before deep analysis'). Record this as an operational failure lesson — the failure traces appear in telemetry but the behavioural countermeasure is not reconstructible purely from logs.

- Failure mode (2026-08-06): reviewer empty-result resume pattern — risk of re-dispatching fresh instance
  Symptom: a reviewer task completed with an EMPTY result (no report). Consumers attempted to recover by re-dispatching a fresh reviewer which created a new stateless session and lost the original context. The correct recovery was to resume the original reviewer instance using its task_id (resume succeeded and returned the full report).
  Root cause: orchestration lanes re-dispatched a fresh reviewer rather than resuming the exact prior instance; failure to capture/persist the original task_id made resume harder.
  Preventive action:
    1. Persist task() result.task_id for any dispatched reviewer/ai-specialist tasks in the registry.jsonl/messages.md sidecar at dispatch-time.
    2. When an EMPTY result is observed but prior context is expected, resume by calling task() with the original task_id instead of re-dispatching a fresh reviewer.
    3. After N failed resume attempts, escalate rather than looping re-dispatches which create noisy fresh sessions. Implement an automated 3-failure cap.
  Notes: this is an operational failure pattern discovered on 2026-08-06 and is not recoverable from git diffs alone.

- Failure mode (2026-08-04): dispatched-but-not-executed subagent tasks when batching edits
  Symptom: orchestration logs showed lanes marked as 'DISPATCHED (in-flight)' while the corresponding task() call never executed. Observed 2–3× during this campaign when a single agent message contained multiple operations (edit tool calls + task() calls) batched together.
  Root cause: batching task() calls with edit tool invocations in a single message caused the runtime to drop or silently ignore the task() invocation in some cases; pure task() messages reliably launched subagents.
  Preventive action:
    1. Avoid batching edit-tool calls and task() invocations in the same agent message; prefer single-responsibility messages where a task() call is the sole action to ensure reliable subagent dispatch.
    2. Add a monitoring assertion in the orchestrator that verifies a dispatched lane transitions from DISPATCHED -> RUNNING within a short window, and raise an audible/logging alert if the lane remains DISPATCHED without a matching session startup event after N seconds.
    3. Document this failure mode in operational runbooks and include an explicit test in the verification loop that simulates a batched edit+task message to detect regressions.
  Notes: check existing failures.md for related resume/dispatch failure modes; this entry records the batching-specific trigger and mitigation.

- Failure mode (2026-08-07): code-executor / subagent "step-cap" verification stall (commit-lane step-cap)
  Symptom: during verification-heavy change commits, code-executor subagents repeatedly hit a configured step/verification cap before executing the final commit action. The session required six resume attempts because each resumed run re-ran verification steps (re-checking byte-identical hunks) instead of performing the previously planned commit. This produced a repeated re-verification loop and delayed delivery.
  Root cause: resume/dispatch prompts omitted an explicit instruction to skip re-verification and execute the previously-verified commands; the subagent default behaviour is to re-run verification steps unless told otherwise. Additionally, fresh dispatches create a new session that redoes analysis rather than continuing the verified run.
  Preventive action / mitigation that worked:
    1. Resume by reusing the original task_id (exact-instance resume) rather than fresh dispatches so the prior run's verified state is available.
    2. When resuming, include the prior run's verified analysis and the exact commands to run verbatim in the resume prompt and add an explicit instruction: "do NOT re-verify, execute the following commands".
    3. Add an orchestrator-side resume checklist item: capture and persist the subagent's last verification digest (hunk map + checksum) at dispatch time so resumes can assert equivalence and safely skip verification.
    4. Implement a small resume-time guard in the orchestrator: if a resumed session is detected and the digest matches, set a `skip_verification` flag in the prompt payload; otherwise, fall back to full verification.
  Why persist: this is an operational failure pattern tied to agent step-cap and resume semantics observed in-session and is not reconstructible from code diffs or commit history alone. Recording the precise mitigation (task_id resume + verbatim commands + skip_verification flag) prevents repeated lost-time loops in future commit-lane operations.

- Failure mode (2026-08-04): Hallucinated model ID propagated into active preset config
  Symptom: post-restart observer agent failed to launch with "Model not found: github-copilot/gemini-3.6-flash" because the ACTIVE preset contained a non-existent primary model ID while a related preset (opencode-go) had been updated.
  Root cause:
    - A learnings file asserted a model (github-copilot/gemini-3.6-flash) as GA without live-catalog verification; that assertion propagated into a preset and into the ACTIVE preset array.
    - The fix applied edits to one preset's observer model entry but did not reconcile the ACTIVE preset (cebula), leaving the stale ID as primary.
  Preventive action:
    1. When changing model assignments, always verify model IDs against the provider's live model catalog (models.dev or vendor model card) before committing. Do not rely on learnings or memory claims about availability unless a verification date and source are recorded.
    2. When patching a single preset, perform a preset-resolution check: enumerate all presets, the ACTIVE preset, and any preset-alias resolution chain to ensure no stale model IDs remain as primary or fallback.
    3. Add a post-restart smoke step to the change checklist that performs a dry-launch of critical agents (observer, orchestrator) and fails fast on "Model not found" errors.
  Cross-reference: lessons.md entry about model metadata verification and campaign registration pattern.
