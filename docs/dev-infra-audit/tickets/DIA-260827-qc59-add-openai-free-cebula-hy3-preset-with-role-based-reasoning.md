# DIA-260827-qc59 - add OpenAI-free cebula HY3 preset with role-based reasoning

---

id: DIA-260827-qc59
title: "add OpenAI-free cebula HY3 preset with role-based reasoning"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: inventory
date: 2026-08-27
created: 2026-08-27
updated: 2026-09-01

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

Create and activate a new `cebula-hy3` preset in
`.opencode/oh-my-opencode-slim.jsonc`. The preset must contain no `openai/*`
or GPT-branded fallback models. Use only variants confirmed by the live model
catalog and preserve model-family diversity between coder/reviewer and
ai-specialist/ai-auditor.

## Verification

- [ ] `cebula-hy3` is the active preset.
- [ ] The new preset contains no `openai/*` or GPT-branded model IDs.
- [ ] Fallback chains use per-model inline variants where required.
- [ ] `make test-config` passes.
- [ ] Restart smoke verifies effective orchestrator, coder, reviewer,
      ai-specialist, and ai-auditor models in logs.

## Alternatives considered

### Variant A: HY3 Free first with paid Go fallbacks

Selected. Use HY3 Free Medium for volume work. Developer overrides: reviewer
DeepSeek V4 Flash High; architector Qwen 3.7 Plus without an unsupported named
variant; OpenSpec Plan HY3 Free High. Evidence:
`knowledge/res021-opencode-agent-presets/res021-opencode-agent-presets-conspect.md`
and
`knowledge/res029-model-fallback-semantics/res029-model-fallback-semantics-conspect.md`.

### Variant B: Paid-Go-first HY3

Rejected. More reliable, but paid HY3 has no Medium variant and consumes the Go
quota. Evidence:
`knowledge/res030-opencode-go-usage-limits-mimo-v25/res030-opencode-go-usage-limits-mimo-v25-conspect.md`.

### Variant C: Status quo

Rejected. Keep `cebula-openai-hy3`; direct OpenAI lanes continue to fail with
API `429 insufficient_quota`, and unsupported scalar variants remain. Evidence:
`knowledge/res021-opencode-agent-presets/res021-opencode-agent-presets-conspect.md`.

### Chosen: Variant A

## Fix

Add OpenAI-free cebula HY3 preset with role-based reasoning (2e081b6).

## Re-verify

Commits: 2e081b6
Tests: make test-config exit 0
Confirm: cebula HY3 OpenAI-free preset landed.
