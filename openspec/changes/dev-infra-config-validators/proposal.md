# Proposal: dev-infra-config-validators

> **Status:** proposed · **Scope:** dev-infra (`scripts/`, `Makefile`, bats test scaffolding) + AI-tooling config cross-reference integrity (4 agent-name sources + `HANDOFF.md` prognosis schema). No application code touched.
> **Escalation:** none — change stays within existing module boundaries. Per AGENTS.md §2.4 (dev-infra within existing boundaries → spec chain + `@reviewer`), no `@architector` dispatch is required.
> **Source tickets:** `docs/dev-infra-audit/tickets/DIA-045.md` (audit-gaps 1–3: agent-name cross-ref validator + HANDOFF schema validator + fragmented agent-name sources) and `DIA-050` (new tracking note — the `.mise.toml` ↔ `Dockerfile.dev` pin-sync gap carried as F15 of DIA-045). All decisions below trace to owner-confirmed interview rulings (Q1, Q2 × 7, Q4, Q5).

## Motivation

DIA-045's 2026-08-04 ai-specialist review surfaced three audit gaps that ship as latent drift risk in the opencode config surface:

1. **Audit gap 1 — no cross-reference validator for agent names.** The project's agent canonical name (kebab-case internal form, per AGENTS.md §9) is declared in four independent sources that must stay coherent under a **containment** contract (each §9 name resolves somewhere in S2∪S3∪S4∪exempt; each config-declared name in S2∪S3 appears in §9 — per owner ruling row 420):
   - AGENTS.md §9 table, "Internal name" column (the canonical display→internal mapping).
   - `.opencode/opencode.jsonc` — the `agents { <name> { ... } }` block keys (project-scoped).
   - `.opencode/oh-my-opencode-slim.jsonc` — the `agents { <name> { ... } }` keys AND the values referenced by `routing` / preset assignments.
   - `.opencode/agents/<name>.md` — the file-stem of each agent definition in the project-scoped agent directory.

   Today, a rename in one source can silently drift from the others. The §10 cleanup lane has already been bitten by this: DIA-045's fix sweep covered `ai_specialist` / `resource_manager` → `ai-specialist` / `resource-manager` renames, and the F18 finding for the vestigial `explorer` agent showed that a name can linger in one source while being removed from others. The drift mode is "no test fails, but dispatch-by-name silently misses at runtime".

2. **Audit gap 2 — no HANDOFF.md schema validator.** `openspec/templates/HANDOFF.md` declares the Prognosis schema (5 required `###` subsections under `## Prognosis for next cycle` — `session_summary` / `fixes_applied` / `open_tickets` / `verification_request` / `resume_instructions`). The fresh-session verifier contract depends on all five being present and correctly named. A typo in any subsection heading (e.g. `session_sumary`, `fixes_aplied`) silently breaks batch-approval boot without any gate catching it.

3. **Audit gap 3 — agent-name sources are fragmented across 5 files.** This gap is structural; the validator for gap 1 is the remediation.

The DIA-045 fix sweep addressed the _current_ drift instances. This change addresses the _recurrence risk_: it installs deterministic, hermetic, collect-all validators that fail the build before drift ships.

## Scope

### In scope (two validators + one tracking note + Makefile wiring)

1. **T1 — DIA-050/F15 tracking note.** Create `docs/dev-infra-audit/tickets/DIA-050.md` as a cross-ref bookkeeping placeholder carrying the `.mise.toml` ↔ `Dockerfile.dev` pin-sync gap (DIA-045 F15) as its body. Non-code deliverable; no Makefile target, no tests. The new ticket is referenced by this change's proposal for traceability but its remediation is out of scope here.
2. **T2 — `scripts/validate-agent-names.sh` + `scripts/__tests__/validate-agent-names.bats`.** Cross-reference validator for the 4 agent-name sources listed above. Exit-code contract + stream contract per §Design. bats coverage per §Testing Decisions. **Contract (owner ruling row 420, supersedes strict 4-way lockstep + row-415 amendment):** declared-⊆-resolved containment semantics — (a) every §9 name must resolve in S2∪S3∪S4-or-exempt; (b) every S2∪S3 name must appear in §9. Council KEY-only read (the top-level `council` block makes the name `council` S3-valid; its model-seat members are NOT extracted). S4-exemption retained for the 6 built-ins/native-aliases (`explore`, `general`, `oracle`, `fixer`, `explorer`, `librarian`).
3. **T3 — `scripts/validate-handoff.sh` + `scripts/__tests__/validate-handoff.bats`.** HANDOFF.md prognosis-schema validator. Takes a HANDOFF file path as argument (exact-name only — no glob, per Q2 ruling). Asserts the `## Prognosis for next cycle` heading plus the 5 required `###` subsections (strict literal match, per Q2 ruling). Extra `###` subsections are a SOFT warning (do not flip exit code, join the soft-warnings bucket, per Q5 ruling).
4. **T4 — Makefile wiring.** Both validators wired into the existing `make test-config` target (alongside the pre-existing `validate-skills.sh` and `validate-opencode-config.sh`). No new `test-dev-infra` target (per Q4 ruling). Both scripts are make-callable and have a standalone exit-code contract so they can be invoked outside Make too.

### Out of scope (explicitly deferred — interview-confirmed)

- **Global config (`~/.config/opencode/opencode.jsonc`).** OUT of scope (Q2 ruling). The validator walks only project-scoped sources. A future change may add a companion global-config sweep; this one does not.
- **Remediation of DIA-045 F15 (the `.mise.toml` ↔ `Dockerfile.dev` pin-sync gap).** Tracked as DIA-050, not closed by this change.
- **Remediation of DIA-045's other still-open findings (F19/F20/F22).** Orthogonal; not touched.
- **Glob-based HANDOFF discovery.** The validator takes an exact path. Discovery of HANDOFF files is the caller's concern (Make wiring points at the template only, not at cycle-produced HANDOFF files).
- **Any `.sdd/` module doc authoring.** See Design authority section below.
- **Anything beyond the two validators + the tracking note + the Makefile wiring.**

## Design authority (.sdd/) reference

**No `.sdd/` module doc governs this change.** The `.sdd/` directory contains only `.sdd/dia-redispatch-cycle/architecture.md` (DIA cycle protocol) and `.sdd/README.md`. Neither `scripts/validate-*.sh` nor the agent-name sources (`.opencode/opencode.jsonc`, `.opencode/oh-my-opencode-slim.jsonc`, `.opencode/agents/*.md`, `AGENTS.md`) have an `.sdd/` entry.

This is the same precedent as `openspec/changes/dev-infra-copilot-fixes/proposal.md` §Design authority and `openspec/changes/volta-to-mise/proposal.md` §Design authority (.sdd/) reference: bounded dev-infra within existing boundaries does not require architectural escalation. Per AGENTS.md §3, the absence of a governing `.sdd/` is a documentation gap, but one this change does not fill.

**Relevant existing patterns this change follows:**

- **Standalone shell validators with 3-tier exit codes** — `.opencode/scripts/validate-skills.sh` (the immediate prior art; same `exit 0 / exit 1 / exit 2` contract, same HARD vs SOFT partition, same collect-all-never-fail-fast discipline, same stderr/stdout stream protocol).
- **bats meta-tests on validators** — `scripts/__tests__/validate-skills.bats` uses `SKILLS_ROOT` env override to point the validator at a temp fixture tree; this change's bats tests follow the same shape (env override for source root / HANDOFF path).
- **`test-helper.bash` assertion vocabulary** — `assert_status`, `assert_output_contains`, `assert_file_contains` reused verbatim; no new assertions added.
- **Makefile `test-config` target pattern** — already aggregates `test-interview`, `test-skills`, and `validate-opencode-config.sh` as prereqs + recipe lines; the two new validators slot in as additional recipe lines (shape decision for the coder lane; see design.md §Makefile wiring).

## Success criteria

1. **Agent-name drift is hermetically caught.** Any future rename in one of the 4 sources that is not mirrored in the others fails `make test-config` with a clear `FAIL:` line naming the offending source pair. Disabled agents are NOT excluded (Q2 ruling).
2. **HANDOFF.md schema regressions are caught.** A HANDOFF file missing any of the 5 required `###` subsections (or the `## Prognosis for next cycle` heading itself) fails the validator with a clear `FAIL:` line. Extra subsections warn to stderr but do not flip the exit code.
3. **Both validators are wired into `make test-config`.** `make test-config` exercises both; no new `test-dev-infra` target is introduced.
4. **Baselines preserved.** `make test-shell` remains at 93/93 bats tests. `make test-config` preserves the pre-existing 20 passed / 0 failed / 33 soft-warnings baseline of `validate-opencode-config.sh` and adds the two new validators' pass/warn counts.
5. **JSONC parse failure is a HARD fail (Q2 ruling).** If either project JSONC config cannot be parsed, the agent-name validator exits 1 (not 0, not 2 — 2 is reserved for infrastructure errors like missing directories).
6. **Rollback is trivial.** `git revert` of the merge commit + `make test-config` restores the pre-change state. No data migration, no persistent-state change.

## Non-goals

- **Resolving DIA-045's still-open findings.** Tracked separately.
- **Resolving DIA-050's underlying `.mise.toml` pin-sync gap.** Tracked as DIA-050; this change only creates the tracking ticket.
- **Validating the global opencode config (`~/.config/opencode/opencode.jsonc`).** OUT of scope (Q2).
- **Glob-based HANDOFF discovery.** The validator is exact-name only (Q2).
- **Adding a new Makefile top-level target (e.g. `test-dev-infra`).** OUT of scope (Q4).
- **Authoring a `.sdd/` module doc.** OUT of scope (precedent allows).
- **Any change beyond the 4 tasks listed.**

## Stakeholders

| Stakeholder                      | Interest                                                                                                                                      |
| -------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Orchestrator                     | `make test-config` catches agent-name drift and HANDOFF schema regressions at PR time, not at runtime.                                        |
| Fresh-session verifier           | HANDOFF schema is enforced mechanically; the verifier no longer has to hand-check the 5-subsection contract.                                  |
| `@ai-specialist` (§10 reviewers) | The agent-name validator reduces the surface of §10 config-drift reviews — the validator pre-catches the mechanical part of the audit.        |
| `@reviewer` (§2.4 reviewers)     | The wiring is inside the dev-infra review lane; the two new bats suites give the reviewer concrete test evidence, not just visual inspection. |
| DIA audit trail                  | DIA-045 audit gaps 1–2 move from FUTURE to RESOLVED. DIA-045 F15 is spun out to DIA-050 for separate tracking.                                |

## Testing Decisions

> Per `openspec/config.yaml`: "Include a Testing Decisions section that states what makes a good test for this change, which modules will be tested, and the prior art in the codebase."

### What makes a good test here

The artifacts under test are bash scripts that parse text files (markdown, JSONC) and assert structural properties. The prior art — `.opencode/scripts/validate-skills.sh` + `scripts/__tests__/validate-skills.bats` — is the exact shape we copy: a standalone script with a 3-tier exit contract, driven by bats tests that point the script at a temp fixture tree via an env override (so the real project config is never mutated by tests). Tests assert observable behavior (exit code, stderr/stdout content), not implementation details (line counts, specific regex forms).

We do NOT test by:

- Loading real JSONC files with a JSON parser and trusting the parser to catch malformed JSONC — we test the script's actual JSONC-handling path (which uses `python3 -c '...'` inline, same as `validate-skills.sh`).
- Booting OpenCode to see if agent-name drift breaks dispatch — that is a runtime integration concern outside this change's scope. The structural assertion "the names match" is exactly what we want to guarantee.

### Modules under test

| Module                                                    | Test type                               | Gate              |
| --------------------------------------------------------- | --------------------------------------- | ----------------- |
| `scripts/validate-agent-names.sh` (new)                   | bats unit (`S1`)                        | `make test-shell` |
| `scripts/__tests__/validate-agent-names.bats` (new)       | bats suite                              | `make test-shell` |
| `scripts/validate-handoff.sh` (new)                       | bats unit (`S2`)                        | `make test-shell` |
| `scripts/__tests__/validate-handoff.bats` (new)           | bats suite                              | `make test-shell` |
| `scripts/__tests__/test-helper.bash` (extended)           | bats helper additions                   | `make test-shell` |
| `scripts/__tests__/bats-wrapper.sh` (extended)            | `bash -n` syntax-check loop additions   | `make test-shell` |
| `Makefile` (`test-config` target)                         | wiring regression bats test (new, `S3`) | `make test-shell` |
| `docs/dev-infra-audit/tickets/DIA-050.md` (new, non-code) | visual review (no automated test)       | n/a               |

### Fixture matrix

The bats tests for each validator use a fixture matrix of temp-directory layouts. Same shape as `validate-skills.bats`'s `SKILLS_ROOT` override.

**validate-agent-names fixture matrix (8 cases):**

| #   | Case                                                                                                                              | Expected exit | Expected output                                                                                                                                                                                                                                                                                  |
| --- | --------------------------------------------------------------------------------------------------------------------------------- | ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | Valid: all §9 names resolve + all S2∪S3 names canonical (2 agents, one disabled)                                                  | 0             | stdout `ok:` lines, final `N passed, 0 failed, 0 warnings`                                                                                                                                                                                                                                       |
| 2   | Agent-name mismatch: stem in `agents/` differs from `opencode.jsonc` key                                                          | 1             | stderr `FAIL:` line naming the mismatch; final `N passed, 1 failed, 0 warnings`                                                                                                                                                                                                                  |
| 3   | Disabled-agent mismatch: non-exempt agent in `disabled_agents` list with name differing across sources                            | 1             | stderr `FAIL:` line (disabled agents STILL validated per Q2 ruling — the 6-name exempt set is the only exception, per row-420 declared-⊆-resolved contract); final `N passed, 1 failed, 0 warnings`                                                                                              |
| 4   | JSONC parse error in `opencode.jsonc`                                                                                             | 1             | stderr `FAIL:` line (HARD fail per Q2 ruling — parse error is NOT exit 2); final `N passed, 1 failed, 0 warnings`                                                                                                                                                                                |
| 5   | Empty `agents/` directory                                                                                                         | 0             | `0/0/0` line: `0 passed, 0 failed, 0 warnings` (per Q5 ruling — empty dir is OK)                                                                                                                                                                                                                 |
| 6   | Missing `AGENTS.md` (source absent)                                                                                               | 2             | stderr `FAIL:` line (INFRA error, not HARD); final `N passed, 0 failed, 0 warnings` — exit code 2                                                                                                                                                                                                |
| 7   | Missing required routing reference in oh-my-opencode-slim.jsonc                                                                   | 1             | stderr `FAIL:` line; final `N passed, 1 failed, 0 warnings`                                                                                                                                                                                                                                      |
| 8   | S3 council-KEY-only read: top-level `council` block with model-seat members (NOT treated as agents) + exempt-name-without-S4-file | 0             | council KEY presence makes `council` S3-valid; model-seat members (`deepseek`, `gemini-3.1-pro`, etc.) are NOT extracted as agent names (owner ruling row 420); exempt name accepted with no S4 file required; stdout `ok:` lines; PASS path validating the row-420 declared-⊆-resolved contract |

**validate-handoff fixture matrix (4 cases):**

| #   | Case                                                       | Expected exit | Expected output                                                                                  |
| --- | ---------------------------------------------------------- | ------------- | ------------------------------------------------------------------------------------------------ |
| 1   | Valid HANDOFF with all 5 required subsections              | 0             | stdout `ok:` lines; final `5 passed, 0 failed, 0 warnings`                                       |
| 2   | Missing one required `###` subsection                      | 1             | stderr `FAIL:` line naming the missing subsection; final `4 passed, 1 failed, 0 warnings`        |
| 3   | Missing `## Prognosis for next cycle` heading              | 1             | stderr `FAIL:` line; final `0 passed, 1 failed, 0 warnings`                                      |
| 4   | Extra `###` subsection beyond the required 5               | 0             | stderr `warn:` line for the extra heading (SOFT); final `5 passed, 0 failed, 1 warnings`; exit 0 |
| 5   | Missing input file (no argument / nonexistent path)        | 2             | stderr `FAIL:` line (INFRA); exit 2                                                              |
| 6   | Missing `openspec/templates/HANDOFF.md` reference template | 2             | stderr `FAIL:` line (INFRA — cannot locate reference template); exit 2                           |

**Wiring regression (1 case):**

| #   | Case                                                                                                     | Expected exit   | Expected output                                   |
| --- | -------------------------------------------------------------------------------------------------------- | --------------- | ------------------------------------------------- |
| 1   | `Makefile` `test-config` target body references both `validate-agent-names.sh` and `validate-handoff.sh` | 0 (test passes) | bats asserts file contains both script references |

### Prior art in the codebase

- **`.opencode/scripts/validate-skills.sh`** — the immediate prior art. Same 3-tier exit contract, same HARD/SOFT partition, same collect-all discipline, same stderr/stdout stream protocol. This change's two validators are near-clones of its shape with different predicates.
- **`scripts/__tests__/validate-skills.bats`** — the immediate bats prior art. Same `SKILLS_ROOT` env override pattern; this change uses `AGENTS_ROOT` / `HANDOFF_FILE` overrides.
- **`scripts/__tests__/test-helper.bash`** — `assert_status`, `assert_output_contains`, `assert_file_contains` reused verbatim.
- **`.opencode/scripts/validate-opencode-config.sh`** — peer validator (JSONC syntax checks); already wired into `make test-config`. The new validators are peers of this one, not replacements.
- **`Makefile` `test-config` target** (lines 131–132) — the wiring seam. Already aggregates `test-interview`, `test-skills`, and `validate-opencode-config.sh`; the two new validators slot in as additional recipe lines.

### Test risk and mitigation

**Risk:** the agent-name validator parses JSONC (which is JSON-with-comments). JSONC parsing in bash without a dedicated tool requires an inline parser that strips comments before feeding JSON. **Mitigation:** reuse the same `python3 -c '...'` inline strategy as `validate-skills.sh` (Python `json` module after comment-strip); bats tests include a JSONC-parse-error case (fixture matrix case 4) that verifies HARD fail, not silent acceptance.

**Risk:** AGENTS.md §9 is markdown, not machine-readable. Extracting the "Internal name" column requires grep/awk with knowledge of the table layout. **Mitigation:** the validator is intentionally narrow — it greps for the §9 heading, then walks the table rows. A regression in the table layout is caught by the wiring test (the validator would exit 2, not 0). Bats tests cover the happy-path layout; future layout changes must update the validator in lockstep (enforced by the wiring regression test).

**Risk:** the validator reads `.opencode/agents/*.md` filename stems. If a developer adds a new `.md` file that is not an agent definition (e.g., a README), the validator will include it and produce a spurious mismatch. **Mitigation:** the validator documents that every `.md` file in `.opencode/agents/` is an agent definition (this is already the convention; `.opencode/agents/` currently contains only `memory-manager.md`). A future need for non-agent markdown in that directory is a design change that would require re-scoping the validator (out of scope for this change).

## Rollback plan

Rollback is trivial because this change has no persistent-state impact:

1. **`git revert <merge-commit>`** — reverts all file changes.
2. **`make test-config`** — re-runs the config-validation gate (now without the two new validators wired in); the pre-existing baseline (20 passed / 0 failed / 33 soft warnings from `validate-opencode-config.sh` + the `test-interview` and `test-skills` prereqs) must still pass.
3. **`make test-shell`** — bats re-runs at 93/93 baseline.

No data migration is needed. DIA-050 is deleted on revert (it was created by this change). The only things that need to exist after rollback are the original `Makefile` `test-config` recipe and the original bats-wrapper.sh syntax-check loop.

**Rollback risk:** very low. The change is a bounded dev-infra addition (two new scripts, two new bats suites, one Makefile extension, one tracking ticket) with no application-code impact and no persistent-state impact.
