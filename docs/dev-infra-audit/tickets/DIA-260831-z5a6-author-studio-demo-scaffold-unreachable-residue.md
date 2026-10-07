# DIA-260831-z5a6 - Author Studio demo scaffold unreachable residue

---

id: DIA-260831-z5a6
title: "Author Studio demo scaffold unreachable residue"
area: js-tooling
severity: Medium
status: OPEN
blocked_by: []
parent_epic: DIA-260827-wfcx
gate_state: "skipped"
gate_triggers: []
gate_waivers: []
gate_override: ""
discovered: 2026-08-31
source: inventory
date: 2026-08-31
created: 2026-08-31
updated: 2026-08-31

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

Reaudit (DIA-260827-wfcx, 2026-08-31; C-M5) evidence: routes.ts:3-8 declares IndexPage but MainLayout.vue:1-27 has no router-view; IndexPage.vue/ExampleComponent.vue contain demo/todo; i18n is set up with no $t() usage. Impact: contradictory app structure, extra dependencies/assets, and a false entry surface. Correct fix: safely remove the unreachable demo page/component/assets and unused i18n wiring. Empty workers/API/analytics target seams are design-gated, not automatic deletion.

## Verification

Confirm no route references the removed demo page; build succeeds without the removed assets; empty target seams remain as documented futures.

## Fix

Remove the unreachable demo page/component/assets and unused i18n wiring from author-studio. Do not delete the empty workers/API/analytics target seams without a design disposition.

## Re-verify

> To be filled at re-verify time.
