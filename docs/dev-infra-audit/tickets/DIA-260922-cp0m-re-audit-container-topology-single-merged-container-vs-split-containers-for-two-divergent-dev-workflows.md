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

### Problem: in-container engine probes are wrong by construction (2026-09-26)

- The AGENTS.md section 6 Docker-gate wording (DIA-094) tells the agent to treat "a running docker dev container" as a precondition to verify. From inside the container there is no daemon and no socket (the dev service deliberately has no engine socket mounted), so that instruction induces a guaranteed false blocker. A coder lane hit exactly this on 2026-09-26 while fixing the Makefile test-infra teardown, and correctly refused to proceed.
- The pre-commit hook does NOT probe a socket: it detects the container by hostname (scripts/in-container.sh:10-12, hostname == poetry-dev; scripts/verify-pre-commit.sh:63), so in-container commits work. The false premise is in the PROSE, not in the code.
- The same failure is already documented as lesson L20260901-003 (.opencode/memory/lessons.md:2297-2299) yet recurs, because the rule wording was never corrected.
- Repo prose is also stale on the engine: AGENTS.md says "runs inside Docker" while the code is engine-neutral (scripts/container-engine.sh:11-18, .env.example:31 COMPOSE_ENGINE=podman, docker-compose.podman.yml).
- Additional lock-in found: scripts/**tests**/batch-d-infra.test.mjs:457 asserts AGENTS.md literally contains "docker compose ps", which freezes the DIA-174 R3 merge-gate wording and asserts no behavior.

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

### Fix: make the container rules detection-based and engine-neutral

1. AGENTS.md section 6 - replace the DIA-094 block with a context-aware, ENGLISH paragraph: the agent determines its location the way the hook does (hostname == poetry-dev). Inside: the container is up by construction and is self-evident; NEVER start a container and NEVER probe for a daemon or engine socket (docker info, docker compose ps, /var/run/docker.sock) from inside - none is visible and any such probe is wrong by construction. On the host: the host-path checks apply. If container status is genuinely required, ASK THE DEVELOPER to run the command on the host and paste the output. What remains of DIA-094: commits still route through the husky pre-commit autofix gate, which detects in-container by hostname and needs no daemon; never bypass with --no-verify.

2. AGENTS.md gates table (around lines 183-189) - retitle so it does not imply the agent must verify a running container; note that `make test-infra` genuinely needs a live engine and is therefore run by the developer on the host.

3. AGENTS.md merge-gate bullet (DIA-174 R3, around line 74) - KEEP the guarantee (recorded evidence of the dev service being Up before a merge phase) but change the EVIDENCE SOURCE to host-side, and make it engine-neutral (docker compose ps OR podman compose ps, or the developer-pasted output). The guarantee must not be silently dropped.

4. ~~NEW RULE (developer request, 2026-09-26) - agents COMMIT only; `git push` is performed by the DEVELOPER from the host.~~ **WITHDRAWN (2026-09-26).** Rules and permissions stay unchanged; host-side push is a session practice only, not a new rule. The developer pushes from the host because the agent cannot push from inside the container -- that is a session practice, not a new rule to codify.

5. docs/docker-dev.md (around lines 104-106) - add that the hooks detect the container by hostname and need no daemon.

6. scripts/**tests**/batch-d-infra.test.mjs:457 - remove the assertion that AGENTS.md contains the literal "docker compose ps", or refactor it so it asserts no wording. If removing it makes the test fail elsewhere, refactor rather than delete the whole test. Developer decision: this assertion is meaningless.

7. Cross-link this ticket with DIA-260925-td9h (the session that produced the findings) and with DIA-174 R3 / DIA-094 for traceability.

### Legacy orphan cleanup (2026-09-26)

- The functional retirement under DIA-260824-8k62 (CLOSED, commit 63d6478) was already complete: Dockerfile, scripts, bin/, the Makefile target, the bats tests, docker-compose.fedora.yml and the test-shell wiring are gone; no pin divergence remains (single Dockerfile.dev ARG OPENCODE_VERSION).
- A single orphan remained OUTSIDE 8k62's scope: tools/opencode-docker/config/ (node_modules ~62 MB, package.json, package-lock.json, .gitignore, **pycache**) - the former Context7 MCP config now living in .opencode/opencode.jsonc. Zero executable references existed.
- Action: removed the orphan directory. git ls-files reported ZERO tracked paths (entire directory was untracked/ignored). No commit needed (nothing tracked to remove).
- test-shell: exit 1. 3 failures in check-compose-config (tests 98-100) -- HOST-scoped compose validation tests that require a Docker/Podman engine, which is unavailable inside the container. NOT caused by this change.
- test-config: exit 0. All structural gates PASS.
- Documentary references in tickets, knowledge/, openspec/ and CHANGELOG are historical records and were intentionally LEFT UNCHANGED.

### WSL in-container path verified COMPLETE (2026-09-26)

Entry points for a Windows/WSL developer, all from the WSL host terminal:

- .devcontainer/devcontainer.json:3-4 (VS Code "Reopen in Container",
  dockerComposeFile=../docker-compose.yml, service=dev)
- `make up && make opencode`
- `make up && make shell`
- `make up && make dev`
- raw `docker compose exec dev ...`

Engine auto-detection covers WSL: scripts/compose-env.sh:64 detects WSL
via /proc/version and appends docker-compose.wsl.yml. No remaining gap
was found; the bare-host opencode path is NOT required for anything.

**STALE CLAIM ANNOTATION:** The claim at line 61 of this ticket
("Developer: Windows. Runs opencode on the WSL HOST, never inside the
container") is STALE. It reflected the developer's session practice at
the time (2026-09-22), not a constraint on the container path. The
container path is fully functional on WSL. Current truth: BOTH developers
work inside the Poetry Dev container (developer on Linux+Podman, colleague
on Windows+WSL). This annotation does not rewrite the historical text.

### R3 decision (2026-09-26)

**Enforcement inventory:** R3 is enforced ONLY by string-presence
assertions that assert no behaviour:

- scripts/**tests**/batch-d-infra.test.mjs:431-432 asserts
  /docker compose ps/ in orchestrator_append
- :434-435 asserts /dev service/
- :437-438 asserts /before merge dispatch/
- :440-441 asserts /session log/
- :457-458 asserts /docker compose ps/ in AGENTS.md

Rule text: .opencode/oh-my-opencode-slim/orchestrator_append.md:448-453
and AGENTS.md ~line 74.

**Options evaluated:**
(a) Keep R3, re-source evidence to host (developer pastes). Loses:
nothing, but requires a manual developer step on every merge.
(b) Replace `docker compose ps` with an in-container readiness/health
evidence line (TCP probe). `docker compose ps` is not runnable from
inside the dev container at all -- neither the container-engine CLI nor
its socket is mounted -- so it was never a valid option; the in-container
TCP probe is the only viable check. No engine socket required.
(c) Delete R3 entirely. Loses: the original motivation (a merge once
proceeded without evidence the stack was up, per DIA-172).

**CHOSEN: option (b).** The in-container TCP probe was verified as
VIABLE from inside the dev container (see learnings addendum Part 7).
Verified command:

python3 -c "import socket; s=socket.socket(); s.settimeout(3);
s.connect(('postgres',5432)); print('REACHABLE'); s.close()"

This replaces the `docker compose ps` requirement. `docker compose ps`
is not runnable from inside the dev container (neither the engine CLI nor
its socket is mounted), so the in-container TCP probe is the only viable
merge-gate evidence: the agent verifies that postgres is reachable from
inside the dev container, proving both the network path AND the service
are up -- no engine socket, no compose binary required.

**Status-quo defect (recorded):** R3 was a rule that looked enforced
but could not be satisfied from the most common execution context. The
lessons file carried an undocumented workaround (lessons.md:2531-2561:
accept the pre-commit hook exit 0 as implicit evidence) not in any
committed gate text. This defect is now resolved by option (b).

**Supersession (Fix item 3):** the original R3 requirement for `docker
compose ps` evidence is superseded by option (b). Fix item 3 in the
original audit is CLOSED as superseded.

**PROSE-ONLY enforcement note:** R3's enforcement is PROSE-ONLY. The
orchestrator reads the STACK_READY token from the script output and
records it in the merge report. No mechanical consumer (CI gate, hook,
or automated check) parses the token. This is an accepted ceiling: the
gate relies on agent discipline to run and record the probe.

### Implementation complete (2026-09-26)

**Commit:** c1b1429

**Changed files:**

- scripts/check-stack-ready.sh (NEW - real postgres protocol probe)
- scripts/**tests**/check-stack-ready.bats (NEW - bats tests)
- .opencode/oh-my-opencode-slim/orchestrator_append.md (R3 rewritten)
- AGENTS.md (Docker-gate detection-based, gates table retitled, merge-gate re-sourced)
- docs/docker-dev.md (hostname-detection + check-stack-ready note)
- scripts/**tests**/batch-d-infra.test.mjs (docker compose ps assertions replaced)
- .opencode/memory/lessons.md (append-only correction near L20260922-env-fact)
- .opencode/learnings/external-patterns/2026-09-26-in-container-engine-probes-wrong-by-construction.md (Addendum 2 frozen design)

**Verification:**

- check-stack-ready.sh positive case: exit 0, stdout STACK_READY
- check-stack-ready.sh negative case (CHECK_TARGET override): exit 1, stdout STACK_NOT_READY
- check-stack-ready.sh no-URL case: exit 1, stdout STACK_NOT_READY
- make test-config: exit 0 (57 tests, 56 pass, 1 pre-existing orchestrator_append line-wrap fix applied)
- make test-shell: 3 pre-existing check-compose-config failures (host-scoped, no engine reachable from inside the container); no new failures

**IMPORTANT:** An OpenCode RESTART is required for the orchestrator-prompt change (R3 in orchestrator_append.md) to take effect. The new R3 rule requires check-stack-ready.sh output as merge evidence instead of docker compose ps.
