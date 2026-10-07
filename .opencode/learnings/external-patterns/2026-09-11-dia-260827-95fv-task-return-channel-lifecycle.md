# AI-specialist gate findings: DIA-260827-95fv

- **Source:** ai-specialist gate review for campaign ticket DIA-260827-95fv
- **Date:** 2026-09-11

1. The change is TypeScript lifecycle behavior, not JSON config.
2. The claimed 500-entry tombstone bound is not established for Board records.
3. Child idle must not convert no-result jobs to completed.
4. Deletion must preserve stopped tombstones.
5. Return-channel-pending is a Board-backed projection, not native TaskOutputState.
6. Define exact metadata wire format and no-task_id behavior.
7. Required RED tests cover live/absent/contradictory evidence, cancellation confirmation, idle/deletion tombstones, failed resume, metadata, legacy states, stale/busy/duplicate regressions.
