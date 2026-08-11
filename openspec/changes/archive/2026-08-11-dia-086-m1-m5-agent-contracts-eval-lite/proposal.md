# Proposal: dia-086-m1-m5-agent-contracts-eval-lite

> **Status:** proposed · **Scope:** agent contracts + eval-lite harness (config-tooling + dev-infra)
> **Escalation:** none -- change is within existing module boundaries. M1-M4 are agent/skill config additions; M5 is a dev-infra script. Per AGENTS.md 2.4 and 2.5, neither requires @architector. No `.sdd/` module doc is created; this change references `.sdd/README.md` (three-layer model) and `.sdd/dia-redispatch-cycle/architecture.md` only.
> **Source:** ana012-scientific-workflow-proposal (knowledge/ana012-scientific-workflow-proposal/ana012-scientific-workflow-proposal-report.md) + res012-scientific-methodology conspect (knowledge/res012-scientific-methodology/res012-scientific-methodology-conspect.md).
> **Interview:** Phase 3 summary approved. Five open questions confirmed (see locked decisions below).

## Why

The DIA-086 scientific-methodology survey (res012 conspect, 50 sources) identified two structural gaps in the project's AI-assisted development workflow:

1. **No falsification step.** The two-axis @reviewer verifies prior findings (review-re-verify) but never challenges the lane's own claims. There is no distinct "break your own claim" mechanism.
2. **No explicit hypothesis in spec interviews.** The openspec-propose and domain-grilling Socratic interviews extract requirements but never surface the underlying hypothesis or its falsification conditions.

ana012 proposed five mandatory lightweight additions (M1-M5, <12h total) to close these gaps. Each mandate is additive (no existing behavior removed), in-process (no FFI/IPC/network per Q9), and declarative (schema metadata only, not coupled to machine-readable session refs per observability decision).

This change implements all five mandates as ONE change with TWO implementation slices following the volta-to-mise precedent (config + dev-infra in one change, two review chains).

## What Changes

### Slice A: Config-tooling (M1 + M2 + M3 + M4) -- review chain: @coder + @ai-auditor (AGENTS.md 2.5)

- **M1: analyzer output contract.** Additive HTML-comment header block in `.opencode/agents/analyzer.md` (Output Contract section). Every analyzer report carries a declarative header: `schema-version: 1.0`, `agent: analyzer`, `claim-type`, `evidence-source`, `confidence: <High | Medium | Low>`, `shelf-registration`. Interview decision: schema-version field included (locked decision #3); confidence field is mandated by ana012 lines 67 and 104 (the mandate text is authoritative -- locked decision #3 governs versioning only, not field set). Migration strategy: FORWARD-ONLY (existing reports are not retroactively updated; schema-version: 1.0 lets validators distinguish pre-M1/M2 reports (no header) from post (header present), council finding H).
- **M2: conspecter output contract.** Additive HTML-comment header block in `.opencode/agents/conspecter.md` (PHASE B section). Every conspect carries a declarative header: `schema-version: 1.0`, `agent: conspecter`, `phase-a-source-count`, `phase-a-failures`, `shelf-registration`. Interview decision: schema-version field included (locked decision #3). M2 confidence field (the M1 `confidence` field carried over to conspects): DECLINED -- the approved M2 is an experiment-log header (phase-a-source-count / phase-a-failures only); adding confidence to M2 would exceed the mandate. Recorded explicitly per council delta-suggestion ruling.
- **M3: reviewer falsification axis.** Insert `## Falsification` section in `.opencode/oh-my-opencode-slim/reviewer.md` AFTER `## Spec`, BEFORE `## Summary`. Exactly 3 falsification claims `[FALSIFICATION-N] file:line -- claim`, each severity-labelled with the Standards-axis rubric (Blocker/Critical/Major/Minor/Suggestion). Interview decisions: claim + severity ONLY, no fix-direction field (locked decision #2); flows into existing practice-protected section-4 disposition loop, no new verdicts, no separate escalation path; review-re-verify SKILL.md UNTOUCHED. Falsification triad is emitted on FULL reviews only; re-review mode (review-re-verify) tracks prior findings via its findings-resolution table and emits NO new Falsification analysis; 'exactly 3' is per full review, not per re-review cycle; initial Falsification findings enter the existing findings-resolution table via the generic prefix handling.
- **M4: hypothesis question in Socratic interviews.** Insert identical question in Phase 1 of `.opencode/skills/openspec-propose/SKILL.md` AND `.opencode/skills/domain-grilling/SKILL.md`, placed AFTER an explicit `<!-- FIRST-QUESTION -->` HTML anchor comment (defense-in-depth: each skill ALSO gains at least one explicit example question ending in `?` in Phase 1 so the anchor is never orphaned). Wording (locked decision #5): "What is the primary hypothesis this feature/design validates, and how will you know if it is falsified?" Placement rule: the hypothesis question must appear after the `<!-- FIRST-QUESTION -->` anchor; the anchor must appear after any frontmatter/license HTML comments and before any interview methodology prose. Verified safe: the `<!-- FIRST-QUESTION -->` anchor lives in the body (post-frontmatter), so validate-skills.sh HARD checks (YAML parse + name/description presence + name==dirname) are unaffected; the SOFT activation-phrase check is WARN-only and both skill files already carry HTML comments as their first body line.

### Slice B: Dev-infra (M5) -- review chain: @coder + @reviewer (AGENTS.md 2.4)

- **M5: eval-lite harness.** Host-runnable `make eval-lite` target (DIA-094 host-runnable exemption like test-config/test-shell -- NOT dev-container). New files: `scripts/eval-lite.sh`, `scripts/__tests__/eval-lite.bats`, `docs/dev-infra/eval-lite-tasks.md`. Serial execution, <=60s wall clock, initial curated set of 20 tasks from 4-source priority (DIA ledger, vitest editor-engine/phonetics-core, pytest api-server/analytics-pipeline, escalated/crisis session-log patterns). Tab-separated 6-field task format (6th field: `container-bound: yes|no`). Container-aware harness: `scripts/eval-lite.sh` detects dev-container state via `docker compose ps --format json dev` (JSON parse of service status -- robust to missing daemon), SKIPS container-bound tasks with a `WARN: skipping container-bound task <ticket> (dev container not running)` line, exits 0 when all runnable required tasks pass. Exit codes: 0 (all runnable pass; container-bound skips count as pass for the 'all pass' condition, reported separately in the summary as `N passed, M failed, K skipped`), 1 (any non-skipped task fails), 2 (file missing), 3 (no tasks defined). Malformed lines skipped with WARN. Interview decisions: stdout only, no --log flag (locked decision #4); NOT wired into CI or verify-pre-commit.sh; NOT replacing existing test gates. Manifest header carries curation metadata (curation date, curator, review cadence) -- see design.md Decision 8.

## Capabilities

### New Capabilities

None. This change introduces no application-level capabilities. All additions are agent/skill configuration (M1-M4) and dev-infra tooling (M5).

### Modified Capabilities

None. No existing application capabilities have their requirements changed.

**`skip_specs: true` is set in `.openspec.yaml`** -- consistent with dia-066-tool-coverage-audit and volta-to-mise precedents. The change affects agent definitions, skill files, and dev-infra scripts, none of which alter the poetry-platform application's observable behavior.

## Design authority (.sdd/) reference

**No new `.sdd/` module doc is created.** The developer confirmed (locked decision #6): "Feature-level, no .sdd/ -- M1-M5 belong in openspec/changes/ (L3), no .sdd/ escalation."

This change references:

- **`.sdd/README.md`** (three-layer model) -- M1-M5 live in L3 `openspec/changes/`, not L1 `.sdd/`.
- **`.sdd/dia-redispatch-cycle/architecture.md`** (5-ADR seed for cycle-management protocol) -- the only existing .sdd/ module doc; M3 falsification axis interacts with the cycle-management protocol's crisis-detection triggers (C1-C5) by providing a review-level falsification mechanism that precedes cycle-level escalation.

Per AGENTS.md 2.4 and 2.5, changes within existing boundaries use the spec chain directly without architectural escalation. No `@architector` dispatch is required.

## Impact

| Affected area     | Files changed                                                                             | Nature                                                                                                |
| ----------------- | ----------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Agent definitions | `.opencode/agents/analyzer.md`, `.opencode/agents/conspecter.md`                          | Additive header block (M1, M2)                                                                        |
| Reviewer config   | `.opencode/oh-my-opencode-slim/reviewer.md`                                               | New section inserted (M3)                                                                             |
| Skill files       | `.opencode/skills/openspec-propose/SKILL.md`, `.opencode/skills/domain-grilling/SKILL.md` | One question + `<!-- FIRST-QUESTION -->` anchor added (M4)                                            |
| M1/M2 validator   | `scripts/validate-output-contracts.sh` (new)                                              | Output-contract header validator (M1+M2)                                                              |
| M3 validator      | `scripts/validate-reviewer-sections.sh` (new)                                             | Falsification-section validator (M3)                                                                  |
| M4 validator      | `.opencode/scripts/validate-skills.sh` (extended)                                         | Hypothesis-question placement check (M4)                                                              |
| Dev-infra scripts | `scripts/eval-lite.sh` (new), `scripts/__tests__/eval-lite.bats` (new)                    | New harness (M5)                                                                                      |
| Dev-infra tests   | `scripts/__tests__/bats-wrapper.sh` (extended)                                            | `bash -n` allowlist adds `eval-lite.sh` (M5)                                                          |
| Dev-infra tasks   | `docs/dev-infra/eval-lite-tasks.md` (new)                                                 | Task manifest, 6-field TSV with curation-metadata header (M5)                                         |
| Makefile          | `Makefile`                                                                                | New `eval-lite` target + wire M1-M4 validators into `test-config` / `test-skills` chains (M1-M4 + M5) |

**No application code changed. No Dockerfile changed. No dependency added. No API changed.**

## Testing Decisions

Per `openspec/config.yaml` rules: this section states what makes a good test for this change, which modules will be tested, and the prior art in the codebase.

### What makes a good test here

- **Slice A (M1-M4): Validation tests.** The artifacts under test are HTML comment blocks in Markdown files and question placement in skill files. The right test is structural validation: parse the Markdown, assert the header block exists with correct fields (including `confidence` for M1), assert the section heading is in the correct position, assert the hypothesis question appears after the `<!-- FIRST-QUESTION -->` anchor. Prior art: `scripts/validate-agent-names.sh` (4-source containment contract), `scripts/validate-skills.sh` (skill-file structural checks). The `make test-config` gate already validates agent-name containment and config integrity; M1-M4 validators extend this pattern via three NEW validator scripts:
  - `scripts/validate-output-contracts.sh` -- asserts the M1 `ANALYZER-OUTPUT-CONTRACT` header block (all required fields including `confidence: <High | Medium | Low>`) in `.opencode/agents/analyzer.md`, AND the M2 `CONSPECTER-OUTPUT-CONTRACT` header block in `.opencode/agents/conspecter.md`. Wired into `make test-config`.
  - `scripts/validate-reviewer-sections.sh` -- asserts the M3 `## Falsification` heading exists in `.opencode/oh-my-opencode-slim/reviewer.md`, positioned AFTER `## Spec` and BEFORE `## Summary`, with the `[FALSIFICATION-N]` format and the exactly-3 claims requirement stated in the section body. Wired into `make test-config`.
  - Extension to `.opencode/scripts/validate-skills.sh` -- asserts the M4 hypothesis question text appears after the `<!-- FIRST-QUESTION -->` anchor in BOTH `.opencode/skills/openspec-propose/SKILL.md` AND `.opencode/skills/domain-grilling/SKILL.md`. Wired into `make test-skills` (already part of the `make test-config` prereq chain).
- **Slice B (M5): bats unit tests.** The artifact under test is a bash script (`scripts/eval-lite.sh`). The existing prior art is `scripts/__tests__/*.bats` (8+ suites). Tests cover all exit codes (0/1/2/3), malformed-line handling, the curated task-set dry run, container-aware skip behavior, and a `bash -n` syntax preflight. Docker is mocked (consistent with `make test-shell` pattern). The harness script itself is added to the explicit `bash -n` list in `scripts/__tests__/bats-wrapper.sh` lines 20-42 so syntax errors surface before the test suite.

### Modules under test

1. `.opencode/agents/analyzer.md` (M1) -- header block presence + field validation INCLUDING `confidence` field, via `scripts/validate-output-contracts.sh`.
2. `.opencode/agents/conspecter.md` (M2) -- header block presence + field validation, via `scripts/validate-output-contracts.sh`.
3. `.opencode/oh-my-opencode-slim/reviewer.md` (M3) -- `## Falsification` section position + 3-claim structure, via `scripts/validate-reviewer-sections.sh`.
4. `.opencode/skills/openspec-propose/SKILL.md` + `.opencode/skills/domain-grilling/SKILL.md` (M4) -- hypothesis question placement relative to `<!-- FIRST-QUESTION -->` anchor, via extension to `.opencode/scripts/validate-skills.sh`.
5. `scripts/eval-lite.sh` (M5) -- bats unit tests in `scripts/__tests__/eval-lite.bats`; also listed in the `bash -n` allowlist in `scripts/__tests__/bats-wrapper.sh`.

### Prior art

- `scripts/validate-agent-names.sh` -- 4-source containment validation pattern (M1-M4 validators follow this shape).
- `scripts/validate-skills.sh` -- skill-file structural validation (M4 placement test extends this script directly).
- `scripts/validate-output-contracts.sh` (NEW, M1+M2) -- output-contract header validation.
- `scripts/validate-reviewer-sections.sh` (NEW, M3) -- section-position + claim-format validation.
- `scripts/__tests__/check-pin-sync.bats` -- bats pattern for dev-infra scripts (M5 tests follow this shape).
- `scripts/__tests__/audit-agent-tool-coverage.bats` -- hermetic bats via fixture trees (M5 tests follow this shape).
- `scripts/__tests__/bats-wrapper.sh` -- `bash -n` allowlist pattern (M5 script added here).
- `make test-config` -- existing validation gate (M1-M4 validators wire into this).
- `make test-shell` -- existing bats gate (M5 bats wire into this).

## Rollback plan

All changes are additive files or insertions into existing Markdown/config files. Rollback is trivial:

- **Slice A:** `git revert` of the merge commit restores the original agent/skill files. No persistent state changed.
- **Slice B:** `git revert` removes `scripts/eval-lite.sh`, `scripts/__tests__/eval-lite.bats`, `docs/dev-infra/eval-lite-tasks.md` and the Makefile target. No CI wiring to undo (M5 is NOT wired into CI per locked decision #4).

## Locked decisions (interview transcript)

| #   | Decision                | Ruling                                                            |
| --- | ----------------------- | ----------------------------------------------------------------- |
| 1   | Phase 3 summary         | Approve, proceed to synthesis                                     |
| 2   | M3 falsification format | Claim + severity only -- no fix-direction field                   |
| 3   | M1/M2 header schema     | Include schema-version -- schema-version: 1.0 in header blocks    |
| 4   | M5 results log          | Stdout only -- no --log flag                                      |
| 5   | M4 wording              | Identical wording in both skills, placed after the first question |
| 6   | .sdd/ escalation        | Feature-level, no .sdd/ -- M1-M5 belong in openspec/changes/ (L3) |
