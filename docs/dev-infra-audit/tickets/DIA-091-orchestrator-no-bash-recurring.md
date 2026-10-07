# DIA-091 — orchestrator repeatedly reports "I have no bash" across sessions — document and enforce the bash-delegation pattern

<!-- Filed by the docs lane (code-executor re-route) 2026-08-10. Recurring theme;
     cost so far: session-4 boot lost 3 lanes (coder snip-loop error +
     analyzer/resource-manager lacking bash). -->

---

id: DIA-091
title: "orchestrator repeatedly reports \"I have no bash\" across sessions — document and enforce the bash-delegation pattern"
area: opencode-config
severity: Major
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-10
source: test-lane
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
files_touched: ["docs/dev-infra-audit/tickets/DIA-091-orchestrator-no-bash-recurring.md"]
artifacts: []
evidence: []

---

## Description

The orchestrator repeatedly reports "I have no bash" across sessions (recurring
theme). Document and enforce the bash-delegation pattern: all bash work must be
delegated to bash-capable agents (coder is the only currently-provisioned bash
lane; code-executor is blocked by the orchestrator task allowlist). Investigate
whether the orchestrator should gain a narrowly-scoped bash tool for gate
mechanics (checksum verification, git status) or whether delegation-only is
correct.

Cost so far: session-4 boot lost 3 lanes to this (coder snip-loop error +
analyzer/resource-manager lacking bash).

## Verification

- [ ] Document the bash-delegation pattern (who may run bash, who delegates to whom).
- [ ] Enforce: orchestrator never attempts bash inline — delegates to bash-capable lanes.
- [ ] Investigate + decide: narrowly-scoped orchestrator bash tool (checksum verification, git status) vs delegation-only.
- [ ] Confirm no lane is lost to missing bash in 2+ consecutive sessions.

## Fix

§10-routed if it touches .opencode/ permission/task allowlists.

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## Resolution (2026-08-11): subsumed by DIA-097 (orchestrator role consolidation) per batch-brief disposition - bash-delegation pattern requirements are tracked under DIA-097.
