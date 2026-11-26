# DIA-261022-5fbg - .vscode chat.tools.terminal.autoApprove: repository-controlled script execution without a governing ticket

---

id: DIA-261022-5fbg
title: ".vscode chat.tools.terminal.autoApprove: repository-controlled script execution without a governing ticket"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-10-22
source: inventory
date: 2026-10-22
created: 2026-10-22
updated: 2026-10-22

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

`.vscode/settings.json:41-51` (added by aae39879 "chore(vscode): allow exact
verification commands") auto-approves two exact command lines in the VS Code
chat terminal via `chat.tools.terminal.autoApprove`:

- `/^node scripts/__tests__/batch-d-infra\.test\.mjs$/`
- `/^bash scripts/container-engine\.sh compose exec --user dev dev hostname$/`

Both execute repository-controlled scripts without a human prompt and -
until this ticket - without any governing ticket: a malicious or careless PR
could widen the regexes (drop anchors, add a pattern) and get arbitrary
repo-controlled commands auto-approved in the chat terminal. The current
patterns are full-line anchored with matchCommandLine and point at two
benign verification commands, so the practical risk is low but the
governance gap is real.

Decision needed: keep the block under a governing ticket (this one) or
remove auto-approve until a security review?

Recommended option: keep both entries with THIS ticket as the governing
record (full-line anchored, matchCommandLine pinned, two known-benign
commands), and treat any future pattern addition as an OpenCode config
change that requires its own ticket plus the ai-auditor review matrix.

Alternative: delete the block from .vscode/settings.json and approve each
run manually (safest, loses the convenience that aae39879 added).

## Verification

- [ ] Decision recorded (keep-with-governance or remove)
- [ ] If keep: a comment in .vscode/settings.json points at this ticket as the governing record
- [ ] make test-config stays green

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
