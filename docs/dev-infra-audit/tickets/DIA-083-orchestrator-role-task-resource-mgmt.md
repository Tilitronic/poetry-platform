# DIA-083 — orchestrator's main role is task/resource management — automate repetition by dispatching @coder to create scripts/tools

<!-- Filed by the docs lane (code-executor re-route) 2026-08-10. -->

---

id: DIA-083
title: "orchestrator's main role is task/resource management — automate repetition by dispatching @coder to create scripts/tools"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-10
source: test-lane
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
files_touched: ["docs/dev-infra-audit/tickets/DIA-083-orchestrator-role-task-resource-mgmt.md"]
artifacts: []
evidence: []

---

## Description

The orchestrator's main role is task/resource management, work delegation, and
work optimization. When repetitive work is noticed, the orchestrator should
dispatch @coder to create scripts/tools that automate the repetition, rather
than repeating the same delegated pattern each time.

Impact: repeated manual delegation of the same pattern wastes lanes and session
budget; automation keeps the daily dev loop lean.

## Verification

- [ ] Identify 2+ recurring delegation patterns the orchestrator repeats across sessions.
- [ ] Dispatch @coder to create a script/tool automating one such pattern.
- [ ] Confirm subsequent sessions use the script/tool instead of re-delegating the same pattern manually.

## Fix

May be §10-routed if it touches .opencode/ prompts or config (prompt guidance for the orchestrator's role framing).

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
