# HANDOFF.md — Cycle <cycle_id>

> **Template:** `openspec/templates/HANDOFF.md` — the outgoing (producer) session
> fills this in at cycle end. Governed by the PROGNOSIS-DISCIPLINE rule text
> (design.md §2) and the HANDOFF.md schema (design.md §3).
> **Every cycle MUST produce a HANDOFF.md at termination** — whether `clean`,
> `crisis`, `exhausted`, or `manual-halt` (ADR-001: the prognosis lives here and
> only here). The successor session reconstructs its full working context from
> this document ALONE (prognosis must be self-contained, §2.2).

<!--
  Authoring rules (design.md §2):
  - The prognosis is the single source of truth for the successor session.
  - It must be self-contained (no reading of predecessor conversation history).
  - It must be structured (all 5 subsections below are required).
  - It must be honest (do NOT mark a crisis as clean — sandbagging is a violation).
  - It must be actionable (every open_ticket has a next_step; every
    verification_request has success criteria; every resume_instruction is executable).

  cycle_id format: c-YYYYMMDD-HHMMss UTC (design.md §6). Example: c-20260803-143025
  exit_state enum MUST be one of: clean | crisis | exhausted | manual-halt (design.md §7)

  CYCLES BUDGET recording (locked decision Q12 R12.2, design.md §7):
  - Budget state (cycle current/max, clean-re-audit, budget-exhausted) is recorded
    in THIS HANDOFF.md (in the session_summary table or a clearly-labelled budget
    block) AND in the campaign trigger manifest — it is NEVER recorded in
    NEXT-RUN.md.
  - On `exhausted`, the summary_narrative is the ≤200-char postmortem (ADR-005).

  NOTE: the fresh-session verifier appends a `verification_result` note to this
  document during clean-termination verification (design.md §9). It is written by
  the VERIFIER, never by the producer session — the 5 subsections above it are the
  producer's contract.
-->

## Prognosis for next cycle

### session_summary

<!-- **Session summary** — Required. Concise narrative of what this cycle accomplished.
     On `exhausted`, the summary_narrative MUST be a postmortem of ≤200 characters
     (design.md §7, ADR-005). -->

| Field             | Type     | Required | Description                                                                 |
| ----------------- | -------- | -------- | --------------------------------------------------------------------------- |
| cycle_id          | string   | yes      | This cycle's ID (`c-YYYYMMDD-HHMMss` UTC)                                   |
| started_at        | datetime | yes      | ISO 8601 UTC timestamp of cycle start                                       |
| ended_at          | datetime | yes      | ISO 8601 UTC timestamp of cycle end                                         |
| exit_state        | enum     | yes      | One of: `clean`, `crisis`, `exhausted`, `manual-halt`                       |
| tasks_completed   | string[] | yes      | List of task IDs (from tasks.md) that reached "done" in this cycle          |
| tasks_attempted   | string[] | yes      | List of task IDs that were attempted but not completed                      |
| crisis_triggers   | string[] | no       | List of trigger IDs that fired (e.g., `["C1", "C3"]`). Empty if clean exit. |
| summary_narrative | string   | yes      | 3–10 sentence prose summary of what happened and why                        |

<!-- Example values:
  cycle_id: c-20260803-143025
  started_at: 2026-08-03T14:30:25Z
  ended_at: 2026-08-03T16:05:11Z
  exit_state: clean
  tasks_completed: ["T1", "T2"]
  tasks_attempted: []
  crisis_triggers: []
  summary_narrative: "Completed the spec-infra scaffold (T1) and the messages.md
  fixture (T2). Both passed manual verification per the VP procedures. No crisis
  triggers fired; exit is clean and ready for fresh-session verification."
-->

### fixes_applied

<!-- **Fixes applied** — Required. List of concrete changes made during this cycle. -->

| Field       | Type   | Required | Description                                                       |
| ----------- | ------ | -------- | ----------------------------------------------------------------- |
| file_path   | string | yes      | Path of the changed file                                          |
| change_type | enum   | yes      | One of: `created`, `modified`, `deleted`                          |
| description | string | yes      | What was changed and why (1–3 sentences)                          |
| task_ref    | string | yes      | Task ID this change belongs to                                    |
| test_status | enum   | yes      | One of: `passing`, `failing`, `not_tested`, `no_tests_applicable` |

<!-- Example values:
  file_path: openspec/templates/HANDOFF.md
  change_type: created
  description: "Created the HANDOFF.md template matching design.md §3."
  task_ref: T1
  test_status: no_tests_applicable
-->

### open_tickets

<!-- **Open tickets** — Required. Unfinished work that the successor session must address.
     Mark a ticket [BLOCKING] when blocking: true — C5 prognosis-debt detection
     depends on this (design.md §1). -->

| Field       | Type     | Required | Description                                                                  |
| ----------- | -------- | -------- | ---------------------------------------------------------------------------- |
| ticket_id   | string   | yes      | Unique ID within this HANDOFF.md (e.g., `OT-001`)                            |
| task_ref    | string   | yes      | Task ID this ticket relates to                                               |
| title       | string   | yes      | Short title                                                                  |
| description | string   | yes      | Full description of what remains                                             |
| blocking    | boolean  | yes      | `true` if this blocks the next cycle from proceeding; `false` if deferrable  |
| next_step   | string   | yes      | Concrete next action the successor should take                               |
| evidence    | string[] | no       | File paths, test outputs, or other evidence supporting the ticket's validity |

<!-- Example values:
  ticket_id: OT-001 [BLOCKING]
  task_ref: T3
  title: "OAuth flow untested"
  description: "Auth module scaffolded but the OAuth flow has no passing tests."
  blocking: true
  next_step: "Write OAuth integration tests and run `pnpm verify:test`."
  evidence: ["packages/auth/src/oauth.ts", "tests/auth.spec.ts: 3 failures"]
-->

### verification_request

<!-- **Verification request** — Required. What the successor session must verify before declaring progress.
     The fresh session executes these INDEPENDENTLY — the producer's claims are
     never accepted as verification (design.md §9, ADR-003). -->

| Field            | Type    | Required | Description                                                               |
| ---------------- | ------- | -------- | ------------------------------------------------------------------------- |
| verification_id  | string  | yes      | Unique ID (e.g., `VR-001`)                                                |
| what_to_verify   | string  | yes      | What specifically must be checked                                         |
| success_criteria | string  | yes      | How to determine the verification passed (observable, testable condition) |
| how_to_verify    | string  | yes      | Concrete steps: commands to run, files to read, tests to execute          |
| blocking         | boolean | yes      | `true` if this blocks cycle completion                                    |

<!-- Example values:
  verification_id: VR-001
  what_to_verify: "HANDOFF.md template matches design.md §3."
  success_criteria: "All 5 subsections present; field tables match §3.1–§3.5."
  how_to_verify: "Read openspec/templates/HANDOFF.md and diff against design.md §3."
  blocking: true
-->

### resume_instructions

<!-- **Resume instructions** — Required. Step-by-step instructions for the successor session to resume work. -->

| Field           | Type     | Required | Description                                                     |
| --------------- | -------- | -------- | --------------------------------------------------------------- |
| step_number     | integer  | yes      | Sequential step number (1-indexed)                              |
| instruction     | string   | yes      | What to do (imperative mood)                                    |
| rationale       | string   | no       | Why this step is necessary (helps successor understand context) |
| depends_on      | string[] | no       | Step numbers this step depends on (for ordering)                |
| estimated_scope | enum     | yes      | One of: `trivial` (<5 min), `small` (<30 min), `medium` (<2 hr) |

<!-- Example values:
  step_number: 1
  instruction: "Approve the batch (this HANDOFF.md) with the developer."
  rationale: "Batch-approval boot protocol (design.md §8): no work before approval."
  depends_on: []
  estimated_scope: trivial
-->

## Verification Result

<!--
  Filled by the FRESH-SESSION VERIFIER only — NEVER by the producer session
  (design.md §9, ADR-003: no self-certification; "I verified" markers are untrusted
  and block SELF-RERUN). The fresh session independently executes each
  verification_request and records the outcome here. Appended AFTER the producer's
  five subsections; the producer's contract ends above this section.
-->

| Field            | Type     | Required | Description                                                                  |
| ---------------- | -------- | -------- | ---------------------------------------------------------------------------- |
| verification_id  | string   | yes      | Must match a verification_id from the Verification request section           |
| status           | enum     | yes      | One of: `verified-pass` \| `verified-fail` \| `verified-partial`             |
| evidence         | string   | yes      | Concrete evidence: exit codes, test counts, file paths, observed vs expected |
| verifier_session | string   | yes      | Session ID of the fresh-session verifier (never the producer session)        |
| verified_at      | datetime | yes      | ISO 8601 UTC timestamp of verification                                       |

### Outcome rules

- ALL `verified-pass` → confirm `exit_state: clean` (append `Verified by:
<session-id>, <timestamp>`).
- ANY `verified-fail` → downgrade `exit_state` to `crisis`; append failure details.
- Mixed `verified-pass` + `verified-partial` → `manual-halt` (partial means the
  verification could not be completed conclusively).

<!-- Example values:
  verification_id: VR-001
  status: verified-pass
  evidence: "make test-config exit 0; validate-opencode-config.sh 6/6 checks pass"
  verifier_session: s-20260803-183000
  verified_at: 2026-08-03T18:35:00Z
-->
