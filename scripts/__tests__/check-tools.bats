#!/usr/bin/env bats
# Unit tests for scripts/check-tools.sh (seam S2) + .mise.toml integrity (S4).
#
# mise/node/pnpm are replaced by fakes on PATH — no real toolchain is involved.
# The script is copied into an isolated temp tree (dev-stack.bats pattern) so
# its repo-root resolution points at a controlled tree; only the S4 test asserts
# on the REAL repo .mise.toml (the file this change creates).

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

@test "check-tools: mise present + pins match -> exit 0 with ok summary" {
  install_check_tools_fakes "$BATS_TEST_TMPDIR/fakes"
  tree="$(setup_check_tools_tree 1)"

  run bash "$tree/scripts/check-tools.sh"

  assert_status 0
  assert_output_contains "ok: node 24.18.0 (mise-declared, version matches)"
  assert_output_contains "ok: pnpm 10.33.0 (mise-declared, version matches)"
}

@test "check-tools: mise absent -> exit 1 with 'run make build first' pointer" {
  tree="$(setup_check_tools_tree 1)"

  # Strip PATH to a known-good base that cannot contain mise.
  run env PATH="/usr/bin:/bin" bash "$tree/scripts/check-tools.sh"

  assert_status 1
  assert_output_contains "'make build' first"
}

@test "check-tools: .mise.toml missing -> exit 1 with clear message" {
  install_check_tools_fakes "$BATS_TEST_TMPDIR/fakes"
  tree="$(setup_check_tools_tree 0)"

  run bash "$tree/scripts/check-tools.sh"

  assert_status 1
  assert_output_contains "no .mise.toml at repo root"
}

@test "check-tools: mise which fails (shim not active) -> exit 1" {
  install_check_tools_fakes "$BATS_TEST_TMPDIR/fakes"
  tree="$(setup_check_tools_tree 1)"
  export FAKE_MISE_WHICH_FAIL=1

  run bash "$tree/scripts/check-tools.sh"

  assert_status 1
  assert_output_contains "node shim not active"
}

@test "check-tools: mise current mismatch (wrong pin) -> exit 1" {
  install_check_tools_fakes "$BATS_TEST_TMPDIR/fakes"
  tree="$(setup_check_tools_tree 1)"
  export FAKE_MISE_CURRENT_MISMATCH=1

  run bash "$tree/scripts/check-tools.sh"

  assert_status 1
  assert_output_contains "expected 24.18.0"
}

@test "check-tools: real tool mismatch (node --version differs) -> exit 1" {
  install_check_tools_fakes "$BATS_TEST_TMPDIR/fakes"
  tree="$(setup_check_tools_tree 1)"
  export FAKE_NODE_MISMATCH=1

  run bash "$tree/scripts/check-tools.sh"

  assert_status 1
  assert_output_contains "expected 24.18.0"
}

@test "check-tools: .mise.toml structural integrity (S4)" {
  # S4 asserts the single source of truth: header contract comment present,
  # [tools] section declaring node + pnpm with the spec-pinned versions.
  assert_file_contains "$REPO_ROOT/.mise.toml" "[tools]"
  assert_file_contains "$REPO_ROOT/.mise.toml" 'node = "24.18.0"'
  assert_file_contains "$REPO_ROOT/.mise.toml" 'pnpm = "10.33.0"'
  assert_file_contains "$REPO_ROOT/.mise.toml" "derived from Dockerfile.dev ARGs"
}
