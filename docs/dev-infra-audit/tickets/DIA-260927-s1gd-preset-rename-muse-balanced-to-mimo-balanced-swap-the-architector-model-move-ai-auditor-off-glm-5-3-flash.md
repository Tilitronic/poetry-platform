# DIA-260927-s1gd - preset: rename Muse Balanced to Mimo Balanced, swap the architector model, move ai-auditor off GLM-5.3-Flash

---

id: DIA-260927-s1gd
title: "preset: rename Muse Balanced to Mimo Balanced, swap the architector model, move ai-auditor off GLM-5.3-Flash"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-27
source: inventory
date: 2026-09-27
created: 2026-09-27
updated: 2026-09-27

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

Origin: developer request, 2026-09-27. Three changes to the active preset, stated verbatim by the developer:

1. rename the preset currently called "Muse Balanced" to "Mimo Balanced";
2. replace the architector lane's model with "Kimi K3 High";
3. replace the ai-auditor lane's model with "DeepSeek Flash V4.1 high" (ai-auditor currently runs on GLM-5.3-Flash).

WARNING - the three model/preset names above are the developer's informal wording, NOT verified catalog IDs. Resolving the exact IDs is the FIRST task of the gate research, not an assumption for the implementer.

Routing: OpenCode config change, AGENTS.md section 2.5. Sequence: (1) gate research lane (read-only) to resolve the exact catalog model IDs and enumerate every surface; (2) developer decision; (3) implement; (4) make test-config + restart-verify; (5) independent audit; (6) CHANGELOG.yaml entry.

Surfaces to enumerate during the gate (do NOT edit anything in this ticket lane): the preset definitions and per-lane model assignments in .opencode/oh-my-opencode-slim.jsonc, any per-agent model overrides in .opencode/opencode.jsonc, knowledge/model-registry.yaml, the AGENTS.md section 9 naming table if a declared name changes, docs and learnings that reference the preset by name, Makefile preset targets and scripts, and any validator that pins preset names, keys or model IDs (scripts/validate-\*).

Related ledger entries to reconcile before implementing: DIA-260926-n49u (muse-balanced preset swap to mimo-v2.6-flash) - determine whether this ticket supersedes, extends or contradicts it and say so in the Fix block.

## Verification

- [ ] the exact catalog model IDs behind "Kimi K3 High" and "DeepSeek Flash V4.1 high" are resolved from the live catalog and knowledge/model-registry.yaml BEFORE any edit (evidence: the command run plus its output)
- [ ] the preset is named Mimo Balanced everywhere it is declared or referenced; a repo-wide search finds zero stale "Muse Balanced" references (evidence: search command + empty result)
- [ ] the architector lane resolves to the new model (evidence: the agent-debug command output)
- [ ] the ai-auditor lane resolves to the new model and GLM-5.3-Flash is no longer referenced for it anywhere (evidence: debug output + search result)
- [ ] make test-config exit 0 with the naming/lockstep validators green
- [ ] restart-verify: a fresh session shows the renamed preset and the new per-lane models
- [ ] CHANGELOG.yaml entry registered for this ticket (AGENTS.md section 2.5 step 7)

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
