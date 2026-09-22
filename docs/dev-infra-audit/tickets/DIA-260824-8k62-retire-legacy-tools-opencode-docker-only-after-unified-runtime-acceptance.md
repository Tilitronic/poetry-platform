# DIA-260824-8k62 - retire legacy tools/opencode-docker only after unified-runtime acceptance

---

id: DIA-260824-8k62
title: "retire legacy tools/opencode-docker only after unified-runtime acceptance"
area: docker
severity: Medium
status: CLOSED
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

PHASE 3 retired: the legacy tools/opencode-docker/ directory, the dead duplicate
docker-compose.fedora.yml, the test-opencode-docker Makefile target and its
bats test, and the stale check-opencode-docker script. Review-driven follow-ups
swept all surviving references to the deleted surface across scripts, tests,
docs, and the SDD.

Commits: 63d6478 (PHASE 3 retirement), 4b00b2d (reference sweep + gate
inversion record), 488350b (ADR non-port consequence + stale path fixes),
0a78c4b (cycle 2 review residuals), 8317ebc (record-only metric correction),
this commit (final record correction + close).

## Re-verify

Two-axis review plus two fix/re-review cycles completed:

- Cycle 1 (4b00b2d): verified 9 of 14 findings closed, no regressions.
- Cycle 2 (0a78c4b): verified 12 of 13 findings closed; remaining item was the
  record's unsupported causal metric claim, corrected in this commit.
- Fix/re-review cap reached; no further cycles.

## UPDATE 2026-09-22

Blocking edges reduced by developer disposition:

- DIA-260821-m7vk - already CLOSED (blocker cleared).
- DIA-260821-aoag - already CLOSED (blocker cleared).
- DIA-260824-ifcf - CLOSED as obsolete placeholder (see that ticket).
- DIA-260821-n8sq - DECOUPLED by developer disposition 2026-09-22: it is independent scripts/CI test work (its `test-runtime-config` make target is verified ABSENT - `grep -n "test-runtime-config" Makefile` exits 1, no match in scripts/). It stays OPEN as independent work but no longer gates this ticket.
- DIA-260821-x5nj - EDGE CLEARED 2026-09-22: x5nj was CLOSED with criterion (g) superseded by Accepted ADR 11 (see that ticket and knowledge/ana-260922-4fod-x5nj-scope-breach-disposition/). This ticket is now unblocked; PHASE 3 (retire tools/opencode-docker, delete docker-compose.fedora.yml, drop the test-opencode-docker target) executes under it.
- PHASE 3 COMPLETE (commit 63d6478): the legacy tools/opencode-docker/ directory, the dead duplicate docker-compose.fedora.yml, and the test-opencode-docker Makefile target are retired; the stale check script and its bats test removed; check-pin-sync.sh trimmed to the single remaining Dockerfile; two further stale-reference fixes applied (.mise.toml comment, an audit bats test path). Gates green: make test-shell exit 0, make test-config exit 0. Container stack healthy at commit time. Pre-change baseline (1e04881): 719 @test blocks / 715 bats-passing lines; post-cycle-2 (0a78c4b): 691 @test blocks / 689 bats-passing lines; net -28 @test blocks / -26 bats-passing lines.
- GATE INVERSION (developer direction 2026-09-22): The T8.1-T8.5 acceptance chain (collect acceptance evidence -> 3-day countdown -> reviewer audit -> ai-auditor audit -> developer confirmations) was INVERTED by explicit developer direction: T8.6 (retirement) was executed BEFORE the T8.1-T8.5 acceptance evidence existed. The developer accepted the risk of retiring the legacy runtime without prior acceptance evidence, reasoning that the unified runtime was already the production container and the legacy image was dead weight. T8.1-T8.5 are struck as superseded-by-direction in openspec/changes/dia-260821-x5nj-unified-docker-dev-runtime/tasks.md.
- TEST COUNT RECONCILIATION (C2, corrected 2026-09-22, revised to pinned SHAs): Three conflicting figures circulated: 734 (ADR PHASE 1, commit 07c0513 -- NOT a current baseline), 717 (DIA-260920-cry5, 2026-09-20), 691 (my measurement). bats-wrapper.sh does NOT count tests itself -- it execs bats (`exec "$BATS" --print-output-on-failure "$TESTS_DIR"`). The grep metric `^ok [0-9]+` counts bats output lines for passing tests. Two metrics, pinned to commits: (i) `grep -cE "^ok [0-9]+"` in make test-shell output = 715 at 1e04881, 689 at 0a78c4b (delta: 26); (ii) `grep -c '^@test'` across all .bats files = 719 at 1e04881, 691 at 0a78c4b (delta: 28). The `^ok N` output-line metric and the `^@test` block metric are different and do not reconcile exactly. Measured deltas: `@test` 719 -> 691 (-28); passing lines 715 -> ~688/689 (-26/-27, the count varied by +/-1 across repeated runs on the same commit 0a78c4b). The small residual gap (2-4 observed) is run-variable and is NOT attributable to a specific subset of removed tests; treat the removal as approximately -28 blocks / -26 passing lines rather than an exact causal decomposition. The likely source is a metric-scope artifact: the bats wrapper execs bats over the test directory while the `@test` grep counts blocks across all .bats files. Three-cycle removal arithmetic: 27 removed in PHASE 3 (13 ssh-agent-forward.bats + 9 opencode-docker.bats + 3 check-pin-sync.bats T11-T13 + 2 verify-pre-commit.bats fabricating tests), minus 1 added in cycle 1 (A6 blanket-WARN fixture), plus 2 removed in cycle 2 (same A6 fixture deleted as redundant with pre-existing test at audit-agent-tool-coverage.bats:386, plus weaker duplicate host-down test) = net 28 removed. 719 - 28 = 691. The `692 ok` cited in the 63d6478 commit message was the wrapper's grep count at that intermediate state. The 734 figure in .sdd/dev-infra/architecture.md:104 is the ADR's PHASE 1 number and should not propagate as a current baseline.
- SSH AGENT FORWARDING - INTENTIONALLY NOT PORTED (developer disposition 2026-09-22). The retired wrapper carried a shipped, verified capability (DIA-173 DONE: openssh-client added, GIT_SSH_COMMAND pinned, agent push verified end-to-end, covered by ssh-agent-forward.bats 10/10 + opencode-docker.bats 8/8). It probed $SSH_AUTH_SOCK / ${XDG_RUNTIME_DIR}/keyring/ssh / ${XDG_RUNTIME_DIR}/gcr/ssh, mounted the first found socket READ-ONLY at /tmp/ssh-agent.sock, and wired SSH_AUTH_SOCK + GIT_SSH_COMMAND via EXTRA_ENV (key material never entered the container). Its deletion was a pure consequence of retiring the directory - no decision was ever taken to drop the feature, and neither this ticket nor ADR 11 mentioned it. Disposition: do NOT re-implement now. Rationale: the capability was specific to the retired container; the surviving dev container authenticates over HTTPS via a github_token Docker secret, git remote is HTTPS (https://github.com/Tilitronic/poetry-platform.git), and Dockerfile.dev has no SSH wiring. Re-implement if an SSH-remote workflow inside the dev container ever appears. ADR 11 was amended with this non-port as a consequence line (commit 488350b; .sdd/dev-infra/architecture.md:99).
- RE-REVIEW RESIDUALS (accepted, cycle 2/2): (a) the hardened Dockerfile.dev existence guard in scripts/test-docker-smoke.sh has no regression test, because that script is integration-only and not run by make test-shell - a future rename of Dockerfile.dev would re-introduce the false-green uncaught; deferred as YAGNI (the guard itself is correct and now fails loudly). (b) that guard sits after ~10 live container probes, so a missing Dockerfile.dev aborts late; reordering would fail faster. Neither is a correctness break.
