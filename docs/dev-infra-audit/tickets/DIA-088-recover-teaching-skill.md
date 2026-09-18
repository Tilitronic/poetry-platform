# DIA-088 — teaching skill missing from the active skill registry — recover it

<!-- Filed by the docs lane (code-executor re-route) 2026-08-10. -->

---

id: DIA-088
title: "teaching skill missing from the active skill registry — recover it"
area: skills
severity: Medium
status: VERIFIED
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-10
source: inventory
date: 2026-08-10
created: 2026-08-10
updated: 2026-08-11

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_0133de7fdffeKc3ClhE6fqFy0X"
lane_id: "docs"
agent: "code-executor"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-088-recover-teaching-skill.md"]
artifacts: []
evidence: []

---

## Description

The teaching skill is missing from the active skill registry — recover it.
Verify availability in the opencode backup folder / global skills dir
(~/.config/opencode/skills/teaching), re-register, confirm activation.

## Verification

- [x] Check for the skill source at ~/.config/opencode/skills/teaching and in the opencode backup folder. (PASS 2026-08-11 - source exists)
- [x] Re-register the skill in the active skill registry. (PASS 2026-08-11 - ALREADY REGISTERED; no action needed)
- [x] Confirm activation (skill appears in the available-skills list; a minimal teaching prompt invokes it). (PASS 2026-08-11 - active in OMO arrays + runtime registry)

## Fix

§10-routed if skill registration touches .opencode/ config.

> To be filled at fix time.

## Re-verify

**VERIFIED 2026-08-11 (session 6, wrap-up lane, campaign
c-20260809-residual-closure).** Status OPEN -> VERIFIED; no action needed.

Session-6 verification (2026-08-11):

- PASS - teaching skill source exists at
  ~/.config/opencode/skills/teaching/SKILL.md (frontmatter valid:
  name: teaching, compatibility: opencode).
- PASS - ALREADY REGISTERED + ACTIVE: present in OMO per-agent skill arrays
  (oh-my-opencode-slim.jsonc) and in the runtime available-skills registry.
- The ticket premise (skill missing) was incorrect; the skill was never lost.
  Closed as verified, no fix required.
