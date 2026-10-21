# DIA-261021-51pm - re-review cycle 1/2 and push gate for the 5 unpushed omo-slim-changes commits

---

id: DIA-261021-51pm
title: "re-review cycle 1/2 and push gate for the 5 unpushed omo-slim-changes commits"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-10-21
source: inventory
date: 2026-10-21
created: 2026-10-21
updated: 2026-10-21

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

Cycle-2 re-review of the 5 unpushed omo-slim-changes commits (chain 2c3ce945..bd9f8f79) and push gate. Cycle 1 (DIA-261021-t8bh, commit bd9f8f7) fixed two Majors; the cycle-2 re-review found three regressions in the tightened command-reference validator. (R1) The HARD class took the first token of ANY backticked span starting with a slash, so a backticked absolute path such as `/workspace/.opencode/skills/book-rag` hard-failed with exit 1. (R2) WARN noise: the at-sign scan warned scoped package specs (`npx @scope/cli`) and the plain-text scan warned the first segment of a multi-segment prose path. (R3) The fence stripper only recognised backtick fences and toggled on any triple-backtick run, so tilde (~~~) fences were transparent and a 4-backtick fence was closed by an inner 3-backtick line, letting fenced content reach both scan classes. GREEN fix (validate-skills.sh only, no delegation-observer.ts change in this pass): HARD now requires a COMMAND-SHAPED first token (^/[A-Za-z0-9_-]+$, single segment, no dot, no second slash, no ".."); path-shaped backticked tokens, plain-text slash tokens immediately followed by "/", and at-sign tokens immediately followed by "/" are WARN-only and never change the exit status; one fence-stripped body feeds both streams with delimiter and run-length tracking for backtick and tilde fences; the header contract (check 12) states the new rules. RED tests (5 new bats cases 49-53 plus the active.json payload pin) were authored by a separate instance per DIA-175. Bookkeeping: `**tests**` evidence paths repaired with backticks in four tickets, DIA-260831-n9o0 Fix/Re-verify residual text rewritten to the true contract, DIA-261021-t8bh area set to opencode-config, and the three cycle-1 changelog entries given factual verification strings.

## Verification

- [x] RED baseline observed: bats validate-skills 48 ok / 5 red; bun parallel-handoff 16/16 green (payload pin already passing)
- [x] make test-config: exit 0 (validate-plugin-structure all PASS)
- [x] make test-shell: exit 0 (740 ok, 0 not ok)
- [x] bun test parallel-handoff.test.mjs: 16 pass / 0 fail (111 expect)
- [x] bats validate-skills.bats: 53 ok / 0 not ok
- [x] bash .opencode/scripts/validate-skills.sh (real repo): exit 0, 26 passed, 0 failed, 41 warnings (was 42; @scope noise gone, only bare @pytest remains as a class-body warn)
- [x] node --test scripts/**tests**/batch-d-infra.test.mjs: 64 pass / 0 fail
- [x] scripts/validate-changelog.sh and scripts/changelog-render: exit 0 after replacing the three `verification: manual` fields
- [x] No SKILL.md file edited; no test weakened (only the permitted trailing newline added to parallel-handoff.test.mjs)

Open follow-ups deliberately NOT addressed in this pass (orchestrator disposes after re-review):

- (a) the apoptosis stdout-semantics change at delegation-observer.ts:840
- (b) the throw-vs-return contract in lib/handoff.ts
- (c) two remaining unawaited app.log promises
- (d) .vscode auto-approve has no governing ticket
- (e) the turbo cache experiment is still unrun

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
