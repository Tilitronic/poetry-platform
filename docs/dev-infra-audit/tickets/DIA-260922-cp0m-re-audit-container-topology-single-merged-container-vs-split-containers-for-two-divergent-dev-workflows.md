# DIA-260922-cp0m - Re-audit container topology: single merged container vs split containers for two divergent dev workflows

---

id: DIA-260922-cp0m
title: "Re-audit container topology: single merged container vs split containers for two divergent dev workflows"
area: docker
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-22
source: inventory
date: 2026-09-22
created: 2026-09-22
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

CONTEXT / TRIGGER:

- A colleague consolidated the container setup: previously TWO containers, now everything in ONE. The developer wants a re-audit of whether that change was warranted.
- Two DIFFERENT workflows must both be supported:
  (a) Colleague: Linux. Runs opencode INSIDE the container (make opencode / docker compose exec).
  (b) Developer: Windows. Runs opencode on the WSL HOST, never inside the container (authoritative clarification 2026-09-22; confirmed by evidence: /.dockerenv absent, /proc/1/cgroup = "0::/init.scope", hostname = wn - ses_f37b8d93dffeCt29mlT42pi2n2).
- Developer's stated goal: a RELIABLE and LOW-MAINTENANCE approach.

CURRENT DOCUMENTED STATE (AGENTS.md section 6): "One dev workstation container (poetry-dev) + one stateful postgres container (poetry-postgres)". Verify whether the working tree still matches that description or whether it was changed.

AUDIT QUESTIONS TO ANSWER WITH EVIDENCE:

1. What exactly changed? Find the commit(s) that consolidated the containers (git log/diff on docker-compose\*.yml, Dockerfile.dev, dev-entrypoint.sh, tools/opencode-docker/). Report the before/after topology verbatim with commit hashes.
2. What was the stated rationale at the time (commit message, ticket, PR, docs)? Was a ticket raised for it?
3. Was the change warranted? Evaluate against: isolation (postgres state vs dev toolchain), startup time, image size/build time, blast radius (does a dev-container rebuild kill DB state?), and the two workflows above.
4. Does the merged design serve the Windows/WSL-host workflow at all? If the Windows developer never runs opencode in the container, which parts of the container setup are actually load-bearing for them (e.g. only postgres? the pre-commit delegation target?) and which are dead weight?
5. Does the merged design still serve the Linux-in-container workflow (the colleague's)?
6. Reliability risks introduced or removed by the merge: restart coupling, volume/state handling, healthcheck wiring, port collisions, the DIA-094 pre-commit container gate dependency.
7. Low-maintenance assessment: how many files must change to add a service, bump a version, or support a new platform? Is there duplication between Dockerfile.dev and tools/opencode-docker/Dockerfile (a prior lane bumped BUN_VERSION in BOTH - is that duplication itself a maintenance hazard)?
8. Recommendation: keep merged / revert to split / hybrid (e.g. split stateful services from the dev toolchain, or make the opencode-in-container path optional). State the trade-offs and name the ADR-worthy decision.

DELIVERABLE EXPECTATION: this ticket is for the re-audit; the audit itself will be dispatched separately. Record the questions and the acceptance criteria (an evidence-cited before/after topology, a warrant assessment, a reliability/low-maintenance comparison, and a recommendation with trade-offs).

ACCEPTANCE CRITERIA:

1. Evidence-cited before/after topology (commit hashes, file diffs)
2. Warrant assessment (was the consolidation justified for both workflows?)
3. Reliability/low-maintenance comparison (merged vs split)
4. Recommendation with trade-offs (keep merged / revert to split / hybrid)

---

## Audit + Verification Findings (2026-09-22)

VERDICT: PARTLY justified. The premise "two containers merged into one" is IMPRECISE: docker-compose.yml has exactly two services (dev, postgres) and postgres has ALWAYS been separate. The real consolidation was of two DEV IMAGES (Dockerfile.dev vs tools/opencode-docker), and it is INCOMPLETE.

### Evidence-cited topology

- Live `docker compose ps`: 2 services only (dev Up 4 days, postgres Up 4 days).
- All 7 cited commit hashes VERIFIED (arc-1 ses_f37a6b044ffer0rrVC9eHFBfFP).
- Legacy runtime still present: tools/opencode-docker/ directory retained; gated by `make test-opencode-docker`.
- OPENCODE_VERSION DIVERGED: Dockerfile.dev has 1.18.32; tools/opencode-docker/Dockerfile has 1.18.4.
- check-pin-sync.sh does 4 comparisons (node/pnpm x 2 Dockerfiles).
- opencode install block at Dockerfile.dev:143-160; 13 RUN layers follow it; image 9.17GB.
- No CHANGELOG entry for DIA-260821-x5nj.
- DIA-260821-x5nj: OPEN (planning only). DIA-260824-8k62 (retire legacy): OPEN, blocked on 5 tickets.

### Windows/WSL-host workflow load-bearing assessment

- Load-bearing: postgres, the dev container as DIA-094 pre-commit delegation target, and the test/toolchain executor.
- NOT load-bearing: the baked opencode binary, OMO cache, make opencode, and the opencode-keyed healthcheck.

### DECISION (developer, 2026-09-22)

Variant 3 - keep ONE dev-toolchain container plus the separate stateful postgres; FINISH the merge rather than revert. Rationale: the drift problem is real and recurring; the security boundary was already consciously traded by the DIA-260824-iirx decisions; one image + one pin source is strictly lower maintenance.

### ACCEPTED FOLLOW-UPS

1. Retire tools/opencode-docker + delete docker-compose.fedora.yml and drop test-opencode-docker from test-shell.
2. Consolidate pins to one edit site.
3. Move the opencode install block to the last Docker layer (highest-value reliability win).
4. Decouple the dev healthcheck from opencode.
5. Resolve the Docker-CLI contradiction (x5nj T0.9 vs Dockerfile.dev:82-112).
6. ADR persisted in .sdd/dev-infra/architecture.md (ADR 11, container topology).

## Re-verify

## Re-verify

> Filled 2026-09-22.

### PHASE 1 COMPLETE (commit 07c0513)

The opencode install block (formerly Dockerfile.dev:143-160) was moved to the last layer, immediately before the OMO cache layer. Measured improvement: ~85% reduction in invalidated layers per opencode bump (13 layers previously -> 3 layers now: opencode layer + OMO cache + git global safe.directory).

Verified green (ses_f375702edffe36XpGy4yluTINz):

- test-shell: exit 0, 734 ok / 0 not-ok (full run to completion, no artificial timeout)
- Container: opencode 1.18.32, bun 1.4.2
- Binary ownership: /usr/local/bin/opencode 1001:1001 preserved
- Functional check: OPENCODE_OK
- Git tree: clean, 07c0513 as HEAD

### CORRECTIONS

1. **DNS misdiagnosis** -- the `--network=host` workaround reported by the implementation lane was NOT needed. ses_f374fe4afffeS5bFb7qV7haetj proved plain `docker compose build dev` exits 0 with an UNCACHED build (all 23 layers, all network fetches succeeded). The `curl: (22) ... 500` was a transient GitHub CDN HTTP 500 (server-side), NOT a DNS failure (which would read `curl: (6) Could not resolve host`). Both plain and --network=host probes returned NET_OK. No daemon.json exists. The Linux colleague is NOT affected.

2. **Causation** -- the reorder is a pure positional move of an existing RUN block (identical curl URL, identical sha256 digests, zero content change) and therefore cannot have caused any network error.

### REMAINING PHASES

1. Consolidate pins to one edit site
2. Retire tools/opencode-docker + delete docker-compose.fedora.yml + drop test-opencode-docker from test-shell
3. Decouple the dev healthcheck from opencode (probe node/pnpm)
4. Resolve the Docker-CLI contradiction (x5nj T0.9 vs Dockerfile.dev:82-112) and formally abandon/defer the hook-inversion

### STATUS

OPEN (phases 2-5 remaining; legacy still present; OPENCODE_VERSION diverged).
