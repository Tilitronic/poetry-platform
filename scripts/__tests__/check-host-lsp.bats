#!/usr/bin/env bats
# Gate A unit tests for scripts/check-host-lsp.sh (host-scope 3-gate acceptance,
# proposal.md §Host-scope 3-gate acceptance). FAKE-mock pattern from
# check-tools.bats.
#
# The probe script is copied into an isolated temp tree (check-tools.bats
# pattern) so its lsp-versions.env resolution points at a controlled tree, and
# every `--version` probe is driven by a FAKE binary planted on PATH. INVARIANT:
# bats NEVER shells a real LSP binary — each test runs with an explicit
# PATH containing only the fakes dir + /usr/bin:/bin, so real
# typescript-language-server / pyright / rust-analyzer are unreachable by
# construction.
#
# rust-analyzer is CONTAINER-FIRST (DIA-106): the probe execs it THROUGH the
# dev container via `docker compose exec`. The container path is mocked with a
# fake `docker` on PATH (eval-lite.bats PATH-docker shim pattern): UP prints a
# canned `rust-analyzer --version` (version-match / version-mismatch against
# the 1.97.1 pin), DOWN fails every probe so the host PATH fallback runs
# (host-matches-pin / host-drifts-from-pin scenarios).

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# install_fakes <dir>: plants fake typescript-language-server / pyright /
# rust-analyzer in <dir>. Behavior is driven by env (set per test):
#   FAKE_TSLS_MISMATCH=1     typescript-language-server reports 99.0.0
#   FAKE_PYRIGHT_MISMATCH=1  pyright reports pyright 99.0.0
#   FAKE_RA_MISMATCH=1       rust-analyzer reports rust-analyzer 99.0.0 (...)
#   FAKE_RA_OLD=1            rust-analyzer reports rust-analyzer 1.83.0 (...)
#                            (host rustup default, the DIA-106 designed drift)
install_fakes() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/typescript-language-server" <<'FAKETSLS'
#!/usr/bin/env bash
[ "${FAKE_TSLS_MISMATCH:-}" = "1" ] && { printf '%s\n' "99.0.0"; exit 0; }
printf '%s\n' "5.3.0"
FAKETSLS
  cat > "$dir/pyright" <<'FAKEPYRIGHT'
#!/usr/bin/env bash
[ "${FAKE_PYRIGHT_MISMATCH:-}" = "1" ] && { printf '%s\n' "pyright 99.0.0"; exit 0; }
printf '%s\n' "pyright 1.1.411"
FAKEPYRIGHT
  cat > "$dir/rust-analyzer" <<'FAKERA'
#!/usr/bin/env bash
[ "${FAKE_RA_MISMATCH:-}" = "1" ] && { printf '%s\n' "rust-analyzer 99.0.0 (fake 2026-08-06)"; exit 0; }
[ "${FAKE_RA_OLD:-}" = "1" ] && { printf '%s\n' "rust-analyzer 1.83.0 (fake 2026-08-06)"; exit 0; }
printf '%s\n' "rust-analyzer 1.97.1 (fake 2026-08-06)"
FAKERA
  chmod +x "$dir/typescript-language-server" "$dir/pyright" "$dir/rust-analyzer"
}

# mock_docker_up <version>: plants a fake `docker` on PATH whose
# `compose ... exec dev bash -lc 'rust-analyzer --version'` probe prints the
# canned version (container UP path). Echoes the shim dir (pass to run_probe).
mock_docker_up() {
  local version="${1:-1.97.1}"
  local bindir="$BATS_TEST_TMPDIR/fakebin"
  mkdir -p "$bindir"
  cat > "$bindir/docker" <<EOF
#!/usr/bin/env bash
# Fake docker for check-host-lsp tests: container UP -> the rust-analyzer
# probe prints the canned version.
if [ "\${1:-}" = "compose" ]; then
  for a in "\$@"; do
    if [ "\$a" = "exec" ]; then
      printf '%s\n' "rust-analyzer ${version} (fake container 2026-08-06)"
      exit 0
    fi
  done
fi
exit 1
EOF
  chmod +x "$bindir/docker"
  echo "$bindir"
}

# mock_docker_down: plants a fake `docker` on PATH whose every compose probe
# FAILS (container DOWN path — the host PATH fallback must run). Echoes the
# shim dir (pass to run_probe).
mock_docker_down() {
  local bindir="$BATS_TEST_TMPDIR/fakebin"
  mkdir -p "$bindir"
  cat > "$bindir/docker" <<'FAKEDOCKER'
#!/usr/bin/env bash
# Fake docker for check-host-lsp tests: container DOWN -> every probe fails.
exit 1
FAKEDOCKER
  chmod +x "$bindir/docker"
  echo "$bindir"
}

# run_probe <tree> <fakes_dir> [docker_dir]: runs check-host-lsp.sh with a
# hermetic PATH (fakes dir + optional fake docker dir + /usr/bin:/bin only) so
# no real LSP binary or real docker can ever be shelled.
run_probe() {
  local tree="$1"
  local fakes="$2"
  local docker_dir="${3:-}"
  local probe_path="${fakes}:/usr/bin:/bin"
  if [ -n "${docker_dir}" ]; then
    probe_path="${fakes}:${docker_dir}:/usr/bin:/bin"
  fi
  run env PATH="${probe_path}" bash "$tree/scripts/check-host-lsp.sh"
}

# setup_tree <with_env 0|1>: copies check-host-lsp.sh into an isolated tree
# and (optionally) seeds it with a lsp-versions.env copy. Echoes the tree root.
setup_tree() {
  local tree="$BATS_TEST_TMPDIR/tree"
  mkdir -p "$tree/scripts"
  cp "$REPO_ROOT/scripts/check-host-lsp.sh" "$tree/scripts/check-host-lsp.sh"
  if [ "${1:-1}" = "1" ]; then
    cp "$REPO_ROOT/scripts/lsp-versions.env" "$tree/scripts/lsp-versions.env"
  fi
  echo "$tree"
}

@test "check-host-lsp: all tools present at pinned versions -> exit 0 with 3 ok lines and summary" {
  fakes="$BATS_TEST_TMPDIR/fakes"
  install_fakes "$fakes"
  tree="$(setup_tree)"
  docker_dir="$(mock_docker_up 1.97.1)"

  run_probe "$tree" "$fakes" "$docker_dir"

  assert_status 0
  assert_output_contains "ok: typescript-language-server 5.3.0 (host, version matches scripts/lsp-versions.env)"
  assert_output_contains "ok: pyright 1.1.411 (host, version matches scripts/lsp-versions.env)"
  assert_output_contains "ok: rust-analyzer 1.97.1 (container poetry-dev, version matches scripts/lsp-versions.env)"
  assert_output_contains "summary: 3 ok, 0 fail, 0 skip"
}

@test "check-host-lsp: one tool missing on PATH -> exit 1 with fail line plus 2 ok lines" {
  fakes="$BATS_TEST_TMPDIR/fakes"
  install_fakes "$fakes"
  rm "$fakes/typescript-language-server"
  tree="$(setup_tree)"
  docker_dir="$(mock_docker_up 1.97.1)"

  run_probe "$tree" "$fakes" "$docker_dir"

  assert_status 1
  assert_output_contains "fail: typescript-language-server — not found on PATH. Run scripts/install-host-lsp.sh (see docs/dev-infra/host-lsp-setup.md)"
  assert_output_contains "ok: pyright 1.1.411 (host, version matches scripts/lsp-versions.env)"
  assert_output_contains "ok: rust-analyzer 1.97.1 (container poetry-dev, version matches scripts/lsp-versions.env)"
  assert_output_contains "summary: 2 ok, 1 fail, 0 skip — see above"
}

@test "check-host-lsp: version mismatch on one tool -> exit 1 with fail line naming the mismatch" {
  fakes="$BATS_TEST_TMPDIR/fakes"
  install_fakes "$fakes"
  export FAKE_PYRIGHT_MISMATCH=1
  tree="$(setup_tree)"
  docker_dir="$(mock_docker_up 1.97.1)"

  run_probe "$tree" "$fakes" "$docker_dir"

  assert_status 1
  assert_output_contains "fail: pyright — 99.0.0 on PATH, expected 1.1.411. Run scripts/install-host-lsp.sh"
  assert_output_contains "summary: 2 ok, 1 fail, 0 skip — see above"
}

@test "check-host-lsp: SKIP_RUST=1 -> skip line for rust-analyzer, exit 0" {
  fakes="$BATS_TEST_TMPDIR/fakes"
  install_fakes "$fakes"
  rm "$fakes/rust-analyzer"
  export SKIP_RUST=1
  tree="$(setup_tree)"

  run_probe "$tree" "$fakes"

  assert_status 0
  assert_output_contains "skip: rust-analyzer (SKIP_RUST=1 set; not required for TS/Python LSP work)"
  assert_output_contains "summary: 2 ok, 0 fail, 1 skip"
}

@test "check-host-lsp: multiple tools fail -> all failures reported, exit 1, single summary" {
  fakes="$BATS_TEST_TMPDIR/fakes"
  install_fakes "$fakes"
  rm "$fakes/typescript-language-server"
  export FAKE_RA_MISMATCH=1
  tree="$(setup_tree)"
  docker_dir="$(mock_docker_down)"

  run_probe "$tree" "$fakes" "$docker_dir"

  assert_status 1
  assert_output_contains "fail: typescript-language-server — not found on PATH. Run scripts/install-host-lsp.sh (see docs/dev-infra/host-lsp-setup.md)"
  assert_output_contains "fail: rust-analyzer — 99.0.0 on PATH, expected 1.97.1. Run scripts/install-host-lsp.sh"
  assert_output_contains "summary: 1 ok, 2 fail, 0 skip — see above"
}

@test "check-host-lsp: container path version mismatch -> exit 1 with fail line naming the container version" {
  fakes="$BATS_TEST_TMPDIR/fakes"
  install_fakes "$fakes"
  tree="$(setup_tree)"
  docker_dir="$(mock_docker_up 1.83.0)"

  run_probe "$tree" "$fakes" "$docker_dir"

  assert_status 1
  assert_output_contains "fail: rust-analyzer - 1.83.0 in dev container, expected 1.97.1 (scripts/lsp-versions.env). Rebuild: docker compose build dev && docker compose up -d dev"
  assert_output_contains "summary: 2 ok, 1 fail, 0 skip — see above"
}

@test "check-host-lsp: container down + host matches pin -> exit 0 with host ok line" {
  fakes="$BATS_TEST_TMPDIR/fakes"
  install_fakes "$fakes"
  tree="$(setup_tree)"
  docker_dir="$(mock_docker_down)"

  run_probe "$tree" "$fakes" "$docker_dir"

  assert_status 0
  assert_output_contains "ok: rust-analyzer 1.97.1 (host, version matches scripts/lsp-versions.env)"
  assert_output_contains "summary: 3 ok, 0 fail, 0 skip"
}

@test "check-host-lsp: container down + host version drifts from pin (designed) -> exit 1" {
  fakes="$BATS_TEST_TMPDIR/fakes"
  install_fakes "$fakes"
  export FAKE_RA_OLD=1
  tree="$(setup_tree)"
  docker_dir="$(mock_docker_down)"

  run_probe "$tree" "$fakes" "$docker_dir"

  assert_status 1
  assert_output_contains "fail: rust-analyzer — 1.83.0 on PATH, expected 1.97.1. Run scripts/install-host-lsp.sh"
  assert_output_contains "summary: 2 ok, 1 fail, 0 skip — see above"
}

@test "check-host-lsp: lsp-versions.env missing -> exit 1 with remediation pointer" {
  fakes="$BATS_TEST_TMPDIR/fakes"
  install_fakes "$fakes"
  tree="$(setup_tree 0)"

  run_probe "$tree" "$fakes"

  assert_status 1
  assert_output_contains "lsp-versions.env not found"
  assert_output_contains "docs/dev-infra/host-lsp-setup.md"
}
