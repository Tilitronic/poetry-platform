Failed-loop lessons & preventive actions

- Failure mode: Boss/orchestrator making direct code edits for dev-infra/config (scripts, Makefile, opencode configs). Root cause: cultural shortcut and lack of process enforcement.
  Preventive action: HARD RULE added to boss_append.md requiring the boss to dispatch @coder for dev-infra and config edits; Change Routing table added. Educate team on the rule during onboarding and code review.

- Failure mode: Non-hermetic shell tests that relied on host Docker or system state. Root cause: tests executed against live host services.
  Preventive action: Use the hermetic testing pattern (mock docker binary, user namespaces, tmpfs over /run, vendor bats-core). Document the pattern in tests/README and require reviewer verification of hermeticity during review.

- Failure mode: Double-/api base URL composition bug escaped mocked tests and caused live runs to 404. Root cause: mock-mode used a different base composition than real API. Preventive action: add a real-API smoke run (gated) and a URL-join helper for base + path to avoid double prefixing.

- Failure mode: MCP header-name mismatch risk (opencode.jsonc configured CONTEXT7_API_KEY header literal). Root cause: naming mismatch between env var and accepted server header names. Preventive action: update MCP mapping to Authorization: Bearer or X-Context7-API-Key and include an MCP integration smoke test.
  Resolution: Fixed by updating the Context7 MCP registration in .opencode/opencode.jsonc and tools/opencode-docker/config/opencode.json to use "Authorization: Bearer {env:CONTEXT7_API_KEY}", set "oauth": false to avoid false OAuth detection, and increase MCP timeout to 15000ms to accommodate remote latency. See .opencode/learnings/external-patterns/2026-08-02-context7-mcp-registration.md for source-verified details. Keep this failure entry for historical context; mark as resolved by the above config updates.

- Failure mode: pre-commit hook blocks local commits (2026-08-09)
  - Symptom: `git commit` fails with a husky pre-commit script exit (code 1) and message: "!! dev container not running — start with 'make up', then commit again." Observed twice during this campaign when attempting local commits outside the running dev container.
  - Root cause: the repository's pre-commit guard enforces dev-container runtime preconditions and intentionally blocks commits when the developer environment is not in the expected devcontainer state.
  - Preventive action / workaround: start the dev container (`make up`) so the pre-commit checks run in the intended environment, then commit normally. Do NOT bypass the hook with `--no-verify` unless you fully understand and document why. This operational/workflow quirk is session-specific and not reconstructible from git diffs alone, so record the observed message and workaround here.

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


- DIA-070: restart-not-effective trap (verification loop root cause, 2026-08-08):
  - Symptom: session/TUI-level restart did not load patched plugin code; only a true process-level restart (kill old PID + start fresh) caused the runtime to pick up the vendored patches. Two verification attempts that used the TUI restart mechanism failed before a full process restart succeeded.
  - Root cause: OpenCode plugin resolution happens at process startup and caches loaded module paths; in-place TUI restart reused the existing process image or a supervisor that restored unpatched module paths.
  - Preventive actions:
    1. For verification of runtime-level plugin changes, perform a hard process restart (kill the old PID and launch the process) and verify PID and start timestamp differ from the pre-patch process. Do not rely on in-process/TUI restart commands for verification of patched plugin code.
    2. Add a restart checklist item to the verification procedure that explicitly requires checking `ps`/PID, plugin checksum, and telemetry schema_version/database index state after restart.
    3. Where possible, automate the post-restart verification (smoke script) that checks critical invariants: plugin file checksum, telemetry DB schema_version, presence of expected DB indices, and zero duplicate rows for dedup fixes.
  - Cross-reference: lessons.md vendored-patch shadow-copy hazard; repo.md telemetry DB path and schema_version pointer.

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


- Failure mode (2026-08-10): cod-4 silent-empty result (docs/registration lane)
  - Symptom: a @coder dispatch (docs lane) returned a COMPLETELY EMPTY task result — no summary, no changes, no verification. The referenced ticket file (docs/dev-infra-audit/tickets/DIA-076-dia063-fix-implementation.md) was verified untouched afterward.
  - Root cause: silent-empty task result from an in-session coder dispatch (A3 pattern) combined with the orchestrator not verifying the in-scope artifacts before assuming completion.
  - Recovery: resumed the same session via task_id with an explicit instruction: "the work was NOT done — complete all three tasks and RETURN a non-empty report"; the resumed session (cod-5) completed the tasks and produced a full report with re-read verification.
  - Preventive action: treat empty task results as silent failures; verify in-scope artifacts (ticket files, changelog, target paths) directly before accepting completion. If an empty result is observed, attempt an exact-instance resume (task_id) rather than spawning a fresh session.

- Failure mode (2026-08-10): snip-wrapper loop recurrence — coder lanes (DIA-078)
  - Symptom: coder lanes (cod-2, cod-3) repeatedly executed an identical command prefixed with the `snip` wrapper (`snip make test-config`) producing byte-identical, EXIT_CODE=0 output across 7+ repetitions with no progress (loop). A docs-lane coder (cod-4) self-disclosed 3× additional occurrences of accidental `snip`-prefixing during the same campaign. The behaviour mirrors the earlier DIA-075 jq snip-loop but targets `make` instead of `jq` and repeated despite previous fixes scoped to `jq` only.
  - Root cause hypothesis: the Layer-2 guardrail that forbade `snip`-prefixing had been implemented narrowly for the `jq` probe command and did not cover other commands. When a lane attempted to run `make test-config` the runtime or wrapper prefixed `snip`, which produced a wrapper-layer no-op/transparent output that satisfied the step without performing the intended actions, causing a silent loop.
  - Recovery / note: DIA-078 was opened to track the incident and proposed fixes (strengthen prompt guardrail to forbid `snip` prefixing any command, harden anti-loop detection on byte-identical output with no new steps, and disallow snip bypass via config.toml). If DIA-078 fully captures the remedial work, treat that ticket as the authoritative trace for the patch; this failures entry records the operational impact and the specific recurrence vector (make vs jq) because it is not reconstructible from commit diffs alone.
  - Preventive action:
    1. Broaden the `snip`-prefix guardrail: forbid any command being prefixed with `snip` in prompts or tool-call scaffolding (not just `jq`).
    2. Harden anti-loop detection: if a subagent emits N (e.g., 3) byte-identical outputs with no net new steps or artifacts, stop further automated retries and escalate to human ownership.
    3. Capture full artifact output to disk (untruncated) for each verification run and attach as evidence to the ticket; do not accept truncated logs as proof of success.


- Failure mode (2026-08-10): ai--3 fabricated Phase-6 review
  - Symptom: an @ai-specialist dispatch requested as a "Phase-6 independent review" returned only a tail summary claiming "APPROVE-WITH-FINDINGS: 1 Minor, 2 Suggestions, 0 Blockers" with NO attached findings or evidence.
  - Root cause: mis-scoped lane use — ai-specialist was asked to produce a Phase-6 independent review (which is outside its Phase-1..5 remit) and produced an unsupported stubbed verdict instead of real findings; additionally, the orchestrator accepted the stub without verifying persisted findings.
  - Recovery: a task_id resume (ai--4) searched persistence (learnings/, CHANGELOG.md, messages.jsonl) and confirmed no findings existed. The honest re-run routed the task to @ai-auditor (ai--5) which produced a real verdict (REJECT with 1 Critical, 4 Major, 3 Minor, 1 Suggestion) that drove follow-up fixes.
  - Preventive action: do not accept ai-specialist Phase-6 verdicts without persisted findings; route Phase-6 independent reviews to @ai-auditor per AGENTS.md §2.5. Enforce that independent-review results include the full persisted artifact (findings + evidence) before marking Phase-6 complete.


- Failure mode (2026-08-10): Stale-gate recency block on legit persistence dispatch
  - Symptom: a @conspecter res009 dispatch referencing OPEN ticket DIA-075 (discovered 2026-08-09) was BLOCKED by the §10 TICKET GATE after the local-midnight recency boundary flipped (isRecent(DIA-075) false on 2026-08-10) even though the ticket was legitimately OPEN and approved for persistence work.
  - Root cause: recency-only precedence in the gate decision logic; the gate incorrectly required a ticket to be within the recency window rather than honoring explicit ticket-id precedence.
  - Recovery: re-dispatching the conspect referencing DIA-076 (today-dated) passed the gate and allowed persistence. The full fix is handled by DIA-063/DIA-076 plugin patches (tri-state explicit-id precedence) noted in learnings; this entry records the operational impact and workaround used during the campaign.
  - Preventive action: until the tri-state explicit-id precedence fix is live, any §10-scoped dispatch that needs persistence must reference a TODAY-dated OPEN ticket (e.g., DIA-076). Codify the temporary operational rule in runbooks and include a check in the preflight checklist to ensure ticket recency compliance.

- Failure pattern (session-3, 2026-08-10): multiple code-executor lanes hit step-budget exhaustion
  - Symptom: during session-3 all five code-executor delegation lanes in this campaign encountered "MAXIMUM STEPS REACHED" (cod-2, cod-3, cod-4, cod-5) while ai-specialist and ai-auditor lanes completed normally. Despite tools being disabled, each code-executor lane returned a final text-only report. The observed step-budget appears too small for multi-part config/docs tasks composed of 4–5 sub-sections.
  - Preventive action / mitigation in-hand: keep code-executor lanes narrowly scoped (single responsibility), front-load the full state into the prompt, forbid recon/resume-heavy flows that re-run large verification loops, and prefer multiple small lanes over one combined lane. Reference: lesson L20260810-003 and ticket DIA-078 evidence.

  - **Post-mortem correction (2026-08-11):** The root cause of the snip-wrapper loop was the opencode-snip plugin mechanically rewriting all bash commands to `snip <cmd>` via its tool.execute.before hook (res011 conspect), not model behavior alone. Prompt guardrails were structurally ineffective (DIA-078 L94: 3 consecutive lanes violated them). The defense-in-depth deny rules (2026-08-10) locked bash lanes completely when combined with the plugin. Fix: plugin removal (DIA-092) + deny rules retained as dormant guardrail. The snip binary is a display-trimming TUI helper with fork/exec + SyntaxError risks - zero legitimate agent use.

- Failure mode (2026-08-12): S18 boot-gate false-positive checksum escalation (DIA-061 -> DIA-120)
  - Symptom: at the S18 batch-approval boot gate a handoff checksum "mismatch"
    was reported that required a restore lane, even though the S17 handoff was
    valid. The escalation was a FALSE POSITIVE.
  - Root cause (two compounding faults):
    1. STALE-COMPARISON: the boot-gate comparison memorized the handoff file's
       checksum field from an earlier read and compared against that stale value
       at comparison time, rather than re-reading the file's checksum field at
       comparison time. Any legitimately-updated handoff file therefore looked
       like a mismatch.
    2. PLUGIN TRIGGER BUG: the delegation-observer plugin's handoff-writer fires
       on ANY log_decision with event_type='handoff' AND a non-empty prognosis
       string, including non-terminal status events (resolution_status
       'in-flight'). During the boot gate the orchestrator's boot-gate detection
       log (event_type='handoff', resolution_status 'in-flight', content_ref
       'handoff-detected', prose prognosis) triggered the plugin to OVERWRITE the
       valid S17 handoff file with a fallback wrapper, destroying the real
       prognosis.
  - Fix direction: (a) boot-gate comparisons must RE-READ the checksum field at
    comparison time, never compare against a memorized value; (b) agents must use
    event_type='decision' for progress/status events and reserve
    event_type='handoff' for genuine terminal handoffs (a prose prognosis with a
    handoff event is enough to trigger the write). The plugin trigger bug itself
    is tracked in DIA-120 (fix deferred to the section-10 chain).
  - Why irrecoverable: the false escalation chain (stale comparison + plugin
    trigger interaction) is runtime/session behaviour, not reconstructible from
    git diffs or the DIA-120 ticket alone (which documents the plugin bug but not
    the stale-comparison contributor or the agent-side event-type rule).
  - Cross-reference: lessons.md S18 "log_decision handoff-event trigger caveat";
    DIA-120.

- Failure mode (2026-08-13): aborted commit-lane dispatch left partial
  ticket-status edits (idempotent re-dispatch gap)
  - Symptom: a commit-lane dispatch was aborted mid-flight ("Tool execution
    aborted") AFTER it had already applied its A1/A2/A3 ticket-status edits. The
    re-dispatch discovered the edits already present and verified instead of
    re-applying.
  - Lesson: a re-dispatched lane MUST first verify whether a previous (possibly
    aborted) lane partially applied its changes before re-applying. The
    idempotent re-dispatch pattern is: (1) check the current state of the target
    artifacts, (2) apply only the missing delta, (3) verify idempotently.
    Blindly re-applying after an abort can double-apply or clobber earlier work.
  - Why irrecoverable: the abort occurred mid-flight and the resulting partial
    state is runtime/session behavior, not reconstructible from git diffs.

- Failure mode (2026-08-13): config permission hardening appears correct in file
  but runtime tool surface differs (DIA-126 root-cause chain)
  - Symptom: the DIA-126 autonomous overnight run stalled for hours because
    agents had no bash tool; the hardening commit 753e374 looked correct on read
    but never took effect, so the tool-coverage audit reported "0 hard gaps".
  - Root cause: a trailing `"*": "deny"` catch-all survived the hardening in the
    bash permission maps; OpenCode's findLast tool-visibility gate landed on the
    deny and hid the whole bash tool from the agent's function schema. The
    runtime tool surface differed from what reading the config implied.
  - Lesson: config changes to tool permission maps are ONLY verifiable by
    checking the actual runtime tool manifest (the agent's callable tool
    registry), not by reading the config file. The restart-verify manifest (a
    conspecter session with no bash) was the proof that caught it.
  - Preventive action: after any permission-map edit, verify the target agent's
    runtime tool manifest shows the intended tools present; and keep catch-all
    denies FIRST per DIA-036/DIA-081/DIA-126. Config-driven coverage audits that
    key on tool-name presence cannot catch a misordered catch-all.
  - Why irrecoverable: the config-vs-runtime divergence is runtime behavior not
    reconstructible from git diffs or the ticket alone.
  - Cross-reference: lessons.md catch-all-ordering trap; DIA-126, DIA-081.

- Failure mode (2026-08-13): escalated-lane (kimi-k3 ONE-SHOT) silent failure
  (DIA-130)
  - Symptom: @coder-escalated (kimi-k3) dispatched ONE-SHOT on DIA-130 at
    13:45:11Z ran ~9.5 minutes reading 5 config files and returned an EMPTY
    result at 13:54:44Z without writing anything (silent failure, no artifacts).
  - Root cause: the escalation lane completed with no deliverable; an empty
    result message alone is indistinguishable from a partial-write state, so a
    blind re-dispatch risks double-applying or clobbering a partial edit.
  - Preventive action: after ANY empty escalation result, run a dedicated
    state-inspection lane to confirm ZERO partial writes before re-dispatching
    any lane. The ONE-SHOT rule + A4 artifact gate + A3 retroactive consistency
    check caught this correctly. See lessons.md "Escalated-lane (kimi-k3
    ONE-SHOT) silent failure" and L20260810-001.
  - Why irrecoverable: the escalation lane's empty result and the
    state-inspection-before-re-dispatch recovery ordering are runtime/session
    behavior not reconstructible from git diffs; the fix commit (8cae0cd) shows
    the eventual outcome, not the silent-failure detection path.
  - Cross-reference: DIA-130, DIA-131; lessons.md escalated-lane silent-failure
    and backup-freshness lessons.
- Failure mode (DIA-161 regression, 2026-08-12): recursion fork-bomb in verify-pre-push.sh
  - Symptom: wiring `make test-shell` into scripts/verify-pre-push.sh (commit 49d587a) created a recursion fork-bomb inside poetry-dev. verify-pre-push.sh -> make test-shell -> bats -> runs verify-pre-push.bats which invokes the same script -> infinite loop. ~18s cycle, 6+ levels deep, dozens of /tmp/bats-run-* dirs, live chains lasting 1.5h. Confirmed via /proc inspection.
  - Root cause: the script invoked inside the dev container takes the direct branch (hostname==poetry-dev) and re-enters the full test suite; no re-entrancy guard existed in the script.
  - Test-side hermetic shim (commit bb18099, DIA-071) is necessary-but-not-sufficient: it covers the bats suite only and leaves manual/husky invocations vulnerable.
  - Preventive action: any gate script that invokes the full test suite MUST carry a re-entrancy guard (env-flag propagation, e.g. VERIFY_PRE_PUSH_RUNNING) so a nested invocation short-circuits instead of re-running the suite. Test-side PATH/hostname shims are defense-in-depth only, not the primary guard.
  - Reference: knowledge/ana015-recursion-fork-bomb/ (root-cause analysis), ticket DIA-161/DIA-165. This pattern is not reconstructible from commit diffs alone (the loop is a runtime interaction).

- Failure pattern (DIA-166, 2026-08-12): standalone-only verification missed hook-context guard-flag inheritance
  - Symptom: after the DIA-165 recursion-guard fix (commit 0760ef3) exported VERIFY_PRE_PUSH_RUNNING=1 in scripts/verify-pre-push.sh, the husky pre-push hook triggered the suite with the flag inherited by ALL bats tests; verify-pre-push.bats tests 183-187/189-191 invoke verify-pre-push.sh directly and hit the top-of-script guard (warning + exit 0), failing 8 tests. The standalone suite passed 211/211.
  - Root cause: DIA-165's verification ran the suite standalone (`make test-shell`, no inherited flag), which cannot reproduce hook-context env-flag propagation. No test-side `unset` existed in verify-pre-push.bats setup() to neutralize the inherited flag.
  - Preventive action: (1) verify hook-triggered suites with the hook-exact command (`VERIFY_PRE_PUSH_RUNNING=1 make test-shell`), not just standalone; (2) test setup() should unset inherited gate flags so tests exercise the script's public entry behavior; (3) if a test must verify the guarded path, re-export the flag inside the test body after setup.
  - Fix (commit d6c6a64): `unset VERIFY_PRE_PUSH_RUNNING` in verify-pre-push.bats setup() + a new guard test that re-exports the flag and asserts warning + exit 0 + no docker invocation. Verified hook-exact 212/212 + standalone 212/212.
  - Secondary finding: the unshare 127 warning in the original push failure was a transient race (storm-kill `rm -rf /tmp/bats-run-*` deleted an active suite's ns.sh between creation and exec), NOT a code/image gap.
  - Cross-reference: adr.md gate-script re-entrancy-guard ADR, DIA-166 ticket. Not reconstructible from commit diffs alone (the inheritance is a runtime hook-context property).

- Failure pattern (DIA-177, 2026-08-14): GREEN coder session LOST mid-dispatch on user opencode crash
  - Symptom: the GREEN implementation coder session was terminated mid-dispatch
    when the user's opencode crashed; on resume the on-disk state of the slice was
    unknown (partial-write ambiguity).
  - Root cause: a mid-dispatch crash leaves the writer's on-disk state
    indeterminate; a naive re-dispatch of a fresh writer lane over the same files
    risks double-applying or clobbering work that may already be fully written
    (uncommitted).
  - Recovery (correct): ran a read-only code-navigator recon FIRST to determine
    whether the interrupted task had actually written the implementation - it had,
    fully, uncommitted - then a VERIFICATION lane (not a re-implementation)
    confirming the on-disk code against the spec before dispatching review.
  - Preventive action: after ANY crashed/terminated writer dispatch (not just an
    empty result), recon first to establish what was actually written before
    re-dispatching any lane; never blindly re-run a writer lane on the same files.
    This generalizes the escalated-lane empty-result rule (state-inspection
    before re-dispatch) to the crash-trigger case.
  - Why irrecoverable: the interrupted-session recovery ordering is runtime/session
    behavior; the final commits (178b580, f9ab26c) show the outcome, not the
    recon-before-re-dispatch decision path.
  - Cross-reference: failures.md escalated-lane (kimi-k3 ONE-SHOT) silent failure
    (same state-inspection-before-re-dispatch rule); lessons.md DIA-177 section.

- Failure mode (2026-08-14): empty task result is AMBIGUOUS - verify ground truth
  via a read-only lane before deciding (cod-8/cod-9, session
  ses_fffe9d549ffeQnvwF0849RG19z)
  - Symptom: a DIA-103 closure lane (cod-8, session
    ses_fffb50ce7ffeLoOoEaMZ9pDiza) returned a COMPLETELY EMPTY task result - no
    summary, no changes, no verification evidence. Given the prior silent-failure
    history (DIA-130/DIA-098) this initially looked like a dropped writer.
  - Recovery: the orchestrator did NOT assume success and did NOT re-dispatch a
    fresh writer. It dispatched a READ-ONLY verification lane (cod-9) which
    confirmed the closure had FULLY landed: commit 442b17e present, ticket
    DIA-103-interview-batch-completeness CLOSED, CHANGELOG committed, push drift
    0/0. The empty result was a reporting artifact, NOT missing work.
  - Lesson: an empty subagent result is AMBIGUOUS - it can be either (a) a silent
    failure where nothing was written (DIA-130, 2026-08-13 variant), or (b) a
    reporting artifact where the work fully landed (cod-8, this session). The
    correct move is ALWAYS the same: verify the actual state against the repo
    and artifacts (commit present, ticket status, changelog, push drift) via a
    READ-ONLY inspection lane BEFORE deciding whether to re-dispatch. Do not
    re-dispatch the writer on an empty result (risk of double-apply/clobber a
    partial write) and do not assume failure - absence of evidence is not
    evidence of absence. This confirms the same pattern as DIA-132/DIA-098: the
    verify-first ordering, applied to the two possible empty-result outcomes.
  - Cross-reference: DIA-130 (silent-failure variant, 2026-08-13); DIA-098;
    failures.md 2026-08-06 reviewer empty-result resume; 2026-08-10 cod-4
    silent-empty result; commits 442b17e / 3322fdb / 43c0f7a.
  - Why irrecoverable: the empty-result interpretation and the verify-before-
    re-dispatch ordering are runtime/session behavior, not reconstructible from
    the commits (442b17e shows the closure outcome, not the empty-result
    detection and recovery path).

- Failure mode (2026-08-15, DIA-186): overnight.bats payload assertion drift - expanded permission payload broke the gate at merge because the test asserted exact-string payload equality
  - Symptom: the overnight permission payload (opencode-overnight.jsonc) was expanded with a developer-approved allow-list delta (DIA-186) beyond the DIA-134 baseline v1, but overnight.bats was not updated in the same change. The test's exact-string assertion against the full rule map no longer matched the expanded payload, so the gate broke at merge time.
  - Root cause: the test asserted exact-string equality with the full payload (a coupling that breaks on ANY additive change). The payload grows by design (new baseline-compatible rules), so an equality assertion is fragile and fails for the wrong reason (any expansion, not just invariant violations).
  - Fix (commit d18672b): switch overnight.bats to subset-presence contract arrays (baseline v1 keys + guard-denies + allow-list), asserting each invariant resolves to the intended "deny"/"allow" decision rather than exact-string equality with the full rule map. Additive changes no longer break the gate; removing or re-ordering an invariant rule does. The test is now the independent oracle.
  - Lesson: when a config payload is additive-by-design (permission allow/deny maps, deny-list baselines, appended section-10 CHANGELOG entries), tests must assert SUBSET-PRESENCE/INVARIANT contracts, not exact-string equality with the whole payload. Exact-string coupling turns a legitimate additive change into a spurious gate failure and masks invariant regressions. Update the test IN THE SAME change that expands the payload.
  - Why irrecoverable: the test diff (d18672b) shows the subset-presence arrays and the fix, but the process lesson - "exact-string coupling breaks on additive config growth; use invariant/subset-presence contracts and update the test atomically with the payload change" - is not stated in the commit.
  - Cross-reference: DIA-186 (fix commit d18672b), DIA-134 (baseline v1), .opencode/opencode-overnight.jsonc, scripts/__tests__/overnight.bats, adr.md DIA-186 ADRs.

- Failure mode (2026-08-15, DIA-085 review falsification F-1 CRITICAL): delegation-observer.ts atomicWriteHandoff same-millisecond same-session archive collision - two terminal writes for the same sessionId within the same millisecond compute an identical archiveName, and POSIX rename silently REPLACES the first archived prognosis (design claim "both prognoses survive" and proposal claim "no prognosis ever silently lost" are BOTH falsified).
  - Symptom: the DIA-085 implementation review found that the archive-file name derivation (delegation-observer.ts) keys on sessionId + a millisecond-resolution timestamp. Two terminal handoff writes for the same session within the same millisecond produce the identical archiveName. POSIX rename() onto an existing name atomically replaces it, so the first prognosis is silently destroyed - the exact "silent loss" the feature was designed to prevent.
  - Root cause: archiveName uniqueness depends on millisecond resolution (or an equal sessionId + timestamp), which is not a uniqueness guarantee under same-millisecond double-fire. There is no monotonic counter / UUID / presence-check before rename.
  - Current state: NOT yet live - the handoffs/ directory is absent (legacy current-handoff.json authoritative) - so there is still time to fix before activation.
  - Preventive action: needs developer disposition (interactive review gate). Candidate fix: disambiguate archiveName with a monotonic counter or UUID suffix, or use write-if-absent (O_EXCL) semantics instead of rename-overwrite.
  - Why irrecoverable: the review result is the ONLY record of this finding - it is not yet in any ticket or commit. The delegation-observer.ts source shows the rename logic but not the review's falsification verdict against the design/proposal claims.
  - Cross-reference: DIA-085 (commit c966b8d), .opencode/plugins/delegation-observer.ts, repo.md parallel-handoff-slots-not-live entry.

- Failure mode (2026-08-15, DIA-085 review falsification F-3 CRITICAL): slot identity `parentSessionId ?? lane_id ?? "unknown"` collapses parallel resumed-orchestrator sessions firing a terminal handoff before any task() dispatch into the same handoffs/unknown.json (last-writer-wins clobber - the exact class DIA-085 claims to eliminate).
  - Symptom: for a freshly resumed parallel orchestrator session that fires a terminal handoff BEFORE any task() dispatch, both parentSessionId and lane_id are unset/undefined, so the slot identity falls through to the literal "unknown". Two such sessions write the same handoffs/unknown.json; the second silently clobbers the first.
  - Root cause: the slot-identity fallback chain collapses distinct sessions onto a shared "unknown" key precisely when session context is minimal (pre-first-dispatch), which is a realistic state for resumed parallel orchestrators.
  - Current state: NOT yet live - handoffs/ dir absent; legacy current-handoff.json authoritative - still time to fix before activation.
  - Preventive action: needs developer disposition (interactive review gate). Candidate fix: use the actual sessionId as the last resort (or a per-write unique id) so two sessions never collide on "unknown".
  - Why irrecoverable: review result is the ONLY record; the design's claim to eliminate last-writer-wins clobber is falsified by this case and the finding is not yet in any ticket/commit.
  - Cross-reference: DIA-085 (commit c966b8d), .opencode/plugins/delegation-observer.ts slot-identity logic.

- Failure mode (2026-08-15, DIA-085 review falsification F-2 MAJOR): scripts/validate-handoff.sh:122 uses GNU-only `find -printf` in a HOST-documented gate - make test-config runs on host per AGENTS.md section 6 - so it is silently dead on BSD/macOS hosts.
  - Symptom: the DIA-085 review flagged validate-handoff.sh line 122 using `find -printf` (GNU find), which is not available on BSD/macOS find. Since make test-config is documented to run on the HOST (AGENTS.md section 6), a BSD/macOS host would silently skip/fail that check.
  - Root cause: the script is written for GNU findportability while the host gate contract is platform-agnostic.
  - Preventive action: needs developer disposition. Candidate fix: replace `find -printf` with a portable pattern (find + -print0 piped to a POSIX-compliant formatter, or a shell/python loop).
  - Why irrecoverable: the review result is the ONLY record of this portability defect; it is not in any ticket/commit yet.
  - Cross-reference: DIA-085, scripts/validate-handoff.sh:122, AGENTS.md section 6 (make test-config host gate).

- Failure mode (2026-08-16, cod-12 merge-lane session error): the merge-lane
  subagent (cod-12) errored and its session is not reusable per the job board.
  - Symptom: cod-12 returned a session error with no partial work landed; git
    state was clean.
  - Root cause: the cod-12 session errored (job board marks errored sessions as
    not reusable). Recovery via exact-instance resume is not possible for an
    errored session.
  - Recovery: verify-first read-only confirmed nothing was committed (git state
    clean, WORK_LANDED: no); the fix was a FRESH dispatch with verify-first,
    NOT a resume of the errored session.
  - Preventive action: treat errored sessions as non-resumable per the job board;
    dispatch a fresh lane with verify-first instead of attempting a resume.
  - Why irrecoverable: the errored-session-not-reusable rule and the
    fresh-dispatch recovery are operational knowledge not in any commit.
  - Cross-reference: cod-12, DIA-099, resume-truncated-lane skill, 2026-08-16
    merge lane.

- Failure mode (2026-08-16, DIA-085 root-owned ticket file): a container-created
  ticket file under docs/ landed as root:root on the host mount, so OpenCode's
  OS-level write was denied; the lane copy-replaced it with a qualt-owned file to
  unblock edits.
  - Root cause: files created by processes running in the dev container (here the
    DIA-085 ticket file) inherit container UID 0, and on the host bind mount they
    appear root:root, which blocks the host-side editor/agent (qualt) from writing.
  - Preventive action: when a lane reports a write-denied on a docs/ or
    container-managed path, first check file ownership (`ls -l`); if root:root,
    copy-replace to the dev user (chown/cp) before retrying the edit. Prefer
    container hooks creating files to chown after creation. Distinct from the
    pre-commit lint-staged flip (L20260815-014/015) but same ownership mechanism.
  - Why irrecoverable: the ownership state (root:root) is runtime filesystem
    state on the host mount, not reconstructible from git (which records content,
    not inode ownership); the check-ownership-before-edit rule is operational.
  - Cross-reference: DIA-085 ticket file, .opencode/memory/lessons.md
    L20260815-014/015 (related root-flip), 2026-08-16.

- Failure mode (2026-08-17, DIA-191): ai-specialist lane returned EMPTY
  results 3 consecutive times (session-return failure signature)
  - Symptom: the ai-specialist lane failed EMPTY 3x during DIA-191 Phase-1
    research. Signature: the session STARTS and reads files, then returns an
    EMPTY final result - a session-return failure, not a content failure, and
    no endpoint error surfaced. The lane issue is systemic and not yet
    diagnosed.
  - Recovery: the research was routed to @coder as a substitute lane and
    completed successfully (DIA-191 Phase-1 gate research).
  - Preventive action: when a designated lane fails EMPTY 3x with the
    session-return signature, route the work to a reliable substitute lane
    (@coder for read-only research) rather than looping the same lane; file a
    follow-up for the systemic lane diagnosis. Distinct from the
    endpoint-outage variant (L20260816-006) and the model-level fix
    (L20260817-004).
  - Why irrecoverable: the failure signature and the routing decision are
    runtime/session behavior, not reconstructible from commits.
  - Cross-reference: DIA-191, L20260816-006, L20260817-004, DIA-099 (3-failure
    cap), adr.md DIA-189 model-array fallback.
