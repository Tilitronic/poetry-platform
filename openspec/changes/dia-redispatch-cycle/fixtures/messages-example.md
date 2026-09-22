# messages.md — Schema Evolution Fixture

> **Fixture:** `openspec/changes/dia-redispatch-cycle/fixtures/messages-example.md`
> **Purpose:** demonstrates the messages.md schema extension (design.md §4) —
> legacy 5-column rows coexisting with new-format 9-column rows, with the
> explicit-null convention. Serves as living documentation and the VP-6
> backward-compatibility verification exercise.
>
> **Schema identity:** design.md §4 calls this the "8-column schema" (referring to
> the extended schema's identity — 4 new columns added to the original 5). The
> actual extended row has **9 fields**: columns 1–5 are legacy, columns 6–9 are
> new and all nullable (see the note in design.md §4).
>
> **Backward compatibility (interview Q4, locked):** NO migration. Existing
> 5-column rows stay as-is. Readers default missing `cycle_id` to null. New rows
> must include all 9 fields, with nullable fields explicitly `null` if not
> applicable (design.md §4 backward compatibility rules).

---

## Section 1 — Legacy rows (5-column, pre-cycle format)

Columns: `timestamp | sender | recipient | channel | content_ref`

No `cycle_id`, no `evidence`, no `prognosis_ref`, no `resolution_status`.

| timestamp            | sender       | recipient    | channel    | content_ref                                                       |
| -------------------- | ------------ | ------------ | ---------- | ----------------------------------------------------------------- |
| 2026-08-01T09:00:12Z | orchestrator | coder        | delegation | "T1: implement tokenizer" (inline summary)                        |
| 2026-08-01T09:15:40Z | coder        | orchestrator | result     | tests pass: 12/12 (inline summary)                                |
| 2026-08-01T10:02:03Z | reviewer     | orchestrator | review     | openspec/changes/context7-docs-pipeline/design.md §12 (file path) |
| 2026-08-01T10:30:55Z | developer    | orchestrator | decision   | "Approved. Proceed to implementation." (inline summary)           |

> These rows predate the cycle concept and carry no cycle information by
> definition (interview Q4 rationale). They remain valid and parseable after the
> schema extension.

---

## Section 2 — New-format rows (9-column, post-change)

Columns: `timestamp | sender | recipient | channel | content_ref | cycle_id | evidence | prognosis_ref | resolution_status`

| timestamp            | sender       | recipient    | channel      | content_ref                                                                       | cycle_id          | evidence                                                                                                                     | prognosis_ref                       | resolution_status |
| -------------------- | ------------ | ------------ | ------------ | --------------------------------------------------------------------------------- | ----------------- | ---------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- | ----------------- |
| 2026-08-03T14:45:10Z | coder        | orchestrator | crisis       | "C1 fired: T3 failed 3rd consecutive attempt" (inline summary)                    | c-20260803-143025 | [{"type":"test_output","value":"tests/auth.spec.ts: 3 failures","produced_at":"2026-08-03T14:44:58Z","produced_by":"coder"}] | null                                | open              |
| 2026-08-03T16:05:11Z | coder        | coder-next   | handoff      | HANDOFF.md written: cycle c-20260803-143025 (file path)                           | c-20260803-143025 | null                                                                                                                         | HANDOFF.md#prognosis-for-next-cycle | resolved          |
| 2026-08-03T14:30:25Z | orchestrator | coder        | verification | "VR-001: run `make test` and report output" (inline summary)                      | c-20260803-143025 | null                                                                                                                         | null                                | resolved          |
| 2026-08-03T14:50:02Z | developer    | coder        | delegation   | "Defer OT-003 (ticket system) to a separate change" (inline summary)              | c-20260803-143025 | null                                                                                                                         | null                                | deferred          |
| 2026-08-03T15:12:44Z | system       | orchestrator | log          | "Context usage 55% — soft rerun signal tracked; cycle continues" (inline summary) | c-20260803-143025 | null                                                                                                                         | null                                | null              |

Row-by-row reading:

1. **Crisis trigger message** — `cycle_id` set, `evidence` populated (a
   `test_output` evidence object carrying the C1 trigger data). `prognosis_ref`
   and `resolution_status` are explicitly `null` (not applicable).
2. **Handoff message** — `cycle_id` set, `prognosis_ref` set to the HANDOFF.md
   prognosis section anchor. `evidence` `null`, `resolution_status: "resolved"`.
3. **Verification request row** — `cycle_id` set, `resolution_status:
"resolved"` (the verification passed).
4. **Deferred ticket row** — `cycle_id` set, `resolution_status: "deferred"`
   (per-item deferral recorded in the batch-approval audit trail, design.md §8).
5. **Explicit-null convention row** — all nullable columns (`evidence`,
   `prognosis_ref`, `resolution_status`) explicitly set to `null`; only
   `cycle_id` populated.

---

## Verification — VP-6 backward-compatibility scenario

**Test:** Parse the legacy rows above (Section 1) using the 9-column schema.
Verify that columns 6–9 default to null for each legacy row. Then parse each
new-format row (Section 2) and confirm all 9 columns are present.

**Expected result:** All legacy rows parse successfully. `cycle_id` = null,
`evidence` = null, `prognosis_ref` = null, `resolution_status` = null.

**Why this matters (design.md §4 backward compatibility rules):**

- A parser encountering a row without `cycle_id` defaults it to `null` (rule 2).
- A parser encountering a row without `evidence` defaults it to `null`, NOT an
  empty array (rule 3).
- A parser encountering a row without `prognosis_ref` defaults it to `null`
  (rule 4).
- A parser encountering a row without `resolution_status` defaults it to `null`
  (rule 5).
- New rows must include all 9 fields with nullable fields set explicitly to
  `null` if not applicable (rule 6) — demonstrated by Section 2.

**Result:** PASS — verified by column-count check (see implementation report):
all 4 legacy rows have exactly 5 columns; all 5 new-format rows have exactly
9 columns; every nullable column in Section 2 is either populated or explicitly
`null`.
