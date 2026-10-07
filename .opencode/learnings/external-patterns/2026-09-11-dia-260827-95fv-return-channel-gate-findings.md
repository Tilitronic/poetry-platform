# DIA-260827-95fv - ai-specialist gate findings

**Scope:** registration only; no implementation or configuration changes.

## Findings

- **Board authority:** The Background Job Board is the sole source of truth for
  terminal lifecycle outcomes. A `Task cancelled` receipt is not terminal
  evidence. Project `cancelled` only when `terminalState=cancelled` and
  `cancellationRequested=true`. Sources: [mitigation design](../../../docs/design/95fv-return-channel-mitigation-design.md#2-verification-steps-performed-read-only),
  [OpenSpec design](../../../openspec/changes/task-return-channel-state-reliability/design.md#decisions),
  [spec](../../../openspec/changes/task-return-channel-state-reliability/specs/task-return-channel-lifecycle/spec.md#requirement-board-confirmed-cancellation).

- **Separate projected return type:** Keep legacy `running`, `completed`,
  `error`, and confirmed `cancelled`; add exactly
  `return-channel-pending` and `stopped-without-result`. Pending covers absent,
  live, contradictory, or unconfirmed evidence. Stopped requires non-live,
  `terminalUnreconciled=true`, and no terminal result. Sources: [OpenSpec
  design](../../../openspec/changes/task-return-channel-state-reliability/design.md#decisions),
  [lifecycle spec](../../../openspec/changes/task-return-channel-state-reliability/specs/task-return-channel-lifecycle/spec.md#requirement-explicit-non-terminal-lifecycle-states).

- **Idle/deletion and tombstones:** Do not treat idle as proof of completion
  when no result exists. Do not drop an unreconciled record on session deletion;
  preserve it as a listable tombstone so exact-session recovery can inspect it.
  Sources: [mitigation design](../../../docs/design/95fv-return-channel-mitigation-design.md#v3-confirmed-board-reconciliation-path),
  [mitigation C](../../../docs/design/95fv-return-channel-mitigation-design.md#mitigation-c---board-reopen-guard-background-job-board-only).

- **Explicit metadata wire format:** Every pending or stopped projection must
  carry exactly the recovery metadata `task_id`, `board_state`,
  `cancellationRequested`, and `terminalUnreconciled`. Serialize the state and
  metadata in the established task return envelope; preserve legacy state lines
  byte-for-byte, and never synthesize or serialize a guessed `terminalState`.
  The RED tests must assert the field names, values, and presence for both new
  states. Sources: [lifecycle spec](../../../openspec/changes/task-return-channel-state-reliability/specs/task-return-channel-lifecycle/spec.md#requirement-recovery-metadata-and-tombstone-preservation),
  [mitigation B](../../../docs/design/95fv-return-channel-mitigation-design.md#mitigation-b---distinct-stopped-without-result-state-taskts--board).

- **Retention contradiction:** The OpenSpec design says tombstones survive
  explicit recovery or the existing 500-entry bound, but the mitigation draft
  describes `MAX_PROCESSED_INJECTED_COMPLETIONS=500`, which is a processed
  completion deduplication bound, not proven Board-history retention. Do not
  claim the retention contract is settled or add a time-based setting. The
  implementation must first verify the actual Board eviction path; until then,
  deletion is allowed only on explicit recovery and unreconciled tombstones
  remain inspectable. Sources: [OpenSpec retention decision](../../../openspec/changes/task-return-channel-state-reliability/design.md#decisions),
  [draft open question](../../../docs/design/95fv-return-channel-mitigation-design.md#5-open-questions-for-implementer),
  [constant](../../../.opencode/oh-my-opencode-slim/src/hooks/task-session-manager/index.ts).

- **Required RED tests:** Before GREEN work, a different coder instance must
  write failing tests for live receipt to pending, cancellation without a
  request, stopped tombstone plus all metadata, confirmed cancellation,
  failed/result-less exact-session resume, idle/deletion preservation, and
  unchanged legacy parsing. Source: [tasks](../../../openspec/changes/task-return-channel-state-reliability/tasks.md#1-define-the-failing-lifecycle-contract-red).

- **Implementation constraints:** No new dependency, timer, retention
  configuration, observer-lifecycle rewrite, or inferred terminal state. Use
  the existing task-output, Board, and exact-session recovery seams; pending
  work waits/rechecks, stopped work resumes the exact session, and replacement
  dispatch is permitted only after confirmed cancellation. RED and GREEN must
  use different coder instances. Sources: [OpenSpec design](../../../openspec/changes/task-return-channel-state-reliability/design.md#goals--non-goals),
  [architecture ADR 3](../../../.sdd/opencode-config/architecture.md#adr-3-strict-instance-separation-red-test-author-vs-green-implementer),
  [recovery procedure](../../../docs/design/95fv-return-channel-mitigation-design.md#mitigation-d---orchestrator-verify-step-procedure--resume-truncated-lane).
