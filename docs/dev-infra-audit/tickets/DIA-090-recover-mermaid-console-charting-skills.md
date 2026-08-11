# DIA-090 — recover mermaid-diagramming and console-charting skills (source: opencode backup folder)

<!-- Filed by the docs lane (code-executor re-route) 2026-08-10. -->

---

id: DIA-090
title: "recover mermaid-diagramming and console-charting skills (source: opencode backup folder)"
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

- [ ] Check registration at ~/.config/opencode/skills/mermaid-diagramming and ~/.config/opencode/skills/console-charting.
- [ ] Restore from the opencode backup folder if missing.
- [ ] Validate activation (skills appear in the available-skills list; a minimal mermaid/charting prompt invokes them).

## Fix

§10-routed if registration touches .opencode/ config.

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
