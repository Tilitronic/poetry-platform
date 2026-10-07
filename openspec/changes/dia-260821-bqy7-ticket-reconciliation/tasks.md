## 1. Ticket Inventory

- [ ] 1.1 Query all tickets with `created: 2026-08-*` in frontmatter using `scripts/tickets list` and manual grep for sequential DIA-NNN tickets. Compile a list of ticket IDs, titles (slugs from filenames), and current status.
- [ ] 1.2 For each ticket, extract frontmatter fields: status, Fix section (placeholder vs populated), Re-verify section (placeholder vs populated), gate_state, gate_triggers.

## 2. Git Log Evidence

- [ ] 2.1 For each ticket, search git log for commits referencing the ticket ID (e.g., `git log --all --grep="DIA-260821-bqy7"`). Record commit SHAs, dates, and messages.
- [ ] 2.2 Classify git evidence: (a) commit with populated Fix/Re-verify in ticket = strong evidence, (b) commit without Fix/Re-verify = partial evidence, (c) no commits = no git evidence.

## 3. OpenSpec Change State

- [ ] 3.1 For each ticket, check if a corresponding OpenSpec change exists in `openspec/changes/` (match by ticket ID in change name or proposal.md content).
- [ ] 3.2 For each OpenSpec change found, check: (a) is it archived (in `openspec/changes/archive/`)? (b) does tasks.md exist and are all checkboxes checked? (c) does tasks.md map to the ticket's Verification section?
- [ ] 3.3 Classify OpenSpec evidence: (a) archived change with all tasks checked = strong evidence, (b) active change with partial tasks = partial evidence, (c) no change = no OpenSpec evidence.

## 4. ana026 P0/P1 Verification

- [ ] 4.1 Extract ana026 P0 and P1 findings from `knowledge/ana026-opencode-setup-audit/ana026-opencode-setup-audit-report.md` (lines 98-109).
- [ ] 4.2 For each P0/P1 finding, verify against current code/config:
  - P0 "runtime duplicates observer plugins": run `opencode debug config` (if available) or check `.opencode/opencode.jsonc` plugin array for duplicate paths.
  - P0 "container socket security": check `tools/opencode-docker/bin/opencode-docker` for socket mount options and whether `--with-engine` flag exists.
  - P1 "make test-config not hermetic": run `make test-config` and check if it passes in a clean environment.
  - P1 "make test-shell contradicts docs": run `make test-shell` and check if it fails on missing LSP.
  - P1 "two images with different contracts": compare `Dockerfile.dev` and `tools/opencode-docker/Dockerfile` for OpenCode version and plugin sets.
- [ ] 4.3 For each finding, classify: (a) still exists = active risk, (b) no longer exists = resolved, (c) partially addressed = partial.

## 5. Test Execution

- [ ] 5.1 For each ticket with a CLOSE recommendation candidate, identify relevant tests (e.g., `make test-config`, `make test-shell`, `make test-infra`, or specific test files).
- [ ] 5.2 Run the identified tests and record results: (a) green (exit 0), (b) red (exit non-zero), (c) no tests exist, (d) tests not run (environment unavailable).
- [ ] 5.3 For CLOSE candidates without green tests, explicitly disclose "no tests exist" or "tests not run" in the triage table.

## 6. Reverse-Drift Detection

- [ ] 6.1 For each ticket with status CLOSED, check if Fix and Re-verify sections are still placeholder text (contain "<To be filled" or are empty).
- [ ] 6.2 Classify reverse-drift: (a) CLOSED with placeholder Fix/Re-verify = full reverse-drift, (b) CLOSED with populated Fix but placeholder Re-verify = partial reverse-drift, (c) CLOSED with both populated = no reverse-drift.

## 7. Triage Table Compilation

- [ ] 7.1 For each ticket, apply the evidence taxonomy (interview decision 4) to assign a recommendation: CLOSE, UPDATE, KEEP OPEN, or OBSOLETE.
- [ ] 7.2 Compile the triage table with columns: Ticket ID, Title (slug), Current Status, Evidence Summary, Test Status, Recommendation, Action Required.
- [ ] 7.3 Group the table by recommendation: CLOSE candidates, UPDATE candidates, KEEP OPEN, OBSOLETE candidates.
- [ ] 7.4 Append reverse-drift flags as a separate informational table.
- [ ] 7.5 Append ana026 gap flags (P0/P1 findings with no corresponding OPEN ticket) as a separate informational table.

## 8. Developer Approval

- [ ] 8.1 Present the triage table in conversation for developer review.
- [ ] 8.2 Wait for explicit developer approval before proceeding to task 9.
- [ ] 8.3 If developer requests changes to the triage table, revise and re-present.

## 9. Ticket Frontmatter Updates (post-approval)

- [ ] 9.1 For each CLOSE recommendation, update ticket frontmatter: set status to CLOSED, populate Fix section with evidence summary, populate Re-verify section with test results or "no tests exist" disclosure.
- [ ] 9.2 For each UPDATE recommendation, update ticket frontmatter: refresh Fix/Re-verify sections with current evidence, keep status OPEN.
- [ ] 9.3 Do not create new tickets for ana026 gaps without explicit developer approval.
- [ ] 9.4 Do not edit implementation code or OpenSpec artifacts.
