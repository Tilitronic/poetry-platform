# Proposal: dia-260827-36ht-plugin-behavioral-gate

## Why

Ticket DIA-260827-36ht reports the plugin behavioral gate is red and missing from pre-push. The DIA-189 desktop-toast assertions require a captured powershell.exe spawn, but the DIA-189 harness registers only the spawn mock and injects no WSL capability marker, so the platform gate early-returns and the assertions cannot observe a spawn. Separately, scripts/verify-pre-push.sh does not invoke make test-harness, so the full plugin behavioral suite is not push-blocking.

## What Changes

- DIA-189 harness: set WSL_DISTRO_NAME for desktop-toast tests only, restore the prior value in cleanup, keep the existing child_process spawn mock; no filesystem mock, no change to the platform-gate virtual /mnt/wslg pattern.
- Pre-push ladder: invoke a host-local Bun leg after make test-omo and before pnpm verify:python, running only the six DIA-189 desktop-toast tests with the pattern "desktop toast|Cyrillic|control chars|single quotes|180 chars|C1 control"; host Bun on PATH is a prerequisite, the leg is push-blocking under set -e, no Docker is used, and the container-down warn-and-pass contract remains unchanged.
- Wiring regression check: extend scripts/**tests**/verify-pre-push.bats with a structural assertion for the host-local Bun leg line and its placement, plus an absence pin for the old delegated harness line; no new test suite.

## Capabilities

### New Capabilities

None. This is a test-harness fixture fix plus pre-push wiring with no product behavior change.

### Modified Capabilities

None. No spec-level requirement changes; plugin runtime behavior, the pure-Linux no-spawn assertion, and the intentional empty-result skip are unchanged. This change sets skip_specs: true in .openspec.yaml.

## Impact

- Files: .opencode/plugins/**tests**/needs-input-observer.dia189.test.mjs (fixture only), scripts/verify-pre-push.sh (one ladder line), scripts/**tests**/verify-pre-push.bats (structural assertion).
- Systems: bun plugin behavioral suite (focused DIA-189 leg plus unchanged platform-gate), host-local Bun pre-push leg, husky pre-push ladder.
- Untouched: .opencode/plugins/needs-input-observer.ts runtime gate, needs-input-observer.platform-gate.test.mjs assertions, empty-result-detection.test.mjs skipped cleanup test.
- Dependencies: none new.

## Alternatives considered

- A. Virtual /mnt/wslg filesystem mock in DIA-189 (mirror platform-gate pattern): rejected - heavier than needed; the plugin isWSL() also accepts WSL_DISTRO_NAME, and an env-only fixture keeps the DIA-189 diff minimal. Evidence Tier-1: .opencode/plugins/**tests**/needs-input-observer.platform-gate.test.mjs:90-102 (fs mock), .opencode/plugins/needs-input-observer.ts:218-219 (either marker opens the gate).
- B. Change plugin source to bypass the platform gate under test: rejected - would weaken the gate under test and contradict Q2/Q7 no-source-change bound. Evidence Tier-1: .opencode/plugins/needs-input-observer.ts:228,820 (canUsePowershellToast early-return).
- C. Status-quo / do nothing: rejected - DIA-189 desktop assertions stay red for harness reasons and the behavioral suite stays out of pre-push, so regressions ship silently. Evidence Tier-1: scripts/verify-pre-push.sh:147-154 (no test-harness line), Makefile:304-312 (test-harness target exists but unwired).
  Chosen option: scoped WSL_DISTRO_NAME fixture + pre-push wiring + bats structural check - because it turns the harness-caused red green with zero source change and makes the behavioral gate push-blocking.

## Testing Decisions

A good test for this change proves the harness gap is closed without moving the product gate: DIA-189 desktop assertions observe a spawn only when the explicit WSL marker is present, the platform-gate pure-Linux suite still observes no spawn without markers, and pre-push ordering is pinned structurally. Modules under test: the focused DIA-189 host-local Bun leg, the unchanged platform-gate bun suite, and the verify-pre-push bats suite. Prior art: platform-gate virtual-marker pattern, dia189 mock-restore helpers, verify-pre-push.bats structural assertions.

ownership:
substance: developer
structure: AI
interview_depth: full
interview_reason: ""
