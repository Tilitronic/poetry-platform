# Lessons from 2026-08-01 dev-infra & config workflow change

These lessons capture irrecoverable, human-context knowledge discovered during the recent dev-infra/config workflow work. Only items that are not recoverable from git logs, diffs, tests, or code are recorded here.

- doc-contract-must-mirror-algorithm: during DIA-045 we observed documentation language (AGENTS.md §9) that described a stricter "4‑way lockstep equality" than the validator implemented (containment). Lesson: policy/docs language must precisely mirror the enforced algorithm; when validators are changed, update the human-facing contract text in the same change or add a cross-reference that points to the authoritative algorithm. Record as an operational doc-governance rule.


- boss/orchestrator role enforcement (process): a HARD RULE was required to stop the boss from implementing dev-infra or config changes directly. The cultural/coordination lesson: small mechanical edits by an orchestrator reliably reoccur unless explicitly blocked. The fact that a HARD RULE (boss_append.md) was added and why it was necessary is a human-process lesson not present in code history.

- Host vs container orchestration (operational rationale): turbo runs inside containers and cannot reliably manage host-level services (Docker daemon, docker-compose, Xvfb setup). The pragmatic boundary decision — keep host orchestration in host-side scripts (scripts/dev-stack.sh) and keep turbo for in-container tasks — is stored in the ADR but this lessons entry records the human reasoning and operational expectations teams should follow when designing dev workflows.

- Shell-test hermeticity pattern (testing practice): For unit-testing shell entrypoints and orchestration scripts without launching real privileged services, we used a combination of:
  - vendor-pinned bats-core in scripts/__tests__/vendor/ (to avoid external installs)
  - a mocked docker binary placed earlier in PATH for unit tests
  - user-namespace isolation (unshare -r -m) and tmpfs mounts over /run to avoid touching host state
  - Xvfb invocation in a controlled temporary DISPLAY for display-requiring smoke tests

  This pattern (mock binary + user namespaces + tmpfs) is operational knowledge about how to make shell tests fast, hermetic, and safe in CI/local dev and is not reconstructible purely from code diffs.

- JSONC/comment-stripping caveat (validator): naive comment-stripping using regexes can break on URLs containing '//' and similar character sequences. The validator was implemented using a proper JavaScript tokenizer to strip comments safely. Record: use a tokenizer-aware approach when removing comments from JSONC; do not rely on naive regex replacement.

- Verification outcome (human confirmation): Final verification run produced bats 13/13, pytest 2/2, and config validation OK. The fact that reviewers iterated and that fixes were required (pinning bats-core, hermeticity tweaks, test renames, and .gitignore cleanup) is documented in the change history but the human lesson is: independent review (ai-specialist + reviewer) found maintainability and hermeticity issues that otherwise slip by when implementers work alone.

- Campaign registration pattern (2026-08-03): Owner-followed convention during this audit run — implementation changes were applied but the final commit was deferred until the owner restarts OpenCode and runs the 10-item post-restart smoke checklist. The registration lane then syncs the ledger (OPEN→IMPLEMENTED) and appends the CHANGELOG and learnings entry in a single atomic commit. This owner-driven commit-after-restart behavior is session-scoped and not recoverable from git alone; record it as an operational lesson for future audits.

- Verify against deployed npm dist, not vendored fork source: During the audit we found behaviour differences between the deployed oh-my-opencode-slim@2.2.8 dist and the repo's vendored/forked source. Runtime semantics (deepMerge array handling, agent default resolution) must always be verified against the deployed npm dist artifact (e.g. ~/.cache/opencode/packages/oh-my-opencode-slim@2.2.8/dist/index.js); rely on the deployed dist as the ground-truth for runtime behaviours. This is not recoverable from code diffs and should be consulted for future audits.

- Mock-mode blindspot: unit/mocked tests passed while real API runs failed due to a double-/api base URL bug that only real network runs caught. For networked dev-infra scripts, add at least one real-API smoke run to the verification matrix (optionally gated behind an env var like CONTEXT7_API_KEY_REAL_RUN) so base-URL and auth header mismatches are caught before merging.

- Model window drift lesson (2026-08-03): operational manuals that copy model metadata (context windows, token limits) into repo docs can silently diverge from live model catalogs. In our recent campaign a handoff threshold fired at ~95,627 tokens because the NEXT-RUN.md table used a stale 64k value for `deepseek-v4-flash` (V3). The real V4-Flash window is 1,000,000 tokens; after correction the same usage was only ~9.6% of the true window. Lesson: when making rerun/handoff decisions, verify context windows against models.dev (the canonical catalog) or the model vendor's model card; do not treat in-repo lookup tables as authoritative without a verify-on-use step.

- Context7 301 handling nuance: Context7 indicates moved libraries via 301 responses carrying a JSON body with redirectUrl (not Location header). When redirectUrl missing or not resolvable, the pipeline treats the library as "skipped" rather than "failed"; however, redirect-loop exhaustion is considered a failure. This behaviour was agreed in spec review — kept in lessons because the operational nuance (301+body) is easy to miss during later API client changes.

- Reviewer prompt / orchestrator budget lesson (2026-08-03): during the §10 campaign the reviewer/orchestrator prompt length soft-budget was exceeded in practice (design budget ~2,000 chars vs actual ~3,225ch used). Operational lesson: always validate prompt-size budgets against the actual file state and the concrete prompt assembled at runtime (not just the design assumptions). Add a pre-merge check that computes prompt length and warns when it will exceed the soft budget so reviewers can trim or split prompts before the change lands. This is not reconstructible from git diffs or changelogs and is stored here as an operational safeguard.

- Project-scope skill shadowing (2026-08-03): when adopting or merging a global skill into the platform, check for an existing project-scoped copy (same skill path under .opencode/skills/) because project copies shadow global merges and must be synchronized or removed. The existence of a project copy means the global update will not affect runtime until the project copy is updated or deleted; record this as a deployment-time checklist item. This nuance is recoverable from file inspection but is an easily-missed operational rule and thus recorded here for future orchestrators.

- envsitter-plugin tool-name caution (2026-08-06): the envsitter-guard plugin exposes a specific list of tool entrypoints (envsitter_add/annotate/copy/delete/fingerprint/format/help/keys/match/match_by_key/reorder/scan/set/unset/validate). During the campaign some spec text and permission blocks referenced non-existent helpers (envsitter_read/envsitter_edit). Preventive rule: enumerate and validate plugin tool names directly from the plugin dist package or the plugin's published manifest before writing permission or allow lists. This operational fact (plugin dist vs spec mismatch) is not always recoverable from the repository and is stored here to avoid future permission misconfigurations.

- §10 workflow validation (2026-08-06): this campaign completed the first full run of the AGENTS.md §10 AI Devtools Modernization Workflow (Phase-1 gate → Phase-2 decision → Phase-3 design → Phase-4 implement → Phase-5 validate → Phase-6 independent review). What worked: the ai-specialist independent review materially caught a config overlap (F4) that implementers missed and the validate-agent-names + test-config gates (22/0/0, 0 failures) enforced correctness. Operational lesson: require an explicit Phase-6 independent ai-specialist review for future opencode config changes; this is a process-level lesson not reconstructible from git alone.

- Spec errata convention (2026-08-06): when implementation realities diverge from spec wording in ways that are clarifying (for example, 5→3 deletions due to byte-exact dup detection), append an `Errata (date):` blockquote to the change's artifacts rather than editing the contractual AC text. Rationale: preserves the original contract for traceability while documenting pragmatic implementation corrections; this practice prevented openspec-validate churn during the campaign and is not recoverable from code diffs.

- Discovery reliability: code-navigator inventory vs ground-truth (2026-08-04): during the dev-environment audit the code-navigator agent reported 4 artifacts as MISSING/orphaned which the validation loop later confirmed were PRESENT on disk and valid. Root cause: the subagent's listing heuristic (agent-scoped file index) can lag or mis-scan transient working-tree state and is not authoritative.
  Preventive action:
    1. Treat autonomous subagent inventory reports as heuristics; always verify critical artifact existence with the project's verification scripts (validate-opencode-config.sh, jsonl-stats.sh, scripts/__tests__ checks) or direct filesystem inspection before acting on 'missing' findings.
    2. Add a post-scan verification step in the inventory lane that runs the repository's validation scripts and reports diffs between the subagent index and the validator output.
  Notes: this lesson is session-scoped and not reconstructible from git; check for existing similar lessons before appending.

- Orchestrator JSONL sidecar & session files are ephemeral (irrecoverable): during the §10 campaign the orchestrator was changed to dual-write a JSONL sidecar (.opencode/session/messages.jsonl) alongside the human-readable messages.md. Both the JSONL sidecar and the session/ README pin for the OTel GenAI semconv are stored in the session/ directory which is gitignored. These files are ephemeral and will be lost on a fresh clone; record the operational expectation that any important pins or sidecar schema pointers written to session/ must be copied into tracked docs or memory entries before finishing the audit.

- Background-job-board sentinel label mismatch (operational gotcha): the background-job-board uses its own sentinel aliases for agent/task IDs (e.g. ai--1, cod-2) which can differ from the campaign lane IDs used in messages.md logs (e.g. ai--3, cod-11). This misalignment can produce "unreconciled" flags for completed sessions when automated reconciliation relies on matching these IDs. Reconciliation is mechanical and possible by referencing messages.md rows, but the mismatch is a recurring operational pattern worth documenting so future automation accounts for alias mapping or normalizes IDs during ledger sync.

- Exact-instance resume success pattern (2026-08-04): During Tickets System 2.0 we validated that resuming a completed subagent session by passing the original task() result's task_id (the session ID) reliably resumes the exact prior session and allows context reuse. Contrast: attempting to resume by sentinel alias or background-job-board alias does NOT restore the prior conversation payload. Operational guidance:
  1. Always capture and persist the task() result.task_id when dispatching subagent tasks if future resume/recall is required.
  2. Treat sentinel/alias labels as human-friendly pointers only; they are not guaranteed to carry the conversation payload needed for programmatic resume.
 3. Record the task_id in the registry.jsonl sidecar (delegation-observer plugin) to enable exact-session lookup across reboots and restarts.
  Note: this success path was validated in-session (cod-3 → resumed cod-2; cod-4 → resumed cod-3) and is not reconstructible from git diffs alone; record it here to guide future orchestrator behaviour.

- MCP auth header mismatch risk: opencode.jsonc currently configures the Context7 MCP to send a header named CONTEXT7_API_KEY (env). The upstream server accepts Authorization: Bearer <key> and several X-* header variants but does not accept the literal header name CONTEXT7_API_KEY. This is a probable config mismatch risk for MCP-based fetches. Recommendation: update MCP config to use Authorization: Bearer or X-Context7-API-Key, and verify in a real MCP load test. This header-name acceptance detail is not present in repo diffs and is recorded here as an operational lesson.
 - MCP auth header mismatch risk: (OUTDATED) earlier notes stated the upstream server "does not accept the literal header name CONTEXT7_API_KEY". Subsequent verification against Context7 server source and the change in .opencode/ shows this is incorrect: the server accepts Authorization: Bearer <key> (canonical) and also accepts several legacy aliases (context7-api-key, x-api-key, context7_api_key, x_api_key). HTTP headers are case-insensitive, so CONTEXT7_API_KEY (env-written) is equivalent to the accepted legacy alias when present. The authoritative details and rationale for switching to Authorization: Bearer (and adding oauth:false + increased timeout) are in .opencode/learnings/external-patterns/2026-08-02-context7-mcp-registration.md. Keep the lesson to warn about header-name risks, but correct the factual error and point to the learnings note for details.

- Telemetry pricing gap (2026-08-03): during post-restart verification we observed that token_stats reported $0.0000 pricing for the opencode-go/deepseek-v4-flash model (displayed as zero cost despite measurable usage). This appears to be a telemetry / provider-metadata gap (pricing lookup missing for that model) rather than a code/config error and is NOT recoverable from git history or repo files. Operational guidance: treat token_stats pricing fields as advisory; when making budget decisions or preset rebalance choices, cross-check with the vendor pricing catalog or fallback to explicit cost-mapping in opencode's pricing config. Record here so future audits do not assume token_stats always contains valid pricing.

- Copilot drain visibility nuance (2026-08-03): measurement of Copilot credit drain in token_stats can be preset-dependent. In this campaign we learned Copilot utilization was only observable in token_stats when sessions ran using the cebula preset (which assigns Copilot seats). A session running on an opencode-go preset did not surface Copilot credit consumption in the same way. Practical takeaway: when auditing or monitoring cross-preset spend (Go vs Copilot), run representative sessions for each preset in use or rely on an aggregated billing view; do not assume a single token_stats run on one preset reveals cross-preset credit movement. This nuance is not present in committed config diffs and is recorded as an operational lesson.

- Dev-infra audit cleanup run (2026-08-03) — transient working-tree state: during the ledger-cleanup campaign the executor deleted 32 ticket files under docs/dev-infra-audit/tickets/ (rollup 36→4 kept: DIA-003, DIA-006, DIA-030, DIA-034) and updated README and _TEMPLATE.md. NOTE: these deletions and README edits are present in the working tree but were not committed at the time of this note. Because uncommitted working-tree state is not recoverable from a fresh clone, record this as an operational artifact and a required owner action: finalize commit or abort to reconcile ledger state. The owner also left three follow-ups: (1) NEXT-RUN.md line ~107 still references DIA-007 (dangling after deletion); (2) README Severity Guide line ~83 cites DIA-015 as a Blocker example (intentional); (3) two extra README in-file edits at lines ~46 and ~79 beyond the approved scope — awaiting owner acceptance.

- Template vocabulary drift (observed): the audit found the ticket template and campaign README used status/severity terms (DEFERRED, IMPLEMENTED, Medium/Low) that are not represented in the template enum/type system. This drift was noted in the campaign docs and remains an open housekeeping item: update the template enum or normalize ticket vocab on next run. This is a coordination note (not a code diff) and should be resolved before future ledger-cleanup runs to avoid enum/validation mismatch.

- Pre-commit / lint-staged partial-staging failure pattern (operational gotcha): when files are only partially staged (git add -p / git apply --cached hunks), lint-staged's auto-restage step can trigger git to attempt to restore unstaged changes. In some cases this restores conflicts ("Restoring unstaged changes to partially staged files" → MERGE CONFLICT) and the husky pre-commit hook exits non-zero, aborting the commit and leaving lint-staged's stash backup (e.g. stash@{0}). Practical, irrecoverable lessons learned:
  - Root cause: partial staging + lint-staged re-staging workflow can produce conflicts that git can't auto-merge.
  - Workarounds: (1) fully stage intended file contents before committing; (2) if stuck and expedient, use `git commit --no-verify` once to finalize the intended staged set (document the reason in the commit message) and then reconcile the stash; or (3) abort and re-apply hunks as full-file staged changes. This behaviour is runtime/working-tree state and not reconstructible from repo files — record it to warn future devs and reviewers.

- Shell "snip" output truncation gotcha (operational): in our environment certain CLI helpers / CI wrappers truncate or "snip" redirected stdout when output is written via tools that implement an --output=FILE flag or pipe through an adapter. The practical workaround when needing full blob output is to use explicit git plumbing or plain shell redirection, for example:
  - `git diff --output=FILE` or `git cat-file -p HEAD:<path> > FILE` to extract full blob contents, or use simple shell redirection (`command > out.txt`) instead of wrapper `--output=` options that the snipping layer mangles. This is an operational I/O quirk not visible in repo state and is recorded here.

- dev-infra-jq-probe snip-wrapper lesson (2026-08-08): a `snip` shell wrapper corrupts pipe-fed jq pipelines and produced an incorrect canonical checksum when used to run the handoff gate command. Lesson: run the canonical gate command raw (no wrapper). jq -c emits a trailing '\n'; use `tr -d '\n'` when computing byte-for-byte canonical checksums. The pipeline to validate handoff uses `jq -c '.prognosis | to_entries | sort_by(.key) | from_entries' | tr -d '\n' | sha256sum` and must not be wrapped. This operational I/O quirk was observed during a real restart boundary and is not recoverable from code diffs.

- snip-guardrail scoping lesson (2026-08-10): previous fixes forbade `snip`-prefixing for the `jq` probe only which left a failure-class hole. Lesson: guardrails that aim to prevent a behavioural class (e.g., snip-wrapper no-op loops) must be specified and enforced against the entire class (forbid `snip` as a command-prefix in any tool invocation) rather than a single command example. Implementation guidance: (1) make the guardrail rule declarative and pattern-based (`^snip\s+`) so it covers all commands, (2) include unit tests simulating multiple command forms, and (3) add an anti-loop watchdog that escalates after N identical, no-effect runs.

- verification-evidence capture (2026-08-10): truncated or snipped logs caused false-positive verification (truncated /tmp/opencode/test-config-full.log missed final summary lines). Lesson: always persist full run output to disk and attach the untruncated file to the ticket/registry entry. Prefer direct shell redirection (`command > /tmp/full.out 2>&1`) or git-plumbing blob extraction for artifacts that may be mangled by wrappers. Do not accept truncated snippets as sole evidence of success.

- trafilatura stdin gotcha (2026-08-09): empirical verification against trafilatura 2.1.0 found that the CLI's `--input -` convention is ambiguous and can error (exit code 2) because `--input` may match `--input-file` or `--input-dir` forms. Using `--input-file -` treats '-' as a literal filename and produces a FileNotFoundError. The reliable stdin usage observed in-session is the bare pipe form: `curl -s <url> | trafilatura --output-format markdown` (or `... | trafilatura --output-format markdown -`). Do not rely on `--input -` or `--input-file -` for piping stdin into trafilatura; use a bare pipe and direct trafilatura to read from stdin. This is an empirically-verified CLI behaviour (trafilatura 2.1.0 quickstart) and is not reconstructible from repo diffs or generic docs; record here to prevent future broken archival pipelines that assume `--input -` semantics.

- dev-container /tmp isolation (2026-08-08): when creating staging artifacts inside a devcontainer, the container's /tmp is not the same as the host's /tmp (WSL/container boundary and some devcontainer runtimes isolate ephemeral temp paths). In our run an upstream staging clone created in the devcontainer's /tmp was not visible to the host-side tools and the host Docker CLI was not reachable from that WSL distro (the distro's shell could not find `docker`). Practical consequence: do not rely on container /tmp as an authoritative cross-environment staging area. Persist important artifacts on the host or in the repository (or use a well-known shared path) so host-side reviewers and CI can access them. This is an environment-specific operational lesson and is not reconstructible from repo diffs.

- stale gate-token liveness probe lesson (2026-08-08): delegation-observer §10 liveness probes can be inconclusive if a stale valid gate token file exists at `.opencode/session/gate-tokens/ai-specialist-reviewed`. With the token present, writes to `.opencode/**` succeed (inconclusive); with the token absent, writes are BLOCKED with the message: "§10 GATE: Editing .opencode/ files requires @ai-specialist gate review." Recommendation: clear the gate-token before running liveness/blocked-path tests and restore it after via `log_decision gate-token/done`. Token lifecycle is managed by the plugin — do not attempt manual edits to token files.

- ai-specialist stub-result lesson (2026-08-08): an ai-specialist independent review returned an empty/stub result message (`"Review complete. Findings logged via log_decision"`) without the substantive artifact payload, violating the A4 artifact gate. Operational mitigation: enforce artifact-content on ai-specialist results; treat a stub as non-deliverable and resume the original reviewer session (call task() with the original task_id) to retrieve the full report. If resume repeatedly returns empty, escalate to human ownership.


- Phase-6 §10 independent review lane = @ai-auditor (2026-08-10)
  - Lesson: Phase-6 independent review is the responsibility of @ai-auditor; ai-specialist covers Phases 1–5 only. AGENTS.md §2.5 was updated 2026-08-10 to reflect this lane boundary. Operational rule: route Phase-6 independent review requests to @ai-auditor and require persisted findings (findings + evidence) before closing Phase-6.


- Registry description-capture quirk (observability defect)
  - Symptom: the delegation-observer background job board showed the stale objective "Verify handoff checksum DIA-061" for ALL coder-lane sessions (cod-1..cod-5) regardless of actual dispatch description, while ai-specialist/ai-auditor/conspecter lanes showed correct descriptions.
  - Likely cause: description reuse or sentinel-label collision for coder lanes in the delegation-observer mapping.
  - Impact: misleading background job board descriptions (observability defect) though session results remained correct. Not blocking but confusing for operators. Consider opening a follow-up DIA ticket to track the fix.


- Gate correlation for §10 dispatches pre-fix (operational rule)
  - Lesson: until the tri-state explicit-id precedence plugin fix (DIA-063/DIA-076) is live, any §10-scoped dispatch that must persist artifacts should reference a TODAY-dated OPEN ticket (e.g. DIA-076) in the dispatch text to avoid the recency cliff blocking legitimate persistence work.

- probe-lane sizing lesson (2026-08-08): a combined probe + test-config lane caused cod-2 to hit MAXIMUM STEPS mid-protocol and required resumption (cod-3). Lesson: split probe and verification lanes into smaller, single-responsibility lanes to avoid step-cap exhaustion and make failures easier to resume.

- Hunk-splitting / coalesced-change workaround (git add -p limitations): when multiple adjacent pure-add blocks or closely coalesced edits are present (for example CHANGELOG append-only blocks or mixed logical changes merged into a single hunk), `git add -p` and its `s` (split) option cannot always separate the edits. Practical workaround used:
  - Create a patch that contains only the desired logical edits by computing the HEAD blob for the file and applying a crafted patch via `git apply --cached` after editing the three diff header lines (diff --git, --- , +++ ) to match the file path. Another approach is `git diff --no-index` against a temporary file that contains only the edits you want, then `git apply --cached` that patch. Record this as a non-obvious, recoverable-by-hand technique for producing fine-grained commits when `git add -p` cannot split hunks. This is an operational technique (working-tree/patch crafting) not recoverable from repo diffs.

- PyYAML presence in CI images (2026-08-03): validate PyYAML presence in CI images to avoid differing validator behavior — validate-skills.sh runs the PyYAML path on hosts with PyYAML (e.g. dev host 6.0.3) and the fallback parser (extra nested-skip WARNs) elsewhere; ensure CI/dev containers install PyYAML for consistent gate output.

- Tool read/grep line-truncation limitation (2026-08-03): during the §10 verification-loop campaign we encountered a tooling limitation where the repository read/grep helpers truncate lines at ~2000 characters when returning file contents. This broke automated verification of very long reviewer/orchestrator prompt blocks (the assembled orchestrator prompt exceeded the truncation threshold), making full prompt inspection impossible without a restart or alternative extraction approach. Operational mitigations:
  - Prefer JSONC-aware parsing and targeted extraction of fields rather than reading whole files when expecting long single-line blobs.
  - Add a post-restart "make test-config" / restart verification step if tool-assisted reads are truncated.
  - When assembling or validating long prompts, compute and warn about prompt length ahead of time and write trimmed artifacts to tracked files for post-commit verification.
 This is an environment/tool-behavior fact (not present in git) and therefore recorded here as an irrecoverable lesson.

- Volta→Mise openspec campaign pause state (2026-08-03): while the §10 campaign was paused mid-interview, an openspec change directory `openspec/changes/volta-to-mise/` appeared in the working tree as untracked (time window ~16:51–16:54). The fact that the campaign was paused at messages.md row ~158 and that the change dir existed during the pause is session-scoped working-tree state and is not recoverable from git after a fresh clone. Operational guidance: when pausing an OpenSpec interview/session, explicitly record a session marker (in the git-tracked messages or memory) if the presence of in-progress untracked artifacts must be preserved for handoff. This note captures that transient state so future auditors know the campaign produced an uncommitted openspec dir during a pause.

- Failure-side lesson (2026-08-04): claimed exact-instance resume must be provable at call-time. During DIA-045 an orchestrator message asserted an "exact-instance resume" but the subsequent task() invocation omitted the task_id parameter, causing a fresh, empty session to run and producing no edits. Preventive guidance:
  1. Always verify the task() call includes the original task_id before announcing or logging an exact-instance resume; treat task_id presence as proof.
  2. Instrument the orchestrator to assert and log task_id at call-time; if missing, fail fast and rerun the subagent explicitly, recording the new session ID.
  3. Record original and replacement session IDs in messages.md and the registry sidecar to make post-mortem reconstruction possible. This operational failure mode is not recoverable from git or changelogs and is therefore recorded here.

- Acceptance-criteria (AC) wording ambiguity — tokens-only vs literal interpretation (2026-08-03):
  - Summary: During the volta→mise change the implementation team and reviewers negotiated a pragmatic interpretation for several ACs that were written as absolute textual requirements (example: "no volta references"). The implemented enforcement used a tokens-only automated check for build/runtime artefacts while allowing historical comments and non-executable textual traces to remain in docs. This reconciliation was resolved via reviewer/orchestrator discussion and is not fully encoded in committed artifacts.
  - Why this is irrecoverable: The conversational resolution between implementer and reviewer about which ACs would be enforced literally versus heuristically (tokens-only) and the resulting guidance to update AC language in future specs occurred during review and is not present in a single committed file.
  - Guidance: When authoring ACs in OpenSpec, include an explicit `check-mode` field (literal | tokens-only | structural) and an example clause for allowed historical comments or non-executable traces to prevent interpretation drift during implementation.

- Tooling-workaround: gh CLI `pr edit` regression (2026-08-04)
  - Symptom: `gh pr edit` exits 1 and can leave the PR body empty when the client requests a deprecated GraphQL field (`repository.pullRequest.projectCards`). The failure surfaced as a silent/partial edit in automation pipelines.
  - Workaround: use the REST API patch: `gh api -X PATCH repos/{owner}/{repo}/pulls/{n} -F body=@file` to set the body from a file. In scripted contexts avoid `git commit -F -` when wrapper shells may consume stdin; prefer `-F <tempfile>`.
  - Rationale: a tooling regression/behavior that is not recoverable from repository diffs or commits; record here so automation lanes can avoid fragile `gh pr edit` usage.

- Openspec CLI permission-shadowing gotcha (2026-08-04)
  - Symptom: an openspec-plan bash permission set included a catch-all `*` deny which shadowed a more specific `openspec *` allow rule, making the openspec CLI unreachable from certain lanes while coder lanes remained functional.
  - Preventive action: avoid broad-deny permission patterns that can shadow narrower allows; prefer explicit denies and validate CLI reachability from the intended lane. Route openspec CLI invocations through a bash-capable lane or fix the permission predicate via config.
  - Rationale: an agent permission subtlety about runtime lane capabilities; this operational fact is not reconstructible from code diffs and is worth persisting.

- openspec-plan bash-tool snip-prefix deny pattern (2026-08-06): during the dev-infra-language-servers campaign the openspec-plan lane's bash tool invocations were systematically blocked by an environment/agent-layer snipping policy that prefixed attempted commands with `snip` and caused the callable-tool registry to drop or deny bash execution (even simple commands like `pwd`/`echo`). Consequence: the spec agent could not run `openspec validate` and the validate gate was routed to the coder lane which executed it (exit 0). Operational lesson:
  1. When an openspec-plan (spec-authoring) lane exhibits a snip-prefixed deny for bash/tool calls, route the `openspec validate` gate to a coder or bash-capable lane rather than pausing the pipeline waiting for the spec agent to gain bash rights.
  2. Prefer explicit pre-flight checks for callable-tool reachability from the intended lane (a short `which bash` / `tool-registry` probe) as part of the change's preflight checklist so gate ownership can be assigned correctly at merge-time.
  3. Record this as an operational mitigation; this deny pattern is an environment/session-level behavior and is not reconstructible from repository diffs.

- Line-number citation drift (process lesson): independent reviewers and auditors produced different line-number citations for the same residual NEXT-RUN.md manual-append references (examples: reviewer A cited lines 41/55/97/172/199 while reviewer B cited L41/L54/L72-73/L98/L128/L172/L199/L211/L221). Root cause: long documents and frequent edits produce line-number drift across reads; human references to line numbers become fragile. Preventive action: prefer content-grep matches (unique string anchors) or structural anchors (heading + short context) in reviewer findings and automated prompts. Record this as an operational rule because line-number instability cannot be recovered reliably from git diffs alone when documents are edited in-session.

- Verify filter assumptions against ground truth (process lesson): a naive filter assumption (`writer == "plugin"` as a discriminator) proved incorrect because the registry sidecar was already plugin-written for legacy rows, making that filter a NO-OP. Preventive action: before implementing a filter-based gate, validate the discriminator against a real sample of the dataset (check histogram of values, edge-case legacy rows, and missing-field semantics). Record this as a pre-flight checklist item for future cross-file gating logic; while the script's header documents the concrete fix (timestamp `--since`), the generalizable verification rule is irrecoverable from code diffs and is therefore stored here.

- §10 deny-semantics (registry-absence vs invocation-error) — observed 2026-08-06 (session rows 493-507):
  - Symptom: after applying a minimal opencode.jsonc deny ("token_export": "deny" at line ~231) the verification smoke did not return a permission-denied runtime error when attempting to call token_export; instead the subagent's callable-tool registry no longer listed token_export. The absence-from-registry is the reliable proof that a deny is active for subagents (the runtime removes the tool from the callable registry), not the presence of a permission error text.
  - Operational lesson: to verify an OpenCode tool deny for a subagent, inspect the subagent's callable tool registry for the tool's ABSENCE. Do not rely on invocation-time error messages which may not be produced.
  - Reference: campaign session rows 493-507 (§10 CONFIG-GAP → FIX; re-smoke deny semantics discovery).

- Token-tool stacking hazard (DIA-056 discovery) — observed 2 occurrences during §10 runs (session rows 494, 504):
  - Symptom: repeated token-tool invocations (token_history/token_stats/token_export) inside smoke/verification lanes caused subagent sessions to stack and eventually error/cancel (session error / cancelled). Two distinct occurrences reproduced the pattern during the campaign.
  - Mitigation (operational): avoid looping token-tool calls inside subagent smoke/verification lanes. Use strict single-attempt, no-loop briefs for token tools. Prefer config-level verification (check callable-tool registry) to assert allow/deny state rather than runtime invocation, and implement a 1-attempt cap plus explicit backoff/escalation to prevent stacking.
  - Ticket: DIA-056 created with fix candidates; record this operational pattern here because it is not reconstructible from code diffs alone.

- cancel_task control-plane reachability note (session row 506):
  - Observation: the cancel_task control-plane tool is reachable from ai-auditor lanes and is state-mutating. It was NOT present in the ai-auditor deny block at the time of the §10 run and therefore counts as a data point in the DIA-055 S-series (permission surface review). Operational guidance: treat cancel_task as a high-sensitivity control-plane tool when authoring allow/deny lists.

- Telemetry recurring-writer & guard durability (rows 508-510):
  - Symptom: a local recurring writer repeatedly reverted a portability guard in `.opencode/commands/telemetry-report.md` and `telemetry-inspect.md` (4th occurrence during this campaign). The committed pre-commit/pre-push guard (guard_no_home_qualt) prevents leakage into commits and is intentionally the durable defense.
  - Operational lesson: expect and accept local revert noise from an unidentified writer so long as the committed guard holds. Document that local reverts are EXPECTED and non-blocking; do not escalate unless the guard is bypassed or commits contain the literal HOME expansion.
  - Reference: audit revert patch `/tmp/opencode/telemetry-revert-4th-20260806-1151.patch` and session rows 508-510.

- opencode-telemetry registerCommands working-tree pollution (2026-08-08):
  - Symptom: the opencode-telemetry plugin's registerCommands() unconditionally wrote `.opencode/commands/telemetry-report.md` and `.opencode/commands/telemetry-inspect.md` with expanded absolute $HOME paths on every plugin load, leaving those files dirty in the working tree after any OpenCode restart. The literal HOME insertion was observed repeatedly during the session and restored locally with `git restore -- <files>`.
  - Why irrecoverable: the repeated working-tree pollution is a runtime/plugin behaviour (not present in our repo commits) and therefore not reconstructible from git history alone. A ticket was opened (DIA-069) to stop unconditional writes and make the operation idempotent or guarded.
  - Mitigation/workaround: locally restore with `git restore -- .opencode/commands/telemetry-report.md .opencode/commands/telemetry-inspect.md` and rely on the pre-commit guard `guard_no_home_qualt` to block accidental commits until the plugin fix lands.


- DIA-070: vendored-patch / volatile-cache shadow-copy hazard (2026-08-08):
  - Symptom: applying hotfixes by vendoring patched dist files into the volatile npm cache (e.g. `~/.cache/opencode/packages/`) left other runtime-installation locations unpatched (example: `~/.config/opencode/node_modules/opencode-telemetry` and unscoped/@latest cache aliases). A fresh process restart sometimes loaded an unpatched copy, silently regressing the fix.
  - Why irrecoverable: the presence of multiple runtime install/cache paths and their state during a session is environment-level and not reconstructible from git or the plugin repo. The exact regression path depended on which cache alias the runtime resolved at startup.
  - Preventive actions (operational):
    1. When vendoring patches into a runtime cache, map and patch every possible install path and cache alias that the runtime may resolve at startup (global, user config, scoped/@latest aliases). Do a targeted `ls` of `~/.cache/opencode/packages/`, `~/.config/opencode/node_modules/`, and any pnpm/volta stores that can shadow installs.
    2. Prefer a durable runtime source-of-truth: either (a) publish a patch release to the artifact registry and pin the runtime to that release, or (b) install patched artifacts into the active runtime's permanent node_modules (not only the volatile cache) so process restarts consistently load the patched code.
    3. Add a startup fingerprint/checksum guard in process bootstrap that verifies critical plugin dist files match an expected checksum and refuse to start (or emit a loud warning) if mismatches exist. This prevents silent regressions when caches are partially patched.
  - Cross-reference: failures.md restart-not-effective trap; repo.md telemetry cache/paths pointer.


- delegation-observer regex detection bug (2026-08-08):
  - Symptom: the delegation-observer plugin's state-detection regex expected `state: completed` (colon form) but the native OpenCode task() tool emits `state="completed"` (XML-attribute form). The AND condition at L736 therefore never matched and `persistence-pending.json` was never written, blocking downstream research-persistence triggers.
  - Lesson: when a plugin detects output from another tool, validate against the ACTUAL runtime output format (capture a real sample) rather than assuming tolerance based on other parsers or docs. The fix direction: adopt a form-tolerant regex such as `/state\s*[:=]\s*["']?completed/i` or remove the redundant state check and rely on a single authoritative signal.
  - Reference: tracked follow-up ticket DIA-068 (research-persistence trigger missing). This is a behavioural/decision lesson (why the mismatch occurred and the recommended tolerant fix) and is not recoverable purely from code diffs.
  - RESOLUTION NOTE (2026-08-08): during the session the plugin was updated to a form-tolerant detection approach (accepting both XML-attribute and colon forms). DIA-068 was advanced to IMPLEMENTED and typecheck/ai-auditor review passed; a restart-verify and mechanical re-smoke are pending. This note is stored so readers don't assume the bug remains open.


- reviewer empty-result → resume-exact-instance pattern (2026-08-06): during the dev-infra-language-servers review a reviewer task (rev-1) completed with an EMPTY result (no report). Resuming the exact prior reviewer instance by passing its original task_id successfully returned the full report on resume (rev-2). Operational guidance:
  1. When a subagent returns an EMPTY result but prior context is expected, DO NOT re-dispatch a fresh reviewer. Instead resume the original session by calling task() with the original task_id.
  2. Capture and persist task() result.task_id at dispatch time in the registry.jsonl/messages.md sidecar to enable exact-instance resume across restarts.
  3. Treat sentinel/background-job-board aliases as human-friendly labels only; they may not carry the payload needed for programmatic resume.
  4. If resume fails repeatedly, escalate after a small retry cap rather than creating fresh sessions which lose the original context.

- Analyzer deployment toolset limitation (2026-08-06):
  - Observation: a recent analyzer subagent deployment (ana-1 / ana-2 / ana-3 sequence) lacked bash/write_file style tool capabilities. As a result, analysis reports produced by the analyzer could not persist themselves to disk and required an intermediate writer lane (typically @coder) to transcribe the full report into tracked knowledge (knowledge/ or docs/). This was the second observed occurrence of this pattern during the audit and caused a resumed-replay mistake when the orchestrator attempted to resume a prior analyzer session without using the proper task_id.
  - Operational guidance:
    1. Treat analyst-tier subagents as potentially write-less by default; do not assume they can perform repository write operations or run bash.
    2. When commissioning an analysis task that must produce an irrecoverable deliverable, include an explicit persistence step in the orchestration plan: either (a) dispatch a writer agent task() with the analyzer's final message as payload, or (b) instruct the analyzer to include the full, self-contained report text in its final message so a human/orchestrator can copy it into tracked files.
    3. Record the analyzer session's task_id in messages.md and the delegation registry at the time of finalization to enable exact-instance resume if needed.
  - Reason to persist: this is operational, not recoverable from git diffs or session logs alone in some failure modes, and it prevents repeated lost-report incidents. Pin the date and reference the ana-1/ana-2/ana-3 campaign sequence for future post-mortem.


- Resource-manager lane toolset gap (2026-08-07):

  - Observation: during the DIA-045/DIA-059 campaign the @resource-manager runtime lacked a bash/shell callable-tool in its runtime toolset. As a result, the resource-manager could not run host-side probes, perform YAML validation, or make git commits; an executor/coder lane had to complete the commit and push steps instead.

  - Why irrecoverable: the runtime toolset availability is an environment/session property (which lanes had which callable tools at runtime) and is not fully reconstructible from git commits or diffs. The ticket documents the symptom but not the operational mitigation pattern that teams adopted during the session.

  - Operational guidance:
    1. Treat resource-manager (and other non-coder lanes) as potentially lacking bash/write/commit capabilities by default. Do not assume they can perform repository mutations or run host probes.
    2. When a change requires host-side execution or committing artifacts, include an explicit handoff step in the orchestration plan that dispatches a writer/coder lane with bash/commit rights to perform those actions.
    3. Add a preflight probe in the change checklist that verifies the intended lane's callable-tool registry contains `bash` and `write_file` (or the required equivalents) and, if not, automatically plan the handoff lane.

   - Suggested ticket: add a lightweight check to the openspec preflight template so authors explicitly declare the lane that will perform repository writes and verify it has the required callable tools before merge.

   - Addendum (2026-08-12, session 14): the resource-manager lane also runs with subagent_depth=1 in the OMO runtime, which BLOCKS nested dispatch (resource-manager cannot itself spawn a coder/@researcher/@conspecter lane). This runtime depth limit is session/environment state, not present in committed config (no explicit subagent_depth value in opencode.jsonc / oh-my-opencode-slim.jsonc). Operational consequence: curation edits (e.g. ai-assist-sources.yaml refresh, DIA-108) must be handed to a SEPARATE coder lane for validation (make test-config / YAML parse) + commit + push; the resource-manager lane can author the scoped edit but cannot orchestrate the validation/commit sub-lane itself.
 
## dev-infra-jq-probe (2026-08-06)

- Title: Probe-pattern evolution and canonical missing-tool bats pattern

- Context: During the `dev-infra-jq-probe` OpenSpec change we added a host probe for `jq` and wired it into the test-shell prereqs before the existing language-server probe. The change included a new scripts/check-host-jq.sh probe, a 3-case bats test, and Makefile wiring (jq-before-lsp). While the code and openspec artifacts record the implementation, several operational decisions and conventions emerged during the campaign that are not fully derivable from repo state.

- Lesson (irrecoverable):
  1. Ordering decision: the explicit jq-before-lsp probe ordering is an owner-level operational decision that should be followed for future host probe additions to avoid gating regressions. This sequencing preference is recorded here because the choice is cross-file and governed by owner rulings in the campaign, not solely by code.
  2. Canonical missing-tool test pattern: prefer the "plant-then-rm" pattern for bats tests that simulate an absent host tool (create fakes first, then remove the target). This mirrors the existing check-host-lsp.bats approach and avoids flakiness or partial-state test artifacts. The convention is a behavioural decision agreed during review and is not easily inferred from a single test file.
  3. Gated-verification preference: the owner preferred gating via a probe (fail-fast in make test-shell) instead of auto-installing host prerequisites during CI or local test runs. This operational preference affects developer experience and is a campaign-level decision to keep jq as a documented host prerequisite while adding an explicit gate.

Notes:
- Recoverable items (code/spec): check-host-jq.sh, check-host-jq.bats, Makefile prereq wiring, and openspec change artifacts are present in the repo and openspec change dir. These are NOT duplicated in this lesson entry; the entry records the human decisions, conventions, and precedence that are not recoverable from code alone.

- Observed hermetic-PATH leak pattern (irrecoverable operational lesson):
  - Symptom: a missing-tool bats case that set PATH="${fakes}:/usr/bin:/bin" could pass "for the wrong reason" once the tool was installed on the host at /usr/bin. The test's invariant "system tool unreachable by construction" silently breaks when a real host binary is present and therefore masks the intended missing-tool behaviour.
  - Root cause: including host system directories in the test's PATH allows host-installed binaries to shadow the fakes-dir simulation that the test relies on.
  - Preventive rule (owner preference): missing-tool hermetic PATH fixtures must exclude host system directories (use the fakes dir only, or accept an explicit empty-suffix sentinel) so the test's absent-tool case cannot be satisfied by the environment. Record this as a canonical test-fixture architecture lesson to apply to future host probes (check-host-yq, etc.).

- env PATH mutation → command-resolution hazard (irrecoverable shell gotcha):
  - Symptom: invoking `env PATH="$restricted" bash` caused a failure mode where `env` resolved `bash` against the restricted PATH and returned 127 (command not found) rather than letting the intended shell run under the restricted environment.
  - Fix applied: resolve and capture the absolute path to the shell before mutating PATH (e.g. `bash_path="$(command -v bash)"` captured before `env PATH=...`), then invoke the captured absolute path so the command is not subject to the modified PATH lookup.
  - Rationale: this is a non-obvious interaction between env's command-resolution and PATH mutation; the fixed code looks correct but does not explain why the pre-fix behaviour failed on hosts with the binary present. Store as operational knowledge for future shell-test fixture authors.

- Minor helper convention (note): the optional-arg helper change used `${3-...}` (intentionally not `${3:-...}`) so that an explicit empty-string argument is preserved by callers who want a PATH suffix of "" (fakes-only). This is a small but deliberate design choice intended to make the hermetic fakes-only invocation ergonomic; record it here to explain the helper's signature for future probe authors.


## Campaign operational addenda (2026-08-06)

- owner-excluded-but-dirty files can block commits via unconditional pre-commit guard (irrecoverable operational lesson):
  - Symptom: a pre-commit guard script (guard_no_home_qualt) scans `.opencode/commands/*.md` for literal `/home/qualt` and fails the commit if found. The guard runs unconditionally before staging logic, so files that are intentionally owner-excluded but left dirty in the working tree can block any commit attempt even when those files are not staged.
  - Practical remedy (operational, not inferable from code alone): before attempting the commit-plan, either (1) restore the excluded files to the guard-safe form (e.g. `${HOME:?HOME must be set}`) so the guard passes locally, or (2) remove/clean the offending working-tree changes. Do NOT rely on `--no-verify` as the first resort; the owner-preferred flow in this campaign was to restore guard-safe content and re-run verification.
  - Why irrecoverable: the script itself exists in repo, but the cross-file interaction and owner-exclusion policy (leaving files dirty yet expecting commits to proceed) plus the chosen human remedy are session-scoped operational knowledge not recoverable from code diffs or commit history.

- Git staging pitfall (working-tree vs index):
  - Symptom: `git restore --worktree --source=<ref>` repaired the working tree but left the INDEX holding the old content; `git status` showed `MM`. A subsequent plain `git commit` would have committed the stale index version (including literal HOME expansions).
  - Fix sequence: run `git reset HEAD -- <files>` to clear the index for those paths, then `git add <files>` to re-stage the intended content before committing.
  - Why stored: this is an operational footgun tied to transient index state and is not reconstructible from commits or diffs.

- Environment wrapper lesson (code-executor/coder lanes):
  - Symptom: inline `git commit -m "<long message>"` inside shell-wrappered lanes can be corrupted by the wrapper (token injection or arg munging), producing truncated or altered commit messages.
  - Mitigation: prefer `git commit -F <message-file>` (or `--amend -F`) to avoid shell interpolation issues and ensure long messages are preserved.
  - Why stored: operational tooling behavior not recoverable from repo history.


- pre-push format gate rejection on NEW files and the safe recovery sequence (irrecoverable operational lesson):
  - Symptom: a pre-push gate runs `pnpm prettier --check` (format:check) and will reject pushes when NEW files in the push are not yet prettier-formatted. In our run, the first push attempt was rejected because `openspec/changes/dev-infra-language-servers/verification-T11.md` was committed unformatted in C1.
  - Recovery sequence that worked safely in this campaign (operational pattern):
    1. Run `pnpm prettier --write` on the offending new file(s).
    2. Run `git reset --soft <parent-commit>` to move HEAD back but keep the index (we used the parent dbd2f71).
    3. Re-commit with the same messages/staging sets (without using `--no-verify`).
  - Important caveat: this safe-reset-and-recommit approach is only safe when the rejected commits were never received by origin (the remote ref still pointed to the parent). If the remote already received the rejected commits, do not use this rewrite path; instead fix forward with new commits or follow your repository's accepted history-rewrite policy.
  - Why irrecoverable: the gate script is in the repo, but the precise human-recovery steps and the conditional safety remark about origin's state (reset --soft only when origin did not receive rejected commits) are procedural knowledge observed in-session and not reconstructible from code or git history alone.


- sdk-app-log-v1-shape-gotcha (2026-08-09): Plugin authors beware: this project's runtime resolved to the v1 `@opencode-ai/sdk` client (via `@opencode-ai/plugin@1.18.10`). In v1 the TUI-safe logging call expects the payload under an Options wrapper `body`: `ctx.client.app.log({ body: { service, level: "info", message } })`. A v2-style flat call (`{ service, level, message }`) fails TypeScript typecheck at edit-time. Mitigation: verify the installed SDK version and consult `node_modules/@opencode-ai/sdk/dist/gen/sdk.gen.d.ts` for the exact call shape before editing plugins; prefer the v1 wrapper form when uncertain. This mismatch caused a typecheck iteration cost during the campaign and is not obvious from repo-level plugin code alone.


## c-20260809-residual-closure (session 2) — addenda (2026-08-10)

- L20260810-001: Empty-return escalation pattern
  - Symptom: coder lanes returned completely empty final messages twice and produced no file changes during DIA-078 fix attempts (session ids are recorded in campaign logs).
  - Operational lesson (persisted): when a subagent returns an empty/blank final result and in-scope artifacts show no changes, immediately escalate: 1) invoke @ai-auditor for a ground-truth read of the repo/state; 2) if auditor confirms no landed changes, mark the original lane as failed and re-route implementation to code-executor. Do NOT allow a 3rd in-lane retry. Rationale: orchestration pattern not reconstructible from git diffs or tests. Reference: docs/dev-infra-audit/tickets/archive/DIA-076-dia063-fix-implementation.md and session logs.

- L20260810-002: Prompt-learned habit persistence — `snip` prefix
  - Symptom: multiple coder agents continued to habitually prefix commands with `snip` across lanes after DIA-078 guardrail (residual occurrences reported by cod-4..cod-7).
  - Implication: mechanical guardrails (doom_loop: deny; narrow jq-scoped rule) reduced impact but did not eliminate model-learned prompt habits. Persist as operational risk: if identical slip recurs in 2+ consecutive sessions, escalate to permission-level deny for bash-level `snip` prefix patterns in agent.coder.permission and add instrumentation to flag prefix usage in dispatch prompts. Cross-reference: .opencode/oh-my-opencode-slim.jsonc; opencode.jsonc L151; knowledge/res010-dia078-loop-hardening/ (conspect).

- L20260810-003: Step-budget resumption pattern
  - Symptom: lanes hit max-steps mid-protocol when recon + heavy verification consumed the budget (observed in cod-5/cod-6 runs).
  - Recovery pattern (persisted): when resuming a step-budget-limited lane, pass the full remaining-state list in the dispatch prompt and instruct the agent to skip recon and start at the remaining edits. Front-load state into the resume prompt to avoid re-running recon/verification steps. This precise resume prompt pattern is not reconstructible from git commits and is therefore recorded here.

## c-20260809-residual-closure - post-mortem correction (2026-08-11)
- L20260810-002 correction: The DIA-078 defense-in-depth deny rules (global L95-96, project L180-181) were added 2026-08-10 but caused a mechanical lock when combined with the opencode-snip plugin (which rewrites ALL bash commands to `snip <cmd>` via tool.execute.before). The root-cause fix is plugin removal: opencode-snip@1.6.1 removed from the global plugin array (DIA-092, res011 conspect). The deny rules are KEPT as a dormant zero-cost hallucination guardrail (council 5/5). Anti-priming lesson: orchestrator prompts must never name the forbidden token ("do not use `snip jq`" primed the prefix - DIA-078 L99). Truncation-defaults note: relying on native OpenCode tool_output defaults (max_lines=2000, max_bytes=50KB) + compaction.prune:true (project .opencode/opencode.jsonc L20); revisit explicit tool_output config only if token overflow is observed. Cross-reference: DIA-075, DIA-078, DIA-092, res011.

## L20260812-001 — clean-exit status correction (session 14, 2026-08-12)

- **Symptom:** at the end of a clean session (all 6 pre-handoff gates confirmed clean), the delegation-observer `log_decision` plugin had written the handoff status as `manual-halt` despite the clean-exit gate evidence. The orchestrator corrected it via a coder-lane single-field `jq` edit on the status field and re-verified.
- **Why irrecoverable:** the plugin miswrite is runtime/plugin behaviour, not present in any commit or ticket. The correction technique and its safety property are not reconstructible from git diffs.
- **Operational lesson:**
  1. The handoff checksum covers ONLY the `.prognosis` field (canonical pipeline: `jq -c '.prognosis | to_entries | sort_by(.key) | from_entries' | tr -d '\n' | sha256sum`). A single-field edit to a DIFFERENT field (e.g. `status`) does NOT invalidate the checksum. This is why a status-only correction via coder-lane `jq` is safe without recomputing the checksum.
  2. Do NOT trust a plugin-written status field over the aggregate pre-handoff gate evidence. When they conflict, correct the status field surgically (single-field `jq` edit) rather than regenerating the whole handoff, then re-verify the gate evidence still stands.
  3. Route the correction through a coder lane (the orchestrator has no bash tool by design) with an explicit "single-field edit, leave `.prognosis` untouched" instruction.

## DIA-100 git worktrees parallel-dev (session 15, 2026-08-12)

- Timeout-bounded best-effort remote check: any "best-effort, skip when
  unreachable" remote call MUST carry an explicit timeout (`timeout 5 git
  ls-remote ...`). The claim "skipped silently" is false if the call blocks
  for minutes when the remote is unreachable. The concrete fix is in
  scripts/worktrees.sh (commit 44865c3), but the generalizable rule (apply a
  timeout to every best-effort network probe, not just ls-remote) is the
  irrecoverable lesson; the code alone does not tell a future author to apply
  it to the next remote probe they add.

- Test-design pattern for bounding untestable waits: prove a bounded-wait
  invariant with outer + inner timeouts (T13: fake ls-remote sleeps 20s; the
  outer `timeout 12` bounds the test while the script's internal `timeout 5`
  must kill the hanging fake; without the internal timeout the outer timeout
  kills the test with status 124 -> RED). This outer/inner timeout pairing is
  a reusable technique for asserting an internal bound on a wait that is
  otherwise untestable without actually waiting it out. The test exists in
  code, but the technique's rationale (and why it is the canonical way to
  prove a bounded-wait invariant) is the irrecoverable lesson.

- Gateway pitfall (this session): an intermediate ticket status (FIXED) that
  the section-10 ticket gate does not recognize silently blocks re-review
  dispatch. Keep ticket status values to the canonical set (OPEN/CLOSED and
  any explicitly-documented states); when a dispatch or re-review is silently
  blocked, verify the referenced ticket is OPEN and not a non-canonical value.
  Cross-reference: adr.md "Git worktrees parallel-dev model" entry.

## L20260812-002 - authoritative-sources over self-benchmarking (session 16, 2026-08-12)

- **Developer decision preference (DIA-116):** do NOT self-benchmark the
  dispatch/candidate models inside this repo. When a model-selection evidence
  gap arises (here: coder-escalated Rung-3 candidates kimi-k3 /
  deepseek-v4-pro / mimo-v2.5-pro, whose headline SWE scores were
  vendor-reported and not independently reproduced), prefer evidence from
  authoritative third-party sources over an in-repo live benchmark. The
  developer's stated rationale: "I prefer to rely on benchmarks done by
  authoritative sources" over self-benchmarking (which would be the agent
  grading its own dispatch pool).
- **Why irrecoverable:** the DIA-116 ticket records the *fact* of the approach
  change and the resulting verdict (KEEP kimi-k3; Rung-3 fallback PREFER
  deepseek-v4-pro over mimo-v2.5-pro), but not the generalizable *preference
  rule* that should steer future model-selection evidence gaps toward the same
  path.
- **Operational lesson (repeatable pattern):** when a model-selection evidence
  gap is identified, the canonical resolution path is authoritative
  third-party research via the research pipeline (researcher + conspecter
  lanes -> conspect registered in the memory shelf), NOT an in-repo benchmark
  of the candidates. The pre-existing in-repo benchmark artifact should be
  annotated CANCELLED/superseded (ana014) rather than deleted, and the
  superseding conspect cited (knowledge/res017-rung3-benchmark-evidence/).
  This keeps the decision auditable without self-grading dispatch models.

## L20260812-003 - section-10 dispatch ticket correlation (session 16, 2026-08-12)

- **Symptom (two linked gate failures during the DIA-117 config-hardening
  flow):**
  1. The first section-10 (opencode config) register dispatch FAILED the
     section-10 ticket gate because its prompt did NOT carry an explicit
     correlating DIA ticket reference; re-dispatching with an explicit
     "TICKET: DIA-NNN ..." header in the prompt passed the gate.
  2. The completed DIA-100 ticket (status FIXED) was NOT accepted by the gate
     as correlation for the follow-up config work (DIA-117); a child OPEN
     ticket (DIA-117) had to be created to carry the config change through the
     section-10 chain.
- **Why irrecoverable:** NEXT-RUN.md and AGENTS.md document ticket REFERENCE
  FORMAT (quote ID + slug) and the recency cliff (L103 / 2026-08-10 failures),
  but neither documents that (a) the section-10 gate requires the DISPATCH
  PROMPT itself to carry an explicit correlating DIA ticket reference, nor
  (b) new section-10 config work needs its OWN OPEN ticket (a completed/FIXED
  parent will not correlate). These are gate-behaviour observations not
  recoverable from git diffs, NEXT-RUN, or the learnings file (which covers
  ID+slug quoting only).
- **Operational lesson:**
  1. ALWAYS lead a section-10 / opencode-config dispatch prompt with a
     "TICKET: DIA-NNN 'slug'" header naming an OPEN correlating ticket.
  2. New section-10 config work requires its OWN OPEN ticket. A FIXED/completed
     ticket is not a valid correlation for follow-up config changes; file a
     child ticket (e.g. DIA-100 FALSIFICATION -> DIA-117) before starting the
     config change.
  3. Do not confuse the three distinct section-10 gate concerns: reference
     FORMAT (ID+slug quoting, learnings 2026-08-12), ticket RECENCY (L103),
     and dispatch CORRELATION / own-ticket (this entry).
   - Cross-reference: DIA-117, DIA-100, lessons.md L103, failures.md
     2026-08-10 stale-gate recency block, learnings/external-patterns/
     2026-08-12-ticket-reference-format.md.

## S18 (session 18, 2026-08-12) - DIA-118 / DIA-119 / boot-gate

- core.filemode=false chmod trap (DIA-118):
  - Symptom: a plain `chmod +x scripts/worktrees.sh` was silently dropped at
    commit time even though the working tree showed the executable bit set.
  - Root cause: this repo sets `core.filemode=false` in .git/config (repo-local),
    so git does not record permission changes on tracked files. A plain chmod
    is invisible to git and never lands in the commit.
  - Fix: stage the mode change explicitly with `git update-index --chmod=+x
    scripts/worktrees.sh` and verify via `git ls-files -s` (100755) or by
    extracting from `git archive` (which respects the index mode) rather than
    trusting the working-tree ls. The DIA-100 OpenSpec spec already required the
    file be "executable"; the initial implementation missed it and review caught
    it. Generalizable rule for any repo with core.filemode=false: NEVER rely on
    chmod +x alone to make a tracked file executable; use git update-index
    --chmod=+x. The repo-local config value (not committed) is the irrecoverable
    part; the fix command is a transferable pattern.

- temp-HOME hermeticity breach pattern (DIA-119):
  - Symptom: an intermittent test-shell failure (verify-pre-push.bats test ~187,
    exit 2, ERR_PNPM_NO_IMPORTER_MANIFEST_FOUND) that did not reproduce reliably.
  - Root cause: the test set `HOME=$BATS_TEST_TMPDIR/home` to keep the login
    shell clean and force the fake pnpm. But a real login shell sources the real
    ~/.profile which prepends $VOLTA_HOME/bin to PATH, so the REAL pnpm/npx
    resolved and shadowed the fake in the empty sandbox, failing because the
    empty sandbox had no importer manifest.
  - Lesson (two parts):
    1. Intermittent test failures can be ENVIRONMENT-DEPENDENT HERMETICITY
       BREACHES, not store/cache races. To prove the leak path, force HOME and
       show which binary actually resolves. A fake-dir PATH that gets appended to
       by a login profile defeats the fixture.
    2. Test sandboxes that fake external tools must seed importer manifests +
       tool stubs so the outcome does not depend on which tool resolves. This is
       the durable test-architecture decision recorded in adr.md "Hermetic
       sandbox seeding".

- npx resolves binaries from node_modules/.bin, NOT package.json scripts
  (DIA-119 F2 lesson):
  - A package.json `scripts` entry is DEAD CODE for `npx`. When real npx runs it
    resolves the command from node_modules/.bin. Therefore a sandbox that fakes
    an npx-invoked tool must place the stub at node_modules/.bin/<cmd>, not add a
    package.json scripts entry. The initial implementation wrote a scripts entry
    expecting npx to honor it; it does not.

- .bin stub $0-reconstruction for identical logging (DIA-119 F2):
  - When real npx invokes a node_modules/.bin stub, it passes only the args AFTER
    the binary name, so `$*` alone loses the command name. To make the real-npx
    path log identically to the fake npx, reconstruct the full command from `$0`:
    `printf 'npx %s\n' "$(basename "$0") $*"`. This $0-reconstruction deviation
    was empirically required (real npx vs fake npx invoke the stub differently)
    and is now the established pattern for sandbox stubs that must produce
    byte-identical logs either way.

- log_decision handoff-event trigger caveat (DIA-120 boot-gate incident):
  - The delegation-observer plugin's handoff-writer fires on ANY log_decision
    with event_type='handoff' AND a non-empty prognosis string - INCLUDING
    non-terminal status events (resolution_status='in-flight'). This clobbers
    the valid handoff file with a fallback wrapper, destroying the real
    prognosis and causing a false checksum mismatch escalation.
  - Operational rule for agents: use event_type='decision' for progress/status
    events; RESERVE event_type='handoff' for genuine terminal handoffs. A prose
    (non-JSON-stringified) prognosis with event_type='handoff' also triggers the
    write - so even non-terminal events carrying any prognosis string are
    dangerous.
  - Secondary boot-gate lesson: comparison logic must RE-READ the file's
    checksum field at comparison time; do not compare against a checksum value
    memorized from an earlier read (stale-comparison false positive).
  - Cross-reference: failures.md S18 boot-gate false-positive escalation;
    DIA-120 (fix deferred to section-10 chain).
  - RESOLUTION NOTE (2026-08-12, S19): the plugin trigger bug was fixed in
    e15a876 by narrowing the handoff-writer to a terminal-status set
    (TERMINAL_HANDOFF_STATUSES = done/escalated/pending-owner) plus a
    console.warn skip path for non-terminal statuses. The operational rule for
    agents (reserve event_type='handoff' for terminal handoffs; use
    'decision' for progress) is now enforced BOTH mechanically (plugin filter)
    and instructionally (orchestrator_append.md / NEXT-RUN.md). A restart-verify
    was still PENDING at end of S19 (must restart OpenCode to load the plugin
    fix, then reproduce: in-flight handoff log must NOT touch
    current-handoff.json; terminal handoff still writes atomically with the
    canonical checksum).

- Prettier rewrites block-style YAML frontmatter inside ticket .md files
  (DIA-121 S1, 2026-08-12):
  - Symptom: the pre-commit prettier 3.8.3 hook reformats mid-file YAML
    frontmatter blocks in ticket documents (docs/dev-infra-audit/tickets/*.md).
    A block-style list like
    `files_touched:\n- ".../bats-wrapper.sh"` was rewritten, and the
    `__tests__` path token was mangled to `**tests**` (markdown emphasis), so
    the committed frontmatter no longer matched the real file paths. This bit
    the DIA-121 S1 fix twice: commit 3d7ebd8 was reverted and 66139dd redone.
  - Workaround (prettier-stable): use inline flow-style
    `files_touched: ["a", "b", "c"]` on a single line, which prettier leaves
    alone, instead of block-style YAML lists.
  - Lesson: when a .md file carries an embedded YAML frontmatter block, prefer
    single-line flow-style for any array fields so the prettier pre-commit hook
    does not rewrite them (block-style lists are reformatted and multi-word
    path tokens like `__tests__` can be mangled to emphasis).
  - Why irrecoverable: the churn is visible in git, but the root cause (prettier
    reformatting embedded frontmatter lists + the `__tests__` -> `**tests**`
    mangling) and the durable workaround (flow-style) are not stated in any
    committed file.

- Instruction-surface coherence when changing a cross-cutting ownership model
  (DIA-120 C1/M1/m1, 2026-08-12):
  - ai-auditor caught that a fix can be correct in one instruction file yet
    leave a contradiction in a sibling instruction file. Concretely, the plugin
    ownership fix (FIX E: plugin-only-write of current-handoff.json) was correct
    in the plugin/agent doc, but a boot-gate step in another instruction file
    still said "write the checksum into the field" (residual manual-write
    wording), contradicting the plugin-only-write model.
  - Lesson: when you change a cross-cutting ownership model (who owns a file,
    who writes a field, single-writer contracts), grep the FULL instruction
    surface (agents/*.md, NEXT-RUN.md, orchestrator_append.md, any
    step-by-step runbooks) for residual wording that still describes the OLD
    ownership. A sibling-file contradiction silently breaks the invariant even
    when the primary fix is correct.
  - Why irrecoverable: the fix commits (e.g. 4820423) show the corrected final
    state but not the generalizable process rule that sibling instruction files
    must be reconciled in the same change.

- Runtime-versus-types gap for plugin event hooks (2026-08-13, DIA-122):
  - Symptom: the installed `@opencode-ai/plugin@1.18.10` (v1) TypeScript Event
    union does NOT declare the `question.asked` / `permission.asked` events (nor
    their `*.v2.*` variants), but the runtime EMITS them via the generic `event`
    catch-all hook regardless. A typechecked observer plugin therefore cannot
    reference these events through the typed union.
  - Lesson: observer modules that hook the `event` catch-all must cast the event
    to a custom union (`.properties` shape) and handle BOTH event-name generations
    (`question.asked` AND `question.v2.asked`, same for `permission`). This mirrors
    the delegation-observer's existing cast for session lifecycle events and is the
    generalizable pattern for any future plugin hooking question/permission events.
  - Why irrecoverable: the runtime emission of events absent from the TS types is a
    versioned toolchain fact (verified against the installed packages) not stated in
    any single committed file; the cast is only understood in context of the runtime
    behavior. Cross-reference: external-patterns 2026-08-12-wsl2-notifications-daemon-required.md
    (verified facts section records the same runtime/types lag).

- WSL2 desktop notifications require a daemon (2026-08-13, DIA-122):
  - Cross-reference: the FULL lesson body is persisted in
    `.opencode/learnings/external-patterns/2026-08-12-wsl2-notifications-daemon-required.md`.
    This entry records ONLY the durable pointer so future work does not duplicate it.
  - Brief pointer: freedesktop Notifications REQUIRES a notification daemon on the
    session bus; WSLg does not provide org.freedesktop.Notifications by default, so
    `dbus-send` fails with ServiceUnknown. Zero-install alternatives on WSL2:
    in-TUI toast (`tui.showToast`) and `powershell.exe` WinRT toast via WSL interop
    (spawn with stdio fully discarded for TUI-safety, res007). Prefer these until a
    daemon is installed.

- Recurring ledger-drift class (2026-08-13, DIA-122 + DIA-092):
  - Symptom: twice in one week a DIA ticket's WORK was fully complete
    (implementation + validation + registration) but the ticket frontmatter
    status and the README index row/counts were never flipped from OPEN to a
    completed status at completion time. The ledger only reflects a ticket's
    real state when the status flip happens AT completion time, not later; a
    deferred flip is easily forgotten and leaves a persistent ledger/index
    mismatch until someone reconciles it.
  - Preventive action: any lane that completes a ticket's final phase MUST flip
    the ticket frontmatter status + the README index row + the rollup status
    counts in the SAME commit as the completion work (atomic status flip at
    completion time). Do not defer the status flip to a separate later step.
  - Why irrecoverable: the individual drifts are visible in git, but the
    recurring behavioral PATTERN (and the atomic-at-completion-time rule) is a
    workflow lesson, not reconstructible from any single diff.
  - Cross-reference: repo.md "Ticket ledger drift: DIA-063" entry; DIA-122, DIA-092.

- Autonomous-night research-persistence gate behavior (2026-08-13, decision
  traceability):
  - Context: when the developer grants an autonomous overnight mandate ("do as
    much work as possible, leave user-input decisions for morning"), the
    research-persistence gate's Phase-2 practice-protected "present to
    developer" step cannot be performed live (the developer is not present
    overnight). This run the orchestrator auto-proceeded with persistence
    (PERSISTENCE_RECOMMENDED: true, 15+ sources) and flagged the persistence for
    morning developer review.
  - Decision to trace: under an autonomous overnight mandate, auto-proceeding
    with research persistence and flagging it for morning review is an ACCEPTED
    pattern, PROVIDED the persistence is reversible/auditable (conspects and
    memory-shelf entries are tracked in git) and the auto-proceed decision is
    recorded for the developer to accept/reject at the next session. If the
    developer's standing preference is that persistence NEVER auto-proceeds even
    under a mandate, amend this rule.
  - Why irrecoverable: the choice to auto-proceed vs block is a session decision;
    the developer's acceptance or amendment of this pattern is a standing
    preference decision that must remain traceable.

- Tool-visibility catch-all-ordering trap (DIA-126 root cause, 2026-08-13):
  - Symptom: agents openspec-plan, resource-manager, ai-specialist, and
    conspecter had NO bash tool exposed at runtime during the autonomous night
    run despite config allow grants; agents stalled for hours on permission asks.
  - Root cause: OpenCode's tool-visibility gate uses findLast over the flattened
    permission rules for a tool map. A trailing `"*": "deny"` catch-all placed
    AFTER specific allow rules makes findLast land on deny, hiding the ENTIRE
    tool from the agent's function schema (identical mechanism to DIA-081 for
    the task tool). The DIA-126 hardening commit 753e374 (crwl allow, webfetch
    deny) kept the pre-existing trailing catch-all, so the hardening never took
    effect; a restart-verify manifest (conspecter session with no bash) was the
    proof.
  - Fix (commit 2faae73): move `"*": "deny"` to FIRST position in the bash maps
    of all four affected agents. findLast then lands on the specific allows for
    matching commands (tool visible) while the catch-all still denies everything
    else. Catch-all-FIRST is the correct pattern (DIA-036, DIA-081).
  - Generalizable rule: in ANY tool permission map the `"*": "deny"` catch-all
    MUST come first; a trailing catch-all silently removes the whole tool from
    the agent's function schema and is undetectable by reading the config file
    (must verify the runtime tool manifest instead).
  - Cross-reference: extends the earlier symptom-level lesson "Openspec CLI
    permission-shadowing gotcha"; complementary to the deny-semantics
    registry-absence lesson. DIA-126, DIA-081, DIA-036.

- Byte-level ASCII audit (DIA-079) should run BEFORE the commit, not after
  (DIA-127 registration, 2026-08-13):
  - Symptom: a post-commit byte-level ASCII audit of the DIA-127 Phase-6
    registration (44ea318) surfaced a pre-existing em-dash on a modified line,
    forcing a separate polish commit (7b33682) purely to keep the changed file
    ASCII-clean.
  - Root cause: the ASCII audit was treated as a post-commit gate for already
    landed work instead of a pre-commit check on the working tree, so an
    untouched non-ASCII byte inherited into a touched line was only caught after
    the first commit.
  - Lesson: for any lane that edits tracked files (especially docs/config), run
    `LC_ALL=C grep -P '[^\x00-\x7F]'` on the diff surface BEFORE committing so
    the ASCII fix folds into the primary commit instead of a follow-up polish
    commit. A pre-existing non-ASCII byte on a modified line is still a DIA-079
    violation that must be corrected, but catching it pre-commit avoids the
    two-commit shape.
  - Why irrecoverable: the ordering (audit-before-commit vs audit-after-commit)
    is a process choice, not visible in the git diff; the em-dash itself was
    pre-existing and the polish commit alone does not reveal the workflow defect.
  - Cross-reference: DIA-079 (ASCII-only protocol), DIA-127 registration commits
    44ea318 / 7b33682.
