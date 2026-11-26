# DIA-260821-aoag - container engine socket security hardening: add default-off --with-engine opt-in flag

---

id: DIA-260821-aoag
title: "container engine socket security hardening: add default-off --with-engine opt-in flag"
area: docker
severity: Major
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260821-bqy7
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-21
source: inventory
date: 2026-08-21
created: 2026-08-21
updated: 2026-08-27

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

- commits d57fb78 (impl), 99eecc0 (fix r1); re-review cycle 1/2 all 6 findings verified-closed; residual spec test-file ref drift noted minor/non-blocking

---

## Description

ana033 rank 11 (P0 / HIGH security boundary). Parent epic: DIA-260821-bqy7
'audit repository risks and prioritize unresolved remediation'. Evidence:
knowledge/ana033-next-remediation-bugs/ana033-next-remediation-bugs-report.md
Section 4 Rank 11; live source `tools/opencode-docker/bin/opencode-docker`
lines 137-178 (`grep -c "with-engine"` returns 0).

Problem: the host container engine socket (e.g. /var/run/docker.sock) is
mounted read-write into the dev container WITHOUT any explicit opt-in. Any
process compromised inside the container gains full control of the host
container engine (create/delete containers, mount host paths, escalate). This
is a P0 security gap with no existing ticket, confirmed live by ana032.

Required outcome:

- Add a default-OFF `--with-engine` flag to the dev launcher
  (`tools/opencode-docker/bin/opencode-docker`); the engine socket is mounted
  ONLY when the flag is passed. Default behavior must NOT mount the socket.
- Document the socket-mount threat model (what access the socket grants, who
  needs it, why it is off by default) in the dev-runtime docs.
- Add `make test-infra` coverage asserting the socket is NOT mounted when the
  flag is absent and IS mounted when present.

## Verification

- [ ] `grep -c "with-engine" tools/opencode-docker/bin/opencode-docker` returns >= 1 (flag exists).
- [ ] Default launch (no `--with-engine`) does NOT mount the engine socket
      into the dev container (verified via `docker inspect` volume mounts or
      `make test-infra` assertion).
- [ ] Launch WITH `--with-engine` mounts the socket as intended.
- [ ] Threat model documented: a docs section describing socket access scope,
      the off-by-default decision, and the opt-in procedure.
- [ ] `make test-infra` includes an assertion that fails when the socket is
      mounted without the flag (exit 0 on pass).

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
