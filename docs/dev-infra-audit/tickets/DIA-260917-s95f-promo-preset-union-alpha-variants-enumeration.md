# DIA-260917-s95f - promo preset union-alpha variants enumeration

---

id: DIA-260917-s95f
title: "promo preset union-alpha variants enumeration"
area: config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-17
source: inventory
date: 2026-09-17
created: 2026-09-17
updated: 2026-09-17

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

Finalize Union Alpha promo preset, variant A Zen primary approved.
Prepend opencode/union-alpha as model[0] on 9 lanes (orchestrator,
architector, openspec-plan, coder, reviewer, analyzer, ai-specialist,
ai-auditor, researcher) in the promo preset, prepend-not-replace (existing
entries retained as fallback). Files: scripts/promo-preset-apply (ROUTING),
.opencode/oh-my-opencode-slim.jsonc (promo block), .opencode/promo-registry.json
(union-alpha entry + accelerated review dates), learnings gate file, CHANGELOG.

EBDV (DIA-115): Choice A selected - Zen primary opencode/union-alpha
prepended on 9 lanes - because Zen docs require the opencode/<id> form and
the Big Pickle precedent established the same prepend-not-replace pattern
for a stealth-launch model. Abort / status-quo variant (keep promo preset
unchanged, no union-alpha) rejected: forgoes zero-cost preview window
through circa 2026-09-23.

Accepted risks: diversity override - reviewer==coder same-family accepted
for the preview window only; correlated auditor (ai-auditor on same model
as lanes it audits) accepted for the window only. Conditions:
non-sensitive traffic only (retained-but-not-trained weaker claim is
operative); single-run-only guard on the generator (see Fix).

## Verification

- [x] make test-config exits 0 (PASS)
- [x] smoke: all 9 lanes model[0]==opencode/union-alpha, fallback order per ROUTING
- [x] registry holds opencode/union-alpha (promo 0/0, req Unlimited, expiry circa 2026-09-23)
- [x] last_reviewed 2026-09-17, next_review accelerated to 2026-09-23 (not +14d)
- [x] auditor APPROVE-WITH-NOTES disposition accepted-all recorded in learnings outcome
- [x] changelog entry appended via scripts/changelog-add (ledger never hand-edited)
- [x] commit contains DIA-260917-s95f, no push

## Fix

Generator ROUTING updated to absolute union-alpha-first arrays (idempotent
re-runs). Promo block regenerated once (single run). DO NOT re-run
scripts/promo-preset-apply until the find_promo_region bug is fixed:
on the next run the upward // walk passes the auto-header into the
contiguous hand-written comment block above it (marker match sets start to
the top of the whole stack), so a second run would delete the hand-written
promo provenance comments. Header review dates synced by hand-edit instead.
Follow-up ticket to carry the generator fix.

## Re-verify

Independent re-run 2026-09-17: make test-config exit 0 (all structural
gates PASS); 9-lane smoke ALL9; git status lists only intended files;
docker compose ps recorded engine-down (no daemon, dev NOT Up - see
evidence note); commit DIA-260917-s95f recorded with hash.
