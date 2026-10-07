# DIA-260831-j5k6 - Skill validator checks form not capability compatibility

---

id: DIA-260831-j5k6
title: "Skill validator checks form not capability compatibility"
area: opencode-config
severity: Medium
status: CLOSED
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
updated: 2026-09-11

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

Closed 2026-09-11 (campaign ticket DIA-260831-j5k6):

- RED 2 fixtures (dangling preset ref, impossible bash 99.0); GREEN compat tier in .opencode/scripts/validate-skills.sh: 4 capability classes (preset/command/agent-permission/binary) via emit_compat_list plus compat-snapshot.py plus COMPAT_CONFIG_FILE/COMPAT_COMMANDS_DIR seams plus command -v cache, with a requires_bash minimum-version floor (full major.minor.patch compare), inline [] support, and unterminated-comment ValueError. Per-entry hard FAIL naming skill plus class plus declaration plus target, collect-all, exit 1.
- Commits 3a7a2b6 (RED-to-GREEN: preset plus requires_bash) plus a054191 (fix loop F1-F5: 4 classes, 10 new fixtures for 12 total, inline [] support, version compare, ValueError).
- Files: `.opencode/scripts/validate-skills.sh`, `scripts/__tests__/validate-skills.bats` (35 tests, already committed); spec `openspec/changes/skill-validator-capability-compatibility/` (openspec validate passed, shelf-registered); conspect `knowledge/res-260911-emj8-skill-validator-compat/` (shelf-registered).
- Review: rev-1 4 findings, all accepted, fixed in a054191; rev-2 re-review cycle 1/2: 5/5 verified-closed, 0 open, 0 observations. ai-auditor ai--3: PASS advisory, no blockers.

## Re-verify

- bats `scripts/__tests__/validate-skills.bats` (vendored bats-core bin/bats): 35/35 pass, 0 not-ok, exit 0.
- Real-tree `bash .opencode/scripts/validate-skills.sh`: 26 passed, 0 failed, 40 warnings, exit 0 (warnings are pre-existing SOFT).
- `bats-wrapper.sh --quick`: exit 0.
- `git diff --check`: exit 0.
- Residual risk (ai--3, accepted): cross-version branch-local enforcement only. The compat tier validates against the branch-local runtime manifest, so cross-version drift (a skill valid here but dangling on another version) is not covered.
