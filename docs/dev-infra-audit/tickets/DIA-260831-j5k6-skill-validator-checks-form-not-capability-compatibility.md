# DIA-260831-j5k6 - Skill validator checks form not capability compatibility

---

id: DIA-260831-j5k6
title: "Skill validator checks form not capability compatibility"
area: opencode-config
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

Reaudit (DIA-260827-wfcx, 2026-08-31; S-M2) evidence: .opencode/scripts/validate-skills.sh:11-22 checks frontmatter/name/description/activation/license; the current run is 26 pass / 40 warnings. All 20 explicit refs currently exist, but a dangling preset ref or an impossible bash requirement does not hard-fail. Impact: a green config does not guarantee a skill is runnable. Correct fix: cross-reference preset arrays, command names, agent permissions, and required binaries in clean runtime fixtures.

## Verification

Add fixtures with a dangling preset ref and an impossible bash requirement; assert the validator hard-fails.

## Fix

Extend validate-skills.sh to cross-reference preset arrays, command names, agent permissions, and required binaries against clean runtime fixtures, and hard-fail on dangling refs or impossible requirements.

## Re-verify

> To be filled at re-verify time.
