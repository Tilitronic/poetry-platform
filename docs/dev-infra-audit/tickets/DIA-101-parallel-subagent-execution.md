# DIA-101 - parallel subagent execution optimization: parallelization rules, dependency detection, resource/shared-file conflicts

<!-- Analyzer-authored manifest transcribed by the coder lane (2026-08-11).
     Parallel dev infra batch ticket. opencode-config: defines which tasks
     parallelize safely, how dependencies are detected, and how
     resource/shared-file conflicts are avoided. Blocked by DIA-097
     (orchestrator role/delegation) and DIA-100 (worktrees isolation). -->

---

id: DIA-101
title: "parallel subagent execution optimization: parallelization rules, dependency detection, resource/shared-file conflicts"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: ["DIA-097", "DIA-100"]
discovered: 2026-08-11
source: inventory
date: 2026-08-11
created: 2026-08-11
updated: 2026-08-11

# --- Session Attribution (v2 schema, optional) ---

session_id: "" # OpenCode session ID that owned this ticket
lane_id: "" # e.g. cod-1, ai--3
agent: "" # agent name (coder, reviewer, etc.)
model: "" # model ID used
parent_session_id: "" # orchestrator's session ID (populated via get-my-session-id tool)
attempts: 0 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [] # list of file paths modified
artifacts: [] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

Define concrete rules for which tasks parallelize safely: (a) task categories
that parallelize (research, analysis, independent implementation slices,
review after impl); (b) dependency detection (task B blocked_by task A);
(c) resource conflicts (shared files, database migrations, config changes);
(d) parallelism limits (max N concurrent lanes to avoid context thrash);
(e) re-visit this batch's own split once rules exist (self-referential
validation - the batch brief's execution split is a first approximation to be
revisited).

### Investigation requirements

1. Enumerate task categories from the 14-item batch and classify by
   parallelizability.
2. Identify shared-file risks (opencode.jsonc, oh-my-opencode-slim.jsonc,
   AGENTS.md, README.md - all tickets touch these).
3. Define dependency graph for the batch (which items block which).
4. Propose parallelism limit (e.g., max 3 concurrent lanes).
5. Self-referential test: re-split the batch's remaining work using the new
   rules; verify the split is valid.

### Deliverables

- Parallelization rules (task categories + conflict criteria).
- Dependency detection pattern (DAG from blocked_by).
- Parallelism limit recommendation with rationale.
- Re-split of the batch (or next batch) as worked example.

## Verification

- [ ] (a) Rules documented for 4+ task categories.
- [ ] (b) Dependency graph for the batch is a valid DAG (no cycles).
- [ ] (c) Parallelism limit tested (run N concurrent lanes, observe no
      conflicts).
- [ ] (d) Re-split of batch passes own rules.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
