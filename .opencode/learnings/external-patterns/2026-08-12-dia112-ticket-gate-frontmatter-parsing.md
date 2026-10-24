# DIA-112 ticket gate frontmatter parsing - fail-closed design

- Date: 2026-08-12
- Ticket: DIA-112
- Source: ai-specialist Phase 1 research

## Pattern

The section-10 ticket gate (delegation-observer.ts) scans ticket files, parses
frontmatter status by finding the first `---` and stopping at the second `---`.
A ticket whose title/comment block sits INSIDE the first `---` block (between
delimiters) yields empty status -> excluded from OPEN -> every dispatch
referencing it is gate-blocked, even with a "Ticket: DIA-NNN" prefix and README
index row.

## Rule

v2 template structure RULE: title + HTML comment MUST be placed BEFORE the
first `---` delimiter; YAML fields AFTER it.
(Correct: `# DIA-NNN title`, blank, comment, `---`, id/status/etc, `---`.
Wrong: `---`, title, comment, `---`, fields.)

## Design constraint

The parser is fail-closed by design: malformed = NOT-OPEN. This is the SAFE
direction (a broken CLOSED ticket must never be treated as OPEN). Do NOT make
the parser lenient to "fix" this - fix the ticket structure instead.

## Reusable lesson

For ticket-creation lanes: always verify a new ticket file has comment BEFORE
the first `---` (mirror DIA-110/DIA-112/_TEMPLATE.md), and after creation run
the PyYAML frontmatter parse check that returns id/status - if status is
missing, the structure is wrong.

## Outcome

DIA-112 closed document-only; DIA-111 file remains malformed so future DIA-111
references are gate-blocked until corrected; res014 deferred.
