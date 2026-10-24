# DIA-260901-m4xq - Pre-push OMO tests run as root (docker compose exec without --user dev) breaks permission tests + /tmp/outside.txt isolation

---

id: DIA-260901-m4xq
title: "Pre-push OMO tests run as root (docker compose exec without --user dev) breaks permission tests + /tmp/outside.txt isolation"
area: dev-infra
severity: Major
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-01
source: inventory
date: 2026-09-01
created: 2026-09-01
updated: 2026-09-01

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

Pre-push gate defect: scripts/verify-pre-push.sh (line 54) runs host pre-push checks via docker compose exec WITHOUT --user dev, so OMO tests execute as root. Three of four tests intentionally expect EACCES after chmod 000 - root bypasses Unix permissions, so the expected error never occurs (blocks internal guard errors / records failures and continues / conflict staging failure). The fourth test has an isolation issue: it always writes to /tmp/outside.txt instead of its own unique temp-path; in the container that file is already root:root, so a dev run gets EACCES. Fix: (1) add --user dev to docker compose exec in verify-pre-push.sh; (2) in hook.test.ts generate a unique sibling file and remove it in finally; (3) rewrite the three permission tests to inject/mock a file error or create a root-independent filesystem conflict - chmod 000 alone is insufficient for a test claimed host- and container-runnable. Never use --no-verify.

## Verification

- [ ] scripts/verify-pre-push.sh line 54 uses `docker compose exec --user dev` so OMO tests run as dev, not root
- [ ] hook.test.ts: fourth test generates a unique sibling file (not /tmp/outside.txt) and removes it in finally
- [ ] Three chmod-000 permission tests rewritten to inject/mock file error or root-independent filesystem conflict (chmod 000 alone removed)
- [ ] OMO tests pass both on host and via `docker compose exec --user dev` without EACCES bypass or isolation failure
- [ ] Pre-push gate no longer requires --no-verify to pass

## Fix

> To be filled at fix time.

## Re-verify

Re-verify 2026-09-01: CLOSED. Fix commits 9d55f9e (--user dev in verify-pre-push.sh host delegation; unique sibling temp + finally cleanup; three root-independent permission tests via stat-mock EACCES / readdirSync-mock EACCES / ENOTDIR collision), 471da45 (review Minor fixes: stale comment, per-test stat mock, atomic createTempDir), 4c0a320 (TOCTOU fix: mkdtemp sibling dir - removes check-then-use window). Spec openspec/changes/dia-260901-m4xq-pre-push-omo-permission-fix/ validated exit 0. Review @reviewer two-axis 0 Blocker/Critical/Major; re-review cycle 1/2 3/3 verified-closed; re-review cycle 2/2 1/1 verified-closed, 0 defects. Verification: make test-omo 1367 pass, make test-shell 586 ok, make test-config 57 pass (all exit 0).
