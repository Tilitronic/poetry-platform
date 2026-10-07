# DIA-260917-knz2 - preset fork promo vs promo-union-alpha strip union-alpha from promo

---

id: DIA-260917-knz2
title: "preset fork promo vs promo-union-alpha strip union-alpha from promo"
area: config
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-17
source: inventory
date: 2026-09-17
created: 2026-09-17
updated: 2026-09-17

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

Fork `.opencode/oh-my-opencode-slim.jsonc` into active `promo` without
Union Alpha and sibling `promo-union-alpha` preserving the nine Union Alpha
model entries. Preserve fallback ordering and keep the active preset on `promo`.

## Verification

- [x] Parsed JSONC: `promo` contains zero `opencode/union-alpha` references.
- [x] Parsed JSONC: `promo-union-alpha` contains nine references.
- [x] Active preset is `promo`; no preset key has leading/trailing whitespace.
- [x] `make test-config` exits 0; behavioral suite: 57 passed, 0 failed.

## Fix

- Commit `923dcab81936c5e0f032a5a351b80e8f1a4a5783` implements the fork and
  leading-space sibling-key fix. No config edits in the finalization lane.
- Changelog registered through `scripts/changelog-add`; schema validation:
  1 passed, 0 failed. Generated verification value remains `manual`.
- Review skipped with explicit developer approval: ai-auditor returned empty
  twice, partials preserved; advisory-only deviation, not a successful review.

## Re-verify

- Finalization retry independently parsed both presets and asserted counts
  0/9, active `promo`, and exact whitespace-free keys; exit 0.
- `make test-config` rerun exits 0, including 57/57 behavioral tests;
  advisory tool-coverage warnings remain (23 agents, 0 gaps, 402 warnings).
- `docker compose ps` exits 1: Docker socket unavailable. Build, lint and
  typecheck were not rerun; no application or config implementation in this lane.
- Pre-existing resource-manager fallback change in the config is left untouched.
- `git status && git push` attempted verbatim; push exits 128:
  `error: cannot run ssh: No such file or directory`; `fatal: unable to fork`.
  No bypass attempted; finalization documentation remains uncommitted.
- Ticket remains OPEN pending finalization disposition; no new commit requested.
