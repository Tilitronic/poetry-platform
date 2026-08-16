#!/usr/bin/env bats
# Render tests for scripts/changelog-render — the derived-view generator that
# overwrites .opencode/CHANGELOG.md from .opencode/CHANGELOG.yaml (DIA-194
# Variant B, ADR: Derived MD View Committed).
#
# Hermetic FAKE-mock pattern (validate-memory-shelf.bats): the render script
# is copied into an isolated temp tree and driven with CHANGELOG_YAML /
# CHANGELOG_MD env overrides pointing at committed fixtures + a temp output —
# the REAL .opencode/CHANGELOG.md is never written here (STEP 4 of DIA-194
# regenerates it against the real ledger).
#
# Assertions stay on the render script's stable protocol: exit code, the
# derived MD layout (## header + Change/Files/Verification bullets), and the
# defensive failures (empty file parses to None -> exit 1; missing required
# key -> exit 1).

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
FIXTURES="$REPO_ROOT/scripts/__tests__/fixtures"

setup_tree() {
  local tree="$BATS_TEST_TMPDIR/tree"
  mkdir -p "$tree/scripts"
  cp "$REPO_ROOT/scripts/changelog-render" "$tree/scripts/changelog-render"
  echo "$tree"
}

# run_render <tree> <yaml> <md_out>: runs the render with hermetic env
# overrides; the output path lives under BATS_TEST_TMPDIR so the real
# .opencode/CHANGELOG.md is never touched.
run_render() {
  run env CHANGELOG_YAML="$2" CHANGELOG_MD="$3" bash "$1/scripts/changelog-render"
}

@test "changelog-render: 2-entry fixture -> exit 0, derived MD has headers and bullets in ledger order" {
  tree="$(setup_tree)"
  out="$BATS_TEST_TMPDIR/CHANGELOG.md"
  run_render "$tree" "$FIXTURES/changelog-valid.yaml" "$out"

  assert_status 0
  assert_output_contains "ok: wrote $out (2 entries)"
  assert_file_exists "$out"

  # First entry header (newest first, matches the fixture's ledger order).
  assert_file_contains "$out" "## 2026-08-16 - DIA-183 (CLOSED): ponytail-half closure (Variant B, doc-only)"
  assert_file_contains "$out" "- **Change:** Change: DIA-183 (ponytail half) closed via developer-approved Variant B."
  assert_file_contains "$out" "- **Files:** AGENTS.md - docs/PONYTAIL-DEBT.md"
  assert_file_contains "$out" "- **Verification:** make test-config exit 0. Review: developer-approved Variant B."

  # Second entry header + its scope (block-scalar prose survives the round trip).
  assert_file_contains "$out" "## 2026-08-15 - DIA-190/192/193: delegation-observer TUI-safe notification downgrades"
  assert_file_contains "$out" "- **Files:** .opencode/plugins/delegation-observer.ts - .opencode/CHANGELOG.yaml"

  # Status-absent entries render without parens; order is preserved (entry 1
  # before entry 2).
  first_line="$(grep -n "DIA-183" "$out" | head -1 | cut -d: -f1)"
  second_line="$(grep -n "DIA-190/192/193" "$out" | head -1 | cut -d: -f1)"
  [ "$first_line" -lt "$second_line" ]
}

@test "changelog-render: empty file (parses to None) -> exit 1 with FAIL line" {
  tree="$(setup_tree)"
  out="$BATS_TEST_TMPDIR/CHANGELOG.md"
  run_render "$tree" "$FIXTURES/changelog-empty.yaml" "$out"

  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_not_contains "ok:"
}

@test "changelog-render: explicit empty array -> exit 0, title block only" {
  tree="$(setup_tree)"
  out="$BATS_TEST_TMPDIR/CHANGELOG.md"
  run_render "$tree" "$FIXTURES/changelog-empty-array.yaml" "$out"

  assert_status 0
  assert_output_contains "ok: wrote $out (0 entries)"
  assert_file_contains "$out" "# OpenCode Config Changelog"
  assert_file_contains "$out" "(no changelog entries)"
}

@test "changelog-render: entry missing required key -> exit 1 with FAIL line" {
  tree="$(setup_tree)"
  out="$BATS_TEST_TMPDIR/CHANGELOG.md"
  run_render "$tree" "$FIXTURES/changelog-missing-required.yaml" "$out"

  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_not_contains "ok:"
}

@test "changelog-render: missing ledger file -> exit 2 INFRA" {
  tree="$(setup_tree)"
  out="$BATS_TEST_TMPDIR/CHANGELOG.md"
  run_render "$tree" "$BATS_TEST_TMPDIR/does-not-exist.yaml" "$out"

  assert_status 2
  assert_output_contains "CHANGELOG.yaml not found"
}
