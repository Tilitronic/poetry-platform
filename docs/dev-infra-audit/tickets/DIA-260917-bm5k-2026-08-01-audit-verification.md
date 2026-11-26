# DIA-260917-bm5k - 2026-08-01 audit verification

---

id: DIA-260917-bm5k
title: "2026-08-01 audit verification"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-17
source: inventory
date: 2026-09-17
created: 2026-09-17
updated: 2026-09-17

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

Needs owner clarification: which "2026-08-01 audit" this ticket verifies, and
where the campaign's "Persist audit verification findings" output was meant
to land (no such artifact exists in the repo).

Reconstructed from title + current repo state; original reporter context not
recoverable.

## Problem

- The 2026-09-17 campaign ran three lanes under this ticket ID
  (`.opencode/session/messages.jsonl` rows with task_ref
  "Recon audit file states campaign ticket DIA-260917-bm5k", "Query DIA
  ticket ledger campaign ticket DIA-260917-bm5k", "Persist audit verification
  findings campaign ticket DIA-260917-bm5k") but produced no
  audit-verification artifact:
  `grep -rn "audit verification" knowledge/ .opencode/learnings/` returns 0
  hits outside this ticket's own title/README.
- The only durable outputs filed under this ticket are unrelated to audit
  verification: the M6 prod-image postponement note (commit `e1c038d8`,
  Update section below) and the skills-lock extension gate learnings (commit
  `55837f2c`, `.opencode/learnings/external-patterns/2026-09-17-skills-lock-extension-gate.md:4`
  "Ticket: campaign ticket DIA-260917-bm5k"). The ticket body also drifted
  to the creation template, so the campaign's scope is not recorded anywhere.
- The title names no audit artifact. The only audit record dated 2026-08-01
  in the repo is the AIHero outcome at
  `.opencode/learnings/external-patterns/2026-08-01-aihero-vertical-slice-alignment.md:17`
  ("AIHero audit found 3 blockers + 2 majors, all fixed and re-audited to 0
  findings"); whether that is the intended subject is unconfirmed.

## Verification

- [ ] Owner names the audit artifact(s) to verify and the intended output
      location
- [ ] Findings are persisted to `.opencode/learnings/external-patterns/`
      with an entry in `learnings/index.md` (if scope (a) below is chosen)
- [ ] `make test-config` exit 0

## Fix

Owner picks one scope, then a lane executes it:
(a) re-verify the 2026-08-01 AIHero learnings' claims against current config
and persist a dated findings file; (b) point the ticket at the intended audit
artifact and close the stale title; (c) re-home the captured side workstreams
(M6 note, skills-lock learnings) onto their own tickets and close this one.
Touch: this ticket (+ a new learnings file only for scope (a)).

## Re-verify

```bash
# scope (a): findings persisted
grep -rln "DIA-260917-bm5k" .opencode/learnings/external-patterns/ | grep -v skills-lock
grep -n "DIA-260917-bm5k" .opencode/learnings/index.md
# scope (b)/(c): decision recorded on the ticket
scripts/tickets show DIA-260917-bm5k      # Fix section names the chosen scope
make test-config                          # exit 0
```

## References

- `.opencode/session/messages.jsonl` (task_ref rows for the three campaign lanes, 2026-09-17)
- `.opencode/learnings/external-patterns/2026-09-17-skills-lock-extension-gate.md:4` (side workstream filed under this ticket)
- `.opencode/learnings/external-patterns/2026-08-01-aihero-vertical-slice-alignment.md:17` (only 2026-08-01 audit record found)
- Commits `e1c038d8` (M6 note), `55837f2c` (skills-lock learnings)

## Update 2026-09-17 -- M6 decision (prod image postponed)

- Decision: postponing a separate production Dockerfile for apps/api-server. Reason (developer ruling): still working in the dev environment and fixing it; too early to create a prod image.
- Current state: apps/api-server has pyproject.toml + uv.lock and no Dockerfile\*; dev coverage via Dockerfile.dev + docker-compose.yml stands.
- Revisit trigger: dev environment stabilizes / production deployment of api-server is planned.
