#!/usr/bin/env bats
# Unit tests for scripts/__tests__/bats-wrapper.sh --quick mode (DIA-139
# F-4). The audit finding: the bats monolith (240 tests in one pass) has no
# fast tier for shell-edit iteration. The fix adds a --quick flag to the
# wrapper that runs a syntax tier (bash -n, node --check) plus ONLY the
# three smallest suites (check-host-jq.bats:3, check-host-lsp.bats:9,
# validate-skills.bats:23 = 35 tests), per design.md DD4.
#
# Seam under test: the wrapper's bats invocation. Instead of executing real
# suites (slow, and the real 240-test run would recurse into this very
# file), each test builds a hermetic tree with the REAL wrapper copied in,
# plants tiny stand-in suites (the three curated names + one "slow
# monolith" marker suite), and records which files the wrapper asks bats to
# run via a fake `bats` shim on PATH. The assertions are on the recorded
# argument list + exit status + syntax-tier gating. No network, no real
# bats, no mutation of the real repo.

load test-helper

WRAPPER="$REPO_ROOT/scripts/__tests__/bats-wrapper.sh"

# make_quick_tree: builds a hermetic tree under $BATS_TEST_TMPDIR containing
# the real bats-wrapper.sh, the real scripts/context7-docs.mjs (so the
# wrapper's node --check tier passes), the three curated suite names as tiny
# stand-ins, and a slow-monolith.bats marker suite that MUST NOT be selected
# in --quick mode. Echoes the tree root.
make_quick_tree() {
  local tree="$BATS_TEST_TMPDIR/quick-tree"
  local tests_dir="$tree/scripts/__tests__"
  mkdir -p "$tests_dir" "$tree/.opencode/scripts"
  cp "$WRAPPER" "$tests_dir/bats-wrapper.sh"
  # Copy the node script to BOTH locations: the current wrapper runs
  # `node --check $ROOT/scripts/context7-docs.mjs` (hardcoded), while the
  # DIA-139 --quick syntax tier checks *.mjs under scripts/__tests__/
  # (tasks.md 4.1). Either implementation must find it.
  cp "$REPO_ROOT/scripts/context7-docs.mjs" "$tree/scripts/context7-docs.mjs"
  cp "$REPO_ROOT/scripts/context7-docs.mjs" "$tests_dir/context7-docs.mjs"

  for suite in check-host-jq check-host-lsp validate-skills; do
    cat > "$tests_dir/$suite.bats" <<'SUITE'
#!/usr/bin/env bats
@test "stand-in for the curated suite" { true; }
SUITE
  done
  cat > "$tests_dir/slow-monolith.bats" <<'SUITE'
#!/usr/bin/env bats
@test "marker: the slow monolith must not run in quick mode" { true; }
SUITE
  echo "$tree"
}

# install_fake_bats: plants a recording fake `bats` on PATH. It appends every
# argument to $FAKE_BATS_LOG and exits 0, so tests can assert EXACTLY which
# suite files the wrapper selected without executing them.
install_fake_bats() {
  local bindir="$BATS_TEST_TMPDIR/fakebin"
  mkdir -p "$bindir"
  cat > "$bindir/bats" <<'FAKEBATS'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "${FAKE_BATS_LOG:?FAKE_BATS_LOG not set}"
exit 0
FAKEBATS
  chmod +x "$bindir/bats"
  PATH="$bindir:$PATH"
  export PATH
}

@test "--quick selects exactly the three curated suites and skips the slow monolith (DIA-139 F-4)" {
  local tree wrapper
  tree="$(make_quick_tree)"
  wrapper="$tree/scripts/__tests__/bats-wrapper.sh"
  FAKE_BATS_LOG="$BATS_TEST_TMPDIR/bats-args.log"
  export FAKE_BATS_LOG
  install_fake_bats

  run bash "$wrapper" --quick

  # Both tiers pass -> exit 0 (tasks.md 4.1 acceptance criterion).
  assert_status 0
  # The three smallest suites are the curated subset (design.md DD4).
  assert_file_contains "$FAKE_BATS_LOG" "check-host-jq.bats"
  assert_file_contains "$FAKE_BATS_LOG" "check-host-lsp.bats"
  assert_file_contains "$FAKE_BATS_LOG" "validate-skills.bats"
  # No other suite may run: the marker suite is absent from the invocation.
  run grep -qF -- "slow-monolith" "$FAKE_BATS_LOG"
  assert_status 1
}

@test "--quick runs the syntax tier: a syntax-broken shell script fails the run (DIA-139 F-4)" {
  local tree wrapper
  tree="$(make_quick_tree)"
  printf '#!/usr/bin/env bash\nif then fi\n' > "$tree/scripts/broken.sh"
  wrapper="$tree/scripts/__tests__/bats-wrapper.sh"
  FAKE_BATS_LOG="$BATS_TEST_TMPDIR/bats-args.log"
  export FAKE_BATS_LOG
  install_fake_bats

  run bash "$wrapper" --quick

  # Syntax tier (bash -n over scripts/*.sh, tasks.md 4.1) runs FIRST and
  # gates the run: a broken script means --quick must NOT exit 0 even
  # though every curated suite would pass. Only non-zero is part of the
  # contract; bash -n happens to exit 2, but the wrapper's exact failure
  # code is an implementation detail.
  [ "$status" -ne 0 ] || {
    echo "expected --quick to fail on a syntax-broken script, got exit 0" >&2
    echo "--- output ---" >&2
    echo "$output" >&2
    return 1
  }
  assert_output_contains "broken.sh"
}

@test "--quick runs the syntax tier before the suite tier: a broken script aborts before bats is invoked (DIA-139 F-4)" {
  local tree wrapper
  tree="$(make_quick_tree)"
  printf '#!/usr/bin/env bash\nif then fi\n' > "$tree/scripts/broken.sh"
  wrapper="$tree/scripts/__tests__/bats-wrapper.sh"
  FAKE_BATS_LOG="$BATS_TEST_TMPDIR/bats-args.log"
  export FAKE_BATS_LOG
  install_fake_bats

  run bash "$wrapper" --quick

  # Both a syntax-broken script AND valid curated suites are present. The
  # run must fail (syntax tier gates the run), AND the recording fake bats
  # must never have been invoked: the suite tier is only reached after the
  # syntax tier passes, so an absent arg-log proves the syntax tier ran
  # FIRST and aborted before any suite invocation (ordering, review
  # FALSIFICATION-2, DIA-139 fix loop 2).
  [ "$status" -ne 0 ] || {
    echo "expected --quick to fail on a syntax-broken script, got exit 0" >&2
    echo "--- output ---" >&2
    echo "$output" >&2
    return 1
  }
  assert_file_not_exists "$FAKE_BATS_LOG"
}
