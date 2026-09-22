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

## Re-verify

> To be filled at re-verify time.
