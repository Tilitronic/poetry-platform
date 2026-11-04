# DIA-261104-dexw - Coder lane contract hardening: bounded investigation, role-scoped checklist, explicit BLOCKED path

---

id: DIA-261104-dexw
title: "Coder lane contract hardening: bounded investigation, role-scoped checklist, explicit BLOCKED path"
area: opencode-config
severity: Major
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-11-04
source: fix-lane
date: 2026-11-04
created: 2026-11-04
updated: 2026-11-04

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
evidence:

- commit:be2267a2
- commit:99d896d9

---

## Description

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

Fix (DIA-261104-dexw): coder lane contract hardening, Section 2.5 steps 4/6/7.

Files changed (4):

- .opencode/oh-my-opencode-slim/coder.md (full replacement: investigation
  budget, three roles, role-scoped pre-handoff checklist, RESULT: BLOCKED
  path with one-block-per-brief cap, six-field Report schema; DIA-128
  provenance comment reduced to a 3-line stub)
- .opencode/oh-my-opencode-slim/REFERENCE-ONLY.md (full old DIA-128 /
  DIA-260831-h3i4 comment relocated verbatim under a provenance heading)
- .opencode/oh-my-opencode-slim/coder_append.md (Shameless Green scope +
  reuse clause, dead-code bullet scoped to touched files, three-role
  instance-separation wording)
- .opencode/oh-my-opencode-slim/orchestrator_append.md (canonical dispatch
  template with ROLE/TASK/KNOWN FACTS/OUT OF SCOPE/REPORT/SCRATCH, the four
  pre-existing per-lane templates restored, verification-only note moved
  outside the copy-paste block, BLOCKED branch in Escalation Rules next to
  Subagent questions)

Six independent-audit findings: all closed (fix cycle 2/2, re-review ACCEPT,
zero observations). Findings: F1 copy-paste hazard (note inside indented
template block), F2 read scope + load-bearing clause (c) + one-BLOCKED cap,
F3 overwritten per-lane templates, F4 BLOCKED placement/semantics, F5
missing dev-build checklist bullet, F6 botched dead-code bullet splice.

Verification evidence: make test-config exit 0 (473 ok / 0 fail);
scripts/check-omo-version-sync.sh exit 0; prettier --check exit 0 on the
three prompt files; commits be2267a2 (initial 4-file change) + 99d896d9
(audit fix loop). No test asserting prompt text was added (DIA-260827-gnrr).

Residual risk: no steps cap on the base coder lane, so a runaway tail is
bounded only by doom_loop on identical calls; deferred until session
telemetry is measured.

## Re-verify

> To be filled at re-verify time.
