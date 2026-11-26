# DIA-260821-4cx5 - Expose opencode serve over Tailscale for remote Android access

---

id: DIA-260821-4cx5
title: "Expose opencode serve over Tailscale for remote Android access"
area: docker
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-21
source: inventory
date: 2026-08-21
created: 2026-08-21
updated: 2026-08-21

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

Add a serve mode to the unified dev runtime so `opencode serve` is reachable
remotely (Android client over Tailscale), restoring the capability the retired
legacy launcher used to provide.

## Problem

- The legacy launcher that carried `-S/--serve` is gone: `ls tools/` returns
  nothing (tools/opencode-docker retired per x5nj decision 11); the capability
  is documented only in `knowledge/ana035-unified-dev-runtime-gap-migration/ana035-unified-dev-runtime-gap-migration-report.md:236`
  (G7, citing `tools/opencode-docker/bin/opencode-docker:205-225`).
- The replacement launcher has no serve flag: `scripts/opencode-dev:14-24`
  accepts only `--engine`, `--os`, `--run-opencode`, `--test`;
  `grep -n -- '--serve' scripts/opencode-dev` returns 0 matches.
- The governing spec still promises it: `openspec/changes/dia-260821-x5nj-unified-docker-dev-runtime/proposal.md:47`
  (interview decision 4, `unified-runtime-serve-mode-enabled: YES`) and
  `proposal.md:181` (acceptance item 13 "Serve mode works"); ana035 maps it to
  T4.5 Slice 4 (`ana035...report.md:599`). No `--serve` task exists in that
  change's `tasks.md` (grep matches only the word "Preserve").

## Verification

- [ ] `grep -n -- '--serve' scripts/opencode-dev` shows the new flag branch
- [ ] `scripts/opencode-dev --serve` publishes the OpenCode serve port on the host
- [ ] The serve endpoint answers from the host / Tailscale network
      (curl or Android client connects)
- [ ] x5nj proposal acceptance item 13 is marked satisfied, or the serve-mode
      decision is explicitly reversed in the ticket

## Fix

Add a `--serve` mode to `scripts/opencode-dev` (serve command mode plus host
port publish via compose), implementing ana035 T4.5
(`ana035-unified-dev-runtime-gap-migration-report.md:599`); add the port
mapping to `docker-compose.yml` only if compose cannot publish it. Acceptance:
`--serve` starts the stack with the serve port published and the remote
Android/Tailscale path reachable, closing x5nj acceptance item 13.

## Re-verify

```bash
grep -n -- '--serve' scripts/opencode-dev          # non-empty
bash -n scripts/opencode-dev                       # exit 0
scripts/opencode-dev --serve --engine=<engine>     # starts with port published
# then from host/Tailscale: curl -sf http://127.0.0.1:<published-port>/
grep -n "Serve mode works" \
  openspec/changes/dia-260821-x5nj-unified-docker-dev-runtime/proposal.md
```

## References

- `knowledge/ana035-unified-dev-runtime-gap-migration/ana035-unified-dev-runtime-gap-migration-report.md:236,599,627` (G7, T4.5, open decision)
- `openspec/changes/dia-260821-x5nj-unified-docker-dev-runtime/proposal.md:47,148,181`
- `scripts/opencode-dev:14-24` (current argument parser)
