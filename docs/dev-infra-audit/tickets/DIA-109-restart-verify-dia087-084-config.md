# DIA-109 - restart-verify DIA-087/084 config changes (section-10 Phase 5)

<!-- Filed 2026-08-12. DIA-087 and DIA-084 are CLOSED; their config changes
     (commits bcd4df0, dcc7260, 49459a8, 2fb3f48) need section-10 Phase 5
     restart-verify: make test-config + functional smoke after OpenCode restart.
     New ticket required - reopen of CLOSED tickets is impossible. -->

---

id: DIA-109
title: "restart-verify DIA-087/084 config changes (section-10 Phase 5)"
area: opencode-config
severity: Low
status: OPEN
blocked_by: []
discovered: 2026-08-12
source: fix-lane
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-12

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-109-restart-verify-dia087-084-config.md"]
artifacts: []
evidence: []

---

## Description

Section-10 Phase 5 restart-verify for the DIA-087/DIA-084 OpenCode config
changes (commits bcd4df0, dcc7260, 49459a8, 2fb3f48 on omo-slim-changes,
5 commits local-only, push pending). OpenCode has been restarted; confirm the
new config is live:

- DIA-087 R1: cebula preset primaries for conspecter/resource-manager/
  memory-manager/code-navigator point at deepseek-v4-flash.
- DIA-087 R2: architector points at gemini-3.1-pro-preview.
- DIA-087 R3: opencode-go preset coder + 5 agents point at deepseek-v4-flash.
- DIA-087 R6: no inline resource-manager model override at opencode.jsonc:350.
- DIA-084: project-level debugging-workflow skill loads (global copy deleted);
  5 globals pinned project-level; 4 overlap copies deleted.

## Verification

- [ ] make test-config exit 0 (expect 224 known pre-existing WARNs).
- [ ] Functional smoke: agent lanes dispatch and run with the new config.
- [ ] git status clean; 5 commits bcd4df0..b1476f5 local, not yet pushed.
- [ ] Dev container healthy (poetry-dev + poetry-postgres) for the later push.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
