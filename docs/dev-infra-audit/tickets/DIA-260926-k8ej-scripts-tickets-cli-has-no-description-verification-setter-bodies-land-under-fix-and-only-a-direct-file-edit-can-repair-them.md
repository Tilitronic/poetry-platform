# DIA-260926-k8ej - scripts/tickets CLI has no Description/Verification setter - bodies land under Fix and only a direct file edit can repair them

---

id: DIA-260926-k8ej
title: "scripts/tickets CLI has no Description/Verification setter - bodies land under Fix and only a direct file edit can repair them"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-26
source: fix-lane
date: 2026-09-26
created: 2026-09-26
updated: 2026-09-26

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

### Problem

- scripts/tickets update supports ONLY --fix-file / --reverify-file / --status / --evidence. There is NO setter for the Description or Verification sections.
- scripts/tickets new has no description/body flag at all, so whatever body content a caller supplies has nowhere to go: both DIA-260926-40bb and this ticket were created with TITLES ONLY, all template sections left as placeholders.
- Consequence: Description and Verification keep their placeholders, and repairing a ticket body REQUIRES a direct edit of the ticket markdown - in tension with DIA-229 (create tickets ONLY via scripts/tickets new).
- OBSERVED TWICE on 2026-09-26: first DIA-260926-kksa (body landed under '## Fix' while Description and Verification stayed placeholders, requiring a hand edit), then DIA-260926-40bb and DIA-260926-k8ej (created empty because there is no body flag at all).

### Fix

- Add a description/body flag to `scripts/tickets new` that writes into '## Description' (and optionally a verification flag that fills '## Verification' as checkboxes).
- Add matching --description and --verification setters to `scripts/tickets update`.
- Keep --fix-file writing to the Fix section.
- Consider accepting a body from a file or stdin so long content does not have to be passed as a single argument.

### Acceptance criteria

- A ticket can be created entirely from the CLI with Description and Verification populated correctly - no placeholders, no nested headings.
- `scripts/tickets update --description/--verification` can move or replace content in those sections.
- A smoke test asserts the sections land correctly (extend the existing ticket-script tests).
- A full ticket body can be supplied without a direct file edit.

### Relations

- Found while repairing DIA-260926-kksa on 2026-09-26; reproduced immediately on the two tickets created in the same session. Related: DIA-260820-y268 (enforce ticket status queries via scripts) and the ticket template conventions in docs/dev-infra-audit/tickets/.

## Verification

- [ ] A ticket can be created entirely from the CLI with Description and Verification populated correctly - no placeholders, no nested headings.
- [ ] `scripts/tickets update --description/--verification` can move or replace content in those sections.
- [ ] A smoke test asserts the sections land correctly (extend the existing ticket-script tests).
- [ ] A full ticket body can be supplied without a direct file edit.

## Fix

> To be completed when the fix is implemented.

### Confirmed CLI gaps collected 2026-09-28

Three further CLI gaps confirmed on 2026-09-28, each with the concrete case that proved it:

1. `scripts/tickets update` has NO severity setter. `--severity` exists only on `new`; `update --severity High` fails with `error: unknown option '--severity'` (exit 1). Concrete case: `DIA-260928-rzty` was assessed as a HIGH-impact finding but had to be created at Major, and the severity can no longer be corrected through the CLI. Desired outcome: a supported severity setter on `update`.

2. `--fix-file` replaces only the FIRST `## Fix` body and NEVER deletes a line starting with `## `, so heading count is monotonic and a duplicated section cannot be repaired through the CLI. Concrete case: `DIA-260928-nm2u` now carries two identical `## Fix` bodies (cause: a fix file that itself began with its own `## Fix` heading); `DIA-260928-gpcc` escaped it only because its body omitted the heading. Desired outcome: heading-aware replace/dedup on `update`.

3. `scripts/tickets new` has no body/description/verification flag, so composed bodies land under `## Fix` and `## Description` / `## Verification` keep template placeholders (the original subject of this ticket, now with three more instances). Desired outcome: body/description/verification flags on `new`.

## Re-verify

> To be filled at re-verify time.
