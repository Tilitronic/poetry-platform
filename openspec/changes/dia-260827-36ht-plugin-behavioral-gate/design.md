## Context

See proposal.md Why. Current state: the DIA-189 suite mocks node:child_process spawn but sets no WSL capability, so canUsePowershellToast() is false on pure-linux and fireDesktopToast() early-returns before spawn; the desktop assertions that read the captured script therefore fail for harness reasons. The platform-gate suite already demonstrates the working pattern (virtual /mnt/wslg marker). The pre-push ladder runs format, js, js-tests, test-config, test-omo, python, test-shell, but never make test-harness. Governing constraints: .sdd/dev-infra/architecture.md (pre-push and harness ownership), .sdd/opencode-config/architecture.md (plugin test boundaries, no runtime change), architecture.md guiding principles (single responsibility, testable in isolation). No new module boundary or technology decision; no @architector escalation.

## Goals / Non-Goals

**Goals:**

- Give DIA-189 desktop-toast tests an explicit WSL-capable environment with safe restore.
- Wire make test-harness into pre-push as push-blocking without changing the container-down contract.
- Pin the wiring with a structural bats assertion.

**Non-Goals:**

- No change to needs-input-observer.ts runtime logic or platform detection.
- No change to platform-gate assertions or its virtual-marker approach.
- No change to the intentional empty-result-detection skip (needs an exported set-inspection hook first).
- No actual git push test and no new test suite.

## Decisions

- D1: WSL_DISTRO_NAME env fixture scoped to desktop-toast tests, prior value saved and restored in cleanup. Rationale: smallest fixture that opens isWSL(); avoids a second fs mock and keeps the DIA-189 diff local. Alternative (virtual /mnt/wslg fs mock mirroring platform-gate): rejected as heavier than needed.
- D2: Keep the existing mockChildProcess spawn interception unchanged. Rationale: proven hermetic pattern; the only missing piece is the capability marker. Alternative (new spawn harness): rejected, no evidence it is needed.
- D3: Pre-push placement after make test-omo and before pnpm verify:python via a host-local Bun execution that runs only the six DIA-189 desktop-toast tests with the pattern "desktop toast|Cyrillic|control chars|single quotes|180 chars|C1 control". Host Bun on PATH is a prerequisite. Rationale: behavioral gate runs with the other mid-ladder gates while slow bats stays last; nested Docker through run_workspace breaks the warn-and-pass contract, while this no-Docker leg preserves it trivially. Alternative (after test-shell): rejected, buries a fast behavioral signal behind the slowest suite.
- D4: Structural bats check (line presence plus ordering after test-omo and before verify:python) in scripts/**tests**/verify-pre-push.bats. Rationale: follows existing wiring-test precedent and fails loudly on reorder or removal. Alternative (new suite or live pre-push run): rejected per Q6 and Q3 bounds.

## Risks / Trade-offs

- [Risk] Env leak from WSL_DISTRO_NAME into non-desktop tests -> Mitigation: save prior value on entry, restore in cleanup even on failure; non-desktop tests assert no platform dependence.
- [Risk] Pre-push gets slower (extra focused host-local Bun leg) or lacks host Bun -> Mitigation: placement before the slow bats leg keeps fast-fail order; host Bun on PATH is a prerequisite, and no-Docker execution leaves the container-down warn-and-pass path unchanged so offline pushes are not blocked.
- [Risk] A DIA-189 desktop test still fails after the marker (real product defect) -> Mitigation: per Q7 agreement, treat as out of scope for this change and escalate via a new ticket; do not widen this change to source fixes.
- [Risk] Bats ordering assertion becomes brittle on ladder edits -> Mitigation: assert relative order (after test-omo, before verify:python), not absolute line numbers.

## Migration Plan

- Land fixture + host-local Bun ladder line + bats check together; no feature flag.
- Rollback: revert the three files; pre-push returns to prior ladder, DIA-189 returns to prior red. No data migration, no config migration.

## Open Questions

None. All approach questions were closed in the Q1-Q7 interview.

## Seams

- bun plugin suite seam: .opencode/plugins/**tests** run from inside the directory (bun skips dot-directories in discovery); focused DIA-189 file plus unchanged platform-gate file.
- host-local Bun seam: focused DIA-189 bun test runs from .opencode/plugins/**tests** with the approved six-test name pattern; it requires Bun on the host PATH and does not delegate through run_workspace.
- pre-push seam: scripts/verify-pre-push.sh ladder lines plus scripts/**tests**/verify-pre-push.bats structural assertions.

ownership:
substance: developer
structure: AI
interview_depth: full
interview_reason: ""
