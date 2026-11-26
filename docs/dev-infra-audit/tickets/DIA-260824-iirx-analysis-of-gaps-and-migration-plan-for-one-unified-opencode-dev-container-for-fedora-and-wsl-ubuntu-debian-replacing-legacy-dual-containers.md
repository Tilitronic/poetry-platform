# DIA-260824-iirx - Analysis of gaps and migration plan for one unified OpenCode dev container for Fedora and WSL Ubuntu/Debian replacing legacy dual containers

---

id: DIA-260824-iirx
title: "Analysis of gaps and migration plan for one unified OpenCode dev container for Fedora and WSL Ubuntu/Debian replacing legacy dual containers"
area: docker
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-24
source: inventory
date: 2026-08-24
created: 2026-08-24
updated: 2026-08-24

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

Reconcile the unified-dev-container gap analysis (ana035 G1-G8) against the
current repo and record a disposition for every gap so the analysis ticket
can close.

## Problem

- The analysis exists but nothing records which gaps closed:
  `knowledge/ana035-unified-dev-runtime-gap-migration/ana035-unified-dev-runtime-gap-migration-report.md:230-236`
  (G1-G8), the conspect
  `knowledge/res-260921-fo7q-unified-dev-container/res-260921-fo7q-unified-dev-container-conspect.md`
  (shelf `.opencode/memory-shelf.yaml:431`), the twelve grilling decisions at
  `openspec/changes/dia-260821-x5nj-unified-docker-dev-runtime/proposal.md:40-52`
  ("Interview Decisions (DIA-260824-iirx)"), and the ADR citation at
  `.sdd/dev-infra/architecture.md:97-99` (ADR 11, "DIA-260824-iirx decision 3").
  This ticket's body was still the creation template.
- Current state, verified by grep: G3 closed (`bootstrap.py` absent,
  `dev-entrypoint.sh` present), G6 closed (`docker-compose.fedora.yml` absent;
  only `docker-compose.yml`, `.podman.yml`, `.rootless-docker.yml`,
  `.wsl.yml` remain), G4 closed (single `Dockerfile.dev`; `tools/` retired);
  G5 open (`grep -n openssh Dockerfile.dev` returns 0 matches, no
  `openssh-client`); G7 open (`grep -n -- '--serve' scripts/opencode-dev`
  returns 0, tracked as DIA-260821-4cx5); G8 open (`grep -n "memory:\|cpus"
docker-compose.yml` returns 0 resource limits).
- G1/G2 (container-owned commit and hook inversion) are only partially
  migrated: `.husky/pre-commit:6` still calls `scripts/verify-pre-commit.sh`,
  which still handles "host vs dev-container execution"
  (`scripts/verify-pre-commit.sh:6`).

## Verification

- [ ] A disposition line (closed / open + follow-up ticket / deferred by
      developer) exists for each of G1-G8 in this ticket, each with a
      current file:line or command-output pointer
- [ ] Every open gap is either already ticketed (G7 = DIA-260821-4cx5) or has
      a new ticket ID recorded here
- [ ] `make test-config` exit 0

## Fix

Append a "Gap disposition (G1-G8)" section to this ticket, re-running the
greps above for each gap and citing the result; file follow-up tickets for
G5 and G8 if the developer wants them implemented (G7 already exists). Touch:
this ticket only (plus new tickets if approved).

## Re-verify

```bash
ls bootstrap.py docker-compose.fedora.yml 2>&1          # both absent (G3/G6 closed)
grep -n openssh Dockerfile.dev                          # G5 status
grep -n -- '--serve' scripts/opencode-dev               # G7 status (DIA-260821-4cx5)
grep -n "memory:\|cpus" docker-compose.yml              # G8 status
grep -n "G1\|G5\|G7\|G8" docs/dev-infra-audit/tickets/DIA-260824-iirx-*.md
make test-config                                        # exit 0
```

## References

- `knowledge/ana035-unified-dev-runtime-gap-migration/ana035-unified-dev-runtime-gap-migration-report.md:230-236,599-609` (G1-G8, migration table)
- `openspec/changes/dia-260821-x5nj-unified-docker-dev-runtime/proposal.md:40-52`
- `.sdd/dev-infra/architecture.md:97-99` (ADR 11 consequences)
- Commit `a504f965` (conspect + five analysis reports registered under this ticket)
