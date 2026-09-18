# Design: test-skills-gate

> **Proposal:** `openspec/changes/test-skills-gate/proposal.md`
> **Scope:** dev-infra only — no system architecture decisions, no `.sdd/` escalation required.

## Approach

This change stays within the existing dev-infra module boundary. No new module is introduced, no cross-cutting technology decision is made, and `architecture.md` is not affected. The design follows established patterns in the codebase:

- **Validation-script pattern:** reuse the exact structure of `.opencode/scripts/validate-opencode-config.sh` — a single bash script with `set -euo pipefail`, a `ROOT` variable, a `failures` counter, and exit codes 0/1/2. The new script is structurally identical; only the checks differ.
- **Inline-python3 parsing pattern:** reuse the exact `python3 - "$file" <<'PYEOF'` pattern from `validate-opencode-config.sh` for JSONC parsing. The new script uses the same technique for YAML frontmatter extraction and parsing.
- **Collect-all error strategy:** reuse the exact pattern from `validate-opencode-config.sh` — accumulate failures in a counter, print all errors, exit 1 at the end if any failures occurred. NOT fail-fast.
- **bats meta-test pattern:** reuse the temp-tree isolation pattern from `scripts/__tests__/dev-stack.bats` — copy the script + fixtures into `$BATS_TEST_TMPDIR`, override the skills root via an env var, and assert exit code + output.
- **Makefile target pattern:** reuse the exact pattern of `test-interview:` (a one-line target calling `bash scripts/<name>.sh`) and wire it into `test-config:` as a sibling prerequisite.
- **Assertion-helper pattern:** reuse `scripts/__tests__/test-helper.bash` (`assert_status`, `assert_output_contains`, `assert_output_not_contains`).

## Seams

Public boundaries where tests will live:

| Seam                                                           | Test location                                              | What it covers                                                                                                                                                                                    |
| -------------------------------------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.opencode/scripts/validate-skills.sh` CLI contract            | `scripts/__tests__/validate-skills.bats`                   | Exit codes (0/1/2), HARD checks (YAML valid, name+description present+non-empty, name==dirname), SOFT checks (activation-phrase, license), collect-all strategy, env-var override for skills root |
| `.opencode/scripts/validate-skills.sh` infrastructure contract | `scripts/__tests__/validate-skills.bats`                   | Exit 2 when python3 unavailable, exit 2 when skills directory missing                                                                                                                             |
| Makefile `test-skills:` target                                 | Manual verification (documented in T3 acceptance criteria) | Target invokes the script; `make test-config` runs `test-interview`, `test-skills`, and `validate-opencode-config.sh`                                                                             |
| `scripts/__tests__/bats-wrapper.sh`                            | Self-check (existing test infra)                           | Syntax-checks the new script via `bash -n`                                                                                                                                                        |

## Files changed

| File                                     | Change                                                                                                                                                                                                                | Traced to            |
| ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------- |
| `.opencode/scripts/validate-skills.sh`   | New file. Walks `.opencode/skills/*/SKILL.md`, extracts YAML frontmatter, runs HARD + SOFT checks. Exit codes 0/1/2. Accepts optional `SKILLS_ROOT` env var for test override (defaults to `$ROOT/.opencode/skills`). | Proposal §In scope 1 |
| `scripts/__tests__/validate-skills.bats` | New bats test file. Temp-fixture meta-tests covering all HARD/SOFT checks, exit codes, collect-all strategy, infrastructure failures.                                                                                 | Proposal §In scope 3 |
| `scripts/__tests__/bats-wrapper.sh`      | Extend the syntax-check loop to include `.opencode/scripts/validate-skills.sh`.                                                                                                                                       | Test infra           |
| `Makefile`                               | (1) Add `test-skills:` target: `bash .opencode/scripts/validate-skills.sh`. (2) Extend `test-config:` dependency chain: `test-config: test-interview test-skills`. (3) Add `test-skills` to `.PHONY`.                 | Proposal §In scope 2 |

## Decision rationale

### D1: Script location — `.opencode/scripts/validate-skills.sh`

**Decision:** The script lives at `.opencode/scripts/validate-skills.sh` (alongside the existing `validate-opencode-config.sh`).

**Traced to:** Consistency. The script validates `.opencode/skills/` content; it belongs in `.opencode/scripts/` alongside the existing config validator. The project already has two script directories: `scripts/` (general dev-infra) and `.opencode/scripts/` (OpenCode-specific validation). This script is OpenCode-specific.

**Alternatives considered:** `scripts/validate-skills.sh` — rejected because it would be the only OpenCode-specific script in the general `scripts/` directory.

### D2: YAML parsing — inline python3 with PyYAML + fallback

**Decision:** The script uses `python3 - "$frontmatter_file" <<'PYEOF'` to parse the extracted YAML frontmatter. PyYAML is tried first (`import yaml`); if unavailable, a stdlib-only fallback parser is used (a minimal YAML-subset parser that handles the flat key-value frontmatter structure of SKILL.md files — a _permissive_ subset that validates top-level `key:` lines but does not reject nested content, with `>-` block chomping as the only multi-line scalar form).

**Traced to:** Zero-new-dependency principle. python3 is already available in the dev container (it's used by `validate-opencode-config.sh` for JSONC parsing, by `verify-python.sh` for pytest, and by `test-interview-enforcement.sh` for OMO preset validation). PyYAML may or may not be installed — the fallback ensures the script works in any environment with python3, including bare CI runners or developer machines without the project's venv activated.

**Why not a pure-bash YAML parser?** YAML is context-sensitive (indentation, quoting, multi-line scalars). A bash-only parser would be fragile and hard to test. python3 is a known-good dependency for this project.

**Why not require PyYAML?** The script must work in the dev container (where PyYAML is NOT installed by default — only `apps/api-server/.venv` has it, and the script runs on the host or in the dev container's system python, not the venv). Requiring PyYAML would either force an apt-get install (new dependency) or a pip install (requires venv activation). The fallback avoids both.

**Fallback parser scope:** The SKILL.md frontmatter is a flat YAML document with scalar values (strings, occasionally `>-` block scalars for `description:`). The fallback is a **permissive subset parser** — it validates top-level `key:` lines and rejects non-`key:` top-level lines and non-mapping roots, but it does NOT reject nested content. It handles:

- `key: value` (quoted or unquoted scalars)
- `key: >-` (block scalar — collect indented continuation lines, joined with spaces)
- Comments (`# ...`)
- Blank lines

It does NOT handle literal block style (`|`), arrays, or anchors. **Actual behavior on nested content:** the fallback parser _silently skips_ indented lines that are not part of a `>-` block scalar, tolerating the nested `metadata:` blocks present in 17 of 19 skills (a strict flat parser would false-positive on them; only `frontend-design` and `writing-skills` are truly flat). One skill (book-rag) uses a `>-` block scalar for `description:`. The parser does NOT report a parse error for nested maps — it ignores their inner lines and continues validating the top-level keys. A parse error is raised only for a non-`key:` top-level line or a non-mapping root (bare scalar / list), which is treated the same as a PyYAML parse error and fails the file.

### D3: Frontmatter extraction — bash `---` delimiter scan

**Decision:** The script extracts frontmatter by scanning for the first two `---` delimiters at the start of a line. Everything between them (exclusive) is the YAML frontmatter. Everything after the second `---` is the body.

**Traced to:** This is the exact format OpenCode uses to parse SKILL.md files. The extraction logic must match OpenCode's parser to be a valid gate.

**Edge cases:**

- A file with no `---` delimiters → no frontmatter → HARD failure (YAML parse error on empty input, or explicit "no frontmatter" check).
- A file with only one `---` → truncated frontmatter → HARD failure (YAML parse error).
- A file where `---` appears mid-line (e.g., `some text --- more text`) → not a delimiter (the script checks for `^---$`, i.e., `---` as the entire line).

### D4: HARD checks — YAML valid, name+description present+non-empty, name==dirname

**Decision:** Four HARD checks per SKILL.md:

1. Frontmatter parses as valid YAML (or valid YAML-subset via fallback).
2. `name` field is present and non-empty.
3. `description` field is present and non-empty.
4. `name` field value equals the parent directory name (e.g., `name: openspec-propose` must live in `.opencode/skills/openspec-propose/`).

**Traced to:** These are the minimum checks that catch the silent failures described in the proposal §Motivation. Each check maps to a specific failure mode:

- Check 1 → catches broken YAML that makes the skill un-loadable.
- Check 2 → catches skills that load with a blank name.
- Check 3 → catches skills that load with a blank description (which breaks OpenCode's skill-matching logic).
- Check 4 → catches name/directory drift that causes agent dispatch divergence.

**Why not more HARD checks?** Additional checks (e.g., `allowed-tools` format, `compatibility` values, `metadata` structure) are out of scope — they require a schema definition that does not yet exist. The four HARD checks are the minimum viable gate.

### D5: SOFT checks — activation-phrase prefix, license notice

**Decision:** Two SOFT checks per SKILL.md (warn-only, do NOT affect exit code):

1. The body (first non-blank line after the second `---`) starts with an activation-phrase prefix: `"Use when"`, `"Invoke when"`, `"Trigger via"`, `"Use for"`, `"Use ONLY when"` (case-insensitive).
2. The frontmatter contains a `license:` field with a non-empty value.

**Traced to:** Proposal §Motivation items 4 and 5. These are real concerns (activation-phrase drift and license provenance) but the signal is not reliable enough to block on:

- Some skills legitimately have non-standard activation patterns (e.g., `book-rag` uses an "OPT-IN ONLY" rule, not a "Use when" phrase).
- License provenance is an audit concern, not a runtime concern. A missing `license:` field does not break skill loading.

**Why not promote to HARD later?** This decision can be revisited after the team observes the warning output for a few weeks. If the warnings are consistently actionable, a follow-up change can promote them. If the warnings are noisy (false positives on legitimate skills), the check list can be narrowed.

### D6: Env-var override for skills root — `SKILLS_ROOT`

**Decision:** The script accepts an optional `SKILLS_ROOT` env var that overrides the default skills root (`$ROOT/.opencode/skills`). If `SKILLS_ROOT` is set, the script validates the skills in that directory instead.

**Traced to:** Testability. The bats meta-tests need to run the script against temp fixture directories, not the real `.opencode/skills/`. An env-var override is the simplest, most explicit mechanism — no temp-directory monkey-patching, no argument parsing.

**Why not a CLI argument?** An env var is simpler for bats tests (`SKILLS_ROOT="$fixture_dir" run bash "$script"`) and matches the existing pattern in `test-interview-enforcement.sh` (which uses hardcoded paths but could be refactored to use env vars in the future). A CLI argument would require getopt parsing, which is overkill for a single optional override.

### D7: Collect-all error strategy (not fail-fast)

**Decision:** The script accumulates all HARD failures in a counter, prints all errors to stderr, and exits 1 at the end if any failures occurred. It does NOT stop at the first broken skill.

**Traced to:** Developer experience. A developer who introduces 3 broken skills should see all 3 errors in a single run, not fix one, re-run, fix the next, re-run, etc. This matches the established pattern in `validate-opencode-config.sh` (which counts failures and exits 1 at the end).

### D8: Exit code contract — 0/1/2

**Decision:**

- `0` — all skills pass all HARD checks (SOFT warnings may be present on stderr).
- `1` — at least one HARD check failed (errors on stderr).
- `2` — infrastructure failure (python3 unavailable, skills directory missing, etc.).

**Traced to:** Consistency with `validate-opencode-config.sh` (exit 0 all valid, 1 validation failure, 2 node unavailable). The 2-code for infrastructure failures makes it easy to distinguish "the script works but found problems" (exit 1) from "the script itself is broken or the environment is misconfigured" (exit 2).

## Edge cases

### E1: SKILL.md with no frontmatter (no `---` delimiters)

The script detects the absence of frontmatter and reports a HARD failure: "no frontmatter found (expected `---` delimiters)." Exit 1 for that file.

### E2: SKILL.md with only one `---` delimiter

The script detects the truncated frontmatter and reports a HARD failure: "truncated frontmatter (expected two `---` delimiters, found one)." Exit 1 for that file.

### E3: SKILL.md with empty frontmatter (two `---` delimiters with nothing between them)

The YAML parser receives an empty string. PyYAML parses this as `None` (valid YAML, but not a mapping). The script detects the absence of `name` and `description` fields and reports HARD failures for both. Exit 1 for that file.

### E4: SKILL.md with valid YAML but non-mapping root (e.g., a bare scalar or list)

The YAML parser succeeds but the result is not a mapping (dict). The script detects this and reports a HARD failure: "frontmatter is not a YAML mapping (expected key-value pairs)." Exit 1 for that file.

### E5: `name` field with whitespace differences

The script compares `name` to the directory name using exact string equality (no trimming). If `name: " openspec-propose "` (with leading/trailing spaces), it does NOT match `openspec-propose`. This is deliberate — YAML parsers typically strip quotes but preserve internal whitespace, and a name with accidental spaces is a real bug.

### E6: SOFT checks on a file with HARD failures

If a file has HARD failures (e.g., broken YAML), the SOFT checks are skipped for that file. The script reports the HARD failures and moves to the next file. SOFT checks require a successfully parsed frontmatter and an extracted body — if either is missing, SOFT checks cannot run.

### E7: Skills directory does not exist

If `$SKILLS_ROOT` (or the default `$ROOT/.opencode/skills`) does not exist, the script exits 2 with an error: "skills directory not found: $SKILLS_ROOT." This is an infrastructure failure, not a validation failure.

### E8: python3 is unavailable

If `command -v python3` fails, the script exits 2 with an error: "python3 is required to validate YAML frontmatter." This is an infrastructure failure.

### E9: Symlinks in the skills directory

The script uses `for skill_dir in "$SKILLS_ROOT"/*/` which follows symlinks by default. If a skill directory is a symlink, the script validates the target. This is acceptable — the script validates the content, not the filesystem structure.

### E10: Non-SKILL.md files in skill directories

The script only looks for `SKILL.md` (exact filename, case-sensitive) in each skill directory. Other files (e.g., `scripts/`, `templates/`, `README.md`) are ignored. If a skill directory contains no `SKILL.md`, the script reports a HARD failure: "no SKILL.md found in $skill_dir."

## Test strategy

### Unit tests (bats meta-tests)

| Scenario                               | Test fixture                                            | Expected exit | Expected output                                                                   |
| -------------------------------------- | ------------------------------------------------------- | ------------- | --------------------------------------------------------------------------------- |
| Valid SKILL.md (all checks pass)       | Well-formed frontmatter + activation phrase + license   | 0             | No errors on stderr                                                               |
| Broken YAML (missing closing `---`)    | Truncated frontmatter                                   | 1             | Error names the file + "YAML parse error"                                         |
| Missing `name` field                   | Valid YAML, no `name` key                               | 1             | Error names the file + "missing or empty: name"                                   |
| Empty `name` field                     | `name: ""`                                              | 1             | Error names the file + "missing or empty: name"                                   |
| Missing `description` field            | Valid YAML, no `description` key                        | 1             | Error names the file + "missing or empty: description"                            |
| `name` mismatch with directory         | `name: wrong-name` in `correct-name/SKILL.md`           | 1             | Error names the file + "name mismatch: expected 'correct-name', got 'wrong-name'" |
| Missing activation phrase              | Valid frontmatter, body starts with "This skill does X" | 0             | Warning on stderr: "no activation phrase found"                                   |
| Missing `license` field                | Valid frontmatter, no `license` key                     | 0             | Warning on stderr: "no license declared"                                          |
| Multiple HARD failures in one file     | Broken YAML + missing name                              | 1             | Both errors reported (collect-all)                                                |
| Multiple broken skills across the tree | Two skill dirs, each with a different HARD failure      | 1             | Both errors reported (collect-all)                                                |
| python3 unavailable                    | `PATH` overridden to exclude python3                    | 2             | Error: "python3 is required"                                                      |
| Skills directory missing               | `SKILLS_ROOT` set to non-existent path                  | 2             | Error: "skills directory not found"                                               |

### Smoke tests (manual, documented in task acceptance criteria)

| Scenario                           | How to verify                                                                                                   |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Script runs against real skills    | `make test-skills` — observe output for the 19 current skills                                                   |
| Script integrated into test-config | `make test-config` — observe it runs `test-interview`, `test-skills`, and `validate-opencode-config.sh`         |
| Script catches a real broken skill | Temporarily break a SKILL.md (e.g., add a typo to frontmatter), run `make test-skills`, observe failure, revert |

## Rollback plan

See proposal §Rollback plan. Summary: all changes are reversible via git revert. The worst case is a broken `make test-config` target, which is fixed by reverting the Makefile change.
