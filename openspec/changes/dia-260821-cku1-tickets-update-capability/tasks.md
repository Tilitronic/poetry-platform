## 1. Status update (core mutation + rollup)

- [ ] 1.1 Implement `cmd_update()` function skeleton with CLI flag parsing for
      `--status <STATUS>`. Validate that the status value is in the canonical
      `STATUSES` list (OPEN, DONE, VALIDATE, E2E, DEFERRED, MONITOR, FIXED,
      IMPLEMENTED, VERIFIED, CLOSED, BLOCKED, DISPATCHED, RUNNING, COMPLETE).
      Exit 1 with "invalid status" on bad input. Exit 2 if no flags are provided.
      **Acceptance:** `tickets update DIA-130 --status FIXED` succeeds; `tickets
update DIA-130 --status BOGUS` fails with exit 1 and error message; `tickets
update DIA-130` (no flags) fails with exit 2 and usage hint.

- [ ] 1.2 Implement atomic copy-rename mutation for `--status`: copy the
      ticket file to a temp file in the same directory (`mktemp -p
"$TICKETS_DIR"`), rewrite the `^status:` line via `sed`, bump the
      `updated:` field to `$(date +%F)`, validate the temp file (frontmatter
      still parses, ASCII-clean), then `mv` the temp file over the original. On
      validation failure, delete the temp file and leave the original untouched
      (exit 1). On `mv` failure, leave the temp file with a `.partial` suffix
      and error message (exit 1). **Acceptance:** after `tickets update DIA-130
--status FIXED`, the ticket file's `status:` line shows FIXED, `updated:`
      shows today's date, and all other fields are unchanged. Simulated `mv`
      failure (read-only dir) leaves a `.partial` temp file.

- [ ] 1.3 Integrate README rollup after successful status update: reuse
      existing `compute_ledger_counts` + `rewrite_readme` machinery to update
      the README index row's Status column and the severity/status count tables.
      If rollup fails, emit a warning to stderr and exit 2 (partial success -
      ticket updated, README stale, `tickets rollup` can repair). **Acceptance:**
      after `tickets update DIA-130 --status FIXED`, the README index row for
      DIA-130 shows Status=FIXED (not OPEN), and the count tables reflect the
      change (OPEN count -1, FIXED count +1).

- [ ] 1.4 Write bats test cases for status update: extend
      `scripts/__tests__/tickets.bats` with test cases covering (a) happy path
      (`--status FIXED` rewrites status line, bumps updated, leaves everything
      else untouched), (b) validation failure (`--status BOGUS` exits 1, file
      unchanged), (c) no flags (exits 2, usage hint), (d) rollup integration
      (README index row and count tables updated), (e) atomicity (validation
      failure leaves no temp file, simulated `mv` failure leaves `.partial`
      file). **Acceptance:** all new bats tests pass; existing tests still pass.
      **Blocks:** 2.1, 3.1, 4.1, 5.1.

## 2. Evidence append (YAML array manipulation)

- [ ] 2.1 Implement `--evidence <uri>` flag: parse repeatable `--evidence`
      flags, validate each URI is ASCII (DIA-079), exit 1 with "non-ASCII" on
      bad input. Append each URI as a new YAML list item (`- <uri>`) to the
      `evidence:` frontmatter array, deduplicated against existing entries (same
      URI twice = no-op for that entry). If the `evidence:` field is missing
      (legacy v1 ticket), append it after the `updated:` line (before the first
      `---` separator). Integrate with the atomic copy-rename model from 1.2.
      **Acceptance:** `tickets update DIA-130 --evidence "commit:abc123"` appends
      one item to the `evidence:` array; `--evidence` twice with the same URI
      produces no duplicate; `--evidence` twice with different URIs appends both;
      `--evidence "non-ascii:cafe\xcc\x81"` exits 1 with "non-ASCII" error.
      **Blocks:** 4.1, 5.1.

- [ ] 2.2 Write bats test cases for evidence append: extend
      `scripts/__tests__/tickets.bats` with test cases covering (a) single
      evidence append, (b) duplicate dedup, (c) multiple distinct URIs, (d)
      non-ASCII validation failure, (e) legacy ticket (no `evidence:` field) -
      field is appended correctly. **Acceptance:** all new bats tests pass;
      existing tests still pass.

## 3. Body replacement (Fix/Re-verify sections)

- [ ] 3.1 Implement `--fix-file <path>` and `--reverify-file <path>` flags:
      validate that each file exists and is readable (exit 1 with "file not
      readable" on bad input). Read the file contents, sanitize non-ASCII bytes
      (replace with `?`, warning to stderr: "warn: non-ASCII bytes sanitized in
      Fix/Re-verify section"). Replace the `## Fix` or `## Re-verify` section
      contents (everything between the heading and the next `## ` heading) with
      the sanitized file contents. If the section heading is missing (legacy
      ticket), append the section at the end of the file. Integrate with the
      atomic copy-rename model from 1.2. **Acceptance:** `tickets update DIA-130
--fix-file fix.md` replaces the `## Fix` section with the contents of
      fix.md; `--reverify-file reverify.md` same for `## Re-verify`; non-ASCII
      in the file is sanitized; missing section heading is appended; unreadable
      file exits 1.

- [ ] 3.2 Write bats test cases for body replacement: extend
      `scripts/__tests__/tickets.bats` with test cases covering (a) Fix section
      replacement, (b) Re-verify section replacement, (c) non-ASCII sanitization
      (warning emitted, bytes replaced), (d) missing section heading (appended
      at end), (e) empty file (section heading remains, placeholder removed),
      (f) unreadable file (exits 1). **Acceptance:** all new bats tests pass;
      existing tests still pass. **Blocks:** 4.1, 5.1.

## 4. Combined mutations (integration)

- [ ] 4.1 Implement combined mutation support: allow all flags (`--status`,
      `--evidence`, `--fix-file`, `--reverify-file`) in a single invocation.
      Apply all mutations to the temp file in sequence (status, updated,
      evidence appends, Fix/Re-verify replacements), then validate and `mv` as
      in 1.2. Trigger rollup as in 1.3. **Acceptance:** `tickets update DIA-130
--status FIXED --fix-file fix.md --reverify-file reverify.md --evidence
uri1 --evidence uri2` applies all four mutations in one call; the ticket
      file shows status=FIXED, updated=today, evidence=[uri1, uri2], Fix and
      Re-verify sections replaced; README index row and count tables updated.

- [ ] 4.2 Write bats test cases for combined mutations: extend
      `scripts/__tests__/tickets.bats` with test cases covering (a) all flags
      together (status + evidence + fix + reverify), (b) partial combinations
      (status + evidence, fix + reverify, etc.), (c) validation failure in one
      flag (e.g., bad status) leaves the file unchanged even if other flags are
      valid. **Acceptance:** all new bats tests pass; existing tests still pass.

## 5. Edge cases (legacy, archive, missing sections)

- [ ] 5.1 Handle edge cases: (a) archived tickets - search both
      `$TICKETS_DIR` and `$TICKETS_DIR/archive` (same as `find_ticket_by_id`);
      updating an archived ticket is allowed; rollup is a no-op for archived
      tickets (not in README index). (b) legacy tickets (DIA-001..049, v1
      schema, no session attribution block) - update `status:`, `updated:`,
      `evidence:`, Fix, Re-verify; do not add the session attribution block if
      missing. (c) missing Fix/Re-verify sections - append at end of file
      (already handled in 3.1). (d) empty Fix/Re-verify file - section heading
      remains, placeholder removed. **Acceptance:** archived ticket can be
      updated; legacy ticket can be updated without adding session attribution;
      missing section is appended; empty file produces empty section body.

- [ ] 5.2 Write bats test cases for edge cases: extend
      `scripts/__tests__/tickets.bats` with test cases covering (a) archived
      ticket update (ticket in `archive/` subdir, README not updated), (b)
      legacy ticket update (no session attribution block, `evidence:` field
      appended correctly), (c) missing Fix/Re-verify section (appended at end),
      (d) empty Fix/Re-verify file (section heading remains, body empty).
      **Acceptance:** all new bats tests pass; existing tests still pass.

## 6. Help text and integration

- [ ] 6.1 Extend `print_usage()` and `help_and_exit()` to document the
      `update` subcommand: add a `update` entry in the commands list, document
      the flags (`--status`, `--evidence`, `--fix-file`, `--reverify-file`),
      list the canonical statuses (same as `new --severity` lists severities).
      Add `update` to the `main()` dispatch table. **Acceptance:** `tickets
help` shows the `update` entry; `tickets update --help` shows usage;
      `tickets update DIA-130 --status FIXED` works end-to-end.

- [ ] 6.2 Run full test suite and validation: `make test-shell` (bats suite)
      exits 0; `make test-config` exits 0 (no config changes, but verify no
      drift); manual smoke test: create a test ticket with `tickets new`, update
      it with `tickets update`, verify the file and README are correct.
      **Acceptance:** all tests pass; manual smoke test succeeds.
