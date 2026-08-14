# Dev-Infra Audit — Ticket Ledger

| DIA-045 | OpenCode config drift backlog (ai-specialist review 2026-08-04, findings F6–F22) | opencode-config | Medium | CLOSED | [DIA-045-opencode-config-drift-backlog.md](DIA-045-opencode-config-drift-backlog.md) |
| DIA-050 | .mise.toml ↔ Dockerfile.dev pin-sync gap (DIA-045 F15) | dev-infra | Low | CLOSED | [DIA-050-mise-dockerfile-pin-sync-gap.md](DIA-050-mise-dockerfile-pin-sync-gap.md) |
| DIA-051 | Raw JSONL telemetry leak into human chat UI (messages.jsonl sidecar) | opencode-config | Medium | CLOSED | [DIA-051-jsonl-telemetry-leak-chat-ui.md](DIA-051-jsonl-telemetry-leak-chat-ui.md) |
| DIA-052 | Skill dup cleanup: 5 byte-exact dup skill dirs + two-tier dup detection in validate-skills.sh | scripts | Major | DONE | [DIA-052-skill-dup-cleanup.md](DIA-052-skill-dup-cleanup.md) |
| DIA-053 | @ai-auditor 4-source registration + @ai-specialist docs-only narrowing | opencode-config | Medium | DONE | [DIA-053-ai-auditor-4-source-registration.md](DIA-053-ai-auditor-4-source-registration.md) |
| DIA-054 | NEXT-RUN.md §2 council budget guard (COUNCIL-BUDGET-GUARD) | docs | Medium | DONE | [DIA-054-council-budget-guard.md](DIA-054-council-budget-guard.md) |
| DIA-055 | Write-capable token_export exposed to all subagents (permission default-allow model) | opencode-config | Medium | CLOSED | [DIA-055-token-export-subagent-exposure.md](DIA-055-token-export-subagent-exposure.md) |
| DIA-056 | @ai-auditor subagent token-tool stacking loop (session error, cancelled, not reusable) | opencode-config | Medium | CLOSED | [DIA-056-ai-auditor-token-tool-loop.md](DIA-056-ai-auditor-token-tool-loop.md) |
| DIA-057 | Knowledge-workflow violation — conspect not created on research request (2026-08-06) | docs | Low | VERIFIED | [DIA-057-knowledge-workflow-conspect-violation.md](DIA-057-knowledge-workflow-conspect-violation.md) |
| DIA-058 | Research persistence gap — PERSISTENCE_RECOMMENDED flag auto-ignored by orchestrator | docs | Medium | VERIFIED | [DIA-058-research-persistence-gap.md](DIA-058-research-persistence-gap.md) |
| DIA-059 | §10 gate plugin not activated — silent failure on .opencode edits | opencode-config | Blocker | VERIFIED | [DIA-059-gate-plugin-not-activated.md](DIA-059-gate-plugin-not-activated.md) |
| DIA-060 | Orchestrator read scope missing tickets directory | opencode-config | Blocker | VERIFIED | [DIA-060-orchestrator-read-scope-tickets.md](DIA-060-orchestrator-read-scope-tickets.md) |
| DIA-061 | Orchestrator fails to produce handoff files autonomously — core mechanism not triggered | opencode-config | Blocker | VERIFIED | [DIA-061-orchestrator-handoff-files-failure.md](DIA-061-orchestrator-handoff-files-failure.md) |
| DIA-062 | Orchestrator running on deepseek-v4-pro instead of deepseek-v4-flash — model misconfiguration | opencode-config | Blocker | VERIFIED | [DIA-062-orchestrator-model-misconfiguration.md](DIA-062-orchestrator-model-misconfiguration.md) |
| DIA-063 | Orchestrator starts §10 work without creating a ticket first — ticket-creation gate not enforced | opencode-config | Blocker | CLOSED | [DIA-063-ticket-creation-gate.md](DIA-063-ticket-creation-gate.md) |
| DIA-064 | cebula preset models reverted flash→pro in commit 2e0c4f3e — restore pre-commit all-flash state | opencode-config | Critical | VERIFIED | [DIA-064-cebula-preset-flash-revert.md](DIA-064-cebula-preset-flash-revert.md) |
| DIA-066 | Tool-coverage audit script — surface unlisted default-allow tools | scripts | Low | VERIFIED | [DIA-066-tool-coverage-audit-script.md](DIA-066-tool-coverage-audit-script.md) |
| DIA-067 | Docker dev-tool access gap — agents cannot invoke trafilatura (blocks res003 persistence) | docker | Blocker | VERIFIED | [DIA-067-docker-dev-tool-access-gap.md](DIA-067-docker-dev-tool-access-gap.md) |
| DIA-068 | delegation-observer persistence trigger never fires — state-check regex format mismatch | opencode-config | Major | VERIFIED | [DIA-068-delegation-observer-persistence-trigger.md](DIA-068-delegation-observer-persistence-trigger.md) |
| DIA-069 | opencode-telemetry registerCommands() rewrites command docs with literal $HOME paths | opencode-config | Major | CLOSED | [DIA-069-telemetry-command-docs-home-paths.md](DIA-069-telemetry-command-docs-home-paths.md) |
| DIA-070 | Telemetry plugin P2/P4 re-entrancy guard gaps (DIA-056(b) residuals) | opencode-config | Medium | CLOSED | [DIA-070-telemetry-reentrancy-guard-gaps.md](DIA-070-telemetry-reentrancy-guard-gaps.md) |
| DIA-071 | make test-infra/test-shell exit 2 — host check-host-lsp gate fails | dev-infra | Major | VERIFIED | [DIA-071-make-test-gates-exit-2.md](DIA-071-make-test-gates-exit-2.md) |
| DIA-072 | researcher returns unarchived facts: 4/16 sources failed to persist during conspect Phase A | docs | Medium | CLOSED | [DIA-072-researcher-unarchived-facts.md](DIA-072-researcher-unarchived-facts.md) |
| DIA-073 | Investigate handoff coordination for parallel OpenCode sessions via session IDs | docs | Medium | CLOSED | [DIA-073-handoff-coordination-session-ids.md](DIA-073-handoff-coordination-session-ids.md) |
| DIA-074 | Ticket filenames lack human-readable descriptors — orchestrator ticket references are opaque to the developer | docs | Medium | CLOSED | [DIA-074-ticket-filenames-descriptors.md](DIA-074-ticket-filenames-descriptors.md) |
| DIA-075 | DIA-061 boot-gate checksum-mismatch via snip jq wrapper + recurring coder snip-jq loop | docs | Major | CLOSED | [DIA-075-checksum-mismatch-snip-jq-loop.md](DIA-075-checksum-mismatch-snip-jq-loop.md) |
| DIA-076 | Implement DIA-063 ticket-gate fix + DIA-075 snip guardrails | opencode-config | Major | VERIFIED | [DIA-076-dia063-fix-implementation.md](archive/DIA-076-dia063-fix-implementation.md) |
| DIA-077 | OMO background job board shows stale objective for coder-lane sessions (description-reuse) | opencode-config | Low | DEFERRED | [DIA-077-job-board-stale-objective.md](DIA-077-job-board-stale-objective.md) |
| DIA-078 | coder lane repeatedly prefixes commands with snip wrapper — identical-command loop (DIA-075 recurrence, broader than jq) | opencode-config | Major | OPEN | [DIA-078-coder-snip-wrapper-loop.md](DIA-078-coder-snip-wrapper-loop.md) |
| DIA-079 | delegation-observer handoff atomic write fails — JSON Parse error: Unexpected identifier \"computed\ | opencode-config | Major | MONITOR | [DIA-079-handoff-write-json-parse-error.md](DIA-079-handoff-write-json-parse-error.md) |
| DIA-080 | orchestrator halts/stops mid-work repeatedly across sessions — requires developer \"continue\" nudges | opencode-config | Major | CLOSED | [DIA-080-orchestrator-frequent-stops.md](DIA-080-orchestrator-frequent-stops.md) |
| DIA-081 | orchestrator boots without task tool — permission.task '\*' : 'deny' last-key ordering removes task tool entirely (visibleTools findLast) | opencode-config | Blocker | CLOSED | [DIA-081-orchestrator-task-tool-loss.md](archive/DIA-081-orchestrator-task-tool-loss.md) |
| DIA-082 | orchestrator must not perform heavy thinking/analysis itself — delegate to @analyzer; @analyzer may propose council dispatch when warranted | opencode-config | Major | CLOSED | [DIA-082-orchestrator-heavy-thinking-delegation.md](DIA-082-orchestrator-heavy-thinking-delegation.md) |
| DIA-083 | orchestrator's main role is task/resource management — automate repetition by dispatching @coder to create scripts/tools | opencode-config | Major | CLOSED | [DIA-083-orchestrator-role-task-resource-mgmt.md](DIA-083-orchestrator-role-task-resource-mgmt.md) |
| DIA-084 | audit the artifacts folders — ensure proper order/structure, naming conventions, archive policies, index files, cross-references | docs | Medium | CLOSED | [DIA-084-artifacts-folder-audit.md](DIA-084-artifacts-folder-audit.md) |
| DIA-085 | investigate parallel orchestrator sessions — handoff coordination between them (session IDs, worktrees, handoff-file ownership) | docs | Medium | OPEN | [DIA-085-handoff-parallel-orchestrator-sessions.md](DIA-085-handoff-parallel-orchestrator-sessions.md) |
| DIA-086 | improve workflows with a modern scientific-methodology approach — evidence-based reasoning, source citing, reproduction, hypothesis building | docs | Medium | CLOSED | [DIA-086-scientific-methodology-workflow.md](DIA-086-scientific-methodology-workflow.md) |
| DIA-087 | audit picked models and model variants for current agents — is the assignment optimal? | opencode-config | Medium | CLOSED | [DIA-087-agent-model-variant-audit.md](DIA-087-agent-model-variant-audit.md) |
| DIA-088 | teaching skill missing from the active skill registry — recover it | skills | Medium | VERIFIED | [DIA-088-recover-teaching-skill.md](DIA-088-recover-teaching-skill.md) |
| DIA-089 | add the book_rag skill and connect it to OpenWebUI (hybrid RAG over local engineering textbooks) | skills | Medium | OPEN | [DIA-089-book-rag-skill-openwebui.md](DIA-089-book-rag-skill-openwebui.md) |
| DIA-090 | recover mermaid-diagramming and console-charting skills (source: opencode backup folder) | skills | Medium | VERIFIED | [DIA-090-recover-mermaid-console-charting-skills.md](DIA-090-recover-mermaid-console-charting-skills.md) |
| DIA-091 | orchestrator repeatedly reports \"I have no bash\" across sessions — document and enforce the bash-delegation pattern | opencode-config | Major | CLOSED | [DIA-091-orchestrator-no-bash-recurring.md](DIA-091-orchestrator-no-bash-recurring.md) |
| DIA-092 | §10 snip-plugin-removal (opencode-snip mechanical lock fix) | opencode-config | Major | CLOSED | [DIA-092-snip-plugin-removal-s10.md](DIA-092-snip-plugin-removal-s10.md) |
| DIA-093 | Orchestrator boot: 'I have no bash tool' - DIA-061 checksum not delegated to coder lane | opencode-config | Major | CLOSED | [DIA-093-orchestrator-no-bash-checksum-delegation.md](DIA-093-orchestrator-no-bash-checksum-delegation.md) |
| DIA-094 | Husky pre-commit hook cannot run in WSL - docker unavailable, quality gate bypassed via --no-verify | dev-infra | Major | CLOSED | [DIA-094-husky-precommit-wsl-docker-unavailable.md](DIA-094-husky-precommit-wsl-docker-unavailable.md) |
| DIA-095 | Orchestrator needs an optimized project-ops reference - how to run the project, bring up docker, required gates | dev-infra/opencode-config | Major | CLOSED | [DIA-095-orchestrator-project-ops-reference.md](DIA-095-orchestrator-project-ops-reference.md) |
| DIA-096 | Git push permission policy - allow push, restrict destructive commands and main | opencode-config | Major | CLOSED | [DIA-096-git-push-permission-policy.md](DIA-096-git-push-permission-policy.md) |
| DIA-097 | orchestrator role consolidation: task/resource mgmt, delegation, heavy-thinking separation, bash-delegation, automation-of-repetition | opencode-config | Major | CLOSED | [DIA-097-orchestrator-role-delegation.md](DIA-097-orchestrator-role-delegation.md) |
| DIA-098 | spontaneous subagent/session stops: stalled-agent detection, auto-resume, complete-vs-interrupted classification | opencode-config | Major | OPEN | [DIA-098-spontaneous-session-stops.md](DIA-098-spontaneous-session-stops.md) |
| DIA-099 | truncated/partial subagent responses: detect-preserve-resume-validate mechanism | opencode-config | Major | OPEN | [DIA-099-truncated-subagent-responses.md](DIA-099-truncated-subagent-responses.md) |
| DIA-100 | git worktrees for parallel dev sessions: isolation, branch management, merge/conflict handling, cleanup, OpenCode interaction | dev-infra | Medium | FIXED | [DIA-100-git-worktrees-parallel-dev.md](DIA-100-git-worktrees-parallel-dev.md) |
| DIA-101 | parallel subagent execution optimization: parallelization rules, dependency detection, resource/shared-file conflicts | opencode-config | Medium | CLOSED | [DIA-101-parallel-subagent-execution.md](DIA-101-parallel-subagent-execution.md) |
| DIA-102 | specification-document workflow: lifecycle, naming, commit policy, obsolete handling, spec-impl linkage, agent discovery | docs | Medium | CLOSED | [DIA-102-specification-workflow.md](DIA-102-specification-workflow.md) |
| DIA-103 | interview batch completeness enforcement: verify workflow captures ALL questions, not just the first | opencode-config | Medium | OPEN | [DIA-103-interview-batch-completeness.md](DIA-103-interview-batch-completeness.md) |
| DIA-104 | mandatory developer grilling/design review gate: trigger conditions, stages, exit criteria, blocking conditions | docs | Medium | OPEN | [DIA-104-mandatory-developer-grilling-gate.md](DIA-104-mandatory-developer-grilling-gate.md) |
| DIA-105 | Edit-time formatter hooks - run formatters automatically after edits (Claude Code hooks pattern) | opencode-config | Medium | CLOSED | [DIA-105-edit-time-formatter-hooks.md](DIA-105-edit-time-formatter-hooks.md) |
| DIA-106 | Container-first rust-analyzer for LSP gate (pin 1.83.0->1.97.1, container-aware check-host-lsp) | dev-infra | Medium | CLOSED | [DIA-106-rust-analyzer-container-setup.md](DIA-106-rust-analyzer-container-setup.md) |
| DIA-107 | rust-analyzer container setup review-cycle re-verify | dev-infra | Low | CLOSED | [DIA-107-rust-analyzer-review-cycle-reverify.md](DIA-107-rust-analyzer-review-cycle-reverify.md) |
| DIA-108 | audit optimal model assignment across OpenCode agents (usage-driven) | opencode-config | Medium | CLOSED | [DIA-108-optimal-model-assignment-audit.md](DIA-108-optimal-model-assignment-audit.md) |
| DIA-109 | restart-verify DIA-087/084 config changes (section-10 Phase 5) | opencode-config | Low | CLOSED | [DIA-109-restart-verify-dia087-084-config.md](DIA-109-restart-verify-dia087-084-config.md) |
| DIA-110 | add human-readable descriptors to ALL DIA ticket filenames (critical) | docs | Critical | CLOSED | [DIA-110-unreadable-ticket-filenames.md](DIA-110-unreadable-ticket-filenames.md) |
| DIA-111 | model escalation routing for coder and analyzer agents (research-first) | opencode-config | Medium | CLOSED | [DIA-111-coder-analyzer-model-escalation.md](DIA-111-coder-analyzer-model-escalation.md) |
| DIA-112 | section-10 ticket gate fires despite OPEN + indexed + referenced ticket (correlation bug) | opencode-config | Major | CLOSED | [DIA-112-ticket-gate-correlation-bug.md](DIA-112-ticket-gate-correlation-bug.md) |
| DIA-113 | audit workflow-adherence discipline + agentic autonomy configuration vs newest best practices | opencode-config | Major | CLOSED | [DIA-113-workflow-adherence-autonomy-audit.md](DIA-113-workflow-adherence-autonomy-audit.md) |
| DIA-114 | evaluate MiMo-V2.5-Pro agentic coding capability (DIA-087 R5 follow-up) | opencode-config | Medium | CLOSED | [DIA-114-mimo-v25-pro-evaluation.md](DIA-114-mimo-v25-pro-evaluation.md) |
| DIA-115 | mandatory evidence (citations/experiments) for agent decision-variant presentations - cross-agent policy, research-first | opencode-config | Medium | CLOSED | [DIA-115-evidence-based-decision-variants.md](DIA-115-evidence-based-decision-variants.md) |
| DIA-116 | live in-repo Rung-3 benchmark: kimi-k3 vs deepseek-v4-pro vs mimo-v2.5-pro (DIA-111/DIA-114 follow-up) | opencode-config | Medium | CLOSED | [DIA-116-rung3-live-benchmark.md](DIA-116-rung3-live-benchmark.md) |
| DIA-117 | git worktree remove --force missing from DIA-096 permission deny list - config hardening (DIA-100 FALSIFICATION-1) | opencode-config | Major | CLOSED | [DIA-117-worktree-force-remove-config-hardening.md](DIA-117-worktree-force-remove-config-hardening.md) |
| DIA-118 | scripts/worktrees.sh missing executable bit - direct invocation fails exit 126 | dev-infra | Low | CLOSED | [DIA-118-worktrees-sh-missing-executable-bit.md](DIA-118-worktrees-sh-missing-executable-bit.md) |
| DIA-119 | make test-shell exit 2 - verify-pre-push bats pnpm sandbox failure (test 187 ERR_PNPM_NO_IMPORTER_MANIFEST_FOUND) | dev-infra | Low | CLOSED | [DIA-119-test-shell-pnpm-sandbox-failure.md](DIA-119-test-shell-pnpm-sandbox-failure.md) |
| DIA-120 | delegation-observer handoff-writer clobbers valid handoff on in-flight log_decision - false checksum mismatch escalation | opencode-config | Medium | CLOSED | [DIA-120-plugin-handoff-writer-clobber-bug.md](DIA-120-plugin-handoff-writer-clobber-bug.md) |
| DIA-121 | bats-wrapper.sh claims v1.11.0 but vendored bats is v1.14.0 - version drift | dev-infra | Low | CLOSED | [DIA-121-bats-version-drift-wrapper-vendor.md](DIA-121-bats-version-drift-wrapper-vendor.md) |
| DIA-122 | needs-input ticker + notifications: surface which opencode session awaits developer input | opencode-config | Medium | CLOSED | [DIA-122-needs-input-ticker.md](DIA-122-needs-input-ticker.md) |
| DIA-123 | deterministic opencode restart detection for the orchestrator | opencode-config | Medium | CLOSED | [DIA-123-deterministic-restart-detection.md](DIA-123-deterministic-restart-detection.md) |
| DIA-124 | orchestrator must write and verify a terminal handoff BEFORE presenting session-end / new-session prompt | opencode-config | Major | CLOSED | [DIA-124-handoff-before-session-end.md](DIA-124-handoff-before-session-end.md) |
| DIA-125 | automate ticket creation & management - evaluate ready-made local solutions (MCP/self-hosted) vs manual ledger | opencode-config | Medium | CLOSED | [DIA-125-automate-ticket-management-research.md](DIA-125-automate-ticket-management-research.md) |
| DIA-126 | autonomous overnight mode: permission allow-list + no-stall guarantees (agents ask for folder-read permissions and stall for hours) | opencode-config | Major | OPEN | [DIA-126-autonomous-mode-permission-hardening.md](DIA-126-autonomous-mode-permission-hardening.md) |
| DIA-127 | OMO slim 2.2.13 update evaluation - research what is new, decide safety/worth for the project | opencode-config | Medium | CLOSED | [DIA-127-omo-slim-2-2-13-update-evaluation.md](DIA-127-omo-slim-2-2-13-update-evaluation.md) |
| DIA-128 | OMO plugin repeatedly warns 'inline prompt overrides prompt file' for coder and analyzer agents | opencode-config | Medium | CLOSED | [DIA-128-omo-inline-prompt-overrides-warning.md](DIA-128-omo-inline-prompt-overrides-warning.md) |
| DIA-129 | crawl4ai crwl fallback fails: Playwright pins chromium revision 1228, host cache has 1234 only | dev-infra | Medium | CLOSED | [DIA-129-crawl4ai-playwright-chromium-revision-skew.md](DIA-129-crawl4ai-playwright-chromium-revision-skew.md) |
| DIA-130 | Duplicated OMO inline-override warnings still visible in opencode TUI 'Loading plugins...' area (residual after DIA-128) | opencode-config | Major | CLOSED | [DIA-130-duplicated-inline-override-warning-ui.md](DIA-130-duplicated-inline-override-warning-ui.md) |
| DIA-131 | post-restart TUI re-verify of user-level inline-override fix (DIA-130 review finding F3) | opencode-config | Major | CLOSED | [DIA-131-post-restart-tui-reverify.md](DIA-131-post-restart-tui-reverify.md) |
| DIA-132 | coder-escalated (kimi-k3) ONE-SHOT silent failure on DIA-130 (empty result, zero writes) + hardening question | opencode-config | Medium | CLOSED | [DIA-132-coder-escalated-silent-failure.md](DIA-132-coder-escalated-silent-failure.md) |
| DIA-133 | data-driven dispatch routing: orchestrator selects lane by model benchmarks + pricing + quota | opencode-config | Medium | CLOSED | [DIA-133-dispatch-routing-benchmark-pricing.md](DIA-133-dispatch-routing-benchmark-pricing.md) |
| DIA-134 | overnight destructive-command baseline + overnight.sh payload shape validation (DIA-126a ai-auditor suggestions S1/S2) | opencode-config | Low | OPEN | [DIA-134-overnight-hardening-baseline.md](DIA-134-overnight-hardening-baseline.md) |
| DIA-135 | research-pipeline optimization: order corruption + double source fetch + binary persistence decision | opencode-config | Major | OPEN | [DIA-135-research-pipeline-optimization-order-corruption-double-source-fetch-binary-persistence-decision.md](DIA-135-research-pipeline-optimization-order-corruption-double-source-fetch-binary-persistence-decision.md) |
| DIA-136 | orchestrator session records: research JSON-DB + API layer (lowdb/json-server/nedb/tinydb) for visibility, reliability, determinism, token economy | opencode-config | Medium | OPEN | [DIA-136-orchestrator-session-records-research-json-db-api-layer-lowdb-json-server-nedb-tinydb-for-visibility-reliability-determinism-token-economy.md](DIA-136-orchestrator-session-records-research-json-db-api-layer-lowdb-json-server-nedb-tinydb-for-visibility-reliability-determinism-token-economy.md) |
| DIA-137 | orchestrator routine work and artifact systems: research lightweight reliable tools to simplify operations (sibling of DIA-136) | opencode-config | Medium | OPEN | [DIA-137-orchestrator-routine-work-and-artifact-systems-research-lightweight-reliable-tools-to-simplify-operations-sibling-of-dia-136.md](DIA-137-orchestrator-routine-work-and-artifact-systems-research-lightweight-reliable-tools-to-simplify-operations-sibling-of-dia-136.md) |
| DIA-138 | Audit agent instruction/prompt files (.ts and .md) for inaccuracies, duplications, vague wording | opencode-config | Medium | CLOSED | [DIA-138-agent-instruction-files-audit.md](DIA-138-agent-instruction-files-audit.md) |
| DIA-139 | Audit pre-commit and pre-push hook test coverage (turbo-driven) for edge-case gaps | git-hooks | Medium | CLOSED | [DIA-139-hook-test-coverage-audit.md](DIA-139-hook-test-coverage-audit.md) |
| DIA-140 | Analyze task parallelization in agent prompts - maximize concurrent execution without file-write conflicts | opencode-config | Medium | CLOSED | [DIA-140-task-parallelization-analysis.md](DIA-140-task-parallelization-analysis.md) |
| DIA-141 | Fix agent-instruction audit findings: HANDOFF.md refs, missing AGENTS.md section 10, boss_append.md duplicate | opencode-config | Major | VERIFIED | [DIA-141-fix-agent-instruction-findings.md](DIA-141-fix-agent-instruction-findings.md) |
| DIA-142 | Wire host-runnable gates into hooks and fix turbo.json test.inputs cache masking | git-hooks | Major | VERIFIED | [DIA-142-wire-host-gates-into-hooks.md](DIA-142-wire-host-gates-into-hooks.md) |
| DIA-143 | Enable safe task parallelization: BATCH-DISPATCH rule, memory-shelf centralization, ID preallocation, serialization points | opencode-config | Major | VERIFIED | [DIA-143-batch-dispatch-config-changes.md](DIA-143-batch-dispatch-config-changes.md) |
| DIA-144 | Make delegation-observer A1 warning batch-aware (only warn on unsafe parallel task batches) | opencode-config | Medium | VERIFIED | [DIA-144-batch-aware-a1-plugin.md](DIA-144-batch-aware-a1-plugin.md) |
| DIA-145 | Give opencode-docker container host docker/podman socket access so pre-commit hooks work from inside OpenCode | docker | Major | VERIFIED | [DIA-145-opencode-docker-host-socket-access.md](DIA-145-opencode-docker-host-socket-access.md) |
| DIA-146 | verify-pre-push recursion fork-bomb: root-cause fix (DIA-118 regression) | git-hooks | Critical | VERIFIED | [DIA-146-verify-pre-push-recursion-guard.md](DIA-146-verify-pre-push-recursion-guard.md) |
| DIA-147 | pre-push blocked: make test-shell fails inside hook (unshare 127 + guard-flag interaction suspicion) | git-hooks | Critical | VERIFIED | [DIA-147-pre-push-suite-failure.md](DIA-147-pre-push-suite-failure.md) |
| DIA-148 | test infra Phase 0: safety wins (author-studio fails loudly, flaky-pin tests removed, config gate hardened) | tests-infra | Major | CLOSED | [DIA-148-test-infra-phase0-safety-wins.md](DIA-148-test-infra-phase0-safety-wins.md) |
| DIA-149 | test infra Phase 1: de-duplication (bats helpers, it.each, bash -n auto-discovery, per-package dependsOn) | tests-infra | Medium | CLOSED | [DIA-149-test-infra-phase1-dedup.md](DIA-149-test-infra-phase1-dedup.md) |
| DIA-150 | test infra Phase 2: critical gaps (vitest in author-studio, real data-contracts test) | tests-infra | Critical | CLOSED | [DIA-150-test-infra-phase2-critical-gaps.md](DIA-150-test-infra-phase2-critical-gaps.md) |
| DIA-151 | test infra Phase 3: Orchestrator contract test (acceptWorkerResult, zero mocks) | tests-infra | Medium | CLOSED | [DIA-151-test-infra-phase3-orchestrator-contract.md](DIA-151-test-infra-phase3-orchestrator-contract.md) |
| DIA-152 | Install docker CLI + compose plugin in poetry-dev image (pre-push test-config gate) | docker | Major | VERIFIED | [DIA-152-install-docker-cli-poetry-dev-image.md](DIA-152-install-docker-cli-poetry-dev-image.md) |

## Status summary

| Severity | Count |
| -------- | ----- |
| Blocker  | 7     |
| Critical | 5     |
| Major    | 34    |
| Medium   | 47    |
| Minor    | 0     |
| Low      | 10    |
| Info     | 0     |

| Status      | Count |
| ----------- | ----- |
| OPEN        | 13    |
| DONE        | 3     |
| VALIDATE    | 0     |
| E2E         | 0     |
| DEFERRED    | 1     |
| MONITOR     | 1     |
| FIXED       | 1     |
| IMPLEMENTED | 0     |
| VERIFIED    | 21    |
| CLOSED      | 63    |
| BLOCKED     | 0     |
| DISPATCHED  | 0     |
| RUNNING     | 0     |
| COMPLETE    | 0     |

## How to add a ticket

1. Copy `_TEMPLATE.md` → `DIA-<NNN>-<human-slug>.md` (YAML frontmatter format);
   the slug is a short kebab-case descriptor derived from the title (see
   DIA-110: bare `DIA-<NNN>.md` names are deprecated).
2. Fill all fields; `Fix` and `Re-verify` stay blank with a "fill at fix time /
   re-verify time" note until the work happens.
3. Add a row to the index table above with matching Severity and Status.
4. Update the status summary counts.
