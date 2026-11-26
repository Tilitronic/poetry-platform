#!/usr/bin/env bats
# Unit tests for scripts/check-tools.sh (seam S2) + .mise.toml integrity (S4).
#
# mise/node/pnpm are replaced by fakes on PATH — no real toolchain is involved.
# The script is copied into an isolated temp tree (dev-stack.bats pattern) so
# its repo-root resolution points at a controlled tree; only the S4 test asserts
# on the REAL repo .mise.toml (the file this change creates).

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# setup_tools_tree <with_mise_toml 0|1> [opencode_arg]: the shared helper tree
# plus a Dockerfile.dev, because the opencode pin now resolves from ARG
# OPENCODE_VERSION whenever .mise.toml carries no opencode key - and the repo
# copy no longer does. An empty [opencode_arg] plants no Dockerfile.dev (the
# unresolvable-pin fixture). Echoes the tree root.
setup_tools_tree() {
  local tree
  tree="$(setup_check_tools_tree "${1:-1}")"
  if [ -n "${2-1.18.32}" ]; then
    printf 'ARG OPENCODE_VERSION=%s\n' "${2-1.18.32}" > "$tree/Dockerfile.dev"
  fi
  echo "$tree"
}

@test "check-tools: mise present + pins match -> exit 0 with ok summary" {
  install_check_tools_fakes "$BATS_TEST_TMPDIR/fakes"
  tree="$(setup_tools_tree 1)"

  run bash "$tree/scripts/check-tools.sh"

  assert_status 0
  assert_output_contains "ok: node 24.18.0 (mise-declared, version matches)"
  assert_output_contains "ok: pnpm 10.33.0 (mise-declared, version matches)"
}

@test "check-tools: mise absent -> exit 1 with 'run make build first' pointer" {
  tree="$(setup_tools_tree 1)"

  # Strip PATH to a known-good base that cannot contain mise.
  run env PATH="/usr/bin:/bin" bash "$tree/scripts/check-tools.sh"

  assert_status 1
  assert_output_contains "'make build' first"
}

@test "check-tools: .mise.toml missing -> exit 2 with clear message" {
  install_check_tools_fakes "$BATS_TEST_TMPDIR/fakes"
  tree="$(setup_check_tools_tree 0)"

  run bash "$tree/scripts/check-tools.sh"

  # S2: missing .mise.toml is an INFRA error (exit 2) because the pin source
  # is absent, not a tool-mismatch (exit 1).
  assert_status 2
  assert_output_contains "cannot read node pin"
  # The message must name the file path for operator clarity
  assert_output_contains ".mise.toml"
}

@test "check-tools: mise which fails (shim not active) -> exit 1" {
  install_check_tools_fakes "$BATS_TEST_TMPDIR/fakes"
  tree="$(setup_tools_tree 1)"
  export FAKE_MISE_WHICH_FAIL=1

  run bash "$tree/scripts/check-tools.sh"

  assert_status 1
  assert_output_contains "node shim not active"
}

@test "check-tools: mise current mismatch (wrong pin) -> exit 1" {
  install_check_tools_fakes "$BATS_TEST_TMPDIR/fakes"
  tree="$(setup_tools_tree 1)"
  export FAKE_MISE_CURRENT_MISMATCH=1

  run bash "$tree/scripts/check-tools.sh"

  assert_status 1
  assert_output_contains "expected 24.18.0"
}

@test "check-tools: real tool mismatch (node --version differs) -> exit 1" {
  install_check_tools_fakes "$BATS_TEST_TMPDIR/fakes"
  tree="$(setup_tools_tree 1)"
  export FAKE_NODE_MISMATCH=1

  run bash "$tree/scripts/check-tools.sh"

  assert_status 1
  assert_output_contains "expected 24.18.0"
}

@test "check-tools: opencode key absent -> pin resolves from the Dockerfile ARG" {
  install_check_tools_fakes "$BATS_TEST_TMPDIR/fakes"
  # Real `opencode --version` prints "opencode vX.Y.Z", not a bare version.
  printf '#!/usr/bin/env bash\nprintf "opencode v1.18.32\\n"\n' > "$BATS_TEST_TMPDIR/fakes/opencode"
  chmod +x "$BATS_TEST_TMPDIR/fakes/opencode"
  tree="$(setup_tools_tree 1 1.18.32)"

  run bash "$tree/scripts/check-tools.sh"

  # The repo .mise.toml copy has no opencode key, so the pin must come from the
  # fixture ARG; a hard error here (exit 2) is the regression this guards.
  assert_status 0
  assert_output_contains "ok: opencode 1.18.32 (Dockerfile.dev ARG, version matches)"
}

@test "check-tools: opencode .mise.toml key present -> wins over the Dockerfile ARG" {
  install_check_tools_fakes "$BATS_TEST_TMPDIR/fakes"
  # Deliberately mismatched ARG: using it would fail the opencode probe.
  tree="$(setup_tools_tree 1 9.9.9)"
  printf 'opencode = "1.18.32"\n' >> "$tree/.mise.toml"

  run bash "$tree/scripts/check-tools.sh"

  assert_status 0
  assert_output_contains "ok: opencode 1.18.32 (mise-declared, version matches)"
}

@test "check-tools: opencode key absent and no Dockerfile ARG -> exit 2" {
  install_check_tools_fakes "$BATS_TEST_TMPDIR/fakes"
  tree="$(setup_tools_tree 1 '')"

  run bash "$tree/scripts/check-tools.sh"

  # Neither source carries the pin: still INFRA (exit 2), never a silent pass.
  assert_status 2
  assert_output_contains "cannot read opencode pin"
}

@test "check-tools: .mise.toml structural integrity (S4)" {
  # S4 asserts the single source of truth: header contract comment present,
  # [tools] section declaring node + pnpm with the spec-pinned versions.
  assert_file_contains "$REPO_ROOT/.mise.toml" "[tools]"
  assert_file_contains "$REPO_ROOT/.mise.toml" 'node = "24.18.0"'
  assert_file_contains "$REPO_ROOT/.mise.toml" 'pnpm = "10.33.0"'
  assert_file_contains "$REPO_ROOT/.mise.toml" "derived from Dockerfile.dev ARGs"
}
