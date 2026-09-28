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

Implemented 2026-09-28. Eight files, 44 insertions / 44 deletions.
Decisions (developer, recorded): rename the active preset muse-balanced -> mimo-balanced; architector primary -> opencode-go/kimi-k3 keeping variant high; ai-auditor primary -> opencode-go/kimi-k3 with variant medium, replacing opencode-go/glm-5.3-flash.
Rationale: knowledge/model-registry.yaml:125 requires ai-auditor on a different model family from ai-specialist; the informal DeepSeek Flash V4.1 target would have collided with ai-specialist on deepseek-v4.1-flash, so kimi-k3 was chosen. Live catalog confirmed opencode-go/kimi-k3 resolves (opencode models probe, recorded in the learnings entry).
Surfaces retargeted: preset root pointer and key plus header comment; scripts/check-orchestrator-prompt-drift.sh default PRESETS; scripts/test-interview-enforcement.sh tuple and messages; three bats suites; docs/dev-infra/preset-single-path.md; live preset-name comments in knowledge/model-registry.yaml. check-orchestrator-prompt-drift.bats was cohered only after it failed, because its fixtures pinned the old name.
Registry: architector and ai-auditor removed from the deepseek-v4.1-flash lane list; glm-5.3-flash lane list emptied; the stale kimi-k3 entry corrected from active:false retired to active:true with role and lane updated.
Surgical safety: opencode-go/deepseek-v4.1-flash remains unchanged in the six sibling lanes that share it (orchestrator, openspec-plan, reviewer, ai-specialist, coder-escalated, analyzer-escalated). No other preset touched.
Evidence (implementer-asserted, not independently re-run): make test-config exit 0; make test-shell exit 0 with TAP 1..723 all ok; scoped grep for muse-balanced over the config, scripts/, the preset doc and the registry returns no matches; JSONC parses with root preset = mimo-balanced. 75 hits remain in historical surfaces and were deliberately not rewritten.
Independent audit (section 2.5 Phase 6): SOUND-with-conditions, advisory. Conditions accepted: register this changelog entry; keep the ticket OPEN until restart-verify evidence exists; optionally ticket the fallback carve-out.
Developer disposition: ACCEPT, changelog only. The ai-auditor fallback (opencode-go/deepseek-v4-flash at .opencode/oh-my-opencode-slim.jsonc:415) is ACCEPTED AS-IS as a known carve-out: independence holds at primary and only weakens on failover. Recorded, not fixed.
Remaining open items (ticket stays OPEN): (1) restart-verify - a fresh interactive launch must show the renamed preset and the new per-lane primaries; no lane can perform this. (2) The resolved-model debug line for architector and ai-auditor has not been captured. (3) Minor: knowledge/model-registry.yaml kimi-k3 model_id is bare while the config id is prefixed, and its fallback field still lists the old coder-escalated chain. (4) Minor: .opencode/oh-my-opencode-slim.jsonc:11 carries a DIA-260827-8la4 comment that still calls the preset name historical.

## Re-verify

> To be filled at re-verify time.
