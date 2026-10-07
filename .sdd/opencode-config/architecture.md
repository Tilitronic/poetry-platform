# Architecture: opencode-config

> **Created:** 2026-08-13
> **Status:** active
> **Parent:** `architecture.md` (root system architecture authority)
> **Module:** opencode-config (OpenCode configuration, agents, plugins, presets)
> **Decision source:** architector design for DIA-172 "Parallel Coders (Batch D Expansion)" (approved 2026-08-13); DIA-175 coder prompt hygiene policies (2026-08-14)

## Purpose

This document records the architecture decisions that govern future batch-pattern
changes to the OpenCode configuration: how parallel `@coder` dispatches are made
safe (Batch Pattern D), how the batch-classification heuristic treats single
delegations (Singleton-Batch Semantic Exemption), and the DIA-175 coder-lane
workflow policies (strict RED/GREEN instance separation, same-session fix loops).
ADRs 1-2 are transcribed verbatim from the approved architector design; ADRs 3-4
record the DIA-175 policy decisions named in the DIA-175 CHANGELOG entry. They are
the long-lived home of decisions that would otherwise live only in the change
artifacts.

## ADR 1: Batch Pattern D (Parallel Coders)

- **Status:** Accepted
- **Context:** Developer requires parallel implementation throughput without git conflicts (DIA-172).
- **Decision:** Enable parallel @coder dispatches (Batch D) gated by a strict WORKTREE: <path> payload assertion. The delegation-observer plugin dynamically validates that parallel coder tasks assert distinct worktree paths.
- **Consequences:** Enables horizontal scaling of feature implementation. Orchestrator must manage git worktree lifecycles and serialize final squash-merges.
- **Alternatives Considered:** Parallelizing without worktrees (rejected: high risk of git index locks and file contention).

## ADR 2: Singleton-Batch Semantic Exemption

- **Status:** Accepted
- **Context:** A single task() dispatch fired alongside semantic plugin tools (like log_decision()) was incorrectly flagged as an unsafe parallel batch because the hook counted total tools, not just tasks.
- **Decision:** Short-circuit classification to safe immediately if the batch contains exactly one task() call.
- **Consequences:** Eliminates false-positive A1 warnings for single delegations.
- **Alternatives Considered:** Forcing log_decision into a separate orchestrator turn (rejected: wastes context budget and token cycles).

## ADR 3: Strict Instance Separation (RED test-author vs GREEN implementer)

- **Status:** Accepted (DIA-175, 2026-08-14)
- **Context:** After the DIA-174 one-shot batch-D run reused the same coder sessions for RED (test-writing) and GREEN (implementation), developer questions surfaced whether the prompt surfaces mandated a separation. Without an explicit rule, the same instance both authors tests and implements them, removing independent verification at the slice level.
- **Decision:** RED test-writing and GREEN implementation for the same slice MUST be dispatched to DIFFERENT coder instances; the test-author never implements the slice it tested. The role (test-author or implementer) is set by the orchestrator dispatch payload.
- **Consequences:** Codified in AGENTS.md section 2.3, coder_append.md, orchestrator_append.md (rule R4), and all 3 OMO preset prompts (byte-identical INSTANCE-SEPARATION RULE block). Supersedes the DIA-174 same-session GREEN reuse practice.
- **Alternatives Considered:** Allow same-session reuse when context continuity helps (rejected: weakens the independence of RED assertions from the implementing instance); no codification (rejected: ambiguity caused the DIA-174 pattern).

## ADR 4: Same-Session Fix Loops

- **Status:** Accepted (DIA-175, 2026-08-14)
- **Context:** Fix-loop dispatches were not required to resume the coder session that wrote the code, so fresh instances lost the implementer's context (what was written, why, and where), causing re-discovery loops and drift in fixes.
- **Decision:** Fix-loop dispatches MUST resume the SAME coder session that wrote the code (resume by task_id/session_id per the orchestrator recall protocol), never a fresh instance.
- **Consequences:** Codified in AGENTS.md section 2.3.1, orchestrator_append.md (rule R5), and all 3 OMO preset prompts (byte-identical SAME-SESSION FIXES block). Fixes keep the implementer's context; pairs with ADR 3 (RED/GREEN separation applies to new slices, fix loops resume the implementer).
- **Alternatives Considered:** Fresh instance per fix (rejected: loses context, contradicts the existing recall/resume-via-session_id preference).
