# DIA-260929-yanz - ai-auditor websearch MCP drift: network access in a repo-truth-only audit lane

---

id: DIA-260929-yanz
title: "ai-auditor websearch MCP drift: network access in a repo-truth-only audit lane"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-29
source: inventory
date: 2026-09-29
created: 2026-09-29
updated: 2026-09-29

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

Remove the network-capable `websearch` MCP from the ai-auditor lane (or add an
explicit deny for it), so an audit lane whose contract is repo-truth-only stops
shipping live web search.

Reconstructed from title + current repo state; original reporter context not
recoverable (only the title exists in commit history, the README rollup and
`.opencode/learnings/external-patterns/2026-10-22-overengineering-audit-findings.md:33`,
which groups this ticket with the unfilled-template class).

## Problem

- Lane contract is repo-truth-only and explicitly network-free:
  `.opencode/agents/ai-auditor.md:10` - "audit proposed agent/skill/config
  changes against the system's current state and documented best practices";
  step 1-2 of its workflow read local ground truth
  (`.opencode/agents/ai-auditor.md:14-16`). The config comment agrees:
  `.opencode/opencode.jsonc:783-786` - "bash FULLY denied (no curl/wget - the
  auditor has no network need)".
- The ai-auditor permission block denies `webfetch`
  (`.opencode/opencode.jsonc:798`) but does NOT mention `websearch`
  (full block: `.opencode/opencode.jsonc:793-821`).
- `websearch` is declared as a permission key exactly ONCE in the whole config -
  `"websearch": "deny"` at `.opencode/opencode.jsonc:266`, inside the
  ORCHESTRATOR block (169-266). Undeclared keys resolve to ALLOW per the
  baseline comment at `.opencode/opencode.jsonc:26-28`.
- Meanwhile both OMO presets grant the lane the MCP outright:
  active preset `mimo-balanced` (`.opencode/oh-my-opencode-slim.jsonc:3`) has
  `"ai-auditor": { ... "mcps": ["websearch"] }` at
  `.opencode/oh-my-opencode-slim.jsonc:162-175` (the `mcps` array is at
  :172-174, the `websearch` token on :173), and the `openai-first-cost-balanced`
  preset repeats it at `.opencode/oh-my-opencode-slim.jsonc:305`.
- Net effect: the auditor can fetch the web through the MCP tool while its own
  instructions, its `webfetch` deny and its config comment all say it cannot -
  a repo-truth audit can silently cite Tier-2 web material as if it were repo
  ground truth, and no validator catches it (`make test-config` has no
  mcps/permission cross-check: no `scripts/*.sh` validator references `mcps`).

## Verification

- [ ] `ai-auditor` has no `websearch` in any preset's `mcps` array, OR has an
      explicit `"websearch": "deny"` in its `.opencode/opencode.jsonc` permission
      block.
- [ ] The config comment and `.opencode/agents/ai-auditor.md` still describe a
      network-free lane (no doc change needed once the tool is gone).
- [ ] A validator (or a test-config step) asserts the invariant, so the drift
      cannot return: ai-auditor effective tool set contains no network tool.
- [ ] `make test-config` exit 0; `bash scripts/audit-agent-tool-coverage.sh .opencode/opencode.jsonc`
      reports no new gap.

## Fix

Smallest concrete change - one of, in order of preference:

1. `.opencode/oh-my-opencode-slim.jsonc:162-175` (active preset) and `:305`
   (other preset): change `"mcps": ["websearch"]` to `"mcps": []` for
   `ai-auditor`.
   OR
2. `.opencode/opencode.jsonc:793-821`: add `"websearch": "deny"` to the
   ai-auditor permission block (matches the existing `webfetch: deny` line and
   the comment at :786).

Then add the invariant assertion next to the other structural gates
(`scripts/audit-agent-tool-coverage.sh` is the natural home: it already
cross-references agent x tool coverage from `.opencode/opencode.jsonc`).

Acceptance behaviour: an ai-auditor dispatch exposes no web-search tool, and
the assertion fails if a preset re-adds it.

## Re-verify

    grep -n -A14 '"ai-auditor"' .opencode/oh-my-opencode-slim.jsonc | grep -n websearch   # expect no output (or only a deny comment)
    grep -n '"websearch"' .opencode/opencode.jsonc     # 1 hit inside the ai-auditor block (option 2), or only line 266
    grep -n -A14 '"ai-auditor"' .opencode/oh-my-opencode-slim.jsonc | grep -n '"mcps"'    # expect "mcps": []
    bash scripts/audit-agent-tool-coverage.sh .opencode/opencode.jsonc
    make test-config
