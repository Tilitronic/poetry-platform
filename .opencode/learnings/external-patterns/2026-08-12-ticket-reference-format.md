# Ticket reference format - quote ID + human-readable slug

- Date: 2026-08-12
- Topic: ticket-reference-format
- Source: ai--1 / ai-specialist Phase 1 research

## Gap analysis

DIA-110 (closed 2026-08-12) renamed ALL ticket files to slugged format
(DIA-NNN-<descriptor>.md) and declared "reference discipline in effect", but
never codified the rule into the operating manuals. The orchestrator referenced
bare ticket IDs (e.g., "DIA-100") at the S16 batch gate and in session
summaries, leaving the developer unable to identify issues without opening
files. ai-specialist research (ai--1) confirmed the placement for codification.

## Approved placement

- `docs/dev-infra-audit/NEXT-RUN.md` section 7.3, new step 3a (batch-approval
  gate protocol, immediately after the subsection-presentation step 3).
- `AGENTS.md` section 2.3, step 2, new sub-bullet under the "Dispatch @coder"
  bullet (to-tickets option).

## Rule wording

NEXT-RUN.md section 7.3 step 3a:

3a. TICKET-REFERENCE FORMAT: when presenting open_tickets or any subsection that
    references DIA tickets, ALWAYS quote the ticket ID + human-readable slug from
    the filename (e.g., "DIA-100 'git worktrees for parallel dev sessions'", not
    "DIA-100" alone). The slug is derivable from the ticket filename
    (DIA-NNN-<descriptor>.md) or the README index. This applies to all
    user-facing references: batch approvals, handoff prognoses, session summaries,
    and log_decision content_ref fields.

AGENTS.md section 2.3 step 2 sub-bullet:

- **Ticket reference format:** when referencing DIA tickets in any user-facing
  output (session summaries, handoff prognoses, batch approvals), ALWAYS quote
  ID + human-readable slug from the filename (e.g., "DIA-100 'git worktrees for
  parallel dev sessions'"), not bare ID alone. Derive the slug from
  DIA-NNN-<descriptor>.md filenames or the README index.

## Outcome

pending (to be updated after validation).
