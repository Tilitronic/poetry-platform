# DIA-176 — Deep review: 2-day commit window (DIA-167..176) consistency vs pre-existing docs/config/docker

<!-- RENUMBERED 2026-08-14 (phase 1, remote lineage canonical, DIA-153): local DIA-136 collided with origin/omo-slim-changes ticket DIA-136-orchestrator-session-records-research-json-db-api-layer-lowdb-json-server-nedb-tinydb-for-visibility-reliability-determinism-token-economy.md (different ticket). Renumbered to DIA-176. -->

---

id: DIA-176
title: "Deep review: 2-day commit window (DIA-167..176) consistency vs pre-existing docs/config/docker"
area: dev-infra
severity: Major
status: DONE
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-14
source: baseline
date: 2026-08-14
created: 2026-08-14
updated: 2026-08-14

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_ffff689d1ffeoWG0q8HPknkBiM" # OpenCode session ID that owned this ticket
lane_id: "cod-1, cod-2" # e.g. cod-1, ai--3
agent: "code-navigator, architector, reviewer, ai-auditor, coder, memory-manager" # agent names
model: "" # model ID used
parent_session_id: "ses_ffff689d1ffeoWG0q8HPknkBiM" # orchestrator's session ID
attempts: 5 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [".opencode/memory-shelf.yaml", ".opencode/memory/lessons.md", "AGENTS.md", ".opencode/agents/ai-auditor.md", ".opencode/opencode.jsonc", ".opencode/plugins/delegation-observer.ts", ".opencode/oh-my-opencode-slim.jsonc", ".opencode/oh-my-opencode-slim/knowledge/ai-assist-sources.yaml", ".opencode/oh-my-opencode-slim/orchestrator_append.md", ".sdd/dev-infra/architecture.md", ".sdd/opencode-config/architecture.md", "scripts/__tests__/batch-d-infra.test.mjs", ".gitignore", "Makefile", "docs/dev-infra-audit/inventory.md", "tools/opencode-docker/README.md", "tools/opencode-docker/AGENTS.md", "tools/opencode-docker/bin/opencode-docker", "openspec/changes/batch-d-infra-hardening/design.md", "knowledge/"]
artifacts: ["91816ee", "285376a", "d2eaacb", "a7a94fa", "5177aa3"] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

The last two days produced a large commit window (`8fde3c02..HEAD`, 143 files,
+17477/-2037) spanning DIA-167..176: test-infra phases 0-3, docker CLI install
(DIA-171), SSH-agent forwarding into opencode-docker (DIA-173), parallel-coder
batch D expansion (DIA-172), batch D infra hardening (DIA-174), and coder
prompt hygiene (DIA-175). Risk: these changes may contradict or orphan
pre-existing content — stale `.md` references, agent-name contract drift
(`scripts/validate-agent-names.sh`), `.sdd/` architecture ADRs, Docker/yaml
config, `opencode.jsonc` / `oh-my-opencode-slim.jsonc` settings, or duplicated
inline overrides.

Additionally there are UNCOMMITTED changes on top: `.opencode/memory-shelf.yaml`,
`.opencode/memory/lessons.md`, `tools/opencode-docker/AGENTS.md`,
`tools/opencode-docker/README.md`, new ticket `DIA-173-ssh-agent-forward-opencode-docker.md`,
`knowledge/res020-ssh-add-confirmation/`, and
`openspec/changes/ssh-agent-forward-opencode-docker/` — these must be reconciled
with the committed window before merge.

Goal: deep independent multi-agent review that (a) detects contradictions
between the new window and pre-existing files, (b) flags stale/orphaned content
to fix or remove, (c) verifies config contracts (agent names, permissions,
presets) still hold, (d) lists concrete fixes.

## Verification

- `git diff 8fde3c02..HEAD --stat` — confirm review window
- `make test-config` — config contract (agent-name lockstep, JSONC validity)
- `make test-shell` — bats unit tests
- `make test-infra` — full infra suite (requires Docker daemon)
- `scripts/validate-agent-names.sh` — S1-S4 agent-name cross-reference
- Read `.sdd/opencode-config/architecture.md` ADRs vs changed configs
- Grep for stale references: agent names, script paths, worktree flags,
  permission rules in AGENTS.md, README files, `docs/`

## Fix

Applied 2026-08-14 in 5 commits (91816ee, 285376a, d2eaacb, a7a94fa, 5177aa3):

- F1: Phantom "AGENTS.md section 10" refs normalized to section 2.5 (AGENTS.md:78, delegation-observer.ts:947, ai-auditor.md, opencode.jsonc:446/453).
- F2: Un-gitignored + committed `scripts/__tests__/batch-d-infra.test.mjs` (DD2 rationale was false); fresh-clone gate now passes.
- F3: Committed DIA-173 SSH-agent docs atomically (README.md, AGENTS.md, openspec change, ticket, res020 knowledge).
- F4: Renumbered colliding knowledge IDs res014->res021, ana013->ana016, ana014->ana017 (dirs + shelf + refs); fixed res020 path to conspect .md; fixed dangling shelf.specs path to archive.
- F5: ADR 10 (batch-D suite persistence) added to .sdd/dev-infra/architecture.md.
- F6: ADR 3 (strict instance separation) + ADR 4 (same-session fix loops) added to .sdd/opencode-config/architecture.md.
- F7: AGENTS.md:28 ticket-ID wording aligned to actual gate scope (delegation-observer.ts correlation logic).
- F8: inventory.md test-config/test-interview descriptions refreshed.
- F9: CONTAINER-SETUP.md removed (superseded by docs/docker-dev.md); references updated.
- F10: ai-assist-sources.yaml role keys kebab-cased (code-navigator, openspec-plan).
- F11: WHY comment on unconditional GIT_SSH_COMMAND in bin/opencode-docker.
- F12: Triplicated orchestrator prompt across presets - SKIPPED (runtime-behavior risk, documented escape hatch; accepted residual).
- A2 (re-review cycle 1 residual): AGENTS.md:28 + orchestrator_append.md R1 wording tightened to match real gate behavior (hard-block only for explicit bad DIA-id; no-id warns/passes); ssh-agent-forward-opencode-docker registered in shelf.specs (10->11).

## Re-verify

Re-review cycle 1 (8fde3c02 fixed point): 12/12 findings verified-closed, 0 new Standards/Spec issues. ai-auditor: A1, A3-A7 PASS; A2 residual fixed in 5177aa3. Cycle 2/2 targeted re-verify: A2-1..A2-5 all verified-closed - APPROVED FOR MERGE.

Gates (all exit 0): test-config sub-gates (batch-d suite 43/43, test-interview 5/5, validate-skills 24, agent-names 24/24, output-contracts 2, reviewer-sections 1, handoff 5, ticket-gate 6/6), test-shell bats 240, test-python 1+1, shelf YAML parse + all paths OK. Pre-commit hook passed via container on all commits (no --no-verify). Working tree clean.
