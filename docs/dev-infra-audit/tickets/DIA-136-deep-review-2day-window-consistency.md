# DIA-136 — Deep review: 2-day commit window (DIA-124..135) consistency vs pre-existing docs/config/docker

---

id: DIA-136
title: "Deep review: 2-day commit window (DIA-124..135) consistency vs pre-existing docs/config/docker"
area: dev-infra
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-14
source: baseline
date: 2026-08-14
created: 2026-08-14
updated: 2026-08-14

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_ffff689d1ffeoWG0q8HPknkBiM" # OpenCode session ID that owned this ticket
lane_id: "" # e.g. cod-1, ai--3
agent: "" # agent name (coder, reviewer, etc.)
model: "" # model ID used
parent_session_id: "ses_ffff689d1ffeoWG0q8HPknkBiM" # orchestrator's session ID
attempts: 0 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [] # list of file paths modified
artifacts: [] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

The last two days produced a large commit window (`8fde3c02..HEAD`, 143 files,
+17477/-2037) spanning DIA-124..135: test-infra phases 0-3, docker CLI install
(DIA-131), SSH-agent forwarding into opencode-docker (DIA-133), parallel-coder
batch D expansion (DIA-132), batch D infra hardening (DIA-134), and coder
prompt hygiene (DIA-135). Risk: these changes may contradict or orphan
pre-existing content — stale `.md` references, agent-name contract drift
(`scripts/validate-agent-names.sh`), `.sdd/` architecture ADRs, Docker/yaml
config, `opencode.jsonc` / `oh-my-opencode-slim.jsonc` settings, or duplicated
inline overrides.

Additionally there are UNCOMMITTED changes on top: `.opencode/memory-shelf.yaml`,
`.opencode/memory/lessons.md`, `tools/opencode-docker/AGENTS.md`,
`tools/opencode-docker/README.md`, new ticket `DIA-133-ssh-agent-forward-opencode-docker.md`,
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

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
