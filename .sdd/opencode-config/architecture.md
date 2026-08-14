# Architecture: opencode-config

> **Created:** 2026-08-13
> **Status:** seeded
> **Parent:** `architecture.md` (root system architecture authority)
> **Module:** opencode-config (OpenCode configuration, agents, plugins, presets)
> **Decision source:** architector design for DIA-132 "Parallel Coders (Batch D Expansion)" (approved 2026-08-13)

## Purpose

This document records the architecture decisions that govern future batch-pattern
changes to the OpenCode configuration: how parallel `@coder` dispatches are made
safe (Batch Pattern D) and how the batch-classification heuristic treats single
delegations (Singleton-Batch Semantic Exemption). Both ADRs are transcribed
verbatim from the approved architector design; they are the long-lived home of
decisions that would otherwise live only in the change artifacts.

## ADR 1: Batch Pattern D (Parallel Coders)

- **Status:** Accepted
- **Context:** Developer requires parallel implementation throughput without git conflicts (DIA-132).
- **Decision:** Enable parallel @coder dispatches (Batch D) gated by a strict WORKTREE: <path> payload assertion. The delegation-observer plugin dynamically validates that parallel coder tasks assert distinct worktree paths.
- **Consequences:** Enables horizontal scaling of feature implementation. Orchestrator must manage git worktree lifecycles and serialize final squash-merges.
- **Alternatives Considered:** Parallelizing without worktrees (rejected: high risk of git index locks and file contention).

## ADR 2: Singleton-Batch Semantic Exemption

- **Status:** Accepted
- **Context:** A single task() dispatch fired alongside semantic plugin tools (like log_decision()) was incorrectly flagged as an unsafe parallel batch because the hook counted total tools, not just tasks.
- **Decision:** Short-circuit classification to safe immediately if the batch contains exactly one task() call.
- **Consequences:** Eliminates false-positive A1 warnings for single delegations.
- **Alternatives Considered:** Forcing log_decision into a separate orchestrator turn (rejected: wastes context budget and token cycles).
