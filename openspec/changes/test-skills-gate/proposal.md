# Proposal: test-skills-gate

> **Status:** proposed · **Scope:** dev-infra (skill validation script + Makefile wiring + bats meta-tests)
> **Escalation:** none — change is within existing module boundaries (per AGENTS.md §2.4, dev-infra changes do not require @architector)
> **Requirement:** validate the structural integrity of every `SKILL.md` under `.opencode/skills/*/` before the skills are loaded by OpenCode agents

## Motivation

The project ships **19 skills** under `.opencode/skills/*/SKILL.md`. Each skill file carries YAML frontmatter that OpenCode parses at load time to register the skill (name, description, compatibility, allowed-tools, license, metadata). The body of the file is the skill's instructions.

**There is currently no validation of SKILL.md content.** Specifically:

1. **Broken frontmatter ships silently.** A typo in the YAML (missing closing `---`, stray tab, unquoted colon in a description) makes the skill un-loadable — but nothing in `make test-config` catches this. The developer discovers the failure only when an agent tries to invoke the skill at runtime and gets an opaque "skill not found" or "frontmatter parse error."

2. **Name/directory mismatch ships silently.** OpenCode registers a skill by its `name:` frontmatter field, but the filesystem path is `.opencode/skills/<dirname>/SKILL.md`. If `name:` drifts from `<dirname>` (e.g., `name: openspec_propose` with an underscore while the directory is `openspec-propose`), agents dispatching by directory name and agents dispatching by `name` field will diverge. No test catches this.

3. **Empty required fields ship silently.** A skill with `name:` or `description:` set to empty string loads but is unusable — OpenCode's skill list shows a blank entry, and the skill can never match an activation trigger.

4. **Activation-phrase drift is invisible.** Most skills begin their body with an activation phrase ("Use when…", "Invoke when…", "Trigger via…") that OpenCode uses for skill matching. If a skill's body lacks this phrase or uses a non-standard prefix, the skill silently fails to activate in the expected contexts. This is a soft issue (not a hard failure) but worth flagging.

5. **License provenance is undocumented for forked skills.** Several skills are vendored from OMO (`oh-my-opencode-slim/src/skills/`) or openspec upstream. Without a visible `license: MIT` (or equivalent) in the frontmatter, it is impossible to audit whether a skill's licensing is compatible with the project's distribution model. This is a soft (warn-only) issue.

The goal is a **deterministic, fast, zero-dependency validation script** that runs as part of `make test-config` and catches all hard failures before they reach runtime.

## Scope

### In scope

1. **A new shell script** at `.opencode/scripts/validate-skills.sh` that walks every `.opencode/skills/*/SKILL.md`, extracts the YAML frontmatter (the block between the first two `---` delimiters), and runs a set of checks:
   - **HARD checks** (exit 1 on failure):
     - YAML frontmatter parses without error (via inline `python3` with PyYAML, falling back to a stdlib-only parser if PyYAML is absent).
     - `name` field is present and non-empty.
     - `description` field is present and non-empty.
     - `name` field value equals the parent directory name (e.g., `name: openspec-propose` must live in `.opencode/skills/openspec-propose/`).
   - **SOFT checks** (warn-only, printed to stderr, do NOT affect exit code):
     - The body (everything after the second `---`) starts with an activation phrase matching one of: `"Use when"`, `"Invoke when"`, `"Trigger via"`, `"Use for"`, `"Use ONLY when"` (case-insensitive prefix match on the first non-blank line).
     - The frontmatter contains a `license:` field (any non-empty value). Skills without it get a warning: "no license declared — verify provenance."

2. **Makefile wiring:**
   - New target `test-skills:` that runs `bash .opencode/scripts/validate-skills.sh`.
   - Extend existing `test-config:` target's dependency chain: `test-config: test-interview test-skills` (add `test-skills` as a sibling prerequisite alongside the existing `test-interview`). The existing `validate-opencode-config.sh` invocation in the recipe body stays unchanged.

3. **bats meta-tests** at `scripts/__tests__/validate-skills.bats`:
   - Each test creates a **temp fixture directory** mirroring `.opencode/skills/<name>/SKILL.md` with a deliberately broken frontmatter or body, runs the script against the fixture (by overriding the skills root via an env var), and asserts the expected exit code and output.
   - Coverage:
     - Valid SKILL.md → exit 0, no warnings.
     - Broken YAML (missing closing `---`) → exit 1, error names the file.
     - Missing `name` → exit 1.
     - Missing `description` → exit 1.
     - `name` mismatch with directory → exit 1.
     - Missing activation phrase → exit 0 with warning on stderr.
     - Missing `license` → exit 0 with warning on stderr.
     - Multiple failures in one file → all hard errors collected (not fail-fast on first error); exit 1.
     - Multiple broken skills across the tree → all errors collected; exit 1.
   - Error strategy: **collect-all**, not fail-fast. The script must report every broken skill in a single run, not stop at the first failure. This matches the established pattern in `validate-opencode-config.sh` (which counts failures and exits 1 at the end).

4. **Exit code contract:**
   - `0` — all skills pass all HARD checks (SOFT warnings may be present on stderr).
   - `1` — at least one HARD check failed (errors on stderr).
   - `2` — infrastructure failure (python3 unavailable, skills directory missing, etc.).

### Out of scope (non-goals)

- **Modifying any existing SKILL.md.** This change adds a gate; it does not fix pre-existing issues. If the script flags warnings on current skills, those are tracked as follow-up work (not blocked by this change).
- **Validating skills outside `.opencode/skills/`.** The OMO vendored skills at `.opencode/oh-my-opencode-slim/src/skills/` and any user-local `~/.config/opencode/skills/` are NOT in scope. They have their own validation (or none). This script validates only the project's own skills.
- **Validating the body content of SKILL.md** beyond the activation-phrase prefix. The body is free-form Markdown; semantic validation is out of scope.
- **Blocking on SOFT warnings.** The activation-phrase and license checks are warn-only. They print to stderr but do not affect the exit code. A future change may promote them to HARD if the team decides the signal is reliable enough.
- **Schema validation beyond YAML syntax.** The script checks that frontmatter is valid YAML and that `name`/`description` exist and are non-empty. It does NOT validate against a JSON Schema or OpenSpec skill schema (none exists).
- **Network calls.** The script is fully offline. No fetching, no license compatibility checks against SPDX, no HTTP.
- **External dependencies.** python3 is required (part of the dev container's base image). PyYAML is used if available; the script falls back to a stdlib-only parser if PyYAML is absent. No new apt/pip/npm dependencies are introduced.
- **Changes to application code.** This change adds dev-infra tooling only; no application code is modified.

## Design authority (.sdd/) reference

**No `.sdd/` document governs dev-infra.** The project's design authority layer (`architecture.md` + `.sdd/`) describes system architecture (editor, workers, contracts, cloud), not developer tooling. Per AGENTS.md §2.4, dev-infra changes within existing boundaries use the spec chain directly without architectural escalation.

**Precedent:** `pre-commit-autofix` (same dev-infra scope, same "no .sdd/ escalation" pattern) — see `openspec/changes/pre-commit-autofix/proposal.md` §Design authority.

## Testing Decisions

**What makes a good test for this change?**

1. **Meta-tests with temp fixtures.** The script's input is a directory of SKILL.md files. The correct test strategy is to construct **temp fixture directories** (mirroring `.opencode/skills/<name>/SKILL.md`) with deliberately broken content, run the script against the fixture (via an env var override for the skills root), and assert the exit code + stderr output. This is the same pattern as `scripts/__tests__/dev-stack.bats` (which copies the script into an isolated temp tree).

2. **Collect-all error strategy.** The script must NOT fail-fast on the first broken skill. A developer who introduces 3 broken skills should see all 3 errors in a single run, not fix one, re-run, fix the next, re-run, etc. Tests assert that the script accumulates errors and reports them all.

3. **Exit code contract tests.** Tests assert the exact exit code (0/1/2) for each scenario. Exit 2 (infrastructure failure) is tested by unsetting `python3` from PATH.

4. **SOFT vs HARD separation.** Tests assert that SOFT warnings (activation-phrase, license) do NOT affect the exit code. A skill with only SOFT warnings must exit 0.

**Which modules will be tested?**

- `.opencode/scripts/validate-skills.sh` — bats meta-tests at `scripts/__tests__/validate-skills.bats`.
- Makefile `test-skills:` target — verified by running `make test-skills` and asserting it invokes the script (documented in T3 acceptance criteria; no automated test for Makefile wiring itself — same pattern as existing `test-interview:` target).
- Existing `test-config:` chain — verified by running `make test-config` and asserting it runs `test-interview`, `test-skills`, and `validate-opencode-config.sh` (documented in T3 acceptance criteria).

**Prior art in the codebase:**

- `.opencode/scripts/validate-opencode-config.sh` — established pattern for a validation script with exit codes 0/1/2, collect-all error strategy, and inline python3 for JSONC parsing.
- `scripts/test-interview-enforcement.sh` — established pattern for a multi-check validation script with `pass`/`fail` counters and a final exit-code summary.
- `scripts/__tests__/dev-stack.bats` — established bats test structure with temp-tree isolation and fake-command recording.
- `scripts/__tests__/test-helper.bash` — established assertion helpers (`assert_status`, `assert_output_contains`, `assert_file_exists`).
- `scripts/__tests__/bats-wrapper.sh` — established syntax-check loop that must be extended to cover the new script.

## Rollback plan

**If the change causes problems, how do we roll back?**

1. **Remove the script** — `rm .opencode/scripts/validate-skills.sh`.
2. **Remove the bats tests** — `rm scripts/__tests__/validate-skills.bats`.
3. **Revert Makefile** — remove `test-skills` from the `test-config:` dependency chain and delete the `test-skills:` target.
4. **Revert bats-wrapper.sh** — remove the new script from the syntax-check loop.
5. **Git history** — all changes are in a single commit (or a small PR). Revert the commit or merge a revert PR.

**Risk assessment:** LOW. This change adds a read-only validation script; it does not modify any SKILL.md files, application code, or runtime behavior. The worst-case scenario is a broken `make test-config` target, which is fixed by reverting the Makefile change. The script is invoked only on developer demand (`make test-skills` or `make test-config`), not automatically (no pre-commit hook, no CI).

## Stakeholders

| Stakeholder     | Interest                                                                                             |
| --------------- | ---------------------------------------------------------------------------------------------------- |
| Developer (you) | Catch broken SKILL.md before runtime; fast feedback in `make test-config`.                           |
| @openspec-plan  | Ensure skills conform to the interview-first spec-authoring model (activation-phrase check).         |
| @coder          | Implement the script against the spec; no ambiguity in checks or exit codes.                         |
| @reviewer       | Verify the implementation matches the spec (HARD/SOFT separation, collect-all strategy, exit codes). |
| Future agents   | Trust that loaded skills have valid frontmatter and match their directory name.                      |

## Open questions

None. All decisions are locked from the Phase 3 interview summary (messages.md row 154):

- HARD vs SOFT check classification: confirmed.
- Exit code contract (0/1/2): confirmed.
- Collect-all error strategy (not fail-fast): confirmed.
- bats meta-tests with temp fixtures: confirmed.
- Makefile wiring (`test-config: test-interview test-skills`): confirmed.
- No `.sdd/` escalation (pre-commit-autofix precedent): confirmed.
- Script location (`.opencode/scripts/validate-skills.sh`): confirmed.
- SOFT checks (activation-phrase prefix, license notice): confirmed warn-only.
