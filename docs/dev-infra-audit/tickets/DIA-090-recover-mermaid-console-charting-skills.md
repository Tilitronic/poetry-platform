# DIA-090 — recover mermaid-diagramming and console-charting skills (source: opencode backup folder)

<!-- Filed by the docs lane (code-executor re-route) 2026-08-10. -->

---

id: DIA-090
title: "recover mermaid-diagramming and console-charting skills (source: opencode backup folder)"
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
files_touched: ["docs/dev-infra-audit/tickets/DIA-090-recover-mermaid-console-charting-skills.md"]
artifacts: []
evidence: []

---

## Description

Recover mermaid-diagramming and console-charting skills. Recovery source: the
opencode backup folder. Verify they are registered (they appear at
~/.config/opencode/skills/mermaid-diagramming and console-charting), restore
from backup if needed, validate activation.

## Verification

- [x] Check registration at ~/.config/opencode/skills/mermaid-diagramming and ~/.config/opencode/skills/console-charting. (PASS 2026-08-11 - both exist)
- [x] Restore from the opencode backup folder if missing. (PASS 2026-08-11 - restore NOT needed; both present)
- [x] Validate activation (skills appear in the available-skills list; a minimal mermaid/charting prompt invokes them). (PASS 2026-08-11 - active in OMO arrays + runtime registry)

## Fix

§10-routed if registration touches .opencode/ config.

> To be filled at fix time.

## Re-verify

**VERIFIED 2026-08-11 (session 6, wrap-up lane, campaign
c-20260809-residual-closure).** Status OPEN -> VERIFIED; no action needed.

Session-6 verification (2026-08-11):

- PASS - mermaid-diagramming skill source exists at
  ~/.config/opencode/skills/mermaid-diagramming/SKILL.md (frontmatter valid).
- PASS - console-charting skill source exists at
  ~/.config/opencode/skills/console-charting/SKILL.md (frontmatter valid).
- PASS - BOTH ALREADY REGISTERED + ACTIVE: present in OMO per-agent skill
  arrays (oh-my-opencode-slim.jsonc) and in the runtime available-skills
  registry.
- The ticket premise (skills missing) was incorrect; the skills were never
  lost. Closed as verified, no restore/fix required.
