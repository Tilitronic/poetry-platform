## Context

Current state (see proposal.md Why):

- scripts/tickets new already generates datetime IDs (DIA-YYMMDD-XXXX) - the DIA-234 ID-generator part is DONE. The slug is derived from the title and lives in the filename DIA-<id>-<slug>.md.
- scripts/validate-dia-mentions.sh exists and is wired into make test-config (Makefile:207). It scans ONLY AGENTS.md, is warn-only (always exit 0), and uses the regex DIA-[0-9]+(-[a-z0-9]{4})? which already matches both sequential and datetime IDs.
- The delegation-observer DIA-217 gate (delegation-observer.ts:2845+) resolves a ticket_id from dispatch text but does NOT check for a slug.

No .sdd/ module document governs this plugin-internal gate (same as the chicken-egg change). Prior art: dia-260820-jlu0-chicken-egg-ticket-gate (gate extension + bats), dia-260821-cku1-tickets-update-capability (mint_capability tooling), and the DIA-234 ticket.

Constraints:

- ASCII-only (DIA-079) - the mention format uses straight single quotes; no non-ASCII.
- Fail-soft discipline for the gate: a broken validator must not hang make test-config; the script must fail loud but fast.
- Grandfathering: existing tickets must not break the build (Makefile:187 intent).

## Goals / Non-Goals

**Goals:**

- Enforce the human-readable mention at ticket creation (scripts/tickets new).
- Enforce it as a HARD make test-config gate over ticket bodies, with grandfathering for pre-existing tickets.
- Keep AGENTS.md scanning behavior unchanged (warn-only) in this change.

**Non-Goals:**

- Rewriting/fixing existing ticket bodies to add slugs (grandfathered; done opportunistically).
- Making AGENTS.md scanning hard-fail (separate follow-up; it has many bare refs).
- Verifying that a referenced slug TEXTUALLY matches the referenced ticket's canonical filename slug (v1 is presence-only; see Decision 4).
- Changing the DIA-217 gate's ID resolution order or the "campaign ticket DIA-NNN" marker convention.

## Decisions

### Decision 1: Extend validate-dia-mentions.sh to scan ticket bodies with hard-fail

**Choice:** Add a second scan pass over docs/dev-infra-audit/tickets/\*.md (excluding README.md, \_TEMPLATE.md, COORDINATION.md). For each ticket body, skip frontmatter (between the first --- and the closing ---), fenced code blocks (``` / ~~~), and H1 headings matching ^# DIA- (the ticket's own heading uses the title, not a quoted slug). For every remaining prose line, find DIA-[0-9]+(-[a-z0-9]{4})? references; if a reference is NOT immediately followed (after trimming whitespace) by a ' or " quote, it is a bare reference. Tickets whose created: frontmatter date is >= ENFORCEMENT_DATE cause a HARD FAIL (exit 1); tickets with created: < ENFORCEMENT_DATE are warn-only (counted, no exit 1). AGENTS.md scanning stays warn-only as today.

**Rationale:** reuses the existing script and its regex; the only new machinery is the frontmatter/code-fence/H1 skip state and the date-cutoff branch. Scanning ticket bodies (not just AGENTS.md) is what the developer asked for ("make test-config must check that ticket bodies ... contain the slug, failing the build if a bare ID without slug is found").

**Alternatives considered:**

- Scan only AGENTS.md and keep warn-only (status quo): rejected - does not enforce ticket bodies, which is the explicit ask.
- Make AGENTS.md hard-fail too: rejected for this change - AGENTS.md has many bare refs and fixing them is a separate, larger cleanup; scope creep.

### Decision 2: Grandfathering via created: date cutoff

**Choice:** Define ENFORCEMENT_DATE as a constant in the script (the date this change ships, 2026-08-27). A ticket body is "in scope for hard-fail" iff its frontmatter created: >= ENFORCEMENT_DATE. All others are warn-only.

**Rationale:** date cutoff is self-pruning (no manual allowlist to maintain) and matches the Makefile:187 "warn-not-fail on grandfathered bare references" intent. New tickets created after the cutoff are never grandfathered, so the gate tightens automatically over time as legacy tickets are cleaned or closed.

**Alternatives considered:**

- Static allowlist file of exempt ticket IDs: rejected - requires seeding with the current violating set and ongoing maintenance; date cutoff is simpler.
- No grandfathering (hard-fail everything): rejected - breaks the existing ledger (Option D in proposal).

**Known limitation:** a pre-cutoff ticket later EDITED to add a bare reference is still warn-only (its created: predates the cutoff). Acceptable for a scoped change; the scripts/tickets new guard (Decision 3) catches new tickets, and the warn still surfaces the issue.

### Decision 3: scripts/tickets new writes a self-mention and validates its output

**Choice:** In cmd_new(), after the frontmatter, write a canonical self-reference line into the generated Description section of the form:

Self-reference: DIA-<num> '<slug>'

where <slug> is the same kebab-case slug already used in the filename. Then, before printing success, run the mention validator against the just-written file; if it reports a bare DIA reference (it won't for the template, but this guards future body content / a future --body flag), fail creation with exit 1 and a clear message telling the user to qualify references as DIA-<id> '<slug>'.

**Rationale:** this satisfies "a human-readable slug/mention is present in the body" for every newly created ticket by construction, and shifts the enforcement left to creation time (Option A). The self-mention also gives the test-config scanner a compliant anchor.

**Alternatives considered:**

- Require a --body argument and validate only that: rejected - scripts/tickets new currently takes only a title; adding a body arg expands scope and the template body is the natural place for the self-mention.
- Only validate, do not write a self-mention: rejected - then a brand-new ticket body would have NO slug mention at all, failing the "present in the body" requirement; the self-mention guarantees compliance.

### Decision 4: Mention format and v1 check semantics

**Choice:** The canonical mention is DIA-<id> '<slug>' (straight single quotes; double quotes also accepted by the scanner). <id> is either DIA-NNN (sequential, grandfathered) or DIA-YYMMDD-XXXX (datetime). <slug> is the human-readable descriptor from the filename DIA-<id>-<slug>.md. The v1 scanner checks PRESENCE of a following quote (any slug text), not that the slug textually matches the referenced ticket's canonical filename slug.

**Rationale:** presence-check is the minimal correct enforcement and avoids the complexity of resolving each referenced ID to its file (filename collisions, archive paths). It directly implements AGENTS.md 2.3 ("ALWAYS quote ID + human-readable slug"). Slug-text-matching is a stricter future enhancement (see Open Questions).

**Alternatives considered:**

- Require exact slug match to the referenced ticket's filename: rejected for v1 - needs ID-to-file resolution and is YAGNI for the enforcement goal; presence is enough to make references human-readable.

### Decision 5 (OPTIONAL / deferred): delegation-observer DIA-217 gate slug check

**Choice:** NOT implemented by default. If taken later, the gate would, when it materializes a ticket_id from dispatch text, also require a following slug and hard-block dispatches that cite a bare DIA-<id> without a slug.

**Rationale:** the developer said "and ideally" - it is secondary. It conflicts with the existing AGENTS.md 2.3.1 requirement to label governing IDs as "campaign ticket DIA-NNN" (a marked reference, not a quoted slug). Enforcing slug in the gate would over-block legitimate dispatches that use the marker convention. Defer until the two conventions are reconciled.

**Alternatives considered:**

- Implement now: rejected - convention conflict; would break existing dispatch patterns.

## Seams

**Test seam:**

- scripts/validate-dia-mentions.sh: add a fixtures-based self-test (or extend the repo's bats suite under scripts/**tests**/) that creates temp ticket bodies with controlled created: dates and asserts exit codes (1 for post-cutoff bare ref, 0 for pre-cutoff, 0 for all-slug). The scanner is a pure-ish bash function over a file, so a unit-style invocation per fixture is the right seam.
- scripts/tickets new: a bats test invoking tickets new with TICKETS_DIR pointing at a temp ledger, asserting the written file contains the self-mention line and that a simulated bare-ref body (or a future --body flag) causes exit 1.

**Public boundary:** the mention format DIA-<id> '<slug>' is the observable contract. It must be documented in AGENTS.md 2.3 / 2.5 (Task 4). The validator's exit-code contract (0 clean/warn, 1 hard violation) is also public and consumed by make test-config.

**Code seam:** both changes live in existing files (scripts/validate-dia-mentions.sh, scripts/tickets) with no new exported symbols; the delegation-observer gate is touched ONLY if Decision 5 is later adopted.

## Risks / Trade-offs

**Risk:** scanning all ticket bodies on every make test-config adds a small fixed cost.
-> **Mitigation:** hundreds of small files, sub-second; acceptable. If it grows, scope the scan to tickets with created: >= cutoff.

**Risk:** a legitimate pre-cutoff ticket edited after the cutoff still warns only, so a violation could slip through until the ticket is cleaned.
-> **Mitigation:** acceptable; the scripts/tickets new guard covers new tickets and the warn surfaces it.

**Risk:** the self-mention line in new tickets is seen as noise.
-> **Mitigation:** it is a single line in the Description; it also serves as the canonical example of the format and aids grep-ability.

**Trade-off:** v1 checks slug presence, not correctness. A wrong-but-quoted slug passes.
-> **Acceptable:** the goal is human-readability, not a strict ID/slug binding; stricter matching is a future option.

## Migration Plan

**Deployment:** edit scripts/validate-dia-mentions.sh (add ticket-body pass + date cutoff + hard-fail) and scripts/tickets (self-mention + post-write validation). make test-config already invokes validate-dia-mentions.sh (Makefile:207), so no Makefile change is needed for the gate. AGENTS.md doc edit is a separate non-code task.

**Rollback:** git revert the two script edits. The validator returns to warn-only; scripts/tickets new stops writing the self-mention. No data/state lost (ticket files already written keep their content).

## Open Questions (practice-protected - developer to confirm)

1. Enforcement date: confirm 2026-08-27 (ship date) as ENFORCEMENT_DATE, or a later date to give a grace window?
2. Self-mention placement: Description section line "Self-reference: DIA-<num> '<slug>'" - acceptable wording/location, or prefer a different anchor?
3. Should AGENTS.md scanning also become hard-fail in this change, or stay warn-only (recommended: stay warn-only; separate cleanup)?
4. Is the optional delegation-observer gate slug check (Decision 5) wanted now, or deferred?
5. v1 slug presence-only (recommended) vs stricter slug-text-match to referenced filename - confirm presence-only.
