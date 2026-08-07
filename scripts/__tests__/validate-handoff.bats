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

# write_json_handoff <file> [tamper_key]: writes a JSON handoff fixture with a
# prognosis object carrying the 5 canonical subsection keys and a checksum
# computed over the canonical prognosis serialization — the DIA-061 method:
# `jq -c '.prognosis | to_entries | sort_by(.key) | from_entries'` piped to
# sha256sum via printf '%s' (NO trailing newline). When [tamper_key] is given,
# the prognosis value for that key is rewritten AFTER the checksum is computed,
# so the stored checksum no longer matches the file's canonical serialization
# (simulates a tampered handoff).
write_json_handoff() {
  local file="$1"
  local tamper_key="${2:-}"
  jq -n --arg ss "cycle summary" --arg fa "fix a" --arg ot "ticket 1" \
    --arg vr "verify x" --arg ri "resume here" \
    '{cycle_id: "c-fixture", checksum: "0000000000000000000000000000000000000000000000000000000000000000", prognosis: {session_summary: $ss, fixes_applied: $fa, open_tickets: $ot, verification_request: $vr, resume_instructions: $ri}}' > "$file"
  local canonical checksum
  # MUST stay byte-identical to the canonical serialization in
  # validate-handoff.sh (jq sorted-keys + printf '%s' + sha256sum) — change
  # one, change both.
  canonical="$(jq -c '.prognosis | to_entries | sort_by(.key) | from_entries' "$file")"
  checksum="$(printf '%s' "$canonical" | sha256sum | cut -d' ' -f1)"
  jq --arg cs "$checksum" '.checksum = $cs' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  if [ -n "$tamper_key" ]; then
    jq --arg k "$tamper_key" --arg v "TAMPERED value" '.prognosis[$k] = $v' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  fi
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

@test "validate-handoff: valid JSON handoff skips markdown check and verifies checksum, exit 0" {
  # DIA-045 F6: JSON handoffs (current-handoff.json) must NOT run the markdown
  # heading/subsection schema — the checksum block is the authoritative gate.
  local f="$FIXTURES/valid.json"
  write_json_handoff "$f"

  HANDOFF_TEMPLATE="$TPL" run bash "$HANDOFF_SCRIPT" "$f"

  assert_status 0
  assert_output_contains "info: JSON handoff detected"
  assert_output_contains "skipping markdown schema check"
  assert_output_contains "ok: checksum verified"
  assert_output_contains "1 passed, 0 failed, 0 warnings"
  # The markdown schema branch was skipped entirely: no heading FAIL and no
  # per-subsection ok:/FAIL: lines from the markdown block.
  assert_output_not_contains "missing required heading '## Prognosis for next cycle'"
  assert_output_not_contains "missing required subsection"
  assert_output_not_contains "ok: session_summary"
}

@test "validate-handoff: tampered JSON handoff fails checksum validation, exit 1" {
  # DIA-045 F6: a JSON handoff whose stored checksum no longer matches the
  # canonical prognosis serialization must fail hard (exit 1) — never fall
  # through to a markdown-heading error.
  local f="$FIXTURES/tampered.json"
  write_json_handoff "$f" "session_summary"

  HANDOFF_TEMPLATE="$TPL" run bash "$HANDOFF_SCRIPT" "$f"

  assert_status 1
  assert_output_contains "FAIL: checksum mismatch"
  assert_output_contains "0 passed, 1 failed, 0 warnings"
  assert_output_not_contains "missing required heading '## Prognosis for next cycle'"
}
