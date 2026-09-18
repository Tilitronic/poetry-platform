# DIA-187 - OMO slim 2.2.14 update evaluation (research + safety decision)

<!-- UPDATE 2026-08-15: developer decision UPDATE NOW (EBDV variant A, recorded 2026-08-15). Implementation applied: global opencode.jsonc + tui.json pins -> @2.2.14, project comment synced, cache purged. Host gates: make test-config exit 0. PENDING: post-restart re-verify (panel shows v2.2.14, task_result tool registered, smoke lane), ai-auditor independent review, CHANGELOG registration. -->

<!-- FILED 2026-08-15 (docs lane, coder agent). Research/planning ticket - no
     config or code change performed yet. The ai-specialist research lane is
     dispatched separately and will fill the Evidence section; findings are
     reviewed by the developer (practice-protected) before any update action.
     Structural precedent: DIA-127 (omo-slim-2-2-13-update-evaluation). -->

---

id: DIA-187
title: "OMO slim 2.2.14 update evaluation - research what is new, decide safety/worth for the project"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # no blockers
parent_epic: ""

# DIA-104 grilling-gate markers (ai--7 validated design): fill at creation time

# with the defaults below (absent = legacy/skipped, grandfather precedent).

gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered:
source: developer request
date: 2026-08-15
created: 2026-08-15
updated: 2026-08-15

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_ffba9eb5cffei4tn3UljarbL3X" # filing lane (docs, coder agent)
lane_id: "docs"
agent: "coder"
model: "opencode-go/deepseek-v4-flash"
parent_session_id: "ses_ffbaf7352ffex2gLbQswhW2cFx" # orchestrator session (filing dispatch context)
attempts: 0
lease_expires_at: ""
files_touched: [docs/dev-infra-audit/tickets/DIA-187-omo-slim-2-2-14-update-evaluation.md, docs/dev-infra-audit/tickets/README.md, .opencode/opencode.jsonc]
artifacts: []
evidence: []

---

## Description

A new oh-my-opencode-slim version, 2.2.14, is available (developer-requested
evaluation 2026-08-15). The current pin is oh-my-opencode-slim@2.2.13 in the
global config (~/.config/opencode/opencode.jsonc line 148 and
~/.config/opencode/tui.json plugin array) and in the project opencode.jsonc
comment (.opencode/opencode.jsonc line 135). The project runs a customized
OMO config (.opencode/oh-my-opencode-slim.jsonc) with 3 presets
(opencode-go, cebula, free) and heavily customized agents (orchestrator,
coder, reviewer, conspecter, etc.).

NON-REGRESSIBLE items (must survive any upgrade):

- conspecter permission hardening from commit 753e374 (crwl bash allow,
  webfetch deny, websearch MCP removed from all 3 presets);
- agent-name lockstep S1-S4 contract via scripts/validate-agent-names.sh;
- skill-sync behavior (skill-updates staging into version dirs);
- make test-config and make test-interview must stay green.

Before any upgrade, research 2.2.14 vs 2.2.13 and decide:

(a) what is new in 2.2.14 vs 2.2.13 (changelog/diff, release notes);
(b) breaking changes / migration requirements;
(c) impact on the project customizations above (presets, agent names,
permissions, model assignments, skill-sync, the live prompt dir
.opencode/oh-my-opencode-slim/);
(d) known issues / regressions (incl. any OpenCode-version incompatibility);
(e) recommendation update-now / defer / skip with rationale.

Route per section 10 (AI Devtools Modernization Workflow): gate research by
@ai-specialist (web-fresh), findings reviewed by the developer
(practice-protected), design via @architector if non-trivial, implementation
by @coder, validation via make test-config + restart-verify, independent
review by @ai-auditor.

Precedents: DIA-127 (omo-slim-2-2-13-update-evaluation) is the structural
precedent for this ticket class; the res019-omo-slim-version-gate conspect
(knowledge/res019-omo-slim-version-gate/
res019-omo-slim-version-gate-conspect.md) holds the 2.2.13 version-gate
research baseline (10 archived sources, memory-shelf registered). The DIA-127
reopened-analysis lesson applies: upgrade verification MUST check the
actually-loaded instance and ALL plugin declaration sources (global
opencode.jsonc + tui.json plugin key + project opencode.jsonc + docker
opencode.json), not only the opencode.jsonc pin.

Preliminary research DONE 2026-08-15 by ai-specialist lane: recommendation
UPDATE NOW, zero breaking changes. Developer decision PENDING (section 10
Phase 2).

## Evidence (2026-08-15)

Research by the ai-specialist lane (live-fetched Aug 15 2026, npm + GitHub).
Current pin: oh-my-opencode-slim@2.2.13 (global opencode.jsonc + tui.json,
project opencode.jsonc comment line ~135). Target: 2.2.14.

PERSISTENCE_RECOMMENDED: false - small patch release, 3 PRs, no novel
architectural changes; established evaluation criteria from the res019
conspect are sufficient.

### (a) WHAT IS NEW in 2.2.14 vs 2.2.13

Published 2026-08-14T17:39Z, tag 150eaf5, 20 commits/20 files, 2
contributors, dist-tags.latest = 2.2.14.

- PR #1005 feat(tasks): read-only task_result tool (orchestrator-only,
  returns final assistant message of a completed child session without
  resuming; parent-scoped ownership check; per-state errors for
  running/errored/cancelled; closes upstream issue #828; 40 tests + 3
  snapshots). Direct project benefit: eliminates duplicate-specialist-work
  failure mode when the orchestrator loses a task result from context.
- PR #1008 fix: recover background jobs after restart (rehydrates persisted
  background task launches on orchestrator session resume; reconciles
  restored jobs with live host status; serialized runtime reconciliation;
  1989 tests). Direct project benefit: delegation-observer background job
  board survives session restarts/context compaction.
- PR #1010 fix(multiplexer): waitForSessionReady before child attach (1s
  per-attempt probe, 2s absolute bounded deadline, AbortSignal fencing,
  dedup concurrent session.created; 107 tests; Greptile 4/5 - stall concern
  FIXED in second commit ea94922+881eef6). Lower direct impact (project
  uses task() not multiplexer panes).
- 8 non-PR commits: deepwork skill/prompt improvements (phase advancement
  discipline, parallel structure scan, commit-before-next-phase, Oracle
  re-review limits) + docs.

### (b) BREAKING CHANGES

NONE. Schema v2.2.14 identical to v2.2.13 (top-level keys unchanged:
preset, setDefaultAgent, compactSidebar, stripOrchestratorModel,
autoUpdate, presets, agents, disabled_agents, image_routing, disabled_mcps,
disabled_tools, disabled_skills, multiplexer, interview, backgroundJobs,
fallback, council, companion, webfetch, acpAgents). No agent/preset/
disabled_agents/skill name changes. PROMPTS_DIR_NAME unchanged. skill-sync
mechanism unchanged. Dependencies unchanged (@opencode-ai/plugin 1.18.13,
@opencode-ai/sdk 1.18.13). OpenCode 1.18.18 fully compatible. Drop-in
replacement.

### (c) IMPACT ON PROJECT CUSTOMIZATIONS

1. Conspecter permission hardening (commit 753e374: crwl bash allow,
   webfetch deny, websearch MCP removed from all 3 presets) - NONE, no
   permission schema changes.
2. Agent-name lockstep S1-S4 via scripts/validate-agent-names.sh - NONE, no
   agent names changed.
3. skill-sync behavior - LOW RISK (deepwork skill changed upstream;
   project's own deepwork skill at ~/.config/opencode/skills/deepwork/ is
   separate/versioned; skill-sync stages without overwrite).
4. make test-config + make test-interview - LOW RISK (orchestrator prompt
   snapshot updated upstream with task_result tool mention; if
   test-interview audits the prompt verbatim, mechanical snapshot update
   needed, not a design break).

### (d) KNOWN ISSUES

Zero GitHub bug issues filed against 2.2.14 (1 day old). Pre-existing
non-blocking: formatting violation in src/agents/orchestrator.ts blocks
check:ci (pre-existing, acknowledged in PR #1008); 30 pre-existing
multiplexer adapter test failures (herdr/kitty/tmux, base-red confirmed).

### (e) RECOMMENDATION

UPDATE NOW. Rationale: direct benefit from task_result (PR #1005) +
background job restart recovery (PR #1008); zero breaking changes; 2136
combined tests passing (1989+107+40); patch-level low risk (vs v2.2.11
which had 608 lines removed); fresh publish (1 day) with no community
regressions yet.

### MIGRATION STEPS (when approved)

1. Update global pin ~/.config/opencode/opencode.jsonc plugin array to
   oh-my-opencode-slim@2.2.14.
2. Update ~/.config/opencode/tui.json pin to @2.2.14.
3. Sync project comment .opencode/opencode.jsonc line ~135 (2.2.13 ->
   2.2.14).
4. Purge npm cache 2.2.13 install + pre-fetch 2.2.14.
5. Restart OpenCode.
6. make test-config + make test-interview (verify no snapshot drift).
7. Smoke: dispatch a read-only lane.
8. Verify task_result tool registered.

### SOURCE URLS (live-fetched 2026-08-15)

github.com/alvinunreal/oh-my-opencode-slim/releases;
/releases/tag/v2.2.14; /pull/1005; /pull/1008; /pull/1010;
/compare/v2.2.13...v2.2.14;
raw.githubusercontent.com/.../v2.2.14/package.json;
raw.githubusercontent.com/.../v2.2.14/oh-my-opencode-slim.schema.json;
registry.npmjs.org/oh-my-opencode-slim/latest;
github.com/.../issues?q=is:issue+label:bug+created:>2026-08-14.

### CONFIDENCE

(a) HIGH (PRs read in full, release notes confirmed); (b) HIGH (schema +
package.json fetched and compared); (c) HIGH (ground-truth config files
read); (d) MEDIUM (zero results but release 1 day old); (e) HIGH.

## Verification

> To be filled. Suggested checklist (mirrors DIA-127):

- [ ] Changelog/diff for 2.2.14 vs the current pinned 2.2.13 collected, with source URLs cited
- [ ] Breaking-change / migration scan for 2.2.14
- [ ] Impact analysis: agents, skills, presets, models, permissions, MCPs, plugins, prompt dir
- [ ] Compatibility check against .opencode/oh-my-opencode-slim.jsonc customizations (3 presets, conspecter 753e374 hardening, agent-name lockstep S1-S4, skill-sync)
- [ ] make test-config exit 0, make test-interview PASS
- [ ] Recommendation documented with rationale: update now / defer / skip
- [ ] If update recommended: section 10 chain executed (ai-specialist gate -> developer decision -> design -> implement -> make test-config exit 0 -> restart-verify incl. loaded-instance + tui.json check -> ai-auditor review)

## Fix

Applied 2026-08-15 (implementation lane, section 10 chain step 4). EBDV
variant A (UPDATE NOW) recorded in the UPDATE block above.

### Changes applied

1. Global pin: ~/.config/opencode/opencode.jsonc plugin array entry
   "oh-my-opencode-slim@2.2.13" -> "oh-my-opencode-slim@2.2.14" (line 148).
   No other plugin entries touched. Verified array:
   ["@tarquinen/opencode-dcp@3.1.14", "envsitter-guard@0.0.4",
   "opencode-plugin-openspec@0.1.4", "oh-my-opencode-slim@2.2.14"].
2. Global TUI pin: ~/.config/opencode/tui.json plugin array entry pinned
   "oh-my-opencode-slim@2.2.13" -> "oh-my-opencode-slim@2.2.14" (entry KEPT,
   not removed - removing it kills the OMO TUI panel in opencode 1.18.18;
   a bare "oh-my-opencode-slim" would resolve to stale @latest).
3. Project comment sync: .opencode/opencode.jsonc line 135 comment bumped
   2.2.13 -> 2.2.14 (comment only, no logic change).
4. Cache management: purged stale
   ~/.cache/opencode/packages/oh-my-opencode-slim@2.2.13 (no bare or
   @latest dirs existed at purge time); pre-fetched 2.2.14 into
   ~/.cache/opencode/packages/oh-my-opencode-slim@2.2.14 by replicating
   the opencode cache layout (package.json declaring dependency
   oh-my-opencode-slim@2.2.14 + npm install -> node_modules, 353 packages;
   verified node_modules/oh-my-opencode-slim/package.json version =
   2.2.14). Post-purge cache contains ONLY @2.2.14.

### Verification evidence

- make test-config: exit 0 (56 tests / 7 suites pass, 0 fail)
- make test-interview: exit 0 (all 5 checks PASS)
- JSON validity: global opencode.jsonc + tui.json parse clean (JSONC with
  trailing commas tolerated); plugin arrays confirm @2.2.14
- docker compose ps: poetry-dev Up 8 hours (healthy) - docker gate PASS,
  commit allowed
- Remaining 2.2.13 references in project .opencode/ (reported, not
  changed by this lane): historical records in learnings/, memory/lessons.md,
  memory/adr.md, CHANGELOG.md (intentionally untouched - historical);
  LIVE prompt-dir files .opencode/oh-my-opencode-slim/{coder.md,
  analyzer_append.md, REFERENCE-ONLY.md} still name 2.2.13 - candidates
  for the CHANGELOG registration step of this rollout (no runtime impact:
  prompt-precedence semantics unchanged in 2.2.14).

### Pending (post-restart)

- Restart OpenCode; verify OMO panel shows v2.2.14 (loaded instance, not
  inference), task_result tool registered (PR #1005), background job
  recovery (PR #1008), smoke lane dispatch.
- ai-auditor independent review (section 10 Phase 5/6).
- CHANGELOG registration + learnings outcome field.

## Re-verify

> To be filled at re-verify time.
