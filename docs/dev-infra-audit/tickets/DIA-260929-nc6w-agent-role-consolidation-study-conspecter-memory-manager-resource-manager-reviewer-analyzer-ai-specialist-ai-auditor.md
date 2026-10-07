# DIA-260929-nc6w - agent-role consolidation study: conspecter+memory-manager, resource-manager, reviewer+analyzer, ai-specialist+ai-auditor

---

id: DIA-260929-nc6w
title: "agent-role consolidation study: conspecter+memory-manager, resource-manager, reviewer+analyzer, ai-specialist+ai-auditor"
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
updated: 2026-10-06

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [".opencode/oh-my-opencode-slim.jsonc", "knowledge/model-registry.yaml", ".opencode/oh-my-opencode-slim/knowledge/ai-assist-sources.yaml", ".opencode/CHANGELOG.yaml", ".opencode/CHANGELOG.md", ".opencode/learnings/external-patterns/2026-10-06-dia-260929-nc6w-observer-vision-routing.md", "docs/dev-infra-audit/tickets/DIA-260929-nc6w-agent-role-consolidation-study-conspecter-memory-manager-resource-manager-reviewer-analyzer-ai-specialist-ai-auditor.md"]
artifacts: []
evidence: ["make test-config exit 0 (post re-route)", "PNG exact-match probe 6/6 'X7-Q42-LM' on opencode-go/qwen3.8-flash; no-image negative control 0/2", "Phase-6 audit advisory PASS", "CHANGELOG entry appended via scripts/changelog-add (Phase 7)"]

---

## Description

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## Update 2026-10-06 (observer vision routing, Option C)

- EBDV chosen variant: @observer -> opencode-go/qwen3.8-flash primary +
  opencode-go/kimi-k2.7-code fallback in the active mimo-balanced preset.
  Because: Go-native vision, respects the DIA-260916-7jek no-openai
  invariant, probe-validated.
- Rejected: openai/gpt-5.6-luna inside mimo-balanced (violates the
  DIA-260916-7jek no-openai invariant; plus Go transport caveat).
- Probe verdict PNG_PASS: exact-match PNG string "X7-Q42-LM" read 6/6;
  no-image negative control 0/2; image prompts billed 142-178 tokens vs
  76 without.
- PDF finding: the Go gateway accepts a PDF as an OpenAI `file` part
  (HTTP 200, string read exactly); the docs' "no PDF" limit is NOT
  gateway-enforced (only image_url carrying PDF bytes returns 400).
- Registry/config note: observer removed from the mimo-v2.5 and
  mimo-v2.6-flash lane arrays and added to the qwen3.8-flash lane
  (knowledge/model-registry.yaml); no kimi-k2.7-code registry entry
  exists (only kimi-k3). slim.jsonc mimo-balanced observer model array
  re-routed, line 14 volume-lane comment corrected; line 313
  openai-first-cost-balanced left untouched.
