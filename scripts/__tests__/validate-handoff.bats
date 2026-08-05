#!/usr/bin/env bats
# Meta-tests for scripts/validate-handoff.sh (change dev-infra-config-validators,
# task T3). The script validates that a HANDOFF.md file carries the Prognosis
# schema: the `## Prognosis for next cycle` heading plus the 5 required `###`
# subsections (session_summary / fixes_applied / open_tickets /
# verification_request / resume_instructions), strict literal match.
#
# Exit-code contract under test:
#   0  all required headings/subsections present (extra subsections are SOFT
#      warnings to stderr — never flip the exit code, Q5 ruling)
#   1  at least one required heading or subsection missing (HARD)
#   2  infrastructure failure (no input path argument / nonexistent path /
#      reference template missing)
#
# Isolation: each test writes a fixture HANDOFF file under $BATS_TEST_TMPDIR and
# passes it as the positional argument. The reference template is pointed at a
# fixture copy via HANDOFF_TEMPLATE so the real openspec/templates/HANDOFF.md is
# never required by the suite (the template-missing case is tested explicitly).

load test-helper

HANDOFF_SCRIPT="$REPO_ROOT/scripts/validate-handoff.sh"

# write_handoff <file> <content...>: writes the fixture HANDOFF file with printf
# (no interpolation).
write_handoff() {
  local file="$1"
  shift
  printf '%s\n' "$@" > "$file"
}

# valid_handoff <file>: writes a fully conforming HANDOFF fixture — the
# Prognosis heading + all 5 required subsections, no extras.
valid_handoff() {
  local file="$1"
  write_handoff "$file" \
    "# HANDOFF.md — Cycle c-test" \
    "" \
    "## Prognosis for next cycle" \
    "" \
    "### session_summary" \
    "summary" \
    "" \
    "### fixes_applied" \
    "fixes" \
    "" \
    "### open_tickets" \
    "tickets" \
    "" \
    "### verification_request" \
    "verification" \
    "" \
    "### resume_instructions" \
    "resume"
}

# fixture_template <file>: writes a minimal reference template carrying the
# Prognosis heading + the 5 required subsections (mirrors the real
# openspec/templates/HANDOFF.md schema shape).
fixture_template() {
  local file="$1"
  write_handoff "$file" \
    "# HANDOFF.md — Template" \
    "" \
    "## Prognosis for next cycle" \
    "" \
    "### session_summary" \
    "### fixes_applied" \
    "### open_tickets" \
    "### verification_request" \
    "### resume_instructions"
}

setup() {
  FIXTURES="$BATS_TEST_TMPDIR"
  TPL="$FIXTURES/reference-template.md"
  fixture_template "$TPL"
}

@test "validate-handoff: valid HANDOFF with all 5 subsections exits 0" {
  local f="$FIXTURES/valid.md"
  valid_handoff "$f"

  HANDOFF_TEMPLATE="$TPL" run bash "$HANDOFF_SCRIPT" "$f"

  assert_status 0
  assert_output_contains "ok: session_summary"
  assert_output_contains "ok: fixes_applied"
  assert_output_contains "ok: open_tickets"
  assert_output_contains "ok: verification_request"
  assert_output_contains "ok: resume_instructions"
  assert_output_contains "5 passed, 0 failed, 0 warnings"
  assert_output_not_contains "FAIL:"
  assert_output_not_contains "warn:"
}

@test "validate-handoff: missing one required subsection exits 1 and names it" {
  local f="$FIXTURES/missing-sub.md"
  write_handoff "$f" \
    "# HANDOFF.md — Cycle c-test" \
    "" \
    "## Prognosis for next cycle" \
    "" \
    "### session_summary" \
    "summary" \
    "" \
    "### fixes_applied" \
    "fixes" \
    "" \
    "### open_tickets" \
    "tickets" \
    "" \
    "### verification_request" \
    "verification"

  HANDOFF_TEMPLATE="$TPL" run bash "$HANDOFF_SCRIPT" "$f"

  assert_status 1
  assert_output_contains "FAIL: missing required subsection 'resume_instructions'"
  assert_output_contains "4 passed, 1 failed, 0 warnings"
  # collect-all: the 4 present subsections still print ok: lines
  assert_output_contains "ok: session_summary"
}

@test "validate-handoff: missing Prognosis heading exits 1" {
  local f="$FIXTURES/missing-heading.md"
  write_handoff "$f" \
    "# HANDOFF.md — Cycle c-test" \
    "" \
    "### session_summary" \
    "summary"

  HANDOFF_TEMPLATE="$TPL" run bash "$HANDOFF_SCRIPT" "$f"

  assert_status 1
  assert_output_contains "FAIL: missing required heading '## Prognosis for next cycle'"
  assert_output_contains "0 passed, 1 failed, 0 warnings"
}

@test "validate-handoff: extra subsection is a SOFT warn, exit stays 0" {
  local f="$FIXTURES/extra-sub.md"
  write_handoff "$f" \
    "# HANDOFF.md — Cycle c-test" \
    "" \
    "## Prognosis for next cycle" \
    "" \
    "### session_summary" \
    "summary" \
    "" \
    "### fixes_applied" \
    "fixes" \
    "" \
    "### open_tickets" \
    "tickets" \
    "" \
    "### verification_request" \
    "verification" \
    "" \
    "### resume_instructions" \
    "resume" \
    "" \
    "### blockers_encountered" \
    "cycle-specific extra subsection"

  HANDOFF_TEMPLATE="$TPL" run bash "$HANDOFF_SCRIPT" "$f"

  assert_status 0
  assert_output_contains "warn: extra subsection 'blockers_encountered'"
  assert_output_contains "5 passed, 0 failed, 1 warnings"
}

@test "validate-handoff: no input path and no usable default exits 2" {
  # No positional argument AND the default template is unavailable -> INFRA
  # (the no-argument case only manifests when the default cannot supply a
  # target; with the template present the make-callable path validates it).
  HANDOFF_TEMPLATE="$FIXTURES/no-such-template.md" run bash "$HANDOFF_SCRIPT"

  assert_status 2
  assert_output_contains "FAIL:"
}

@test "validate-handoff: nonexistent input path exits 2" {
  HANDOFF_TEMPLATE="$TPL" run bash "$HANDOFF_SCRIPT" "$FIXTURES/does-not-exist.md"

  assert_status 2
  assert_output_contains "FAIL:"
}
