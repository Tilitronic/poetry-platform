## 1. Ticket-body scanner + hard-fail (validate-dia-mentions.sh)

- [ ] 1.1 Extend scripts/validate-dia-mentions.sh with a ticket-body scan pass over docs/dev-infra-audit/tickets/\*.md (exclude README.md, \_TEMPLATE.md, COORDINATION.md). Skip frontmatter (between first --- and closing ---), fenced code blocks (``` / ~~~), and H1 lines matching ^# DIA-. For each prose line, detect DIA-[0-9]+(-[a-z0-9]{4})? references and flag any NOT followed (after trimming whitespace) by a ' or " quote as a bare reference. **Acceptance:** a fixture ticket body containing "see DIA-100 for details" (no slug) is reported as a bare reference; "see DIA-100 'git worktrees'" is NOT. **Blocks:** 3.1.

- [ ] 1.2 Add ENFORCEMENT_DATE constant (default 2026-08-27) and date-cutoff branch: tickets with frontmatter created: >= ENFORCEMENT_DATE cause the script to exit 1 on any bare reference; tickets with created: < ENFORCEMENT_DATE are warn-only (counted, exit 0). **Acceptance:** a post-cutoff fixture with a bare ref makes the script exit 1; an otherwise-identical pre-cutoff fixture exits 0 with a warning count. **Blocks:** 3.1.

- [ ] 1.3 Keep AGENTS.md scanning warn-only (unchanged behavior); ensure the script still exits 0 for AGENTS.md-only findings. **Acceptance:** existing AGENTS.md bare refs do not change the exit code (still 0). **Blocks:** 3.1.

## 2. Creation-time guard (scripts/tickets new)

- [ ] 2.1 In cmd_new(), write a canonical self-mention line into the generated Description section: "Self-reference: DIA-<num> '<slug>'" using the same slug already in the filename. **Acceptance:** a ticket created via scripts/tickets new contains the line "Self-reference: DIA-<num> '<slug>'" with the correct num and slug. **Blocks:** 3.1.

- [ ] 2.2 After writing the file, run the mention validator against the new file; if it reports a bare DIA reference, fail creation with exit 1 and a message instructing the user to qualify references as DIA-<id> '<slug>'. **Acceptance:** with the template body the command succeeds (self-mention satisfies the check); a fixture/simulation where the body contains a bare ref causes exit 1. **Blocks:** 3.1.

## 3. Tests + validation gate

- [ ] 3.1 Add bats tests: (a) validate-dia-mentions.sh exits 1 on a post-cutoff ticket body with a bare ref, exits 0 (warn) on a pre-cutoff one, exits 0 when all refs carry slugs; (b) scripts/tickets new writes the self-mention and exits 1 when the generated body has a bare ref (simulated). **Acceptance:** all new bats tests pass; existing validator/gate tests still pass. **Blocks:** 4.1.

- [ ] 3.2 Run make test-config and openspec validate for this change. **Acceptance:** make test-config exits 0 on the current (grandfathered) ledger and would exit 1 if a post-cutoff violating ticket were present; openspec validate dia-234-ticket-human-readable-mention-enforcement exits 0.

## 4. Documentation follow-up (mention-format contract)

- [ ] 4.1 Update AGENTS.md section 2.3 / 2.5 to document the human-readable mention enforcement: the format DIA-<id> '<slug>', the scripts/tickets new self-mention requirement, and the make test-config hard gate over ticket bodies (grandfathering for pre-cutoff tickets). **Acceptance:** AGENTS.md states the enforcement; make test-config doc-drift checks still pass. (Non-code doc edit; decision made in interview, not invented here.)

## 5. (OPTIONAL / deferred) delegation-observer gate slug check

- [ ] 5.1 Only if the developer confirms (Open Question 4): extend the DIA-217 gate (delegation-observer.ts:2845+) to require a following slug when materializing a ticket_id, hard-blocking dispatches that cite a bare DIA-<id> without a slug. **Acceptance:** a dispatch citing "campaign ticket DIA-174" without a slug is blocked; one citing "DIA-174 'slug'" passes. Note: conflicts with the "campaign ticket DIA-NNN" marker convention - reconcile before implementing.

---

Process note: implementation follows AGENTS.md 2.5 (config-change chain): gate via @ai-specialist (read-only research) -> user reviews -> design via @architector if non-trivial -> implement via @coder -> validate (make test-config) -> independent review via @ai-auditor. This spec is the planning artifact only; no implementation code is written here (practice-protected).
