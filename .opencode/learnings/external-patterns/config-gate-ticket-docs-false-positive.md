# Config-work routing gate false positive on ticket-ledger docs evidence paths (2026-11-04)

- **Date:** 2026-11-04
- **Ticket:** DIA-261104-rhez
- **Status:** applied
- **Outcome:** applied

## Finding

The config-work routing gate (DIA-063 / DIA-261021-cs3v family) hard-blocked a
coder dispatch whose brief cited `.opencode/` evidence paths, although the
mutation surface was 25+24 files under `docs/dev-infra-audit/tickets/` (docs,
outside AGENTS.md section 2.5 scope). The gate matched path strings in the
brief text, not the files the lane would actually write, and routed a
dev-infra docs cleanup toward the ai-auditor config-review path.

## Rule

- Gate on the write surface (the files to be mutated), not on path strings in
  brief text. A brief that merely reads `.opencode/` files as evidence is not
  an OpenCode config change.
- Ticket-ledger edits (`docs/dev-infra-audit/tickets/*`) route to coder +
  reviewer (dev-infra), never to ai-auditor config review.

## Action

- Re-dispatch the lane with evidence paths stripped from the brief, or clearly
  labelled read-only evidence (e.g. "read-only evidence: .opencode/...").
- Do not use a capability-token bypass for real ticket-gated engineering work;
  the token path exists for ticket-creation/bootstrap/ai-infra-application
  bookkeeping, not to slip docs work past the routing gate.

## Related observation: scripts/tickets update rewrites README.md on every call

`scripts/tickets update` rewrites `README.md` on every call
(`scripts/tickets:1937` patches the status column, `scripts/tickets:1942-1943`
run `rewrite_readme` and copy it over the README). Therefore:

- Parallel lanes must edit ticket frontmatter directly; never run
  `scripts/tickets update` concurrently from two lanes.
- Any `scripts/tickets rollup` run must happen once, serialized, after all
  frontmatter edits land, or it clobbers in-flight README deltas.
