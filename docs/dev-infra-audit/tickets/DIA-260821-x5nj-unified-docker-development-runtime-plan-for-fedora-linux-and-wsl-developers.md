# DIA-260821-x5nj - unified Docker development runtime plan for Fedora Linux and WSL developers

---

id: DIA-260821-x5nj
title: "unified Docker development runtime plan for Fedora Linux and WSL developers"
area: docker
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260821-bqy7
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-21
source: inventory
date: 2026-08-21
created: 2026-08-21
updated: 2026-08-21

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

ana033 rank 15 (P1 / MEDIUM). Parent epic: DIA-260821-bqy7 'audit repository
risks and prioritize unresolved remediation'. Evidence:
knowledge/ana033-next-remediation-bugs/ana033-next-remediation-bugs-report.md
Section 4 Rank 15 (two Dockerfiles declare different OPENCODE_VERSION
1.18.18 vs 1.18.4). This ticket is PLANNING FIRST, NOT implementation.

Problem / user constraint: two developers (Fedora Linux host and WSL host)
need the SAME development runtime, but may require small OS-specific settings.
Today the project ships divergent Dockerfiles (`Dockerfile.dev` and
`tools/opencode-docker/Dockerfile`) with different OpenCode versions, causing
irreproducible behavior between entry points. This ticket must produce an
OpenSpec/architecture-backed DECISION on ONE shared development
container/image as the default.

Required planning deliverables (NO Docker/config files changed in this
ticket):

- An OpenSpec change (`openspec/changes/<name>/`) and/or `.sdd`/architecture
  note backing the decision with the project's design-authority workflow.
- Evidence-backed comparison of these GENUINE options:
  1. ONE image + host-specific compose override YAML / config files for
     Fedora vs WSL.
  2. ONE image + fully runtime-detected host behavior (no per-host files; the
     entrypoint detects Fedora vs WSL at runtime).
  3. Status quo: keep separate Dockerfiles.
- Documented user constraint: both developers get the same dev runtime; only
  small OS-specific settings may differ.
- Compatibility evidence for the chosen direction (Fedora + WSL both usable).
- A rollback plan (how to revert to status-quo if the unified image fails).
- A contract test specification: both entry points (Fedora path and WSL path)
  MUST report the SAME `opencode --version`.

This ticket MUST NOT decide an option or modify any Dockerfile / compose /
config file. It delivers the decision record + comparison + contract-test
spec, then implementation follows in a separate ticket.

## Verification

- [ ] An OpenSpec/architecture-backed decision artifact exists naming ONE
      shared dev container/image as the default (practice-protected authoring).
- [ ] The three options (compose overrides / runtime detection / status quo)
      are each compared with evidence (pros, cons, effort, compatibility).
- [ ] The user constraint (same runtime, small OS-specific settings allowed)
      is recorded and addressed by the chosen direction.
- [ ] Compatibility evidence is provided for both Fedora Linux and WSL.
- [ ] A rollback plan to status-quo is documented.
- [ ] A contract-test spec is defined: both entry points report the same
      `opencode --version` (the test itself is implemented in a follow-up
      ticket, not here).
- [ ] No Dockerfile, compose, or config file was modified by this ticket
      (planning-only; verified via `git status`).

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
