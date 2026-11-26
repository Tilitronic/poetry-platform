# DIA-260929-sjwm - Remove all live SNIP traces: docker binary install, plugin declarations, dormant deny rules, comments, tests, docs and package manifests

---

id: DIA-260929-sjwm
title: "Remove all live SNIP traces: docker binary install, plugin declarations, dormant deny rules, comments, tests, docs and package manifests"
area: scripts
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "grilled" # grilled | waived | bypassed | partial | skipped
gate_triggers: ["cross-boundary", "cross-cutting", "hard-to-reverse"] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-29
source: inventory
date: 2026-09-29
created: 2026-09-29
updated: 2026-09-29

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

- commit 25eb9289, 24bc3f0a (Dockerfile/config/docs snip removal + pin reconcile); 719fd4bf (openspec OQ1 resolution); 9d081d00, bd421a57, bf85f4a (tickets, knowledge reports, memory shelf, changelog)
- HEAD bf85f4a6: make test-config exit 0; make test-shell exit 0 in-container with 724/724 and 0 failures; openspec validate --strict exit 0; snip scan of the three live files = 0 hits
- F5 CLOSED by host evidence: docker compose config --quiet exit 0
- F6 recorded: docs/dev-infra-audit-plan.md:47 preserved historical, alongside researcher.md:15 false positive
- Slice 4 TRANSFERRED to DIA-260827-txq2; OQ1 resolved; this change closes REPO-ONLY
- KNOWN RESIDUAL: F3 (real image build) NOT evidenced - no engine reachable in-container, host run aborted on pre-existing host-only test 451; host-side verification remains owed

---

## Description

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

> To be filled at fix time.

## Re-verify

- Commits: 25eb9289, 24bc3f0a (Dockerfile/config/docs snip removal + pin reconcile); 719fd4bf (openspec OQ1 resolution); 9d081d00, bd421a57, bf85f4a (tickets, knowledge reports, memory shelf, changelog).
- Evidence at HEAD bf85f4a6: make test-config exit 0; make test-shell exit 0 in-container with 724/724 and 0 failures; openspec validate --strict exit 0; snip scan of the three live files = 0 hits.
- F5 CLOSED by host evidence: `docker compose config --quiet` exit 0.
- F6 recorded: the durable scan classification must name docs/dev-infra-audit-plan.md:47 (preserved historical), alongside the researcher.md:15 false positive.
- Slice 4 TRANSFERRED to DIA-260827-txq2; OQ1 resolved; this change closes REPO-ONLY.
- KNOWN RESIDUAL (must be stated, not hidden): F3 (real image build) is NOT evidenced - no engine is reachable in-container and the host run aborted on the pre-existing host-only test 451. Host-side verification remains owed.
