#!/usr/bin/env bats
# Gate A unit tests for scripts/check-host-jq.sh (proposal.md §Two-gate
# acceptance — Gate A FAKE-mock). FAKE-mock pattern from check-tools.bats /
# check-host-lsp.bats.
#
# 3-case matrix (Q7, no extras): all-ok / jq-missing / jq-non-functional.
# The probe is copied into an isolated temp tree (check-host-lsp.bats pattern),
# and every jq invocation is driven by a FAKE binary planted on PATH. INVARIANT:
# bats NEVER shells a real jq binary — each test runs with an explicit PATH
# (fakes dir first + /usr/bin:/bin fallback; the jq-missing case restricts PATH
# to the fakes dir alone so a host-installed jq cannot shadow the simulation),
# so a system jq is unreachable by construction.

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# install_fakes <dir>: plants a fake jq in <dir>. Behavior driven by env:
#   FAKE_JQ_BROKEN=1   jq -n '1+1' returns 3 (non-functional)
#   default            jq -n '1+1' returns 2 (functional);
#                      jq --version reports jq-1.7.1
install_fakes() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/jq" <<'FAKEJQ'
#!/usr/bin/env bash
[ "${FAKE_JQ_BROKEN:-}" = "1" ] && { printf '%s\n' "3"; exit 0; }
[ "${1:-}" = "--version" ] && { printf '%s\n' "jq-1.7.1"; exit 0; }
printf '%s\n' "2"
FAKEJQ
  chmod +x "$dir/jq"
}

# setup_tree: copies check-host-jq.sh into an isolated temp tree. Echoes the
# tree root (the probe has no repo-relative dependencies today; the copy keeps
# the test hermetic against any future cwd dependence, mirroring
# check-host-lsp.bats).
setup_tree() {
  local tree="$BATS_TEST_TMPDIR/tree"
  mkdir -p "$tree/scripts"
  cp "$REPO_ROOT/scripts/check-host-jq.sh" "$tree/scripts/check-host-jq.sh"
  echo "$tree"
}

# run_probe <tree> <fakes_dir> [path_suffix]: runs check-host-jq.sh with a
# hermetic PATH (fakes dir + /usr/bin:/bin by default) so no real jq binary
# can ever be shelled. Pass "" as path_suffix to restrict PATH to the fakes
# dir alone — the jq-missing case uses this so `command -v jq` cannot fall
# through to a host-installed jq (e.g. /usr/bin/jq). Note: bash is invoked by
# absolute path (${3-...} preserves an explicit ""; `:-` would re-default it),
# because `env` resolves its command against the MODIFIED PATH, so a bare
# `bash` would be unfindable when PATH is restricted to an empty fakes dir.
run_probe() {
  local tree="$1"
  local fakes="$2"
  local path_suffix="${3-:/usr/bin:/bin}"
  local bash_path
  bash_path="$(command -v bash)"
  run env PATH="${fakes}${path_suffix}" "${bash_path}" "$tree/scripts/check-host-jq.sh"
}

@test "check-host-jq: functional jq on PATH -> exit 0 + ok line + summary" {
  fakes="$BATS_TEST_TMPDIR/fakes"
  install_fakes "$fakes"
  tree="$(setup_tree)"

  run_probe "$tree" "$fakes"

  assert_status 0
  assert_output_contains "ok: jq 1.7.1 (host, functional)"
  assert_output_contains "summary: 1 ok, 0 fail"
}

@test "check-host-jq: jq missing from PATH -> exit 1 + fail line + summary" {
  # plant-then-rm (owner Decision 2): plant all fakes, then remove jq so
  # `command -v jq` fails. PATH is the fakes dir ONLY (path_suffix "") — the
  # host now ships a real jq at /usr/bin/jq, so a /usr/bin:/bin fallback
  # would let the probe find it and this case would no longer be "missing".
  fakes="$BATS_TEST_TMPDIR/fakes"
  install_fakes "$fakes"
  rm "$fakes/jq"
  tree="$(setup_tree)"

  run_probe "$tree" "$fakes" ""

  assert_status 1
  assert_output_contains "fail: jq — not found on PATH. Install jq (e.g. sudo apt install jq, brew install jq, or mise install jq) — see docs/dev-infra/host-lsp-setup.md"
  assert_output_contains "summary: 0 ok, 1 fail — see above"
}

@test "check-host-jq: jq present but non-functional -> exit 1 + fail line + summary" {
  fakes="$BATS_TEST_TMPDIR/fakes"
  install_fakes "$fakes"
  export FAKE_JQ_BROKEN=1
  tree="$(setup_tree)"

  run_probe "$tree" "$fakes"

  assert_status 1
  assert_output_contains "fail: jq — present on PATH but non-functional (jq -n '1+1' did not return 2). Reinstall jq — see docs/dev-infra/host-lsp-setup.md"
  assert_output_contains "summary: 0 ok, 1 fail — see above"
}
