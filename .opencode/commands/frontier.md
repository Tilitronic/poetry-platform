---
description: >-
  Run scripts/tickets frontier and summarize actionable tickets as
  ID + slug + severity. Conversational entry point for "what can I work on?".
# DIA-260831-h3i4 F2: no agent binding - runs in the invoking agent
# (orchestrator); read-only ticket query, no ticket-gate bypass.
---

# Frontier

Run `scripts/tickets frontier` and summarize the actionable tickets.

- One line per frontier ticket: `DIA-NNN 'slug' - <severity>` (ID + slug from
  the filename, never a bare ID).
- Keep the blocker-graph summary to one line.
- Surface live-lease notes (ticket already claimed by another session).
- Never read docs/dev-infra-audit/tickets/ directly - the script output is
  the source of truth (AGENTS.md section 6, DIA-260820-y268).
