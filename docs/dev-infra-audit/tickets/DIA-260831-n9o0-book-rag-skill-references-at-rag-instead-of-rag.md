# DIA-260831-n9o0 - Book-rag skill references at-rag instead of rag

---

id: DIA-260831-n9o0
title: "Book-rag skill references at-rag instead of rag"
area: skills
severity: Low
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

Reaudit (DIA-260827-wfcx, 2026-08-31; S-L1) evidence: .opencode/skills/book-rag/SKILL.md:41 references @rag while the real command surface is .opencode/commands/rag.md. Impact: an agent may fail to find the command and fall back to a forbidden bash path. Correct fix: fix the spelling to /rag and add a command-reference validator.

## Verification

grep the skill for @rag returns nothing; the command-reference validator flags any non-existent command reference.

## Fix

Fix the book-rag skill reference from @rag to /rag and add a command-reference validator that rejects references to non-existent commands.

## Re-verify

> To be filled at re-verify time.
