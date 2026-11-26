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
files_touched:

- '.opencode/scripts/validate-skills.sh'
- 'scripts/**tests**/validate-skills.bats'
  artifacts: []
  evidence:
- '.opencode/scripts/validate-skills.sh#L614'
- 'scripts/**tests**/validate-skills.bats#plain-command-cases'

---

## Description

Reaudit (DIA-260827-wfcx, 2026-08-31; S-L1) evidence: .opencode/skills/book-rag/SKILL.md:41 references @rag while the real command surface is .opencode/commands/rag.md. Impact: an agent may fail to find the command and fall back to a forbidden bash path. Correct fix: fix the spelling to /rag and add a command-reference validator.

## Verification

grep the skill for @rag returns nothing; the command-reference validator HARD-fails on backticked slash commands not in the manifest union allow-list, and WARNs (without changing the exit status) on plain-text and at-sign references that do not resolve. Fenced code blocks (including indented fences) are never scanned, and the allow-list covers OpenCode built-ins plus the ponytail plugin family (DIA-261021-t8bh correction).

## Fix

The skills validator scans one fence-stripped body (fences of either delimiter - three-or-more backticks or tildes, indented or column-0 - are never scanned by either class). HARD applies only to COMMAND-SHAPED backticked tokens (^/[A-Za-z0-9_-]+$, single segment) resolved against the command manifest unioned with the documented built-in/ponytail allow-list; unknown => FAIL. Path-shaped backticked tokens (further slash, dot, or ".."), plain-text slash references, and bare at-sign references are WARN-only and never change the exit status; a plain-text token immediately followed by "/" or an at-sign token immediately followed by "/" is never even warned (multi-segment path segments and scoped package specs).

## Re-verify

The focused validate-skills.bats suite in poetry-dev passed 53/53 (DIA-261021-t8bh + DIA-261021-51pm blocks included), covering known/unknown single-segment backticked commands, multi-token first-token validation, path-shaped backticked tokens, multi-segment plain-text paths, scoped package at-sign specs, and backtick/tilde/4-backtick fence exclusion. The plain-text and at-sign classes are WARN-only. Real-repo run: exit 0, 26 passed, 41 warnings. make test-config exit 0. The existing /rag reference in book-rag is valid.
