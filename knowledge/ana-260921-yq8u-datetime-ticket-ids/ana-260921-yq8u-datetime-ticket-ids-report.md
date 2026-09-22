# DIA-234 Datetime Ticket IDs (DIA-YYMMDD-XXXX) - Analysis

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: finding
evidence-source: docs/dev-infra-audit/tickets/DIA-234-datetime-based-ticket-ids-and-human-readable-mentions.md
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

## Verdict

Domain fully comprehended. Headline finding: **the DIA-234 fix is already
implemented in the working tree, but the ticket itself is still OPEN with
empty Fix/Re-verify sections.** All four verification criteria from the
ticket body are satisfiable today. Remaining work is close-out bookkeeping
plus four minor residuals (one stale comment, one shell-portability
contract breach, one lenient regex, one convention-only enforcement).
Recommendation: fill Fix/Re-verify, run the ticket's 4-step verification,
address or explicitly waive residuals R1-R4, then close.

## Scope and method

Source of truth: `docs/dev-infra-audit/tickets/DIA-234-datetime-based-ticket-ids-and-human-readable-mentions.md`
(status OPEN, severity Major, area scripts, discovered 2026-08-19).

Methods used:

- **5-Whys** on the max+1 race (section 2).
- **Systems thinking** on the allocation path end to end
  (`scripts/tickets cmd_new` -> `scripts/allocate-id` -> README index ->
  `ticket-gate.ts` scan/parse).
- **MECE** enumeration of residual failure modes (section 4).
- **Inversion**: what would still collide or mis-parse after the fix
  (section 5).
- Empirical probes: 3x `allocate-id` burst (all distinct), live ledger
  already contains datetime tickets (358 ticket files, datetime IDs such
  as DIA-260819-8kwm present and gate-readable).

## 1. The race being fixed (5-Whys)

1. Why do duplicate tickets appear? Two parallel `tickets new` calls claim
   the same ID.
2. Why the same ID? Allocation is `max(existing)+1`, computed by scanning
   files+README before writing.
3. Why is the scan unsafe? It is a read-modify-write with no lock: both
   processes read the same max, both compute N+1, both write DIA-N+1.
4. Why does parallelism hit it now? Batch-D dispatch and multiple
   orchestrator sessions create tickets concurrently (previously rare).
5. Why datetime+random instead of a lock? A lock serializes creators and
   adds a new failure mode (stale locks, NFS semantics); timestamp+random
   needs **no shared state at all**, so parallelism is free by
   construction. Correct call.

## 2. Design assessment

Format `DIA-YYMMDD-XXXX`: 6-digit date + 4-char lowercase base36 suffix.

- **Entropy**: 36^4 = 1,679,616 IDs per day. Birthday bound for n same-day
  tickets: P ~= n^2 / (2 * 1.68M). At n=10/day, P ~= 0.003%. At n=100/day
  (far above observed throughput), P ~= 0.3%. Plus the date component
  isolates days. Adequate for this ledger.
- **Randomness quality**: `allocate-id` draws 256 bytes from /dev/urandom
  per attempt and loops until 4 chars accumulate (fixes the old <4-char
  SIGPIPE truncation the script comments document). `date +%N` + PID is
  mixed in only as supplementary material, not the sole source. Sound.
- **Sortability preserved**: YYMMDD prefixes sort lexicographically in
  chronological order, so the README index keeps a total order without a
  sequence counter.
- **Grandfather policy** (sequential DIA-001..DIA-231 untouched) is
  implemented as dual-mode ordering in three places: `find_insert_position`
  (sequential block first, numeric within; datetime block second, lexical
  within), `rollup_sort_check` (same rule, warn on violation),
  `cmd_frontier` (`999999` prefix forces datetime after sequential).
  Consistent triple implementation, no divergence found.
- **Gate compatibility**: `lib/ticket-gate.ts` lines 103-105 accept both
  formats (`/^DIA-(\d{6}-[a-z0-9]+|\d+)$/` + FIND + FILENAME variants),
  and `scanTickets` uppercases both sides, so lowercase filename suffixes
  match uppercased dispatch text. Case handling is symmetric. Good.

## 3. Implementation state audit

| Ticket scope item | State | Evidence |
|---|---|---|
| `scripts/tickets` ID generation (max+1 -> datetime+random) | DONE | `next_dia()` delegates to `scripts/allocate-id`; `num_of_file`, `cmd_frontier`, `blockers_of`, `find_ticket_file` all datetime-aware |
| `blocked-by` / `parent-epic` accept datetime | DONE | `cmd_new` validation branches for both formats |
| Gate parsing/validation for datetime | DONE | `TICKET_ID_RE` / `_FIND` / `_FILENAME` datetime-first alternation |
| AGENTS.md mention format (`DIA-NNN 'slug'` / `DIA-YYMMDD-XXXX 'slug'`) | DONE (prose) | AGENTS.md lines 36, 47 enforce ID+slug, bare IDs called out as opaque |
| Bats coverage for datetime | DONE | `tickets.bats` has datetime-format, README-landing, blocked-by, parent-epic, frontier-sort, rollup tests |
| `allocate-id` unified generator | DONE | Exists, called by `next_dia()`; 3x burst probe returned distinct IDs (`pf9q`, `2d93`, `rpny`) |
| Live ledger adoption | DONE | Datetime tickets (e.g. DIA-260819-8kwm and many DIA-26082x) present in real ledger |
| Ticket close-out (Fix + Re-verify + status) | NOT DONE | DIA-234 still OPEN, Fix/Re-verify sections are placeholders |

## 4. Residual findings (MECE)

| ID | Finding | Severity | Location |
|---|---|---|---|
| R1 | Stale comment describes the OLD max+1 race as current behavior ("Two parallel `tickets new` calls can both compute the same max+1... `next_dia()` re-scans... picks a higher number") while `next_dia()` now returns a random candidate. Misleads the next reader about the mechanism. | Low | `scripts/tickets` lines 852-859 |
| R2 | `rollup_sort_check` uses `[[ "$n" < "$prev" ]]` but the script header (lines 63-66) claims bash-3 compatibility with "no [[ ]]". Works on bash4+ (and the bats suite already requires bash4), but breaches the stated contract; `find_insert_position` shows the POSIX form (`[ "$n" \> "$newnum" ]`) already in use. | Low | `scripts/tickets` line 717 |
| R3 | Gate regexes accept `[a-z0-9]+` (any length) rather than exactly-4 suffix, so malformed IDs (e.g. DIA-260921-x) pass the gate while `allocate-id` always emits 4. Lenient-accept; harmless for genuine tickets but weakens format validation. | Low | `lib/ticket-gate.ts` lines 103-105 |
| R4 | Human-readable mention rule (ID + slug, no bare IDs) is prose-only in AGENTS.md with no mechanical check. Bare IDs still pass the gate. Either accept as convention or add a lint (e.g. warn in `rollup --check` or reviewer checklist). | Info | AGENTS.md lines 36, 47 |

No Critical or Major residuals. No collision path found in the new design
beyond the birthday bound quantified in section 2 (negligible at observed
throughput), and the 5-attempt file/README collision guard in `cmd_new`
remains as a second net.

## 5. Inversion: what could still go wrong

- **Same-millisecond burst on a starved entropy pool** (`/dev/urandom`
  depleted in a container): the loop still terminates (PID/nanosecond
  mixing guarantees 4 chars), but two processes could theoretically draw
  correlated material. Mitigated by the `cmd_new` existence check + retry.
  Acceptable.
- **Clock skew** (system date wrong): two tickets share a date prefix;
  uniqueness still rests on the 4-char suffix. Degrades gracefully.
- **README merge conflict** under parallel writers (both rewrite the index
  table): datetime IDs remove the *allocation* race but README remains a
  shared mutable file. Concurrent `cp tmp README` can lose a row. This is
  the one genuine leftover shared-state race, outside DIA-234's stated
  scope; worth a follow-up ticket (atomic append or retry-on-dirty) if
  batch-D creation becomes frequent.
- **Case-fold collision**: gate uppercases; filesystem is case-sensitive.
  `DIA-260921-AB12` vs `DIA-260921-ab12` would be distinct files but the
  same gate ID. Generators only emit lowercase, so only hand-crafted files
  could trigger this. Negligible.

## 6. Recommendations

1. **Close out DIA-234**: fill the Fix section (point at `allocate-id` +
   `next_dia` delegation + gate regexes + bats tests), run the ticket's own
   4-step verification (`tickets new` format check, rapid-double-create,
   `make test-config`, README parse of sequential tickets), then move to
   CLOSED.
2. **R1**: rewrite the `cmd_new` retry-loop comment to describe random-ID
   collision retry (not max+1 rescan). One-paragraph edit.
3. **R2**: replace `[[ ]]` with the POSIX `[ ... \> ... ]` form per the
   script's own header contract, or downgrade the header claim to bash4+.
   Either way, remove the contradiction.
4. **R3**: tighten gate suffix to `[a-z0-9]{4}` if strictness is wanted, or
   record lenient-accept as intentional (forward-compat for future suffix
   lengths). Decision, not necessarily a code change.
5. **R4**: keep the mention rule as convention (documented, low cost) unless
   bare-ID opacity recurs, then promote to a lint.
6. **Follow-up candidate**: README concurrent-rewrite race (section 5,
   third bullet) as a separate Low-severity ticket if parallel creation
   volume grows.

## 7. Ticket verification mapping

| Ticket criterion | Result here |
|---|---|
| `tickets new` produces DIA-YYMMDD-XXXX | PASS by code inspection (`next_dia` -> `allocate-id`); bats test exists; live ledger shows datetime files |
| Two rapid creates produce distinct IDs | PASS by design (random suffix) + 3x burst probe distinct + bats rapid-call test; full gate run left for close-out (`make test-config`) |
| `make test-config` passes | Not run in this lane (read-only analysis); bats file contains datetime assertions for the gate to execute |
| Sequential tickets still parse | PASS by inspection (numeric branch retained in all four parsers; grandfather sort tested) |

## Sources

- `docs/dev-infra-audit/tickets/DIA-234-datetime-based-ticket-ids-and-human-readable-mentions.md` (ticket body)
- `scripts/tickets` (allocation, sort, frontier, rollup)
- `scripts/allocate-id` (unified generator)
- `.opencode/plugins/lib/ticket-gate.ts` (gate regexes + scan/match)
- `scripts/__tests__/tickets.bats` (datetime coverage)
- `AGENTS.md` lines 28, 36, 47 (mention format)
