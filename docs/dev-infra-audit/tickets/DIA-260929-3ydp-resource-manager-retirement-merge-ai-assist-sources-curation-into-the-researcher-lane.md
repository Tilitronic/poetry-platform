# DIA-260929-3ydp - resource-manager retirement: merge ai-assist-sources curation into the researcher lane

---

id: DIA-260929-3ydp
title: "resource-manager retirement: merge ai-assist-sources curation into the researcher lane"
area: scripts
severity: Medium
status: IMPLEMENTED
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
files_touched: []
artifacts: []
evidence:

- make test-config exit 0 (2026-10-06, post-change)
- scripts/validate-agent-names.sh: 26 passed, 0 failed, 0 warnings
- ai-auditor Phase-6 accept-with-conditions; targeted re-review cycle 1/2 all prior findings closed
- scripts/validate-changelog.sh exit 0; scripts/changelog-render exit 0 (173 entries)

---

## Description

Retire the `resource-manager` lane and merge its ai-assist-sources
curation duty into `@researcher` (Option A), AGENTS.md section 2.5. Gate
findings that justified it: zero recorded dispatches, a write scope of
exactly `.opencode/oh-my-opencode-slim/knowledge/*` (2 files, which the
researcher edit map already covers), and star-count / Tier-2 methodology
duplicated with ai-specialist.

Atomic change set - 14 files, unstaged at bookkeeping time; commit and
OpenCode restart still pending:

- Config: `.opencode/opencode.jsonc`, `.opencode/oh-my-opencode-slim.jsonc`
- Live orchestrator prompt: `.opencode/oh-my-opencode-slim/orchestrator_append.md`
- Agent references: `AGENTS.md`, `.opencode/practice-protected.md`,
  `.opencode/agents/ai-specialist.md`, `.opencode/agents/ai-auditor.md`,
  `.opencode/agents/researcher.md`
- Knowledge: `.opencode/oh-my-opencode-slim/knowledge/ai-assist-sources.yaml`,
  `.opencode/oh-my-opencode-slim/knowledge/opencode-best-practices.md`
- Docs: `docs/dev-infra-audit/NEXT-RUN.md`, `docs/onboarding.md`,
  `docs/dev-infra-audit/opencode-infrastructure.md`,
  `knowledge/model-registry.yaml`
- Learnings: `.opencode/learnings/external-patterns/2026-10-06-resource-manager-retirement-gate-findings.md`

Resolves DIA-260827-ic3r by deletion: the unrestricted `"task": "allow"`
block left the repository together with the agent, so no deny-first edit
was required.

## Verification

- [x] `make test-config` exit 0 (2026-10-06, run against the change set)
- [x] `scripts/validate-agent-names.sh` exit 0 - 26 passed, 0 failed,
      0 warnings (S1-S4 lockstep holds after the lane removal)
- [x] `rg resource-manager` over the live config and doc surfaces
      (`AGENTS.md`, `.opencode/opencode.jsonc`,
      `.opencode/oh-my-opencode-slim.jsonc`, `.opencode/practice-protected.md`,
      `.opencode/agents/`, `.opencode/oh-my-opencode-slim/`,
      `knowledge/model-registry.yaml`, `docs/onboarding.md`,
      `docs/dev-infra-audit/NEXT-RUN.md`,
      `docs/dev-infra-audit/opencode-infrastructure.md`) - no hits
- [x] `scripts/validate-changelog.sh` exit 0; `scripts/changelog-render`
      exit 0 (173 entries)
- [x] ai-auditor Phase-6 verdict: accept-with-conditions
- [x] Targeted re-review cycle 1/2: F1-F4 verified-closed, F5 deferred by
      the developer - all prior findings closed
- [ ] OpenCode restart + functional smoke test (no `resource-manager` in
      `opencode agent list`; `@researcher` can write the OMO knowledge dir) - pending
- [ ] Commit of the 14-file change set - pending

## Fix

Atomic change set (Option A), 14 files, applied unstaged; commit pending.

Config and prompt surfaces:

- `.opencode/opencode.jsonc` - dropped the `resource-manager` allow-list
  key (:230) and the whole agent block (comment + permission, :620-642);
  researcher edit map gained `.opencode/oh-my-opencode-slim/knowledge/*`
  with an updated comment (:518-535).
- `.opencode/oh-my-opencode-slim.jsonc` - composition comment (:14), BOTH
  preset keys (:177-187, :319), ai-specialist referral redirect
  (:349-350), agents block (:355-358).
- `.opencode/oh-my-opencode-slim/orchestrator_append.md` - live
  orchestrator prompt referrals redirected (:178, :399).
- `AGENTS.md` :272 naming-table row removed; `.opencode/practice-protected.md`
  :59 + :73-78; `.opencode/agents/ai-specialist.md` :31 referral redirect;
  `.opencode/agents/ai-auditor.md` :23; `.opencode/agents/researcher.md`
  :45-47 + :72 (curation ownership absorbed); ai-assist-sources.yaml :238;
  opencode-best-practices.md :3.

Doc-accuracy surfaces:

- `docs/dev-infra-audit/NEXT-RUN.md` :157, `docs/onboarding.md` :131,
  `docs/dev-infra-audit/opencode-infrastructure.md` :288,
  `knowledge/model-registry.yaml` :35/:47/:59 (three `lane:` arrays).

Bookkeeping:

- DIA-260827-ic3r resolved-by-deletion - the unrestricted `"task": "allow"`
  block no longer exists, so the deny-first fix described there is moot.
- Methodology stays single-homed in `@ai-specialist` (ai-specialist.md
  :17-19) plus `ai-assist-sources.yaml`
  `community_source_evaluation.evaluation_rules`; researcher received the
  glob and a pointer only, deliberately no third copy.
- `scripts/validate-agent-names.sh` needed no edit: it extracts S1-S4 at
  runtime under a containment contract, so removal keeps it green.

Verification: `make test-config` exit 0; `scripts/validate-agent-names.sh`
26 passed / 0 failed / 0 warnings; `rg resource-manager` over the live
config and doc surfaces returns no hits; ai-auditor Phase-6
accept-with-conditions followed by targeted re-review cycle 1/2 with all
prior findings closed (F1-F4 verified-closed, F5 deferred by developer).

## Re-verify

> To be filled at re-verify time.

## Deferred / follow-up

- **OpenSpec reconciliation (NOT done here):**
  `openspec/changes/dia-260827-ft3z-fetch-artifact-write-containment/`
  still describes a `resource-manager` lane that no longer exists. 4 files,
  14 stale `resource-manager` references total - `proposal.md` (5),
  `design.md` (4), `tasks.md` (2),
  `specs/artifact-fetch-write-containment/spec.md` (3). The change must be
  reconciled to the post-retirement shape (fetch/write containment now
  covers `@researcher`, which absorbed the OMO knowledge-dir write scope)
  before it lands. Deliberately NOT edited by this bookkeeping pass.
- **F5** deferred by the developer during the re-review disposition
  (re-review cycle 1/2 closed everything else).
- **Commit + OpenCode restart** still pending for the 14-file change set;
  ticket stays IMPLEMENTED, not CLOSED, until both land.
