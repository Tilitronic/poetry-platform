# DIA-104 - Mandatory developer grilling/design review gate: trigger conditions, stages, exit criteria, blocking conditions

<!-- UPDATE 2026-08-14 (CLOSED - closure lane):
     FINAL VERDICT: CLOSED. Full chain complete:
     (1) cod-16 implementation lane (session
     ses_fff323710ffetK7rNw5XxBiJTr) - grilling gate implemented across the
     8 locations listed in Fix (orchestrator_append.md cross-reference,
     oh-my-opencode-slim.jsonc Gate Check step, openspec-propose SKILL.md
     Phase 0a gate-check, scripts/tickets cmd_new gate-marker emission,
     _TEMPLATE.md gate fields, validate-grilling-gate.sh NEW, Makefile
     test-config wiring, practice-protected.md zone 6).
     (2) ai-auditor Phase 6 audit (ai--8, session
     ses_fff222228ffeZmeX5BPXSOZtE3) verdict: NON-CONFORMANT - 7 PASS +
     finding 6 Critical (practice-protected.md policy inconsistency: zone 6
     text still claimed orchestrator-only fast-path classification, which
     contradicted the confirmed hybrid model).
     (3) Developer disposition 2026-08-14 (binding): ACCEPT finding 6,
     fix ordered.
     (4) cod-17 fix lane (session ses_fff1a5cbdffe3FEl0RH4fY7fy0) -
     practice-protected.md zone 6 reconciled to the confirmed hybrid model
     (developer owns substance + fast-path opt-in + bypass override;
     @openspec-plan may auto-classify triggers/waivers).
     (5) ai-auditor re-review (ai--9, session
     ses_fff16f2f1ffehIdjpPTMCnD3xH): finding 6 VERIFIED-CLOSED, no
     blocking findings.
     (6) Developer disposition 2026-08-14 (binding): "Close DIA-104" -
     accept the ai--9 re-review; close with the standard deferred live
     restart-verify (DIA-123 second-boot pattern; recorded in Re-verify,
     not blocking).
     README.md index row (line 57) DEFERRED - still shows OPEN; README.md
     is a protected concurrent-session file under the DIA-153 lease; the
     row flip lands when the lease holder commits. DIA-104 itself carries
     NO gate_state markers (predates the marker design; grandfather
     precedent - validate-grilling-gate.sh reports it as a legacy warning,
     which is correct and expected). -->

<!-- UPDATE 2026-08-14 (IMPLEMENTED - implementation lane; interview complete,
     substance developer-confirmed; status stays OPEN - closure is a separate
     lane: ai-auditor Phase 6 review + developer disposition + CHANGELOG):
     SESSION ATTRIBUTION - interview: openspec-plan lane, session
     ses_fff4d79b9ffesEQ8b0ZRYvyZJ8 (developer CONFIRMED the interview
     summary - the substance below was written by the developer through the
     interview answers, practice-protected satisfied; this lane structures
     only). ai-specialist gate: ai--7, session
     ses_fff3b0d25ffeSqCfIa8ICY0Dan (validated the ticket-marker design -
     four optional frontmatter fields always emitted by `tickets new` with
     defaults, no retroactive backfill, grandfather precedent: absent =
     legacy/skipped).
     blocked_by DIA-103 is CLOSED (closed 2026-08-14): its Phase 4 Completion
     Self-Check (pre-synthesis gate) is the DIA-104 stage-3 dependency and is
     SATISFIED - this ticket's stage 3 references it directly.
     No openspec/changes/ artifact created: DIA-104 is a docs/ticket-level
     process change, not a feature spec (interview confirmed no .sdd/ needed).
     Config changes take effect on next OpenCode restart - restart-verify
     DEFERRED per the DIA-123 second-boot pattern (see Re-verify). -->

<!-- UPDATE 2026-08-14 (IMPLEMENTED - implementation lane, phase 4 section-10
     lane; the definition below is the developer-confirmed substance from the
     completed interview, formalized into the Fix section; the 8 implementation
     locations were applied - see Fix; validation evidence: make test-config +
     make test-shell exit 0, see Re-verify). -->

---

id: DIA-104
title: "mandatory developer grilling/design review gate: trigger conditions, stages, exit criteria, blocking conditions"
area: docs
severity: Medium
status: CLOSED
blocked_by: ["DIA-103"] # DIA-NNN refs, or empty - DIA-103 CLOSED 2026-08-14, dependency satisfied (see UPDATE above)
discovered:
source: inventory
date: 2026-08-11
created: 2026-08-11
closed: 2026-08-14
updated: 2026-08-14

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

Define a mandatory developer grilling/design review gate before significant
changes. ana004 (spec-authoring-philosophy audit) scored current enforcement
52/100 ("embedded as intent, not enforcement"). 4 hard bypass paths outrank 4
soft ALIGNED layers. This ticket defines: (a) trigger conditions (what counts
as "significant change" - new module, cross-boundary, API change); (b) stages
(grill to design review to implementation); (c) required challenges
(assumptions, trade-offs, alternatives); (d) exit criteria (what must be
documented before proceeding); (e) blocking conditions (what prevents
proceeding without the gate); (f) exceptions for trivial changes (typo fix,
version bump, single-param tweak). Practice-protected zone: the agent guides,
the developer writes.

### Investigation requirements

1. Read practice-protected.md for current zones.
2. Read ana004 audit for bypass paths and ALIGNED layers.
3. Define trigger conditions (change scope thresholds).
4. Define stages (grill to design to implement, with gates between).
5. Define exit criteria (documented decisions, ADRs, trade-off analysis).
6. Define exceptions (trivial change criteria).

### Deliverables

- Grilling-gate reference (triggers, stages, challenges, exit criteria).
- Blocking conditions (what prevents proceeding).
- Exception criteria (trivial changes that skip the gate).
- Integration with practice-protected.md.

## Verification

- [x] (a) Trigger conditions defined (7 criteria for "significant change").
- [x] (b) Stages documented with gates between them.
- [x] (c) Required challenges defined (assumptions, trade-offs, alternatives,
      edge cases, reversibility).
- [x] (d) Exit criteria + blocking conditions + waivers defined (incl. trivial
      change criteria).
- [x] (e) practice-protected.md updated to reference the gate (zone 6).

## Fix

> Filled 2026-08-14 (implementation lane). The definition below is the
> DEVELOPER-CONFIRMED substance from the completed interview session
> (ses_fff4d79b9ffesEQ8b0ZRYvyZJ8). Practice-protected satisfied: the
> developer wrote the substance through the interview answers; this lane
> structures and formalizes. The ai-specialist gate (ai--7,
> ses_fff3b0d25ffeSqCfIa8ICY0Dan) validated the ticket-marker design.

### (a) TRIGGER CONDITIONS

A change triggers the gate if ANY of these match:

1. New module boundary (new dir under src/, new package, or new
   .sdd/<module>/architecture.md)
2. Cross-boundary change (modifies public interfaces between modules:
   exports, shared types, .tss/ contracts)
3. Schema/state change (DB schema, state machines, persistent data
   structures)
4. New public API (endpoints, CLI commands, exported functions for external
   consumption)
5. Cross-cutting concern (new technology choice, dependency, architectural
   pattern not in .sdd/)
6. Hard-to-revert change (migrations, published APIs, multi-service config)
7. New UI component (even local - a component is a distinct unit)

If none match, the change is trivial and skips the gate.

### (b) STAGES with gates between

1. **Gate check**: orchestrator checks explicit fast-path opt-in (existing
   Fast-Path Opt-In precedent in orchestrator_append.md:73-85 - developer
   must say "fast-path approved" + reason; orchestrator NEVER auto-classifies).
   If no opt-in, @openspec-plan checks the 7 triggers; if a trigger matches,
   checks waivers; if no waiver, MANDATORY GRILL.
2. **Mandatory grill**: @openspec-plan Socratic interview
   (Full/Compressed/Skip per openspec-propose SKILL.md), one question at a
   time with recommended answer. Practice-protected: developer writes
   substance.
3. **Completion self-check** (DIA-103 Phase 4): @openspec-plan states "Gate
   check: triggers matched [list], waivers checked [list], grill completed
   [Y/N], questions asked [N/M]" before synthesis.
4. **Artifact synthesis** from interview transcript only (proposal.md ->
   design.md -> tasks.md).
5. **openspec validate** (existing hard gate - @coder cannot proceed without
   validated artifacts).
6. **Implementation** (@coder).

### (c) REQUIRED CHALLENGES

The grill must surface: assumptions, trade-offs, alternatives, edge cases,
reversibility.

### (d) EXIT CRITERIA (before implementation)

- Interview transcript done.
- Artifacts pass `openspec validate`.
- Ticket frontmatter has gate_state/gate_triggers/gate_waivers/gate_override.
- Completion self-check stated and confirmed (or partial accepted with
  logged reason).

### (e) BLOCKING CONDITIONS

- Triggers match + no waiver + grill not done -> BLOCKED.
- Grill incomplete + self-check failed + developer did not accept partial ->
  BLOCKED.
- Artifacts not validated -> BLOCKED.
- Override allowed ONLY via explicit developer signal ("proceed without
  grill"), never agent auto-override.
- Not blocked when: no triggers match, waiver applies, or explicit override
  logged.

### (f) WAIVERS (skip the gate even if in-scope)

1. **Urgent hotfix** (production down / data loss) - requires "hotfix
   waiver" + reason + post-hoc spec within 48h, logged in ticket + session
   log.
2. **Incremental addition to an already-grilled module** (same session,
   prior spec exists, no new trade-offs; new trade-offs -> re-grill).
3. **Exploratory spike / proof-of-concept** (disposable, not production) -
   requires "spike, not production" + timebox; if it becomes production
   code, grill before commit.
4. **Refactor with NO behavior change** (executes the same specs - developer
   decision: waived even if cross-module). If a refactor introduces a NEW
   approach worth documenting -> architecture concern (.sdd/ ADR via
   @architector), NOT a feature spec - unless behavior/contracts change
   (then it gates).

Modified cases: concurrent sessions on related changes share one grill IF
same spec + no conflicting trade-offs (else independent grills); interrupted
interview resumes without restart but >24h gap = re-grill from scratch.

### ERROR STATES

- **Soft bypass** (trivial change was grilled): no action, calibration data
  for future (@reviewer notes "over-grilled").
- **Hard bypass** (significant change NOT grilled): detection via (1)
  @reviewer post-hoc check, (2) orchestrator pre-dispatch artifact check,
  (3) @openspec-plan self-report, (4) session-log audit. Response: present 3
  options - (a) stop + grill now, (b) proceed + post-hoc spec within 48h,
  (c) retroactive waiver with logged reason.
- **Partial bypass** (grill incomplete): DIA-103 Completion Self-Check
  catches; options continue / accept partial with logged reason / stop and
  resume later.
- **Override**: explicit developer signal required; recorded in ticket
  (gate_state: bypassed, gate_override: "explicit: <reason>") + session log.

### TICKET MARKERS (ai--7 validated design)

Optional frontmatter fields always emitted by `tickets new` with defaults; no
retroactive backfill; GRANDFATHER precedent: absent = legacy/skipped:

```
gate_state: "skipped"          # grilled | waived | bypassed | partial | skipped
gate_triggers: []              # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: []               # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: ""              # free-text: developer signal + reason; empty = no override
```

Frontmatter (not body) - state is machine-checkable. Two-layer enforcement:
(1) scripts/tickets cmd_new printf block always emits the fields with
defaults (follow the parent_epic precedent - \_TEMPLATE.md:22 optional +
scripts/tickets:807-810 always emitted); (2) future
validate-grilling-gate.sh validator (opt-in, warn-not-fail on legacy;
hard-fail when gate_state=bypassed but gate_override empty). gate_override
must be YAML-quoted (use the title: quoting technique at scripts/tickets:787).

### Implementation locations (applied 2026-08-14)

1. This ticket - Fix/Re-verify + verification checkboxes + UPDATE blocks.
2. .opencode/oh-my-opencode-slim/orchestrator_append.md - cross-reference
   added in/near the Fast-Path Opt-In section (L73-85).
3. .opencode/oh-my-opencode-slim.jsonc - "Gate Check" step added to the
   openspec-plan orchestratorPrompt (shared agents section, before Phase 0).
4. .opencode/skills/openspec-propose/SKILL.md - pre-interview gate-check
   step added in Phase 0.
5. scripts/tickets - cmd_new() printf block extended to always emit the four
   gate fields with defaults.
6. docs/dev-infra-audit/tickets/\_TEMPLATE.md - four gate fields added to the
   frontmatter template.
7. scripts/validate-grilling-gate.sh (NEW) - opt-in validator following the
   validate-decision-variants.sh pattern; wired into make test-config as
   warn-not-fail.
8. .opencode/practice-protected.md - zone 6 added (grilling gate for
   significant changes).

Do NOT create an openspec/changes/ artifact - DIA-104 is a docs/ticket-level
process change, not a feature spec (interview confirmed no .sdd/ needed).

## Re-verify

> Filled 2026-08-14 (implementation lane).

Mechanical checks run at fix time (all exit 0):

- `make test-config` - exit 0 (agent-name lockstep, drift gates, JSONC
  parse, interview-enforcement, skills, decision-variants EBDV, NEW
  validate-grilling-gate.sh warn-not-fail wiring).
- `make test-shell` - exit 0 (bats unit tests incl. the new
  validate-grilling-gate.bats).
- `git status` before/after - the 5 protected concurrent-session files
  (.opencode/CHANGELOG.md, .opencode/memory/lessons.md,
  DIA-127-_.md, tickets/README.md, DIA-153-_.md) show the SAME baseline
  state as before this lane (pre-existing modifications, not touched here).

Functional verification (live, post-restart - DEFERRED per DIA-123
second-boot pattern, same as DIA-078/DIA-103): in a POST-change OpenCode
session, dispatch @openspec-plan on a change that matches a trigger (e.g.
new module boundary) and confirm the "Gate Check" step fires BEFORE the
interview (states the matched trigger, checks waivers, records the decision
in the ticket frontmatter). Negative test: dispatch on a trivial change and
confirm @openspec-plan states "no trigger - skip grill". Config changes take
effect on next OpenCode restart - the closure session ran the PRE-change
config; this placeholder is the follow-up plan, NOT evidence of a live run.

DEFERRED live restart-verify (DIA-104 follow-up): in a POST-change OpenCode
session, confirm the gate-check fires for a significant change (triggers ->
mandatory grill -> frontmatter markers) and that fast-path opt-in + explicit
override still work, per the DIA-123 second-boot pattern.
