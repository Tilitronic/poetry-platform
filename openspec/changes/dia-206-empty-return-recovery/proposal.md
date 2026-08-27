# Proposal: dia-206-empty-return-recovery

> **Status:** proposed · **Scope:** dev-infra (delegation-observer plugin - empty-result detection + recovery path)
> **Escalation:** none - change stays within the existing opencode-config module boundary (per AGENTS.md 2.4/2.5, dev-infra plugin changes do not require @architector). Governing .sdd: `.sdd/opencode-config/architecture.md` (ADR 1 - the plugin is the Batch Pattern D dynamic validator). No new module boundary or technology choice is introduced.

## Motivation

The delegation-observer plugin (`delegation-observer.ts`) detects empty/truncated subagent returns (DIA-224 D3) and emits a crisis event (`content_ref=empty-result-requires-redispatch`, `resolution_status=escalated`) when a child session completes with zero file edits. A companion failure cap (DIA-225) tracks consecutive empty results and, at threshold 3, emits a `failure_cap_reached` warning.

Two defects make this detection non-recovering. They were surfaced by the DIA-206 check audit and by DIA-099 (resume-truncated-lane):

1. **Per-SESSION, not per-LANE tracking.** The failure cap is keyed by `session_id`. A single lane (e.g. `"coder"`) that repeatedly returns empty across DIFFERENT dispatch sessions is never caught, because each new session id resets the counter. The audit names this "systemic multi-lane empty-return failure": one lane's repeated empty returns are not tracked or recovered.

2. **No structured recovery signal.** The `failure_cap_reached` event carries `resolution_status="in-flight"` (non-resolving) and is WARNING ONLY. The plugin never tells the orchestrator what to DO. DIA-099 defines the orchestrator protocol (detect -> preserve -> resume -> validate) and the resume-truncated-lane skill, but the plugin never emits a structured recovery directive, so the orchestrator has nothing to act on.

This change introduces a per-LANE resolution state machine and a structured recovery signal so the orchestrator can redispatch or resume (per DIA-099) instead of merely logging a warning.

## Scope

### In scope

1. **Per-lane failure state machine:** replace the per-session `failureCap` map with a per-lane map keyed by lane id (agent name from `childSessionAgent`). Track consecutive empty-result count per lane, plus `lastSessionId` and a `state` field (`monitoring` | `stopped`).
2. **Structured recovery signal:** extend the existing crisis message rows with `lane_id` and `recovery_action` fields. Below cap: `recovery_action="redispatch"`. At/after cap: `recovery_action="stop"` and `resolution_status="escalated"` (was `"in-flight"`).
3. **At-cap behavior:** when a lane's consecutive empty-result count reaches `FAILURE_CAP_THRESHOLD` (keep 3), transition that lane's state to `"stopped"` and emit `failure_cap_reached` with `recovery_action="stop"`. The plugin does NOT auto-dispatch (orchestrator retains control per DIA-224); it signals stop and the orchestrator decides (redispatch fresh, resume same session per DIA-099, or surface to developer).
4. **Reset semantics preserved:** a non-empty result for the lane resets the per-lane counter; cooldown expiry (`FAILURE_CAP_COOLDOWN_MS`, keep 10 min) resets stale counters.
5. **Unit test:** a new test file asserting per-lane counting across distinct session ids, the recovery signal fields, reset, and cooldown.

### Out of scope

- **Orchestrator prompt edits** (how the orchestrator consumes `recovery_action`) - separate concern; this change only emits the signal. DIA-099 resume-truncated-lane is the consumer.
- **Auto-dispatch / auto-resume logic in the plugin** - explicitly NOT added (orchestrator retains control per DIA-224).
- **Registry schema changes / persistence** - the state machine is in-memory, mirroring the existing `failureCap` pattern. No new `.opencode/session` file format.
- **Changes to empty-result DETECTION itself** (DIA-224 D3) - only the recovery path is changed.

## Design authority (.sdd/) reference

Governing doc: `.sdd/opencode-config/architecture.md`. The delegation-observer plugin is the dynamic validator for Batch Pattern D (ADR 1). This change extends the plugin's empty-result handling within its existing module boundary; no new module boundary, no technology choice, no cross-cutting concern. Per AGENTS.md 2.4/2.5, dev-infra plugin changes follow the spec chain directly without architectural escalation.

Related prior art: DIA-224 (D3 empty-result detection), DIA-225 (C4 failure cap), DIA-099 (resume-truncated-lane skill + orchestrator protocol), DIA-260826-zvu4 (verification-only lane exemption, which this change must preserve).

## Success criteria

1. A lane returning empty across 3 distinct session ids is detected and triggers `failure_cap_reached` with `lane_id` set and `recovery_action="stop"`.
2. The recovery signal (`lane_id` + `recovery_action`) is present on every `empty_result_detected` and `failure_cap_reached` row, consumable by the orchestrator per DIA-099.
3. A non-empty result or cooldown expiry resets the per-lane counter (no false cap).
4. Existing behavior preserved: zero-edit coder -> `SILENT_FAILURE`; verification-only lanes (DIA-260826-zvu4) remain exempt; `READ_ONLY_LANES` exempt.
5. Unit tests pass in the poetry-dev container (`bun test`).

## Non-goals

- Automated recovery (the plugin signals; the orchestrator decides).
- Cross-lane aggregation beyond per-lane (e.g. global "too many lanes failing") - not in this change.
- Persistence of the failure state across process restarts - in-memory only, matching existing design.

## Stakeholders

| Stakeholder     | Interest                                                    |
| --------------- | ----------------------------------------------------------- |
| @orchestrator   | Consumes `recovery_action` to redispatch/resume per DIA-099 |
| @openspec-plan  | Authors this spec                                           |
| @coder          | Implements the plugin change + test                         |
| @reviewer       | Verifies spec fidelity + standards                          |
| @memory-manager | Persists lessons on completion                              |

## Rollback plan

All changes are within `delegation-observer.ts` (one file) plus one test file. Rollback = git revert of the plugin edit and deletion of the new test file. No data migrations, no schema changes, no running-service impact (plugin reloads on container restart). The in-memory state machine has no persistent side effects.

## Testing Decisions

> Per `openspec/config.yaml`: "Include a Testing Decisions section that states what makes a good test for this change, which modules will be tested, and the prior art in the codebase."

### What makes a good test here

This is a plugin behavior change with a clear public hook surface (`hooks.event` session.idle, `hooks["tool.execute.after"]` for edits and task dispatch). A good test drives empty results on distinct session ids for the same lane and asserts (a) the per-lane counter increments, (b) the recovery signal fields appear, (c) reset/cooldown work. Mirror the proven hermetic harness in `failure-cap.test.mjs` (mkdtemp workspace, `@opencode-ai/plugin` mock, dynamic import).

### Verification procedures

1. **Per-lane counting:** dispatch 3 coder tasks (distinct session ids), idle each with zero edits -> assert `failure_cap_reached` with `lane_id="coder"`, `recovery_action="stop"`.
2. **Reset on non-empty:** 2 empty + 1 edit + 2 empty for same lane -> no cap (counter reset).
3. **Cooldown:** 2 empty, advance `Date.now` past cooldown, 1 empty -> no cap.
4. **Signal presence:** each `empty_result_detected` below cap carries `recovery_action="redispatch"` and `lane_id`.
5. **Exemption preserved:** verification-only coder + zero edits -> no `SILENT_FAILURE` (regression guard for DIA-260826-zvu4).

### Prior art

- `.opencode/plugins/__tests__/failure-cap.test.mjs` (harness + cap assertions)
- `.opencode/plugins/__tests__/empty-result-detection.test.mjs` (detection + zvu4 exemption)
- `.sdd/opencode-config/architecture.md` ADR 1

---

<!--
ownership:
  substance: AI
  structure: AI
  interview_depth: compressed
-->
