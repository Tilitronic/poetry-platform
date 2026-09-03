# DIA-229 - Ticket creation bypasses scripts/tickets ledger CLI - README row and rollup skipped

---

id: DIA-229
title: "Ticket creation bypasses scripts/tickets ledger CLI - README row and rollup skipped"
area: opencode-config
severity: Critical
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-18
source: fix-lane
date: 2026-08-18
created: 2026-08-18
updated: 2026-08-18

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_fea85e325ffeyXR0u2E7VCeyVh"
lane_id: "build"
agent: "build"
model: "deepseek-v4-flash"
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence: ["registry.jsonl#seq166701", "registry.jsonl#seq166686"]

---

## Description

DIA-228 was created (2026-08-18) by hand-writing the ticket file with a direct
`write` toolcall from the coder lane, instead of running the dedicated ledger
CLI `scripts/tickets new` (DIA-125). The CLI exists precisely to eliminate the
~55k-token manual bookkeeping cost per ticket (number allocation, template
copy, README index row, severity/status rollup recompute - see the script
header WHY note).

**What the bypass skipped:**

1. README index rows are missing for 18 ticket files: DIA-206, DIA-208,
   DIA-214 through DIA-228 (confirmed by diffing ticket filenames against
   README rows, 2026-08-18). The README index silently stops at DIA-213.
2. Severity/status rollup counts drift whenever a manual creation happens and
   no `rollup` run follows (observed: Medium 80->81, OPEN 18->17, DONE 11->12,
   CLOSED 99->100 before this ticket's own `tickets new` run repaired them).
3. The DIA-063 ticket gate emits noise: `gate_blocked` (dispatch without
   ticket_id, registry seq 166686) and `gate_warn` ("ticket_id 'DIA-228' not
   found in tickets directory", registry seq 166701).

**Impact:** the README index is untrustworthy (18 of 30 tickets in the 214+
range invisible), and every manual creation costs ~55k tokens of bookkeeping
(number allocation, template re-craft, row insert, rollup recompute) plus two
model hops instead of one bash call. The ledger has no guard that catches a
missing row: `rollup --check` validates counts only, never row presence.

**Root cause:** `scripts/tickets` is referenced nowhere in agent instructions -
not in `to-tickets/SKILL.md`, not in any `.opencode/agents/*.md`, not in
`opencode.jsonc`. Agents have no signal that the CLI exists, so they fall back
to the generic write-the-file path.

## Verification

Acceptance criteria for the fix:

- [ ] A fresh ticket creation goes through `scripts/tickets new` (one bash
      call) and the README row appears in DIA sort position automatically.
- [ ] `scripts/tickets rollup --check` exits 0 immediately after creation
      (counts never stale).
- [ ] Agent instructions carry an explicit pointer to the CLI: `_TEMPLATE.md`
      header comment and/or `to-tickets/SKILL.md` mention
      `scripts/tickets new "<title>" --area ... --severity ...`.
- [ ] Optional hardening: a validation guard (extend `rollup --check` or a
      `validate-tickets-ledger.sh` wired into `make test-config`) exits 1 when
      a ticket file exists without a README row or when counts are stale.
- [ ] Repair: backfill the 18 missing README rows (DIA-206, 208, 214-228),
      ideally via a scripted `tickets backfill-rows`-style subcommand rather
      than hand-editing.
      PARTIAL (executed 2026-08-18 as a one-off script, not a committed
      subcommand): all 17 rows backfilled + `tickets rollup` recomputed the
      count tables. DIA-221 used v1 frontmatter (`priority: high`, no
      area/severity) and was mapped to area tests-infra / severity Major /
      status COMPLETE by hand -- the mapping rule should be decided and, if a
      `backfill-rows` subcommand is added, encoded there.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
