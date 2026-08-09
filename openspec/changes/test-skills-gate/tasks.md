# Tasks: test-skills-gate

> **Proposal:** `openspec/changes/test-skills-gate/proposal.md`
> **Design:** `openspec/changes/test-skills-gate/design.md`
> **Workflow:** per `openspec/config.yaml`, each task is a vertical slice invoked via the `tdd-craftsman` skill. Write the failing test BEFORE production code. Work one slice at a time.

## Dependency graph

```
T1 (script skeleton + HARD checks + bats) ──▶ T2 (SOFT checks + bats extension)
                                                       │
                                                       ▼
                                               T3 (Makefile wiring + bats-wrapper extension)
                                                       │
                                                       ▼
                                               T4 (bats meta-tests — full coverage)
                                                       │
                                                       ▼
                                               T5 (full validation run against all 19 current skills)
```

**Critical path:** T1 → T2 → T3 → T4 → T5
**Final task:** T5 is the integration smoke test — it runs the script against all 19 current project skills and verifies the output.

---

## T1 — Script skeleton + HARD checks + initial bats tests

**Blockers:** none
**Vertical slice:** create the script skeleton, implement the four HARD checks (YAML valid, name present+non-empty, description present+non-empty, name==dirname), and write the first bats tests covering the HARD checks.
**Traces to:** D1, D2, D3, D4, D7, D8

### What changes

1. `.opencode/scripts/validate-skills.sh` (new):
   - Shebang: `#!/usr/bin/env bash`
   - `set -euo pipefail`
   - `ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"`
   - `SKILLS_ROOT="${SKILLS_ROOT:-$ROOT/.opencode/skills}"`
   - Infrastructure checks (exit 2):
     - `command -v python3` or exit 2 with "python3 is required to validate YAML frontmatter."
     - `[ -d "$SKILLS_ROOT" ]` or exit 2 with "skills directory not found: $SKILLS_ROOT."
   - `failures=0` counter
   - Loop: `for skill_dir in "$SKILLS_ROOT"/*/; do`
     - `skill_name="$(basename "$skill_dir")"`
     - `skill_file="$skill_dir/SKILL.md"`
     - If `[ ! -f "$skill_file" ]` → HARD failure: "no SKILL.md found in $skill_dir", increment failures, continue.
     - Extract frontmatter: use bash to scan for the first two `^---$` lines. Capture everything between them. If fewer than two delimiters found → HARD failure: "truncated or missing frontmatter in $skill_file", increment failures, continue.
     - Write frontmatter to a temp file (`"$BATS_TEST_TMPDIR/frontmatter.yaml"` or `$(mktemp)` if not in bats).
     - Parse + validate via inline python3:
       ```bash
       python3 - "$frontmatter_tmpfile" "$skill_name" "$skill_file" <<'PYEOF'
       import sys
       try:
           import yaml
           parse = yaml.safe_load
       except ImportError:
           # fallback parser: flat YAML-subset (key: value, block scalars)
           def parse(text):
               # ... fallback implementation ...
               pass
       with open(sys.argv[1]) as f:
           data = parse(f.read())
       if not isinstance(data, dict):
           print(f"HARD: frontmatter is not a YAML mapping: {sys.argv[3]}", file=sys.stderr)
           sys.exit(1)
       name = data.get("name")
       desc = data.get("description")
       if not name:
           print(f"HARD: missing or empty: name in {sys.argv[3]}", file=sys.stderr)
           sys.exit(1)
       if not desc:
           print(f"HARD: missing or empty: description in {sys.argv[3]}", file=sys.stderr)
           sys.exit(1)
       if str(name) != sys.argv[2]:
           print(f"HARD: name mismatch in {sys.argv[3]}: expected '{sys.argv[2]}', got '{name}'", file=sys.stderr)
           sys.exit(1)
       PYEOF
       ```
     - If python3 exits non-zero → HARD failure, increment failures, continue.
   - After loop: if `failures -gt 0`, exit 1. Else exit 0.

2. `scripts/__tests__/validate-skills.bats` (new, initial):
   - `load test-helper`
   - `setup()`: copy the script into `$BATS_TEST_TMPDIR`, create a fixture skills root.
   - Test 1: valid SKILL.md → exit 0, no errors.
   - Test 2: broken YAML (missing closing `---`) → exit 1, error names the file.
   - Test 3: missing `name` → exit 1, error mentions "name".
   - Test 4: `name` mismatch → exit 1, error mentions "name mismatch".

### Acceptance criteria (user perspective)

- `.opencode/scripts/validate-skills.sh` is executable and has the correct shebang.
- The script exits 2 when python3 is unavailable.
- The script exits 2 when the skills directory does not exist.
- The script exits 0 when all skills pass HARD checks.
- The script exits 1 when any skill fails a HARD check, and the error message names the broken file and the specific check.
- The script collects all HARD failures (does not stop at the first broken skill).
- bats tests cover: valid SKILL.md, broken YAML, missing name, name mismatch.
- All bats tests pass.

### Testing

- **RED-GREEN:** write the bats tests first (they fail because the script doesn't exist), then create the script until tests pass.
- **Smoke test:** manually run `bash .opencode/scripts/validate-skills.sh` against the real skills directory — observe exit code and output.

---

## T2 — SOFT checks + bats extension

**Blockers:** T1 (script skeleton must exist)
**Vertical slice:** add the two SOFT checks (activation-phrase prefix, license notice) and extend the bats tests to cover them.
**Traces to:** D5

### What changes

1. `.opencode/scripts/validate-skills.sh`:
   - After the HARD checks pass for a skill, add SOFT checks (do NOT increment `failures`):
     - **Activation-phrase check:** extract the body (everything after the second `---`), find the first non-blank line, check if it matches (case-insensitive) one of: `"Use when"`, `"Invoke when"`, `"Trigger via"`, `"Use for"`, `"Use ONLY when"`. If no match → print warning to stderr: "WARN: no activation phrase found in $skill_file (expected 'Use when', 'Invoke when', 'Trigger via', 'Use for', or 'Use ONLY when')."
     - **License check:** if the parsed frontmatter dict does not contain a `license:` key (or the value is empty) → print warning to stderr: "WARN: no license declared in $skill_file."
   - SOFT checks are skipped if HARD checks failed for that file (no body extracted, no frontmatter parsed).

2. `scripts/__tests__/validate-skills.bats`:
   - Test 5: missing activation phrase → exit 0, warning on stderr.
   - Test 6: missing `license` → exit 0, warning on stderr.
   - Test 7: valid skill with all SOFT checks passing → exit 0, no warnings.

### Acceptance criteria (user perspective)

- The script prints a warning to stderr when a skill's body lacks an activation-phrase prefix.
- The script prints a warning to stderr when a skill's frontmatter lacks a `license:` field.
- SOFT warnings do NOT affect the exit code (exit 0 even with warnings).
- SOFT checks are skipped for files with HARD failures.
- bats tests cover: missing activation phrase, missing license, all checks passing.
- All bats tests pass.

### Testing

- **RED-GREEN:** write the bats tests first (they fail because the SOFT checks don't exist), then add the SOFT checks until tests pass.
- **Smoke test:** manually run the script against the real skills directory — observe warnings for skills without activation phrases or licenses.

---

## T3 — Makefile wiring + bats-wrapper extension

**Blockers:** T2 (script must be complete before wiring into Makefile)
**Vertical slice:** add the `test-skills:` Makefile target, wire it into `test-config:`, and extend `bats-wrapper.sh` to syntax-check the new script.
**Traces to:** Proposal §In scope 2

### What changes

1. `Makefile`:
   - Add `test-skills` to `.PHONY` list.
   - Add target:
     ```make
     # Skill frontmatter validation (.opencode/scripts/validate-skills.sh).
     # Walks .opencode/skills/*/SKILL.md, checks YAML frontmatter (HARD: valid YAML,
     # name+description present+non-empty, name==dirname; SOFT: activation-phrase
     # prefix, license notice). Exit codes: 0 all pass, 1 HARD failure, 2 infra error.
     test-skills:
     \tbash .opencode/scripts/validate-skills.sh
     ```
   - Extend `test-config:` dependency chain:
     ```make
     test-config: test-interview test-skills
     \tbash .opencode/scripts/validate-opencode-config.sh
     ```

2. `scripts/__tests__/bats-wrapper.sh`:
   - Extend the syntax-check loop to include `.opencode/scripts/validate-skills.sh`:
     ```bash
     for script in \
       "$ROOT/scripts/dev-stack.sh" \
       ... \
       "$ROOT/.opencode/scripts/validate-skills.sh" \
       "$ROOT/scripts/__tests__/test-helper.bash"; do
       bash -n "$script"
     done
     ```

### Acceptance criteria (user perspective)

- `make test-skills` runs the validation script and exits with the script's exit code.
- `make test-config` runs `test-interview`, `test-skills`, and `validate-opencode-config.sh` (in that order, as prerequisites + recipe body).
- `bash -n .opencode/scripts/validate-skills.sh` passes (syntax is valid).
- The bats-wrapper syntax-check loop includes the new script and passes.

### Testing

- **Smoke test:** run `make test-skills` and verify it invokes the script.
- **Smoke test:** run `make test-config` and verify it runs all three validation steps.
- **Smoke test:** run `make test-shell` and verify the bats-wrapper syntax-checks the new script.

---

## T4 — bats meta-tests — full coverage

**Blockers:** T3 (Makefile wiring must be in place before final test pass)
**Vertical slice:** extend the bats tests to cover all remaining scenarios (collect-all strategy, infrastructure failures, edge cases) and ensure 100% coverage of the design's test matrix.
**Traces to:** D7, D8, E1–E10

### What changes

1. `scripts/__tests__/validate-skills.bats`:
   - Add tests for:
     - Missing `description` → exit 1, error mentions "description".
     - Empty `name` (`name: ""`) → exit 1, error mentions "name".
     - Multiple HARD failures in one file → both errors reported (collect-all).
     - Multiple broken skills across the tree → all errors reported (collect-all).
     - python3 unavailable (`PATH` overridden) → exit 2, error mentions "python3".
     - Skills directory missing (`SKILLS_ROOT` set to non-existent path) → exit 2.
     - SKILL.md with no frontmatter (no `---` delimiters) → exit 1, error mentions "frontmatter".
     - SKILL.md with only one `---` delimiter → exit 1, error mentions "truncated".
     - Valid YAML but non-mapping root (e.g., a bare scalar) → exit 1, error mentions "not a YAML mapping".

### Acceptance criteria (user perspective)

- All scenarios in the design's test matrix (Table: Unit tests) are covered by bats tests.
- All bats tests pass.
- The test file is readable and each test has a clear name and comment explaining the scenario.

### Testing

- **RED-GREEN:** write the bats tests first (they fail because the edge cases are not handled), then extend the script until tests pass.
- **Smoke test:** run `bash scripts/__tests__/bats-wrapper.sh` and verify all bats tests pass.

---

## T5 — Full validation run against all 19 current skills

**Blockers:** T4 (all tests must pass before running against real skills)
**Vertical slice:** run the script against all 19 current project skills, observe the output, and fix any issues in the script (not in the skills — the script is the deliverable, not the skills).
**Traces to:** all

### What changes

1. Manual smoke tests (documented here, executed by the developer):
   - **Full run:** `bash .opencode/scripts/validate-skills.sh` — observe output for all 19 skills.
   - **Makefile integration:** `make test-skills` — observe exit code and output.
   - **test-config chain:** `make test-config` — observe it runs `test-interview`, `test-skills`, and `validate-opencode-config.sh`.
   - **Deliberate breakage:** temporarily break a SKILL.md (e.g., add a typo to frontmatter), run `make test-skills`, observe failure, revert.
   - **Warning audit:** review the SOFT warnings for the 19 skills — are they actionable? Noisy? Document the findings (not a code change).

2. If the script has bugs (false positives, missed errors, poor error messages), fix them in this task. Do NOT fix the skills themselves (that's out of scope).

### Acceptance criteria (user perspective)

- The script runs against all 19 current skills and exits 0 (all HARD checks pass) or exits 1 with clear error messages (if any skill is broken).
- SOFT warnings are printed for skills without activation phrases or licenses — the developer reviews them and decides if follow-up work is needed.
- `make test-config` runs successfully (all three validation steps pass).
- The deliberate-breakage test confirms the script catches real errors.
- The warning audit is documented (in a comment in this task, or in a follow-up ticket).

### Testing

- **Manual verification:** the smoke tests ARE the test for this task. They verify the end-to-end behavior against real skills.
- **Regression check:** after any script fixes, re-run the bats tests to ensure they still pass.

---

## Summary

| Task | Blockers | Key deliverable                                              | Test strategy                                                         |
| ---- | -------- | ------------------------------------------------------------ | --------------------------------------------------------------------- |
| T1   | none     | Script skeleton + HARD checks                                | bats (valid SKILL.md, broken YAML, missing name, name mismatch)       |
| T2   | T1       | SOFT checks (activation-phrase, license)                     | bats (missing activation phrase, missing license, all passing)        |
| T3   | T2       | Makefile wiring + bats-wrapper extension                     | smoke (make test-skills, make test-config, bats-wrapper syntax check) |
| T4   | T3       | Full bats coverage (collect-all, edge cases, infra failures) | bats (all design test matrix scenarios)                               |
| T5   | T4       | Full validation run against 19 real skills                   | manual smoke (full run, deliberate breakage, warning audit)           |
