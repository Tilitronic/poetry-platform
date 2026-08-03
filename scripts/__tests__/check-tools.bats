#!/usr/bin/env bats
# Unit tests for scripts/check-tools.sh (seam S2) + .mise.toml integrity (S4).
#
# mise/node/pnpm are replaced by fakes on PATH — no real toolchain is involved.
# The script is copied into an isolated temp tree (dev-stack.bats pattern) so
# its repo-root resolution points at a controlled tree; only the S4 test asserts
# on the REAL repo .mise.toml (the file this change creates).

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# install_fakes <dir>: plants fake mise/node/pnpm in <dir> and prepends it to
# PATH. Behavior is driven by env (set per test):
#   FAKE_MISE_WHICH_FAIL=1          mise which exits 1 (shim not active)
#   FAKE_MISE_CURRENT_MISMATCH=1    mise current reports a wrong version
#   FAKE_NODE_MISMATCH=1            node --version reports a wrong version
#   FAKE_PNPM_MISMATCH=1            pnpm --version reports a wrong version
install_fakes() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/mise" <<'FAKEMISE'
#!/usr/bin/env bash
case "${1:-}" in
  trust) exit 0 ;;
  install) exit 0 ;;
  which)
    [ "${FAKE_MISE_WHICH_FAIL:-}" = "1" ] && exit 1
    printf '%s\n' "/fake/installs/${2}/current/bin/${2}"
    exit 0
    ;;
  current)
    if [ "${FAKE_MISE_CURRENT_MISMATCH:-}" = "1" ]; then
      printf '%s\n' "99.0.0"
      exit 0
    fi
    case "${2:-}" in
      node) printf '%s\n' "24.18.0" ;;
      pnpm) printf '%s\n' "10.33.0" ;;
      *) exit 1 ;;
    esac
    ;;
  *) exit 1 ;;
esac
FAKEMISE
  cat > "$dir/node" <<'FAKENODE'
#!/usr/bin/env bash
[ "${FAKE_NODE_MISMATCH:-}" = "1" ] && { printf '%s\n' "v99.0.0"; exit 0; }
printf '%s\n' "v24.18.0"
FAKENODE
  cat > "$dir/pnpm" <<'FAKEPNPM'
#!/usr/bin/env bash
[ "${FAKE_PNPM_MISMATCH:-}" = "1" ] && { printf '%s\n' "99.0.0"; exit 0; }
printf '%s\n' "10.33.0"
FAKEPNPM
  chmod +x "$dir/mise" "$dir/node" "$dir/pnpm"
  PATH="$dir:$PATH"
  export PATH
}

# setup_tree <with_mise_toml 0|1>: copies check-tools.sh into an isolated tree
# and (optionally) seeds it with a .mise.toml copy. Echoes the tree root.
setup_tree() {
  local tree="$BATS_TEST_TMPDIR/tree"
  mkdir -p "$tree/scripts"
  cp "$REPO_ROOT/scripts/check-tools.sh" "$tree/scripts/check-tools.sh"
  if [ "${1:-1}" = "1" ]; then
    cp "$REPO_ROOT/.mise.toml" "$tree/.mise.toml"
  fi
  echo "$tree"
}

@test "check-tools: mise present + pins match -> exit 0 with ok summary" {
  install_fakes "$BATS_TEST_TMPDIR/fakes"
  tree="$(setup_tree 1)"

  run bash "$tree/scripts/check-tools.sh"

  assert_status 0
  assert_output_contains "ok: node 24.18.0 (mise-declared, version matches)"
  assert_output_contains "ok: pnpm 10.33.0 (mise-declared, version matches)"
}

@test "check-tools: mise absent -> exit 1 with 'run make build first' pointer" {
  tree="$(setup_tree 1)"

  # Strip PATH to a known-good base that cannot contain mise.
  run env PATH="/usr/bin:/bin" bash "$tree/scripts/check-tools.sh"

  assert_status 1
  assert_output_contains "'make build' first"
}

@test "check-tools: .mise.toml missing -> exit 1 with clear message" {
  install_fakes "$BATS_TEST_TMPDIR/fakes"
  tree="$(setup_tree 0)"

  run bash "$tree/scripts/check-tools.sh"

  assert_status 1
  assert_output_contains "no .mise.toml at repo root"
}

@test "check-tools: mise which fails (shim not active) -> exit 1" {
  install_fakes "$BATS_TEST_TMPDIR/fakes"
  tree="$(setup_tree 1)"
  export FAKE_MISE_WHICH_FAIL=1

  run bash "$tree/scripts/check-tools.sh"

  assert_status 1
  assert_output_contains "node shim not active"
}

@test "check-tools: mise current mismatch (wrong pin) -> exit 1" {
  install_fakes "$BATS_TEST_TMPDIR/fakes"
  tree="$(setup_tree 1)"
  export FAKE_MISE_CURRENT_MISMATCH=1

  run bash "$tree/scripts/check-tools.sh"

  assert_status 1
  assert_output_contains "expected 24.18.0"
}

@test "check-tools: real tool mismatch (node --version differs) -> exit 1" {
  install_fakes "$BATS_TEST_TMPDIR/fakes"
  tree="$(setup_tree 1)"
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
