# DIA-088 — teaching skill missing from the active skill registry — recover it

<!-- Filed by the docs lane (code-executor re-route) 2026-08-10. -->

---

id: DIA-088
title: "teaching skill missing from the active skill registry — recover it"
area: skills
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-10
source: inventory
date: 2026-08-10
created: 2026-08-10
updated: 2026-08-10

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

- [ ] Check for the skill source at ~/.config/opencode/skills/teaching and in the opencode backup folder.
- [ ] Re-register the skill in the active skill registry.
- [ ] Confirm activation (skill appears in the available-skills list; a minimal teaching prompt invokes it).

## Fix

§10-routed if skill registration touches .opencode/ config.

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
