# DIA-260831-n9o0 - Book-rag skill references at-rag instead of rag

---

id: DIA-260831-n9o0
title: "Book-rag skill references at-rag instead of rag"
area: skills
severity: Low
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
updated: 2026-10-13

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
evidence:

- .opencode/scripts/validate-skills.sh#L614
- scripts/**tests**/validate-skills.bats#plain-command-cases

---

## Description

Reaudit (DIA-260827-wfcx, 2026-08-31; S-L1) evidence: .opencode/skills/book-rag/SKILL.md:41 references @rag while the real command surface is .opencode/commands/rag.md. Impact: an agent may fail to find the command and fall back to a forbidden bash path. Correct fix: fix the spelling to /rag and add a command-reference validator.

## Verification

grep the skill for @rag returns nothing; the command-reference validator flags any non-existent command reference.

## Fix

The skills validator now resolves slash-command references in both backticked and plain text body forms against the command manifest. It excludes slash-prefixed filesystem paths such as /tmp/path and ignores command-like text inside fenced code.

## Re-verify

The focused validate-skills.bats suite in poetry-dev passed 42/42, covering known and unknown backticked/plain commands and filesystem-path exclusion. make test-config exited 0. The existing /rag reference in book-rag is valid.
