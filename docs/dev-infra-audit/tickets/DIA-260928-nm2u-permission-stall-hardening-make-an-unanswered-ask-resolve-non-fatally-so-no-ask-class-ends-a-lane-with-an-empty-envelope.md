# DIA-260928-nm2u - permission stall hardening: make an unanswered ask resolve non-fatally so no ask class ends a lane with an empty envelope

---

id: DIA-260928-nm2u
title: "permission stall hardening: make an unanswered ask resolve non-fatally so no ask class ends a lane with an empty envelope"
area: scripts
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-28
source: inventory
date: 2026-09-28
created: 2026-09-28
updated: 2026-09-28

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence: []

---

## Description

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

### Problem

In unattended/parallel runs a permission configured `ask` is not a question - it is a deterministic 5-minute stall followed by death. `deny` fails instantly; `ask` is the only fatal action. Raising PERMISSION_STALL_TIMEOUT_MINUTES is a stopgap only: it buys time, it does not remove the death. The watchdog that force-rejects at the timeout lives in `.opencode/plugins/needs-input-observer.ts` (autoRejectPermission around lines 411-479, env-tuned bound around lines 316-323, default 300 s) and the auto-reject path ends the child turn. The asks originate in OpenCode core, not in a plugin.

### Provenance

This item is OPTION O4 from the analysis at `knowledge/ana-260927-6bpp-scratch-permission-model-safety/ana-260927-6bpp-scratch-permission-model-safety-report.md` (option list around lines 74-93: O1 status quo, O2 check-only helper, O3 performing wrapper, O4 stall-side hardening, O5 do nothing).

Quote O4 verbatim:

"O4 Keep the four rules; harden the STALL itself instead: shorter/env-tuned timer, surfaced ask (parent/orchestrator-visible), or fast auto-answer so no ask ever sits unanswered for 300 s."

Decision record: ADR-001 in `.sdd/scratch-lifecycle/architecture.md` (Status: proposed) directs the next authorized spend at O4 and declines O2 and O3. Quote its O4 direction verbatim:

"Direct the next authorized spend at O4: make an unanswered ask non-fatal - tune/shorten the stall bound, surface the ask, or synthesize a non-fatal decision - so no ask class can end a lane with an empty envelope."

### Required invariant

Quote verbatim from `.sdd/scratch-lifecycle/architecture.md`:

"For every coder-lane permission ask, the ask resolves within the configured stall bound to either an explicit decision or a synthesized non-fatal decision, and the child turn always ends with a non-empty result envelope."

And its test:

"Test: inject an outstanding ask, advance the clock past the stall bound, then assert no permission_auto_rejected row is followed by a zero-length envelope and the lane returns non-empty text."

### Acceptance criteria

- [ ] An unanswered ask resolves within the configured stall bound to an explicit or synthesized NON-FATAL decision.
- [ ] No permission_auto_rejected row is followed by a zero-length result envelope.
- [ ] A lane that hit the stall bound returns NON-EMPTY result text.
- [ ] The resolution mechanism is covered by plugin tests that inject an outstanding ask and advance the clock past the bound.
- [ ] Raising the timeout is explicitly NOT the fix; any timer change is documented as a stopgap only.

### Routing and relations

Route per AGENTS.md section 2.5: read-only research gate first, then an evidence-backed decision-variant presentation to the developer, then implementation with plugin tests, then config validation plus restart-verify, then independent audit, then changelog registration plus learnings outcome.

Related tickets to name:

- DIA-260926-5vin (OPEN, the campaign ticket that authored O4; its own scope does NOT include the non-fatal-ask item)
- DIA-260926-9p7x (OPEN, covers only the surfacing/queue half of a blocked lane, not making the ask non-fatal)
- DIA-260928-rzty (OPEN, the permission-guard finding, whose in-workspace destructive path shows the ask-suppression rules did not close the hole)
- DIA-260927-vw0o (worktree scratch path ask, deferred)
- DIA-260903-oj59 (thresholds)
- DIA-260825-nts7 (prior 300 s watchdog auto-reject incident)

### First ledger record

This item was previously tracked ONLY in the analysis, in ADR-001, and in handoff prose - this ticket is its first ticket-ledger record.

### EBDV decision (2026-09-28)

- Chosen variant: O-B (run-mode-gated fast ask synthesis) + O-D (observer-side envelope guard), gated on `OPENCODE_UNATTENDED=1`.
- Alternatives presented with evidence and not chosen: O-A config-only (cannot cover unenumerated ask classes), O-C wait for the upstream permission.ask hook (unusable today, #7006), O5 status quo (accepts continuing ask-class lane deaths).
- Developer sign-offs, all four approved 2026-09-28: (1) the fast path covers ALL asks in unattended mode, not coder-lane children only; (2) the allow-sublist seed is approved exactly as designed - permission bash, `rm` with exactly one non-flag target under `.scratch/`, both anchor forms, multi-argument rm rejects as a whole, any future entry needs its own ticket plus sign-off; (3) gating signal `OPENCODE_UNATTENDED=1` exported by `scripts/overnight.sh`; (4) `.sdd/scratch-lifecycle/architecture.md` ADR-001 flipped to superseded (partial).
- Design record: `.sdd/permission-stall-hardening/architecture.md` (ADR-001..004 accepted, invariant and its test recorded there).
- Remaining work: RED plugin tests (fast-resolve suite incl. the invariant test), GREEN implementation, config + plugin validation, a live unattended probe to confirm the SDK accepts a reply at T~0 and whether core honors the task-output mutation, independent audit, changelog registration.
- Known CLI limitation carried: `scripts/tickets update` has no severity/description setter and `--fix-file` replaces the FIRST `## Fix` body, so this ticket already carries a duplicate `## Fix` section; see DIA-260926-k8ej.

## Fix

### Problem

In unattended/parallel runs a permission configured `ask` is not a question - it is a deterministic 5-minute stall followed by death. `deny` fails instantly; `ask` is the only fatal action. Raising PERMISSION_STALL_TIMEOUT_MINUTES is a stopgap only: it buys time, it does not remove the death. The watchdog that force-rejects at the timeout lives in `.opencode/plugins/needs-input-observer.ts` (autoRejectPermission around lines 411-479, env-tuned bound around lines 316-323, default 300 s) and the auto-reject path ends the child turn. The asks originate in OpenCode core, not in a plugin.

### Provenance

This item is OPTION O4 from the analysis at `knowledge/ana-260927-6bpp-scratch-permission-model-safety/ana-260927-6bpp-scratch-permission-model-safety-report.md` (option list around lines 74-93: O1 status quo, O2 check-only helper, O3 performing wrapper, O4 stall-side hardening, O5 do nothing).

Quote O4 verbatim:

"O4 Keep the four rules; harden the STALL itself instead: shorter/env-tuned timer, surfaced ask (parent/orchestrator-visible), or fast auto-answer so no ask ever sits unanswered for 300 s."

Decision record: ADR-001 in `.sdd/scratch-lifecycle/architecture.md` (Status: proposed) directs the next authorized spend at O4 and declines O2 and O3. Quote its O4 direction verbatim:

"Direct the next authorized spend at O4: make an unanswered ask non-fatal - tune/shorten the stall bound, surface the ask, or synthesize a non-fatal decision - so no ask class can end a lane with an empty envelope."

### Required invariant

Quote verbatim from `.sdd/scratch-lifecycle/architecture.md`:

"For every coder-lane permission ask, the ask resolves within the configured stall bound to either an explicit decision or a synthesized non-fatal decision, and the child turn always ends with a non-empty result envelope."

And its test:

"Test: inject an outstanding ask, advance the clock past the stall bound, then assert no permission_auto_rejected row is followed by a zero-length envelope and the lane returns non-empty text."

### Acceptance criteria

- [ ] An unanswered ask resolves within the configured stall bound to an explicit or synthesized NON-FATAL decision.
- [ ] No permission_auto_rejected row is followed by a zero-length result envelope.
- [ ] A lane that hit the stall bound returns NON-EMPTY result text.
- [ ] The resolution mechanism is covered by plugin tests that inject an outstanding ask and advance the clock past the bound.
- [ ] Raising the timeout is explicitly NOT the fix; any timer change is documented as a stopgap only.

### Routing and relations

Route per AGENTS.md section 2.5: read-only research gate first, then an evidence-backed decision-variant presentation to the developer, then implementation with plugin tests, then config validation plus restart-verify, then independent audit, then changelog registration plus learnings outcome.

Related tickets to name:

- DIA-260926-5vin (OPEN, the campaign ticket that authored O4; its own scope does NOT include the non-fatal-ask item)
- DIA-260926-9p7x (OPEN, covers only the surfacing/queue half of a blocked lane, not making the ask non-fatal)
- DIA-260928-rzty (OPEN, the permission-guard finding, whose in-workspace destructive path shows the ask-suppression rules did not close the hole)
- DIA-260927-vw0o (worktree scratch path ask, deferred)
- DIA-260903-oj59 (thresholds)
- DIA-260825-nts7 (prior 300 s watchdog auto-reject incident)

### First ledger record

This item was previously tracked ONLY in the analysis, in ADR-001, and in handoff prose - this ticket is its first ticket-ledger record.

## Re-verify

> To be filled at re-verify time.
