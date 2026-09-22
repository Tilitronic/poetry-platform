# Proposal: ai-self-improvement-auditor-and-cleanup

> **Status:** proposed · **Scope:** AI-tooling config (AGENTS.md §10 → §10 workflow mandatory) + dev-infra shell validators (AGENTS.md §2.4 → `@reviewer`). Two routing lanes in one change (per Q4 interview ruling — split is documented, not split into two changes).
> **Escalation:** none — change stays within existing module boundaries. No `@architector` dispatch required (see §Design authority).
> **Source:** owner-confirmed full-depth interview (Q1 scope+name, Q2 boundary conditions, Q3–Q7+Q9, Phase 3 summary — all 7 confirmation items + Phase 3 summary accepted, row 471). Interview CLOSED; artifacts synthesized from confirmed transcript only.
> **§10 gate status:** ai-specialist Phase-1 gate already completed (finding `ai--1`, registered in `.opencode/learnings/external-patterns/`). This proposal documents the gating trace; no re-gate needed.

## Motivation

The owner's original plan was a four-phase evolution of the poetry-platform's AI self-improvement loop:

1. **Phase 1 — CLASH integration** (empathic/clash agent runtime). **DROPPED** per interview Q1 ruling: upstream issue #197 is open, the package is experimental (33 GitHub stars), and the project's native `permission` blocks in `opencode.jsonc` already deliver the behavioural guardrails Phase 1 was meant to provide. Carrying a low-maturity dependency for capability we already have in-house is unjustified risk. The CLASH gap is tracked as a future reconsideration, not as an open ticket in this change.
2. **Phase 2 — Skill hygiene + duplicate detection.** Five project-scoped skill directories under `.opencode/skills/` are byte-for-byte duplicates of skills already loaded from the global skills directory (`~/.config/opencode/skills/`). Double-loading wastes context, produces duplicate entries in the runtime skill list, and — worse — silently masks drift when one copy is updated without the other. The keeper set is `playwright-browser` (project-local acceptance-test extensions) and `git-diff` (project-local context injection); all other duplicates are deleted. A validator is added to `.opencode/scripts/validate-skills.sh` so this class of defect cannot recur.
3. **Phase 3 — `@ai-auditor` agent registration + `@ai-specialist` scope narrowing.** The audit surface has grown to the point where the orchestrator needs a dedicated, read-only auditor agent distinct from the researcher (`@ai-specialist`). `@ai-auditor` is registered in all four agent-name sources (AGENTS.md §9, `opencode.jsonc` `agents` block, `oh-my-opencode-slim.jsonc` agents + 3 presets, `.opencode/agents/ai-auditor.md`), and `@ai-specialist`'s description is narrowed to a docs-only mandate to avoid scope overlap.
4. **Phase 4 — Council budget controls.** Add a §2 rule to `docs/dev-infra-audit/NEXT-RUN.md` instructing the orchestrator to warn at 75% (1125 of 1500) and hard-stop at 90% (1350 of 1500) of the council's per-session credit budget.

The scope corrections (Phase 1 drop, §10 routing split, 4-source deltas, threshold values, keeper skill set) were all confirmed in the interview transcript (Q1–Q7, Q9, Phase 3 summary, row 471 owner acceptance).

## Scope

### In scope (per Q1 interview ruling)

| #   | Deliverable                                                                                                                                                                                                                                                                                                                       | Lane                               |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| 1   | **Skill cleanup** — delete 5 duplicate skill directories under `.opencode/skills/`. Keep `playwright-browser` and `git-diff`.                                                                                                                                                                                                     | §10 (AI-tooling config)            |
| 2   | **Duplicate-detection validator** — extend `.opencode/scripts/validate-skills.sh` with a two-tier dup check (byte-exact HARD exit 1 via single-pass `sha256sum` group-by-hash O(n); near-dupe SOFT warn via single `diff -r`). Add bats coverage to `scripts/__tests__/validate-skills.bats`.                                     | §2.4 (dev-infra, `@reviewer`)      |
| 3   | **`@ai-auditor` 4-source registration** — add `ai-auditor` row to AGENTS.md §9, read-only block to `opencode.jsonc`, agent entry + 3 preset slots to `oh-my-opencode-slim.jsonc`, and `.opencode/agents/ai-auditor.md` (frontmatter: description+mode only, mirroring `memory-manager.md`; permissions live in `opencode.jsonc`). | §10 (AI-tooling config)            |
| 4   | **Narrow `@ai-specialist`** — revise the `description` field in `opencode.jsonc` to a docs-only mandate wording, eliminating the overlap with the incoming `@ai-auditor`.                                                                                                                                                         | §10 (AI-tooling config)            |
| 5   | **Council budget controls in `NEXT-RUN.md` §2** — add a rule + two thresholds: warn at 75% (1125 of 1500 credits), hard-stop at 90% (1350 of 1500 credits).                                                                                                                                                                       | §2.4 (dev-infra docs, `@reviewer`) |

### Out of scope (per Q1 + Q2 interview rulings — explicitly deferred)

| Excluded item                                                                           | Ruling source                                                |
| --------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| CLASH integration (original Phase 1)                                                    | Q1 (dropped — native permissions suffice, upstream immature) |
| Modifications to the global skills directory (`~/.config/opencode/skills/`)             | Q1                                                           |
| Merging the keeper skills (`playwright-browser`, `git-diff`) into the global skills dir | Q1                                                           |
| Changes to `dcp.jsonc`                                                                  | Q1                                                           |
| Filing a DIA-051 tracking ticket for the dropped Phase 1                                | Q1                                                           |
| Global opencode config (`~/.config/opencode/opencode.jsonc`)                            | Q2 (parallel precedent with `dev-infra-config-validators`)   |
| OMO JSONC schema validation (no upstream schema exists)                                 | Q7 (known gap — future work)                                 |
| Authoring a `.sdd/` module doc for AI-tooling                                           | §Design authority (precedent allows)                         |
| Any change beyond the 5 in-scope deliverables                                           | Q1                                                           |

> **Errata (2026-08-06):** factual correction to the skill-cleanup scope above — **not a rule change**. The pre-deletion audit (DIA-052) found only **3 of 5** deletion candidates were byte-exact duplicates: `mermaid-diagramming`, `console-charting`, and `teaching` were deleted. `book-rag` and `debugging-workflow` **differ** from their global counterparts (project-local fixes — `query_rag.py` path references / `@coder` vs `@fixer` stage references) and were **retained** as near-duplicates per the HARD/SOFT partition (SOFT warn, no deletion). Post-cleanup `.opencode/skills/` holds **17 entries, not 15**; the deletions numbered **3, not 5**. References in this proposal (Motivation Phase 2, Scope deliverable 1, Success criteria 2, Rollback plan) that state "5 deletions" / "15 entries" are superseded by this correction.

## §10 routing flag

This change straddles two routing lanes. Per AGENTS.md §10 (AI-tooling modernization workflow) and §2.4 (dev-infra), the split is:

| Deliverable                              | Routing lane | Reviewer                                      |
| ---------------------------------------- | ------------ | --------------------------------------------- |
| Skill cleanup (5 deletions)              | §10          | `@ai-specialist` (Phase-6 independent review) |
| Dup-detection validator extension + bats | §2.4         | `@reviewer` (two-axis)                        |
| `@ai-auditor` 4-source registration      | §10          | `@ai-specialist` (Phase-6 independent review) |
| Narrow `@ai-specialist`                  | §10          | `@ai-specialist` (Phase-6 independent review) |
| Council budget controls in `NEXT-RUN.md` | §2.4         | `@reviewer` (two-axis)                        |

**§10 workflow trace (mandatory):**

1. **Phase 1 — Gate (ai-specialist):** DONE. Finding `ai--1` registered in `.opencode/learnings/external-patterns/`. The gate produced the scope corrections that shaped this proposal (Phase 1 drop, 4-source deltas, threshold values, keeper skill set).
2. **Phase 2 — Review & decide:** owner accepted all via row 471 ("Accept all (Recommended)").
3. **Phase 3 — Design:** this proposal + accompanying `design.md` + `tasks.md`.
4. **Phase 4 — Implement:** `@coder` against `tasks.md` (test-first via `tdd-craftsman` for T1/T2 bats slices).
5. **Phase 5 — Validate:** `make test-config` + `make test-skills` + §10 Phase-5 restart+smoke (dispatch `@ai-auditor` on a minimal test task; assert read-only enforced).
6. **Phase 6 — Independent review:** `@ai-specialist` reviews the implemented AI-tooling changes against best practices + AIHero patterns.
7. **Phase 7 — Register:** update `.opencode/CHANGELOG.md` + learnings outcome field.

The §2.4 validator/bats/Makefile/NEXT-RUN.md slice follows the standard §2.4 chain: `@coder` → `@reviewer` (two-axis).

## Design authority (.sdd/) reference

**No `.sdd/` module doc governs this change.** The `.sdd/` directory contains only `.sdd/dia-redispatch-cycle/architecture.md` (DIA cycle protocol) and `.sdd/README.md`. Neither `.opencode/scripts/validate-skills.sh`, the AI-tooling config surface (`.opencode/opencode.jsonc`, `.opencode/oh-my-opencode-slim.jsonc`, `.opencode/agents/*.md`, `AGENTS.md` §9), nor `docs/dev-infra-audit/NEXT-RUN.md` has an `.sdd/` entry.

This is the same precedent as `openspec/changes/dev-infra-config-validators/proposal.md` §Design authority, `openspec/changes/dev-infra-copilot-fixes/proposal.md` §Design authority, and `openspec/changes/volta-to-mise/proposal.md` §Design authority: bounded dev-infra + AI-tooling config within existing boundaries does not require architectural escalation. Per AGENTS.md §3, the absence of a governing `.sdd/` is a documentation gap, but one this change does not fill.

**Relevant existing patterns this change follows (de-facto SDD):**

- **AGENTS.md §10** — the AI-tooling modernization workflow. The 7-phase chain + Phase-1 ai-specialist gate + Phase-6 independent review are the governing contract for deliverables 1/3/4.
- **`scripts/validate-agent-names.sh` header (lines 1–46)** — the 4-source agent-name contract (containment semantics, §9 table + opencode.jsonc + oh-my-opencode-slim.jsonc + `.opencode/agents/*.md` stems). `@ai-auditor` registration must preserve the post-change `22 passed, 0 failed, 0 warnings` baseline.
- **`.opencode/scripts/validate-skills.sh`** — the immediate prior art for the dup-detection extension. Same 3-tier exit contract, same `SKILLS_ROOT` env override seam (now extended with a `GLOBAL_SKILLS_ROOT` env override for the global-skills fixture), same HARD/SOFT partition, same collect-all-never-fail-fast discipline.
- **`.opencode/agents/memory-manager.md`** — frontmatter pattern to mirror for `ai-auditor.md` (description + mode only; permissions live in `opencode.jsonc`).

## Success criteria

1. **Dup-detection validator is hermetic.** Any future skill duplicate between `.opencode/skills/` and the global skills dir fails `make test-skills` with a clear byte-exact message (HARD exit 1). Near-dupes warn without flipping the exit code.
2. **The 5 duplicates are removed.** `.opencode/skills/` retains exactly 15 entries (the 14 non-duplicate originals + `playwright-browser` + `git-diff`). Keeper skills are byte-identical to pre-change.
3. **`@ai-auditor` is dispatchable and read-only enforced.** `scripts/validate-agent-names.sh` real-config run reports `22 passed, 0 failed, 0 warnings` (was 21 pre-change). `make test-config` exits 0. §10 Phase-5 restart+smoke confirms: `@ai-auditor` is dispatchable on a minimal test task, and the read-only `permission` block in `opencode.jsonc` is enforced (edit: deny, bash: only narrow allowlist).
4. **`@ai-specialist` is narrowed.** The `description` field in `opencode.jsonc` reflects the docs-only mandate; no behavioural change to the existing `prompt` / `orchestratorPrompt` / model / permissions.
5. **Council budget controls are documented.** `docs/dev-infra-audit/NEXT-RUN.md` §2 carries the orchestrator rule + the two thresholds (warn 75% / 1125, hard-stop 90% / 1350, base 1500).
6. **Baselines preserved.** `make test-skills` exits 0 on the post-cleanup project config. `make test-shell` retains its pre-existing bats pass count + the new dup-detection cases. `scripts/validate-agent-names.sh` reports 22 passed (was 21 pre-change).
7. **Rollback is trivial.** `git revert` of the merge commit + `make test-config` + `make test-skills` restores the pre-change state. No data migration, no persistent-state change.

## Non-goals

- **Resolving the upstream CLASH issue (#197).** Out of scope; not tracked as a DIA ticket in this change per Q1.
- **Modifying the global skills directory.** Out of scope (Q1).
- **Merging the keeper skills into the global dir.** Out of scope (Q1).
- **Validating the global opencode config (`~/.config/opencode/opencode.jsonc`).** Out of scope (Q2, parallel precedent).
- **OMO JSONC schema validation.** Known gap (Q7); no upstream schema file exists; future work.
- **Authoring a `.sdd/` module doc.** Out of scope (precedent allows).
- **Any change beyond the 5 in-scope deliverables.**

## Stakeholders

| Stakeholder                             | Interest                                                                                                                                  |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Orchestrator                            | `make test-skills` catches skill duplication at PR time, not at runtime; council budget is mechanically enforced via NEXT-RUN.md §2 rule. |
| `@ai-specialist` (§10 Phase-6 reviewer) | Independent reviewer of the AI-tooling slice; scope narrowed to avoid overlap with incoming `@ai-auditor`.                                |
| `@ai-auditor` (new)                     | New read-only auditor; registered across all 4 sources, dispatchable after §10 Phase-5 smoke.                                             |
| `@reviewer` (§2.4 reviewer)             | Two-axis reviewer for the dev-infra slice (validator + bats + NEXT-RUN.md docs change).                                                   |
| DIA audit trail                         | `@ai-auditor` registration is mechanical; no new DIA ticket generated. The 5 deleted skill directories are recoverable via `git revert`.  |

## Testing Decisions

> Per `openspec/config.yaml`: "Include a Testing Decisions section that states what makes a good test for this change, which modules will be tested, and the prior art in the codebase."

### What makes a good test here

The artifacts under test span two categories:

1. **Bash validators** (`.opencode/scripts/validate-skills.sh` extension). The prior art — `scripts/__tests__/validate-skills.bats` — is the exact shape we extend: bats tests point the validator at a temp fixture tree via env overrides (`SKILLS_ROOT` for the project tree; new `GLOBAL_SKILLS_ROOT` for the global tree) so the real project config is never mutated by tests. Tests assert observable behavior (exit code, stderr/stdout content), not implementation details.
2. **Config surface changes** (4-source agent registration, `opencode.jsonc` description edit, `NEXT-RUN.md` doc addition). These are not meaningfully unit-testable in bats — they are structural invariants enforced by the existing `scripts/validate-agent-names.sh` (for the 4-source contract) + by §10 Phase-5 restart+smoke (for runtime dispatchability + read-only enforcement). The test strategy is: (a) real-config run of `validate-agent-names.sh` must report `22 passed, 0 failed, 0 warnings` (post-change baseline); (b) `make test-config` + `make test-skills` exit 0; (c) §10 Phase-5 restart+smoke is the behavioural test for `@ai-auditor` dispatch + read-only enforcement.

We do NOT test by:

- Booting OpenCode to see if the `@ai-auditor` agent loads — that is a runtime integration concern covered by §10 Phase-5 smoke. The structural assertion "the name is registered across all 4 sources" is exactly what `validate-agent-names.sh` guarantees.
- Loading a JSON schema for `oh-my-opencode-slim.jsonc` — no upstream schema exists (Q7 known gap). The validator's current parsing is the contract.

### Modules under test

| Module                                                                                  | Test type                                                 | Gate                                   |
| --------------------------------------------------------------------------------------- | --------------------------------------------------------- | -------------------------------------- |
| `.opencode/scripts/validate-skills.sh` (extended with dup detection)                    | bats unit                                                 | `make test-skills` / `make test-shell` |
| `scripts/__tests__/validate-skills.bats` (extended with dup-detection cases)            | bats suite                                                | `make test-shell`                      |
| `.opencode/opencode.jsonc` (`ai-auditor` read-only block + `ai-specialist` description) | `validate-agent-names.sh` real-config + §10 Phase-5 smoke | `make test-config` + manual smoke      |
| `.opencode/oh-my-opencode-slim.jsonc` (`ai-auditor` in agents + 3 presets)              | `validate-agent-names.sh` real-config                     | `make test-config`                     |
| `.opencode/agents/ai-auditor.md` (new file)                                             | `validate-agent-names.sh` S4 extraction                   | `make test-config`                     |
| `AGENTS.md` §9 (new `ai-auditor` row)                                                   | `validate-agent-names.sh` S1 extraction                   | `make test-config`                     |
| `docs/dev-infra-audit/NEXT-RUN.md` §2 (council budget rule)                             | visual review (no automated test)                         | n/a                                    |
| 5 skill-dir deletions under `.opencode/skills/`                                         | `validate-skills.sh` real-config                          | `make test-skills`                     |

### Fixture matrix (dup-detection extension to validate-skills.bats)

The bats tests for the dup-detection extension use a fixture matrix of temp-directory layouts. Same shape as the existing `validate-skills.bats` `SKILLS_ROOT` override, extended with `GLOBAL_SKILLS_ROOT`.

| #   | Case                                                                               | Expected exit | Expected output                                                                                  |
| --- | ---------------------------------------------------------------------------------- | ------------- | ------------------------------------------------------------------------------------------------ |
| 1   | Valid: no duplicates between project and global skills dirs                        | 0             | stdout `ok:` lines; final `N passed, 0 failed, 0 warnings`                                       |
| 2   | Byte-exact duplicate between project and global (same SKILL.md content, same hash) | 1             | stderr `FAIL: duplicate skill '<name>' (byte-exact match with global '<global-path>')`; HARD     |
| 3   | Near-duplicate (different whitespace / minor comment drift)                        | 0             | stderr `warn: near-duplicate skill '<name>' (differs from global '<global-path>')`; SOFT, exit 0 |
| 4   | Empty project skills dir (no skill subdirs)                                        | 0             | `0 passed, 0 failed, 0 warnings`                                                                 |
| 5   | Missing global skills dir (GLOBAL_SKILLS_ROOT points at nonexistent path)          | 2             | stderr `FAIL:` line (INFRA — cannot locate global skills dir for comparison); exit 2             |
| 6   | Multiple duplicates in one run (collect-all discipline)                            | 1             | stderr `FAIL:` line per duplicate; final summary aggregates HARD failures; exit 1                |

### Prior art in the codebase

- **`.opencode/scripts/validate-skills.sh`** — the immediate prior art. Same 3-tier exit contract, same `SKILLS_ROOT` env override, same HARD/SOFT partition, same collect-all discipline. The dup-detection extension reuses this shape with a new `GLOBAL_SKILLS_ROOT` env override for the global-side fixture.
- **`scripts/__tests__/validate-skills.bats`** — the immediate bats prior art. Same `SKILLS_ROOT` env override pattern; extended with `GLOBAL_SKILLS_ROOT`.
- **`scripts/validate-agent-names.sh`** — the 4-source validator that will mechanically prove the `@ai-auditor` registration is consistent post-change.
- **`.opencode/agents/memory-manager.md`** — frontmatter pattern for `ai-auditor.md` (description + mode only; permissions live in `opencode.jsonc`).

### Test risk and mitigation

**Risk:** byte-exact dup detection via `sha256sum` is sensitive to line-ending drift (CRLF vs LF) and trailing whitespace. **Mitigation:** the script-header documents the case-sensitive exact + follow-symlinks policy; bats fixtures use controlled line endings via `printf`. A future need for normalized comparison is a design change, not an overloading of this check.

**Risk:** the near-duplicate `diff -r` check may produce noisy output when the two trees have structural differences beyond the skill files themselves. **Mitigation:** `diff -r` is invoked per-skill-pair (not across the whole tree), so only the specific skill directory is compared. bats fixtures cover both the HARD and SOFT branches explicitly.

**Risk:** `GLOBAL_SKILLS_ROOT` defaulting to `~/.config/opencode/skills` means bats tests must set the override or they will walk the developer's actual global skills dir. **Mitigation:** every bats test sets `GLOBAL_SKILLS_ROOT` explicitly via `$BATS_TEST_TMPDIR`; the default path is only used in production (make-callable) invocation. The missing-global-dir fixture (case 5) exercises the exit-2 path with a bogus override.

## Rollback plan

Rollback is trivial because this change has no persistent-state impact:

1. **`git revert <merge-commit>`** — reverts all file changes (including the 5 skill-dir deletions, which git restore recovers in full).
2. **`make test-skills`** — re-runs the skills gate (now without dup detection); the pre-existing baseline (all frontmatter checks pass) must still pass.
3. **`make test-config`** — re-runs the config-validation gate (now without the `@ai-auditor` 4-source registration + without the narrowed `@ai-specialist` description); the pre-existing `validate-agent-names.sh` baseline (21 passed) must still pass.
4. **`make test-shell`** — bats re-runs at the pre-existing baseline + the new dup-detection cases (which are themselves rolled back).

No data migration is needed. The 5 deleted skill directories are recovered in full by `git revert` (git tracks empty-dir content via the files they contain). The `NEXT-RUN.md` §2 addition is reverted. The `.opencode/agents/ai-auditor.md` file is deleted on revert.

**Rollback risk:** very low. The change is a bounded dev-infra + AI-tooling-config addition (validator extension + bats + 4-source registration + doc addition + 5 skill-dir deletions) with no application-code impact and no persistent-state impact.
