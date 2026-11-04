# DIA-260826-uovr - audit MCP server security permissions and usage in opencode setup

---

id: DIA-260826-uovr
title: "audit MCP server security permissions and usage in opencode setup"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260821-bqy7
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-26
source: inventory
date: 2026-08-26
created: 2026-08-26
updated: 2026-08-26

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

Produce the missing security/permissions audit of the MCP servers configured
in the OpenCode setup.

## Problem

- No MCP audit artifact exists: `ls knowledge/ | grep -i mcp` returns only
  `res-260925-70v6-codebase-memory-mcp` (an unrelated MCP-tool evaluation,
  not a permissions audit), and the standing triage still flags this ticket:
  `knowledge/ana-260921-z1g8-repo-risk-triage/ana-260921-z1g8-repo-risk-triage-report.md:51`
  - "Open audit: MCP servers are third-party code with unclear perms".
- The live surface is undocumented: `.opencode/opencode.jsonc:903-921`
  defines two remote MCP servers - `context7`
  (`https://mcp.context7.com/mcp`, `Authorization: Bearer
{env:CONTEXT7_API_KEY}`, `oauth: false`) and `gh_grep`
  (`https://mcp.grep.app`, no auth) - with no recorded answer to which lanes
  may call them, what leaves the machine, or how the bearer token is scoped.
  Only passing mention exists (`knowledge/archive/ana026-opencode-setup-audit/ana026-opencode-setup-audit-report.md:233`
  lists "enabled MCPs" as a smoke-check item, no analysis).

## Verification

- [ ] A knowledge report exists covering the `mcp` block and per-agent
      permission surface, every claim cited file:line
- [ ] Report is registered in `.opencode/memory-shelf.yaml`;
      `bash scripts/validate-memory-shelf.sh` exit 0
- [ ] Each finding carries a severity and a disposition (fix ticket or
      accepted risk)

## Fix

Dispatch the read-only audit (analyzer or ai-specialist per AGENTS.md
section 2.5), persist `knowledge/<slug>/<slug>-report.md`, register it on the
shelf, and record dispositions in this ticket. Touch: new knowledge report,
`.opencode/memory-shelf.yaml`, this ticket. No config change without the
section 2.5 gate.

## Re-verify

```bash
ls knowledge/ | grep -i "mcp"          # audit report present alongside res-260925-70v6
grep -n "uovr\|MCP Server" .opencode/memory-shelf.yaml    # shelf entry present
bash scripts/validate-memory-shelf.sh  # exit 0
grep -n '"mcp"' -A 20 .opencode/opencode.jsonc            # surface the report must cover
make test-config                        # exit 0
```

## References

- `.opencode/opencode.jsonc:903-921` (context7 + gh_grep definitions)
- `knowledge/ana-260921-z1g8-repo-risk-triage/ana-260921-z1g8-repo-risk-triage-report.md:51` (still-open triage row)
- Commit `50b6c1b6` (ticket created alongside DIA-260826-ft3q)
