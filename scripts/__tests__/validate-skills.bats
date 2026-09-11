#!/usr/bin/env bats
# Meta-tests for .opencode/scripts/validate-skills.sh (DIA-037, change
# test-skills-gate). The script validates the YAML frontmatter of every
# .opencode/skills/*/SKILL.md.
#
# Exit-code contract under test:
#   0  all skills pass HARD checks (SOFT warnings may print to stderr)
#   1  at least one HARD check failed (collect-all, never fail-fast)
#   2  infrastructure failure (python3 unavailable / skills root missing)
#
# Isolation: each test builds a temp fixture tree mirroring
# .opencode/skills/<name>/SKILL.md under $BATS_TEST_TMPDIR and runs the script
# against it via the SKILLS_ROOT env override — the real .opencode/skills/ is
# never touched (T5 smoke-tests the real tree separately).

load test-helper

SKILLS_SCRIPT="$REPO_ROOT/.opencode/scripts/validate-skills.sh"

setup() {
  FIXTURES="$BATS_TEST_TMPDIR/skills"
  mkdir -p "$FIXTURES"
  GLOBAL_FIXTURES="$BATS_TEST_TMPDIR/global-skills"
  mkdir -p "$GLOBAL_FIXTURES"
  # DIA-052 (T1): the validator now also consults the global skills tree
  # (GLOBAL_SKILLS_ROOT, default $HOME/.config/opencode/skills). Point it at
  # an empty per-test temp dir so the pre-existing tests stay hermetic — the
  # real global tree is never read, and an empty global root skips dup checks.
  export GLOBAL_SKILLS_ROOT="$GLOBAL_FIXTURES"
  # DIA-086 (task 4.2): validate-skills.sh hard-requires the two Socratic
  # interview skills to pass its M4 checks (FIRST-QUESTION anchor, the exact
  # hypothesis question after it, and an example '?'-ending question). Plant
  # M4-compliant fixtures for both so every test tree mirrors the real
  # .opencode/skills/ tree. Without them the M4 "missing skill file" FAILs
  # flip every exit-0 expectation to exit 1 - the drift this suite suffered
  # when the M4 checks landed without fixture updates.
  write_m4_skill "openspec-propose"
  write_m4_skill "domain-grilling"
  # Resolve absolute interpreters up front: the python3-unavailable test
  # rewrites PATH and needs an absolute bash to still invoke the script.
  BASH_BIN="$(command -v bash)"
}

# write_skill <dirname> <file-content>: writes a SKILL.md into the project
# fixture root. <file-content> is passed through printf %s so no interpolation
# occurs.
write_skill() {
  local dir="$FIXTURES/$1"
  mkdir -p "$dir"
  printf '%s\n' "$2" > "$dir/SKILL.md"
}

# write_global_skill <dirname> <file-content>: writes a SKILL.md into the
# global fixture root (DIA-052 dup-detection fixture matrix).
write_global_skill() {
  local dir="$GLOBAL_FIXTURES/$1"
  mkdir -p "$dir"
  printf '%s\n' "$2" > "$dir/SKILL.md"
}

# valid_skill <dirname>: writes a fully conforming SKILL.md whose body starts
# with the "Use when" activation phrase and declares a license.
valid_skill() {
  local name="$1"
  write_skill "$name" "---
name: $name
description: A fully conforming skill. Use when testing the validator.
license: MIT
---

Use when running the validation suite.
"
}

# write_m4_skill <name>: writes an M4-compliant SKILL.md for one of the two
# Socratic-interview skills that validate-skills.sh hard-requires (DIA-086
# change dia-086-m1-m5-agent-contracts-eval-lite, task 4.2): the
# `<!-- FIRST-QUESTION -->` anchor must appear before the exact hypothesis
# question, followed by at least one explicit '?'-ending example question.
# The fixture mirrors the real skills' shape (flat frontmatter, declared
# license, activation-phrase body) so the M4 checks PASS and emit no warnings.
write_m4_skill() {
  local name="$1"
  write_skill "$name" "---
name: $name
description: M4 fixture copy of the $name Socratic skill. Use when testing the validator.
license: MIT
---

Use when testing the validator.
<!-- FIRST-QUESTION -->
What is the primary hypothesis this feature/design validates, and how will you know if it is falsified?
Example: what is the most important thing to verify first?
"
}

@test "validate-skills: valid SKILL.md exits 0 with no warnings" {
  valid_skill "good-skill"

  SKILLS_ROOT="$FIXTURES" run bash "$SKILLS_SCRIPT"

  assert_status 0
  assert_output_contains "ok:"
  # C1: the summary line's exact counts/format are an implementation detail —
  # assert the stable words (passed/failed/warnings) so a cosmetic summary
  # change doesn't break the test. The zero-warning claim is covered by the
  # not-contains "warn:" assertion below.
  assert_output_contains "passed"
  assert_output_contains "failed"
  assert_output_contains "warnings"
  assert_output_not_contains "FAIL:"
  assert_output_not_contains "warn:"
}

@test "validate-skills: broken YAML inside delimiters exits 1 and names the file" {
  # C3: this fixture exercises the PyYAML path only — `[unclosed` is a YAML
  # ScannerError (unclosed flow sequence). The fallback subset parser would
  # treat `[unclosed` as a plain scalar value, so this test is PyYAML-only by
  # construction and is skipped implicitly on hosts without PyYAML (where the
  # fallback path is covered by the flat-parser fixtures instead).
  write_skill "broken-yaml" '---
name: broken-yaml
description: [unclosed
---

Use when testing.
'

  SKILLS_ROOT="$FIXTURES" run bash "$SKILLS_SCRIPT"

  assert_status 1
  assert_output_contains "YAML parse error"
  assert_output_contains "broken-yaml/SKILL.md"
}

@test "validate-skills: missing closing delimiter (truncated frontmatter) exits 1" {
  write_skill "truncated" '---
name: truncated
'

  SKILLS_ROOT="$FIXTURES" run bash "$SKILLS_SCRIPT"

  assert_status 1
  assert_output_contains "truncated frontmatter"
  assert_output_contains "truncated/SKILL.md"
}

@test "validate-skills: no frontmatter at all exits 1" {
  write_skill "nofm" 'Just body text, no frontmatter delimiters anywhere.
'

  SKILLS_ROOT="$FIXTURES" run bash "$SKILLS_SCRIPT"

  assert_status 1
  assert_output_contains "no frontmatter found"
  assert_output_contains "nofm/SKILL.md"
}

@test "validate-skills: missing name exits 1 and names the field" {
  write_skill "noname" '---
description: Has a description. Use when testing.
license: MIT
---

Use when testing.
'

  SKILLS_ROOT="$FIXTURES" run bash "$SKILLS_SCRIPT"

  assert_status 1
  assert_output_contains "missing or empty: name"
  assert_output_contains "noname/SKILL.md"
}

@test "validate-skills: empty name exits 1" {
  write_skill "emptyname" '---
name: ""
description: Has a description. Use when testing.
license: MIT
---

Use when testing.
'

  SKILLS_ROOT="$FIXTURES" run bash "$SKILLS_SCRIPT"

  assert_status 1
  assert_output_contains "missing or empty: name"
}

@test "validate-skills: missing description exits 1 and names the field" {
  write_skill "nodesc" '---
name: nodesc
license: MIT
---

Use when testing.
'

  SKILLS_ROOT="$FIXTURES" run bash "$SKILLS_SCRIPT"

  assert_status 1
  assert_output_contains "missing or empty: description"
  assert_output_contains "nodesc/SKILL.md"
}

@test "validate-skills: name/directory mismatch exits 1 with both values" {
  write_skill "correct-name" '---
name: wrong-name
description: Has a description. Use when testing.
license: MIT
---

Use when testing.
'

  SKILLS_ROOT="$FIXTURES" run bash "$SKILLS_SCRIPT"

  assert_status 1
  assert_output_contains "name mismatch"
  assert_output_contains "expected 'correct-name', got 'wrong-name'"
}

@test "validate-skills: missing activation phrase exits 0 with a stderr warning" {
  write_skill "noactivation" '---
name: noactivation
description: Has a description. Use when testing.
license: MIT
---

This skill explains itself differently.
'

  SKILLS_ROOT="$FIXTURES" run bash "$SKILLS_SCRIPT"

  assert_status 0
  assert_output_contains "no activation phrase found"
  # C1: stable-word assertion — the exact "N passed, 0 failed, 1 warnings"
  # summary string is an implementation detail.
  assert_output_contains "passed"
  assert_output_contains "warnings"
}

@test "validate-skills: missing license exits 0 with a stderr warning" {
  write_skill "nolicense" '---
name: nolicense
description: Has a description. Use when testing.
---

Use when testing.
'

  SKILLS_ROOT="$FIXTURES" run bash "$SKILLS_SCRIPT"

  assert_status 0
  assert_output_contains "no license declared"
  # C1: stable-word assertion — the exact "N passed, 0 failed, 1 warnings"
  # summary string is an implementation detail.
  assert_output_contains "passed"
  assert_output_contains "warnings"
}

@test "validate-skills: multiple HARD failures in one file are all collected" {
  # Empty frontmatter (two delimiters, nothing between): PyYAML yields None,
  # which the validator treats as an empty mapping -> both name and description
  # are missing and BOTH errors must be reported (collect-all within a file).
  write_skill "emptyfm" '---
---
'

  SKILLS_ROOT="$FIXTURES" run bash "$SKILLS_SCRIPT"

  assert_status 1
  assert_output_contains "missing or empty: name"
  assert_output_contains "missing or empty: description"
  # C1: stable-word assertion — the "1 failed" count is an implementation
  # detail; collect-all within the file is proven by the two errors above.
  assert_output_contains "failed"
}

@test "validate-skills: multiple broken skills across the tree are all collected" {
  write_skill "broken-a" '---
description: Missing its name. Use when testing.
license: MIT
---

Use when testing.
'
  write_skill "broken-b" '---
name: broken-b
license: MIT
---

Use when testing.
'

  SKILLS_ROOT="$FIXTURES" run bash "$SKILLS_SCRIPT"

  assert_status 1
  assert_output_contains "broken-a/SKILL.md"
  assert_output_contains "broken-b/SKILL.md"
  # C1: stable-word assertion — the "2 failed" count is an implementation
  # detail; collect-all across the tree is proven by the two per-file errors.
  assert_output_contains "failed"
}

@test "validate-skills: non-mapping YAML root (bare scalar) exits 1" {
  write_skill "scalar" '---
just a bare scalar
---

Use when testing.
'

  SKILLS_ROOT="$FIXTURES" run bash "$SKILLS_SCRIPT"

  assert_status 1
  assert_output_contains "not a YAML mapping"
  assert_output_contains "scalar/SKILL.md"
}

@test "validate-skills: skill directory without SKILL.md exits 1" {
  mkdir -p "$FIXTURES/empty-dir"

  SKILLS_ROOT="$FIXTURES" run bash "$SKILLS_SCRIPT"

  assert_status 1
  assert_output_contains "no SKILL.md found"
  assert_output_contains "empty-dir"
}

@test "validate-skills: exits 2 when python3 is unavailable" {
  # Rebuild PATH dropping every directory that holds a python3 binary (on this
  # host /usr/bin and /bin both carry one) while keeping everything else so
  # bash and bats still resolve. The script must exit 2 BEFORE any skill is
  # processed.
  local new_path="" p
  IFS=: read -ra parts <<< "$PATH"
  for p in "${parts[@]}"; do
    if [ -n "$p" ] && [ ! -x "$p/python3" ]; then
      new_path="$new_path:$p"
    fi
  done
  new_path="${new_path#:}"

  PATH="$new_path" run "$BASH_BIN" "$SKILLS_SCRIPT"

  assert_status 2
  assert_output_contains "python3 is required"
}

@test "validate-skills: exits 2 when the skills directory is missing" {
  SKILLS_ROOT="$FIXTURES/does-not-exist" run bash "$SKILLS_SCRIPT"

  assert_status 2
  assert_output_contains "skills directory not found"
}

@test "validate-skills: summary line aggregates multiple skills with warnings" {
  valid_skill "alpha"
  write_skill "beta" '---
name: beta
description: Beta skill. Use when testing.
---

Use when testing.
'

  SKILLS_ROOT="$FIXTURES" run bash "$SKILLS_SCRIPT"

  assert_status 0
  # C1: stable-word assertions — the exact "N passed, M failed, K warnings"
  # summary string is an implementation detail.
  assert_output_contains "passed"
  assert_output_contains "failed"
  assert_output_contains "warnings"
}

# --- DIA-052 (T1): cross-location duplicate detection fixture matrix --------
# Each test builds isolated project + global fixture trees under
# $BATS_TEST_TMPDIR and sets SKILLS_ROOT + GLOBAL_SKILLS_ROOT explicitly so the
# real .opencode/skills/ and ~/.config/opencode/skills/ are never touched.

@test "validate-skills: clean tree with no duplicates exits 0 without dup warnings" {
  # Distinct names across the two roots: no byte-exact match, no same-named
  # global to diff against -> no dup findings at all.
  valid_skill "proj-only-a"
  valid_skill "proj-only-b"
  write_global_skill "global-only" '---
name: global-only
description: A global skill with no project counterpart. Use when testing the validator.
license: MIT
---

Use when running the validation suite.
'

  SKILLS_ROOT="$FIXTURES" GLOBAL_SKILLS_ROOT="$GLOBAL_FIXTURES" run bash "$SKILLS_SCRIPT"

  assert_status 0
  assert_output_contains "passed"
  assert_output_not_contains "FAIL:"
  assert_output_not_contains "near-duplicate skill"
  assert_output_not_contains "duplicate skill"
}

@test "validate-skills: byte-exact duplicate exits 1 and names the pair" {
  # Identical SKILL.md content in both roots -> same sha256 -> HARD finding.
  local content
  content='---
name: dup-skill
description: A duplicated skill. Use when testing the validator.
license: MIT
---

Use when running the validation suite.
'
  write_skill "dup-skill" "$content"
  write_global_skill "dup-skill" "$content"

  SKILLS_ROOT="$FIXTURES" GLOBAL_SKILLS_ROOT="$GLOBAL_FIXTURES" run bash "$SKILLS_SCRIPT"

  assert_status 1
  assert_output_contains "FAIL: duplicate skill 'dup-skill'"
  assert_output_contains "byte-exact match with global"
  assert_output_contains "failed"
}

@test "validate-skills: near-duplicate exits 0 with a stderr warning" {
  # Same dirname in both roots but the project copy differs by one comment
  # line -> NOT byte-exact; diff -r reports a difference -> SOFT warning only.
  write_skill "near-skill" '---
name: near-skill
description: A near-duplicate skill. Use when testing the validator.
license: MIT
---

Use when running the validation suite.
'
  write_global_skill "near-skill" '---
name: near-skill
description: A near-duplicate skill. Use when testing the validator.
license: MIT
---

Use when running the validation suite.
# global-only comment line makes the trees differ
'

  SKILLS_ROOT="$FIXTURES" GLOBAL_SKILLS_ROOT="$GLOBAL_FIXTURES" run bash "$SKILLS_SCRIPT"

  assert_status 0
  assert_output_contains "warn: near-duplicate skill 'near-skill'"
  assert_output_contains "differs from global"
  assert_output_not_contains "FAIL:"
}

@test "validate-skills: empty project skills dir fails M4 and exits 1" {
  # M4 (DIA-086 task 4.2) made an empty project tree a HARD failure: the two
  # Socratic-interview skills are required, so a "missing skill file" FAIL is
  # emitted for each before the summary. Dup detection is still skipped (the
  # project side has no skill dirs to hash). This documents the post-M4
  # contract for the previously-exit-0 empty-tree scenario.
  local empty_proj="$FIXTURES/empty-proj"
  mkdir -p "$empty_proj"
  write_global_skill "global-only" '---
name: global-only
description: A global skill with no project counterpart. Use when testing the validator.
license: MIT
---

Use when running the validation suite.
'

  SKILLS_ROOT="$empty_proj" GLOBAL_SKILLS_ROOT="$GLOBAL_FIXTURES" run bash "$SKILLS_SCRIPT"

  assert_status 1
  assert_output_contains "M4: missing skill file"
  assert_output_contains "openspec-propose/SKILL.md"
  assert_output_contains "domain-grilling/SKILL.md"
  assert_output_contains "2 failed"
  assert_output_not_contains "duplicate skill"
  assert_output_not_contains "near-duplicate skill"
}

@test "validate-skills: missing global skills dir warns and skips dup tier (exit 0)" {
  # Contract change 2026-08-12 (DIA-071): the global skills tree is OPTIONAL -
  # environments without one (poetry-dev image) get a warn + skipped
  # duplicate-detection tier, not an INFRA exit. Frontmatter validation (the
  # DIA-037 core purpose) is unaffected by the missing tree.
  valid_skill "good-skill"

  SKILLS_ROOT="$FIXTURES" GLOBAL_SKILLS_ROOT="$FIXTURES/does-not-exist" run bash "$SKILLS_SCRIPT"

  assert_status 0
  assert_output_contains "warn: global skills directory not found"
  assert_output_contains "duplicate-detection tier skipped"
  assert_output_not_contains "FAIL:"
}

# --- DIA-260831-j5k6 slice 2 GREEN (compat tier, all four classes) ---------
# Slice 1 pinned the preset + bash contract (tests above, now passing). Slice
# 2 extends the tier to commands, agents, and required binaries and pins the
# full matrix: valid declarations exit 0, empty lists valid, empty entries
# hard-fail, one invalid fixture per class, multi-failure collect-all, the
# patch-version floor, the inline-`[]` form, and malformed-manifest failure.
#
# Hermetic seams: COMPAT_PRESETS_FILE ({"presets": {name: ...}}),
# COMPAT_CONFIG_FILE ({"command": {name: ...}, "agent": {name: ...}}), and
# COMPAT_COMMANDS_DIR (a dir of <name>.md files completing the command
# registry). Defaults are the real configs; fixtures below always override
# all three so the real tree is never read.

# write_compat_manifests: fixed fixture manifests — one preset, one inline
# config command, one command file, one agent. Everything else dangles.
write_compat_manifests() {
  cat > "$BATS_TEST_TMPDIR/compat-presets.json" <<'EOF'
{"presets": {"fixture-preset-a": {}, "fixture-preset-b": {}}}
EOF
  cat > "$BATS_TEST_TMPDIR/compat-config.json" <<'EOF'
{"command": {"fixture-cmd-a": {}}, "agent": {"fixture-agent-a": {}}}
EOF
  mkdir -p "$BATS_TEST_TMPDIR/compat-commands"
  printf '# fixture file command\n' > "$BATS_TEST_TMPDIR/compat-commands/fixture-file-cmd.md"
}

# write_stub_binary <name>: a no-op executable on a per-test stubbin dir.
# Absolute shebang (never /usr/bin/env): stubbin sits first on PATH in the
# binary tests, so an env shebang could re-resolve an interpreter from here.
write_stub_binary() {
  local stubbin="$BATS_TEST_TMPDIR/stubbin"
  mkdir -p "$stubbin"
  printf '#!%s\nexit 0\n' "$BASH_BIN" > "$stubbin/$1"
  chmod +x "$stubbin/$1"
}

@test "compat: valid declarations across all four classes exit 0" {
  write_compat_manifests
  write_stub_binary "fixture-tool-a"
  write_skill "compat-valid" '---
name: compat-valid
description: Skill declaring valid compat. Use when testing compat.
license: MIT
presets:
  - fixture-preset-a
commands:
  - fixture-cmd-a
  - fixture-file-cmd
agents:
  - fixture-agent-a
requires_binaries:
  - fixture-tool-a
requires_bash: "4.0"
---

Use when testing compat.
'

  SKILLS_ROOT="$FIXTURES" COMPAT_PRESETS_FILE="$BATS_TEST_TMPDIR/compat-presets.json" COMPAT_CONFIG_FILE="$BATS_TEST_TMPDIR/compat-config.json" COMPAT_COMMANDS_DIR="$BATS_TEST_TMPDIR/compat-commands" PATH="$BATS_TEST_TMPDIR/stubbin:$PATH" run bash "$SKILLS_SCRIPT"

  assert_status 0
  assert_output_not_contains "FAIL:"
}

@test "compat: empty declaration lists are valid" {
  write_compat_manifests
  write_skill "compat-empty" '---
name: compat-empty
description: Skill with empty compat lists. Use when testing compat.
license: MIT
presets:
commands:
agents:
requires_binaries:
---

Use when testing compat.
'

  SKILLS_ROOT="$FIXTURES" COMPAT_PRESETS_FILE="$BATS_TEST_TMPDIR/compat-presets.json" COMPAT_CONFIG_FILE="$BATS_TEST_TMPDIR/compat-config.json" COMPAT_COMMANDS_DIR="$BATS_TEST_TMPDIR/compat-commands" run bash "$SKILLS_SCRIPT"

  assert_status 0
  assert_output_not_contains "FAIL:"
}

@test "compat: inline empty list presets [] is a valid empty optional list" {
  write_compat_manifests
  write_skill "compat-inline-empty" '---
name: compat-inline-empty
description: Skill with inline empty presets. Use when testing compat.
license: MIT
presets: []
---

Use when testing compat.
'

  SKILLS_ROOT="$FIXTURES" COMPAT_PRESETS_FILE="$BATS_TEST_TMPDIR/compat-presets.json" COMPAT_CONFIG_FILE="$BATS_TEST_TMPDIR/compat-config.json" COMPAT_COMMANDS_DIR="$BATS_TEST_TMPDIR/compat-commands" run bash "$SKILLS_SCRIPT"

  assert_status 0
  assert_output_not_contains "FAIL:"
}

@test "compat: unknown command exits 1 with a deterministic FAIL" {
  write_compat_manifests
  write_skill "cmd-user" '---
name: cmd-user
description: Skill declaring commands. Use when testing compat.
license: MIT
commands:
  - fixture-cmd-a
  - __dangling_cmd_zzz__
---

Use when testing compat.
'

  SKILLS_ROOT="$FIXTURES" COMPAT_PRESETS_FILE="$BATS_TEST_TMPDIR/compat-presets.json" COMPAT_CONFIG_FILE="$BATS_TEST_TMPDIR/compat-config.json" COMPAT_COMMANDS_DIR="$BATS_TEST_TMPDIR/compat-commands" run bash "$SKILLS_SCRIPT"

  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "cmd-user"
  assert_output_contains "command"
  assert_output_contains "commands"
  assert_output_contains "__dangling_cmd_zzz__"
}

@test "compat: unknown agent exits 1 with a deterministic FAIL" {
  write_compat_manifests
  write_skill "agent-user" '---
name: agent-user
description: Skill declaring agents. Use when testing compat.
license: MIT
agents:
  - fixture-agent-a
  - __dangling_agent_zzz__
---

Use when testing compat.
'

  SKILLS_ROOT="$FIXTURES" COMPAT_PRESETS_FILE="$BATS_TEST_TMPDIR/compat-presets.json" COMPAT_CONFIG_FILE="$BATS_TEST_TMPDIR/compat-config.json" COMPAT_COMMANDS_DIR="$BATS_TEST_TMPDIR/compat-commands" run bash "$SKILLS_SCRIPT"

  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "agent-user"
  assert_output_contains "agent"
  assert_output_contains "agents"
  assert_output_contains "__dangling_agent_zzz__"
}

@test "compat: missing required binary exits 1 with a deterministic FAIL" {
  write_compat_manifests
  write_skill "bin-needer" '---
name: bin-needer
description: Skill requiring binaries. Use when testing compat.
license: MIT
requires_binaries:
  - __missing_bin_zzz__
---

Use when testing compat.
'

  SKILLS_ROOT="$FIXTURES" COMPAT_PRESETS_FILE="$BATS_TEST_TMPDIR/compat-presets.json" COMPAT_CONFIG_FILE="$BATS_TEST_TMPDIR/compat-config.json" COMPAT_COMMANDS_DIR="$BATS_TEST_TMPDIR/compat-commands" run bash "$SKILLS_SCRIPT"

  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "bin-needer"
  assert_output_contains "binary"
  assert_output_contains "requires_binaries"
  assert_output_contains "__missing_bin_zzz__"
}

@test "compat: empty entries are hard failures" {
  write_compat_manifests
  write_skill "empty-entry" '---
name: empty-entry
description: Skill with empty compat entries. Use when testing compat.
license: MIT
presets:
  - ""
commands:
  - ""
---

Use when testing compat.
'

  SKILLS_ROOT="$FIXTURES" COMPAT_PRESETS_FILE="$BATS_TEST_TMPDIR/compat-presets.json" COMPAT_CONFIG_FILE="$BATS_TEST_TMPDIR/compat-config.json" COMPAT_COMMANDS_DIR="$BATS_TEST_TMPDIR/compat-commands" run bash "$SKILLS_SCRIPT"

  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "empty entry"
  assert_output_contains "presets"
  assert_output_contains "commands"
}

@test "compat: multiple unresolved declarations are all collected" {
  write_compat_manifests
  write_skill "multi-bad" '---
name: multi-bad
description: Skill with many bad declarations. Use when testing compat.
license: MIT
presets:
  - __dangling_preset_zzz__
commands:
  - __dangling_cmd_zzz__
agents:
  - __dangling_agent_zzz__
requires_binaries:
  - __missing_bin_zzz__
requires_bash: "99.0"
---

Use when testing compat.
'

  SKILLS_ROOT="$FIXTURES" COMPAT_PRESETS_FILE="$BATS_TEST_TMPDIR/compat-presets.json" COMPAT_CONFIG_FILE="$BATS_TEST_TMPDIR/compat-config.json" COMPAT_COMMANDS_DIR="$BATS_TEST_TMPDIR/compat-commands" run bash "$SKILLS_SCRIPT"

  assert_status 1
  assert_output_contains "__dangling_preset_zzz__"
  assert_output_contains "__dangling_cmd_zzz__"
  assert_output_contains "__dangling_agent_zzz__"
  assert_output_contains "__missing_bin_zzz__"
  assert_output_contains "99.0"
  assert_output_contains "failed"
}

@test "compat: higher patch on equal major.minor does not satisfy requires_bash" {
  # Stubbed PATH: fake `bash` reports 5.1.0 exactly (same stub pattern as the
  # impossible-bash test). Demanding 5.1.999 must FAIL — the floor compares
  # the full major.minor.patch tuple, not just major.minor.
  local stubbin="$BATS_TEST_TMPDIR/stubbin"
  mkdir -p "$stubbin"
  cat > "$stubbin/bash" <<EOF
#!$BASH_BIN
if [ "\${1:-}" = "--version" ]; then
  echo "GNU bash, version 5.1.0(1)-release (x86_64-pc-linux-gnu)"
  exit 0
fi
exec "$BASH_BIN" "\$@"
EOF
  chmod +x "$stubbin/bash"
  write_skill "patch-needer" '---
name: patch-needer
description: Skill requiring a newer bash patch. Use when testing compat.
license: MIT
requires_bash: "5.1.999"
---

Use when testing compat.
'

  SKILLS_ROOT="$FIXTURES" PATH="$stubbin:$PATH" run bash "$SKILLS_SCRIPT"

  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "patch-needer"
  assert_output_contains "bash"
  assert_output_contains "5.1.999"
}

@test "compat: unterminated block comment in preset manifest fails validation" {
  # The manifest is truncated inside a /* comment: accepting it would validate
  # against silently-dropped content, so the snapshot must reject it (exit 1,
  # not infra exit 2).
  printf '{"presets": {"fixture-preset-a": {}} /* never closed' > "$BATS_TEST_TMPDIR/compat-presets.json"
  write_skill "preset-user" '---
name: preset-user
description: Skill declaring presets. Use when testing compat.
license: MIT
presets:
  - fixture-preset-a
---

Use when testing compat.
'

  SKILLS_ROOT="$FIXTURES" COMPAT_PRESETS_FILE="$BATS_TEST_TMPDIR/compat-presets.json" run bash "$SKILLS_SCRIPT"

  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "compat manifest"
}

# Slice 1 contract (presets + requires_bash, still pinned): each entry of
# `presets:` resolves against the preset manifest (absent entry = per-entry
# hard FAIL naming skill/class/declaration, exit 1); `requires_bash:`
# resolves `bash` via PATH against `bash --version` (unsatisfiable minimum =
# hard FAIL naming skill/class/version, exit 1). Both fixtures below are
# otherwise fully form-valid so the compat FAIL is the only finding.

@test "compat: dangling preset declaration exits 1 with a deterministic FAIL" {
  # Fixed preset array: only fixture-preset-a/b exist. The skill declares one
  # valid entry plus one dangling entry.
  cat > "$BATS_TEST_TMPDIR/compat-presets.json" <<'EOF'
{"presets": {"fixture-preset-a": {}, "fixture-preset-b": {}}}
EOF
  write_skill "preset-user" '---
name: preset-user
description: Skill declaring presets. Use when testing compat.
license: MIT
presets:
  - fixture-preset-a
  - __dangling_preset_zzz__
---

Use when testing compat.
'

  SKILLS_ROOT="$FIXTURES" COMPAT_PRESETS_FILE="$BATS_TEST_TMPDIR/compat-presets.json" run bash "$SKILLS_SCRIPT"

  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "preset-user"
  assert_output_contains "preset"
  assert_output_contains "__dangling_preset_zzz__"
}

@test "compat: impossible bash requirement exits 1 with a deterministic FAIL" {
  # Stubbed PATH: a fake `bash` reporting a FIXED old version proves
  # PATH-based resolution; every other invocation execs the real bash (via
  # BASH_BIN captured in setup) so the validator itself still runs. The skill
  # demands bash 99, which no fixture runtime can satisfy.
  local stubbin="$BATS_TEST_TMPDIR/stubbin"
  mkdir -p "$stubbin"
  # Absolute shebang (never /usr/bin/env bash): with stubbin first on PATH,
  # an env shebang would re-resolve `bash` to this stub and recurse until
  # E2BIG. BASH_BIN (absolute, captured in setup) is the real interpreter.
  cat > "$stubbin/bash" <<EOF
#!$BASH_BIN
# RED fixture: fixed bash version for compat tests; all other argv exec real bash.
if [ "\${1:-}" = "--version" ]; then
  echo "GNU bash, version 5.1.0(1)-release (x86_64-pc-linux-gnu)"
  exit 0
fi
exec "$BASH_BIN" "\$@"
EOF
  chmod +x "$stubbin/bash"
  write_skill "bash-needer" '---
name: bash-needer
description: Skill requiring a new bash. Use when testing compat.
license: MIT
requires_bash: "99.0"
---

Use when testing compat.
'

  SKILLS_ROOT="$FIXTURES" PATH="$stubbin:$PATH" run bash "$SKILLS_SCRIPT"

  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "bash-needer"
  assert_output_contains "bash"
  assert_output_contains "99.0"
}

@test "validate-skills: multiple byte-exact duplicates are all reported (collect-all)" {
  # Two distinct duplicate pairs in one run: both must be reported (never
  # fail-fast) with one FAIL line per pair.
  local content_a content_b
  content_a='---
name: dup-a
description: First duplicated skill. Use when testing the validator.
license: MIT
---

Use when running the validation suite.
'
  content_b='---
name: dup-b
description: Second duplicated skill. Use when testing the validator.
license: MIT
---

Use when running the validation suite.
'
  write_skill "dup-a" "$content_a"
  write_global_skill "dup-a" "$content_a"
  write_skill "dup-b" "$content_b"
  write_global_skill "dup-b" "$content_b"

  SKILLS_ROOT="$FIXTURES" GLOBAL_SKILLS_ROOT="$GLOBAL_FIXTURES" run bash "$SKILLS_SCRIPT"

  assert_status 1
  assert_output_contains "FAIL: duplicate skill 'dup-a'"
  assert_output_contains "FAIL: duplicate skill 'dup-b'"
  assert_output_contains "failed"
}
