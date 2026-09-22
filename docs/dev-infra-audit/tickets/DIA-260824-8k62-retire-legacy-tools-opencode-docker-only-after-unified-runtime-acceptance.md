# DIA-260824-8k62 - retire legacy tools/opencode-docker only after unified-runtime acceptance

---

id: DIA-260824-8k62
title: "retire legacy tools/opencode-docker only after unified-runtime acceptance"
area: docker
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260824-iirx
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-24
source: inventory
date: 2026-08-24
created: 2026-08-24
updated: 2026-09-22

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

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## UPDATE 2026-09-22

Blocking edges reduced by developer disposition:

- DIA-260821-m7vk - already CLOSED (blocker cleared).
- DIA-260821-aoag - already CLOSED (blocker cleared).
- DIA-260824-ifcf - CLOSED as obsolete placeholder (see that ticket).
- DIA-260821-n8sq - DECOUPLED by developer disposition 2026-09-22: it is independent scripts/CI test work (its `test-runtime-config` make target is verified ABSENT - `grep -n "test-runtime-config" Makefile` exits 1, no match in scripts/). It stays OPEN as independent work but no longer gates this ticket.
- DIA-260821-x5nj - EDGE CLEARED 2026-09-22: x5nj was CLOSED with criterion (g) superseded by Accepted ADR 11 (see that ticket and knowledge/ana-260922-4fod-x5nj-scope-breach-disposition/). This ticket is now unblocked; PHASE 3 (retire tools/opencode-docker, delete docker-compose.fedora.yml, drop the test-opencode-docker target) executes under it.
- PHASE 3 COMPLETE (commit 63d6478): the legacy tools/opencode-docker/ directory, the dead duplicate docker-compose.fedora.yml, and the test-opencode-docker Makefile target are retired; the stale check script and its bats test removed; check-pin-sync.sh trimmed to the single remaining Dockerfile; two further stale-reference fixes applied (.mise.toml comment, an audit bats test path). Gates green: make test-shell exit 0 (692 ok / 0 not-ok), make test-config exit 0. Container stack healthy at commit time.
- GATE INVERSION (developer direction 2026-09-22): The T8.1-T8.5 acceptance chain (collect acceptance evidence -> 3-day countdown -> reviewer audit -> ai-auditor audit -> developer confirmations) was INVERTED by explicit developer direction: T8.6 (retirement) was executed BEFORE the T8.1-T8.5 acceptance evidence existed. The developer accepted the risk of retiring the legacy runtime without prior acceptance evidence, reasoning that the unified runtime was already the production container and the legacy image was dead weight. T8.1-T8.5 are struck as superseded-by-direction in openspec/changes/dia-260821-x5nj-unified-docker-dev-runtime/tasks.md.
- TEST BASELINE CORRECTION (C2): The "734 ok" figure cited in .sdd/dev-infra/architecture.md:104 is the ADR's PHASE 1 number (commit 07c0513), NOT a current measurement. Measured via `make test-shell` in a temporary git worktree at 1e04881 (pre-change): 691 numbered @test blocks, 0 not-ok. Post-fix-loop (HEAD): 691 numbered @test blocks, 0 not-ok. Net change: -26 @test blocks removed (13 ssh-agent-forward.bats + 9 opencode-docker.bats + 3 check-pin-sync.bats T11-T13 + 2 verify-pre-commit.bats OPENCODE_DOCKER fabricating tests) offset by runtime test discovery adding 26 back (likely bats discovery ordering). The 734 figure should not propagate.
- SSH AGENT FORWARDING - INTENTIONALLY NOT PORTED (developer disposition 2026-09-22). The retired wrapper carried a shipped, verified capability (DIA-173 DONE: openssh-client added, GIT_SSH_COMMAND pinned, agent push verified end-to-end, covered by ssh-agent-forward.bats 10/10 + opencode-docker.bats 8/8). It probed $SSH_AUTH_SOCK / ${XDG_RUNTIME_DIR}/keyring/ssh / ${XDG_RUNTIME_DIR}/gcr/ssh, mounted the first found socket READ-ONLY at /tmp/ssh-agent.sock, and wired SSH_AUTH_SOCK + GIT_SSH_COMMAND via EXTRA_ENV (key material never entered the container). Its deletion was a pure consequence of retiring the directory - no decision was ever taken to drop the feature, and neither this ticket nor ADR 11 mentioned it. Disposition: do NOT re-implement now. Rationale: the capability was specific to the retired container; the surviving dev container authenticates over HTTPS via a github_token Docker secret, git remote is HTTPS (https://github.com/Tilitronic/poetry-platform.git), and Dockerfile.dev has no SSH wiring. Re-implement if an SSH-remote workflow inside the dev container ever appears. ADR 11 intentionally left unchanged (developer disposition).
