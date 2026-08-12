# Dev-Infra Audit — Ticket Ledger

Ledger of all dev-infra audit tickets. Each row points to the ticket file, which
carries the full detail (description, verification, fix, re-verify evidence).

> Archive policy (2026-08-03): completed tickets (VERIFIED or CLOSED for ≥1 cycle with no reopen) move to `tickets/archive/` instead of deletion. Git history preserves all prior states. See [archive/README.md](archive/README.md) for triggers.

## Index

| ID      | Title                                                                                                                                        | Area            | Severity | Status   | Ticket file                                                                                                |
| ------- | -------------------------------------------------------------------------------------------------------------------------------------------- | --------------- | -------- | -------- | ---------------------------------------------------------------------------------------------------------- |
| DIA-045 | OpenCode config drift backlog (ai-specialist review 2026-08-04, findings F6–F21)                                                             | opencode-config | Medium   | CLOSED   | [DIA-045-opencode-config-drift-backlog.md](DIA-045-opencode-config-drift-backlog.md)                       |
| DIA-050 | .mise.toml ↔ Dockerfile.dev pin-sync gap (DIA-045 F15)                                                                                       | dev-infra       | Low      | CLOSED   | [DIA-050-mise-dockerfile-pin-sync-gap.md](DIA-050-mise-dockerfile-pin-sync-gap.md)                         |
| DIA-051 | Raw JSONL telemetry leak into human chat UI (messages.jsonl sidecar)                                                                         | opencode-config | Medium   | CLOSED   | [DIA-051-jsonl-telemetry-leak-chat-ui.md](DIA-051-jsonl-telemetry-leak-chat-ui.md)                         |
| DIA-052 | Skill dup cleanup + two-tier dup detection in validate-skills.sh (5 dirs)                                                                    | scripts         | Major    | DONE     | [DIA-052-skill-dup-cleanup.md](DIA-052-skill-dup-cleanup.md)                                               |
| DIA-053 | @ai-auditor 4-source registration + @ai-specialist docs-only narrowing                                                                       | opencode-config | Medium   | DONE     | [DIA-053-ai-auditor-4-source-registration.md](DIA-053-ai-auditor-4-source-registration.md)                 |
| DIA-054 | NEXT-RUN.md §2 council budget guard (COUNCIL-BUDGET-GUARD)                                                                                   | docs            | Medium   | DONE     | [DIA-054-council-budget-guard.md](DIA-054-council-budget-guard.md)                                         |
| DIA-055 | Write-capable token_export exposed to all subagents (permission default-allow)                                                               | opencode-config | Medium   | VERIFIED | [DIA-055-token-export-subagent-exposure.md](DIA-055-token-export-subagent-exposure.md)                     |
| DIA-056 | @ai-auditor subagent token-tool stacking loop (session error, cancelled)                                                                     | opencode-config | Medium   | VERIFIED | [DIA-056-ai-auditor-token-tool-loop.md](DIA-056-ai-auditor-token-tool-loop.md)                             |
| DIA-057 | Knowledge-workflow violation — conspect not created on research request (2026-08-06)                                                         | docs            | Low      | VERIFIED | [DIA-057-knowledge-workflow-conspect-violation.md](DIA-057-knowledge-workflow-conspect-violation.md)       |
| DIA-058 | Research persistence gap — PERSISTENCE_RECOMMENDED flag auto-ignored by orchestrator                                                         | docs            | Medium   | VERIFIED | [DIA-058-research-persistence-gap.md](DIA-058-research-persistence-gap.md)                                 |
| DIA-059 | §10 gate plugin not activated — silent failure on .opencode edits                                                                            | opencode-config | Blocker  | VERIFIED | [DIA-059-gate-plugin-not-activated.md](DIA-059-gate-plugin-not-activated.md)                               |
| DIA-060 | Orchestrator read scope missing tickets directory                                                                                            | opencode-config | Blocker  | VERIFIED | [DIA-060-orchestrator-read-scope-tickets.md](DIA-060-orchestrator-read-scope-tickets.md)                   |
| DIA-061 | Orchestrator fails to produce handoff files autonomously — core mechanism not triggered                                                      | opencode-config | Blocker  | VERIFIED | [DIA-061-orchestrator-handoff-files-failure.md](DIA-061-orchestrator-handoff-files-failure.md)             |
| DIA-062 | Orchestrator running on deepseek-v4-pro instead of deepseek-v4-flash — model misconfiguration                                                | opencode-config | Blocker  | VERIFIED | [DIA-062-orchestrator-model-misconfiguration.md](DIA-062-orchestrator-model-misconfiguration.md)           |
| DIA-063 | Orchestrator starts §10 work without creating a ticket first — ticket-creation gate not enforced                                             | opencode-config | Blocker  | OPEN     | [DIA-063-ticket-creation-gate.md](DIA-063-ticket-creation-gate.md)                                         |
| DIA-064 | cebula preset models reverted flash→pro in commit 2e0c4f3e — restore pre-commit all-flash state                                              | opencode-config | Critical | VERIFIED | [DIA-064-cebula-preset-flash-revert.md](DIA-064-cebula-preset-flash-revert.md)                             |
| DIA-066 | Tool-coverage audit script — surface unlisted default-allow tools                                                                            | scripts         | Low      | VERIFIED | [DIA-066-tool-coverage-audit-script.md](DIA-066-tool-coverage-audit-script.md)                             |
| DIA-067 | Docker dev-tool access gap — agents cannot invoke trafilatura (blocks res003 persistence)                                                    | docker          | Blocker  | VERIFIED | [DIA-067-docker-dev-tool-access-gap.md](DIA-067-docker-dev-tool-access-gap.md)                             |
| DIA-068 | delegation-observer persistence trigger never fires — state-check regex format mismatch                                                      | opencode-config | Major    | VERIFIED | [DIA-068-delegation-observer-persistence-trigger.md](DIA-068-delegation-observer-persistence-trigger.md)   |
| DIA-069 | opencode-telemetry registerCommands() rewrites command docs with literal $HOME paths                                                         | opencode-config | Major    | OPEN     | [DIA-069-telemetry-command-docs-home-paths.md](DIA-069-telemetry-command-docs-home-paths.md)               |
| DIA-070 | Telemetry plugin P2/P4 re-entrancy guard gaps (DIA-056(b) residuals)                                                                         | opencode-config | Medium   | CLOSED   | [DIA-070-telemetry-reentrancy-guard-gaps.md](DIA-070-telemetry-reentrancy-guard-gaps.md)                   |
| DIA-071 | make test-infra/test-shell exit 2 — host check-host-lsp gate fails                                                                           | dev-infra       | Low      | OPEN     | [DIA-071-make-test-gates-exit-2.md](DIA-071-make-test-gates-exit-2.md)                                     |
| DIA-072 | researcher returns unarchived facts: 4/16 sources failed to persist during conspect Phase A                                                  | docs            | Medium   | CLOSED   | [DIA-072-researcher-unarchived-facts.md](DIA-072-researcher-unarchived-facts.md)                           |
| DIA-073 | Investigate handoff coordination for parallel OpenCode sessions via session IDs                                                              | docs            | Medium   | CLOSED   | [DIA-073-handoff-coordination-session-ids.md](DIA-073-handoff-coordination-session-ids.md)                 |
| DIA-074 | Ticket filenames lack human-readable descriptors — orchestrator ticket references are opaque to the developer                                | docs            | Medium   | OPEN     | [DIA-074-ticket-filenames-descriptors.md](DIA-074-ticket-filenames-descriptors.md)                         |
| DIA-075 | DIA-061 boot-gate checksum-mismatch via snip jq wrapper + recurring coder snip-jq loop                                                       | docs            | Major    | OPEN     | [DIA-075-checksum-mismatch-snip-jq-loop.md](DIA-075-checksum-mismatch-snip-jq-loop.md)                     |
| DIA-076 | Implement DIA-063 ticket-gate fix + DIA-075 snip guardrails                                                                                  | opencode-config | Major    | VERIFIED | [DIA-076-dia063-fix-implementation.md](archive/DIA-076-dia063-fix-implementation.md)                       |
| DIA-077 | OMO background job board shows stale objective for coder-lane sessions (description-reuse)                                                   | opencode-config | Low      | DEFERRED | [DIA-077-job-board-stale-objective.md](DIA-077-job-board-stale-objective.md)                               |
| DIA-078 | coder lane repeatedly prefixes commands with snip wrapper — identical-command loop (DIA-075 recurrence, broader than jq)                     | opencode-config | Major    | OPEN     | [DIA-078-coder-snip-wrapper-loop.md](DIA-078-coder-snip-wrapper-loop.md)                                   |
| DIA-079 | delegation-observer handoff atomic write fails — JSON Parse error: Unexpected identifier "computed"                                          | opencode-config | Major    | MONITOR  | [DIA-079-handoff-write-json-parse-error.md](DIA-079-handoff-write-json-parse-error.md)                     |
| DIA-080 | orchestrator halts/stops mid-work repeatedly across sessions — requires developer "continue" nudges                                          | opencode-config | Major    | CLOSED   | [DIA-080-orchestrator-frequent-stops.md](DIA-080-orchestrator-frequent-stops.md)                           |
| DIA-081 | orchestrator boots without task tool — permission.task '\*': 'deny' last-key ordering removes task tool entirely (visibleTools findLast)     | opencode-config | Blocker  | CLOSED   | [DIA-081-orchestrator-task-tool-loss.md](archive/DIA-081-orchestrator-task-tool-loss.md)                   |
| DIA-082 | orchestrator must not perform heavy thinking/analysis itself — delegate to @analyzer; @analyzer may propose council dispatch when warranted  | opencode-config | Major    | CLOSED   | [DIA-082-orchestrator-heavy-thinking-delegation.md](DIA-082-orchestrator-heavy-thinking-delegation.md)     |
| DIA-083 | orchestrator's main role is task/resource management — automate repetition by dispatching @coder to create scripts/tools                     | opencode-config | Major    | CLOSED   | [DIA-083-orchestrator-role-task-resource-mgmt.md](DIA-083-orchestrator-role-task-resource-mgmt.md)         |
| DIA-084 | audit the artifacts folders — ensure proper order/structure, naming conventions, archive policies, index files, cross-references             | docs            | Medium   | CLOSED   | [DIA-084-artifacts-folder-audit.md](DIA-084-artifacts-folder-audit.md)                                     |
| DIA-085 | investigate parallel orchestrator sessions — handoff coordination between them (session IDs, worktrees, handoff-file ownership)              | docs            | Medium   | OPEN     | [DIA-085-handoff-parallel-orchestrator-sessions.md](DIA-085-handoff-parallel-orchestrator-sessions.md)     |
| DIA-086 | improve workflows with a modern scientific-methodology approach — evidence-based reasoning, source citing, reproduction, hypothesis building | docs            | Medium   | CLOSED   | [DIA-086-scientific-methodology-workflow.md](DIA-086-scientific-methodology-workflow.md)                   |
| DIA-087 | audit picked models and model variants for current agents — is the assignment optimal?                                                       | opencode-config | Medium   | CLOSED   | [DIA-087-agent-model-variant-audit.md](DIA-087-agent-model-variant-audit.md)                               |
| DIA-088 | teaching skill missing from the active skill registry - recover it                                                                           | skills          | Medium   | VERIFIED | [DIA-088-recover-teaching-skill.md](DIA-088-recover-teaching-skill.md)                                     |
| DIA-089 | add the book_rag skill and connect it to OpenWebUI (hybrid RAG over local engineering textbooks)                                             | skills          | Medium   | OPEN     | [DIA-089-book-rag-skill-openwebui.md](DIA-089-book-rag-skill-openwebui.md)                                 |
| DIA-090 | recover mermaid-diagramming and console-charting skills (source: opencode backup folder)                                                     | skills          | Medium   | VERIFIED | [DIA-090-recover-mermaid-console-charting-skills.md](DIA-090-recover-mermaid-console-charting-skills.md)   |
| DIA-091 | orchestrator repeatedly reports "I have no bash" across sessions — document and enforce the bash-delegation pattern                          | opencode-config | Major    | CLOSED   | [DIA-091-orchestrator-no-bash-recurring.md](DIA-091-orchestrator-no-bash-recurring.md)                     |
| DIA-092 | §10 snip-plugin-removal — remove opencode-snip@1.6.1 mechanical lock (root cause of DIA-075/DIA-078; blocks ALL bash lanes)                  | opencode-config | Major    | OPEN     | [DIA-092-snip-plugin-removal-s10.md](DIA-092-snip-plugin-removal-s10.md)                                   |
| DIA-093 | Orchestrator boot: "I have no bash tool" - DIA-061 checksum not delegated to coder lane                                                      | opencode-config | Major    | OPEN     | [DIA-093-orchestrator-no-bash-checksum-delegation.md](DIA-093-orchestrator-no-bash-checksum-delegation.md) |
| DIA-094 | Husky pre-commit hook cannot run in WSL - docker unavailable, quality gate bypassed via --no-verify                                          | dev-infra       | Major    | CLOSED   | [DIA-094-husky-precommit-wsl-docker-unavailable.md](DIA-094-husky-precommit-wsl-docker-unavailable.md)     |
| DIA-095 | Orchestrator needs an optimized project-ops reference - how to run the project, bring up docker, required gates                              | dev-infra       | Major    | CLOSED   | [DIA-095-orchestrator-project-ops-reference.md](DIA-095-orchestrator-project-ops-reference.md)             |
| DIA-096 | Git push permission policy - allow safe branch push, deny destructive commands and main push (config + git-permissions skill)                | opencode-config | Major    | CLOSED   | [DIA-096-git-push-permission-policy.md](DIA-096-git-push-permission-policy.md)                             |
| DIA-097 | Orchestrator role consolidation: task/resource mgmt, delegation, heavy-thinking separation, bash-delegation, automation-of-repetition        | opencode-config | Major    | OPEN     | [DIA-097-orchestrator-role-delegation.md](DIA-097-orchestrator-role-delegation.md)                         |
| DIA-098 | Spontaneous subagent/session stops: stalled-agent detection, auto-resume, complete-vs-interrupted classification                             | opencode-config | Major    | OPEN     | [DIA-098-spontaneous-session-stops.md](DIA-098-spontaneous-session-stops.md)                               |
| DIA-099 | Truncated/partial subagent responses: detect-preserve-resume-validate mechanism                                                              | opencode-config | Major    | OPEN     | [DIA-099-truncated-subagent-responses.md](DIA-099-truncated-subagent-responses.md)                         |
| DIA-100 | Git worktrees for parallel dev sessions: isolation, branch mgmt, merge/conflict, cleanup, OpenCode interaction                               | dev-infra       | Medium   | OPEN     | [DIA-100-git-worktrees-parallel-dev.md](DIA-100-git-worktrees-parallel-dev.md)                             |
| DIA-101 | Parallel subagent execution optimization: parallelization rules, dependency detection, resource/shared-file conflicts                        | opencode-config | Medium   | OPEN     | [DIA-101-parallel-subagent-execution.md](DIA-101-parallel-subagent-execution.md)                           |
| DIA-102 | Specification-document workflow: lifecycle, naming, commit policy, obsolete handling, spec-impl linkage, agent discovery                     | docs            | Medium   | OPEN     | [DIA-102-specification-workflow.md](DIA-102-specification-workflow.md)                                     |
| DIA-103 | Interview batch completeness enforcement: verify workflow captures ALL questions, not just the first                                         | opencode-config | Medium   | OPEN     | [DIA-103-interview-batch-completeness.md](DIA-103-interview-batch-completeness.md)                         |
| DIA-104 | Mandatory developer grilling/design review gate: trigger conditions, stages, exit criteria, blocking conditions                              | docs            | Medium   | OPEN     | [DIA-104-mandatory-developer-grilling-gate.md](DIA-104-mandatory-developer-grilling-gate.md)               |
| DIA-105 | Edit-time formatter hooks - run formatters automatically after edits (Claude Code hooks pattern)                                             | opencode-config | Medium   | OPEN     | [DIA-105-edit-time-formatter-hooks.md](DIA-105-edit-time-formatter-hooks.md)                               |
| DIA-106 | Container-first rust-analyzer for LSP gate (pin 1.83.0->1.97.1, container-aware check-host-lsp)                                              | dev-infra       | Medium   | CLOSED   | [DIA-106-rust-analyzer-container-setup.md](DIA-106-rust-analyzer-container-setup.md)                       |
| DIA-107 | rust-analyzer container setup review-cycle re-verify (section 2.3.1 cycle 1/2 of close-out commit 1dc8f76)                                   | dev-infra       | Low      | CLOSED   | [DIA-107-rust-analyzer-review-cycle-reverify.md](DIA-107-rust-analyzer-review-cycle-reverify.md)           |
| DIA-108 | audit optimal model assignment across OpenCode agents (usage-driven)                                                                         | opencode-config | Medium   | OPEN     | [DIA-108-optimal-model-assignment-audit.md](DIA-108-optimal-model-assignment-audit.md)                     |
| DIA-109 | restart-verify DIA-087/084 config changes (section-10 Phase 5)                                                                               | opencode-config | Low      | CLOSED   | [DIA-109-restart-verify-dia087-084-config.md](DIA-109-restart-verify-dia087-084-config.md)                 |
| DIA-110 | add human-readable descriptors to ALL DIA ticket filenames (critical)                                                                        | docs            | Critical | CLOSED   | [DIA-110-unreadable-ticket-filenames.md](DIA-110-unreadable-ticket-filenames.md)                           |
| DIA-111 | model escalation routing for coder and analyzer agents (research-first)                                                                      | opencode-config | Medium   | OPEN     | [DIA-111-coder-analyzer-model-escalation.md](DIA-111-coder-analyzer-model-escalation.md)                   |
| DIA-112 | section-10 ticket gate fires despite OPEN + indexed + referenced ticket (correlation bug)                                                    | opencode-config | Major    | CLOSED   | [DIA-112-ticket-gate-correlation-bug.md](DIA-112-ticket-gate-correlation-bug.md)                           |
| DIA-113 | audit workflow-adherence discipline + agentic autonomy configuration vs newest best practices                                                | opencode-config | Major    | OPEN     | [DIA-113-workflow-adherence-autonomy-audit.md](DIA-113-workflow-adherence-autonomy-audit.md)               |
| DIA-114 | evaluate MiMo-V2.5-Pro agentic coding capability (DIA-087 R5 follow-up)                                                                      | opencode-config | Medium   | OPEN     | [DIA-114-mimo-v25-pro-evaluation.md](DIA-114-mimo-v25-pro-evaluation.md)                                   |

## Status summary

| Severity | Count |
| -------- | ----- |
| Blocker  | 7     |
| Critical | 2     |
| Major    | 21    |
| Medium   | 28    |
| Minor    | 0     |
| Low      | 7     |
| Info     | 0     |

| Status      | Count |
| ----------- | ----- |
| OPEN        | 23    |
| DONE        | 3     |
| VALIDATE    | 0     |
| E2E         | 0     |
| DEFERRED    | 1     |
| MONITOR     | 1     |
| FIXED       | 0     |
| IMPLEMENTED | 0     |
| VERIFIED    | 15    |
| CLOSED      | 22    |
| BLOCKED     | 0     |

## How to add a ticket

1. Copy `_TEMPLATE.md` → `DIA-<NNN>-<human-slug>.md` (YAML frontmatter format);
   the slug is a short kebab-case descriptor derived from the title (see
   DIA-110: bare `DIA-<NNN>.md` names are deprecated).
2. Fill all fields; `Fix` and `Re-verify` stay blank with a "fill at fix time /
   re-verify time" note until the work happens.
3. Add a row to the index table above with matching Severity and Status.
4. Update the status summary counts.
