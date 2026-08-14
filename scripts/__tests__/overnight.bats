#!/usr/bin/env bats
# DIA-126(a) + DIA-134 overnight.sh unit tests (2026-08-13 Option A full lane;
# 2026-08-14 DIA-134 S1+S2 lane).
#
# The script is copied into an isolated temp tree together with the overnight
# profile, and opencode is replaced by a recording FAKE on PATH
# (check-host-jq.bats FAKE-mock pattern), so the launch line and env vars can
# be asserted WITHOUT ever launching the real opencode (lane invariant: "do
# NOT actually launch opencode in the test"). Node is REAL: the JSONC
# tokenizer must genuinely extract the permission block from the profile -
# faking it would test nothing.
#
# DIA-134 additions: (S1) every rule of the 11-rule "overnight destructive
# command baseline v1" (developer-approved 2026-08-14, Baseline A = 5
# inherited + 6 data+git) must resolve to deny in the exported payload;
# (S2) payload shape validation - a {} or softened ("ask") permission.bash
# exits 1 with a rule-specific error and never launches (fail closed).

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# Node is required by the JSONC tokenizer (same hard requirement as the
# make test-config gate, .opencode/scripts/validate-opencode-config.sh). The
# tests resolve it from the runner's environment (mise/volta shims are on
# PATH under make test-shell) and pass it explicitly because the hermetic
# fake PATH in each test drops it. Skipped with a clear message when the
# runner has no node at all.
NODE_BIN="$(command -v node || true)"

require_node() {
  if [ -z "$NODE_BIN" ]; then
    skip "node is required to extract the overnight permission block (same requirement as make test-config)"
  fi
}

# install_fake_opencode <dir>: plants a recording fake `opencode` binary.
# The fake prints its argv plus the two env vars the wrapper must set, then
# exits 0 - enough to verify the launch contract end-to-end.
install_fake_opencode() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/opencode" <<'FAKEOPENCODE'
#!/usr/bin/env bash
printf 'ARGS: %s\n' "$*"
printf 'OPENCODE_CONFIG=%s\n' "${OPENCODE_CONFIG:-}"
printf 'OPENCODE_PERMISSION=%s\n' "${OPENCODE_PERMISSION:-}"
FAKEOPENCODE
  chmod +x "$dir/opencode"
}

# setup_tree: copies overnight.sh + the overnight profile into an isolated
# temp tree (hermetic against repo-relative cwd dependence, mirroring
# check-host-lsp.bats).
setup_tree() {
  local tree="$BATS_TEST_TMPDIR/tree"
  mkdir -p "$tree/scripts" "$tree/.opencode"
  cp "$REPO_ROOT/scripts/overnight.sh" "$tree/scripts/overnight.sh"
  cp "$REPO_ROOT/.opencode/opencode-overnight.jsonc" "$tree/.opencode/opencode-overnight.jsonc"
  echo "$tree"
}

@test "overnight: script and profile exist and script is executable" {
  [ -f "$REPO_ROOT/scripts/overnight.sh" ]
  [ -x "$REPO_ROOT/scripts/overnight.sh" ]
  [ -f "$REPO_ROOT/.opencode/opencode-overnight.jsonc" ]
}

@test "overnight: --help prints usage and exits 0" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/overnight.sh" --help

  assert_status 0
  assert_output_contains "overnight.sh - autonomous overnight opencode session"
  assert_output_contains "Usage:"
  assert_output_contains "opencode-overnight.jsonc"
}

@test "overnight: TUI mode launches fake opencode with hardened env" {
  require_node
  fakes="$BATS_TEST_TMPDIR/fakes"
  install_fake_opencode "$fakes"
  tree="$(setup_tree)"

  run env PATH="$fakes:/usr/bin:/bin" NODE_BIN="$NODE_BIN" bash "$tree/scripts/overnight.sh"

  assert_status 0
  assert_output_contains "ARGS: --auto"
  assert_output_contains "OPENCODE_CONFIG=$tree/.opencode/opencode-overnight.jsonc"
  assert_output_contains 'OPENCODE_PERMISSION={"bash":{"rm *":"deny","rm -rf *":"deny","rmdir *":"deny","chmod *":"deny","chown *":"deny","docker volume rm *":"deny","docker system prune *":"deny","docker system prune -af*":"deny","git reset --hard *":"deny","git clean -fd*":"deny","git push --force*":"deny"}}'
  assert_output_contains "hardened: DIA-134 baseline v1 - 11 destructive rules -> DENY"
}

@test "overnight: run mode forwards message to opencode run --auto with title" {
  require_node
  fakes="$BATS_TEST_TMPDIR/fakes"
  install_fake_opencode "$fakes"
  tree="$(setup_tree)"

  run env PATH="$fakes:/usr/bin:/bin" NODE_BIN="$NODE_BIN" bash "$tree/scripts/overnight.sh" run "archive the night queue"

  assert_status 0
  assert_output_contains "ARGS: run --auto --title overnight autonomous run (DIA-126 hardened) archive the night queue"
}

@test "overnight: pass-through flags reach opencode unchanged" {
  require_node
  fakes="$BATS_TEST_TMPDIR/fakes"
  install_fake_opencode "$fakes"
  tree="$(setup_tree)"

  run env PATH="$fakes:/usr/bin:/bin" NODE_BIN="$NODE_BIN" bash "$tree/scripts/overnight.sh" -s abc123 --fork

  assert_status 0
  assert_output_contains "ARGS: --auto -s abc123 --fork"
}

@test "overnight: fails closed when the profile is missing (never launches)" {
  fakes="$BATS_TEST_TMPDIR/fakes"
  install_fake_opencode "$fakes"
  tree="$BATS_TEST_TMPDIR/tree-noprofile"
  mkdir -p "$tree/scripts"
  cp "$REPO_ROOT/scripts/overnight.sh" "$tree/scripts/overnight.sh"

  run env PATH="$fakes:/usr/bin:/bin" NODE_BIN="$NODE_BIN" bash "$tree/scripts/overnight.sh"

  assert_status 1
  assert_output_contains "error: overnight profile not found"
  assert_output_not_contains "ARGS:"
}

@test "overnight: fails closed when the JSONC tokenizer cannot run (node missing, never launches)" {
  # ai-auditor suggestion-accepted fail-closed gap (DIA-126a): a node failure
  # (absent binary here; a malformed profile is equivalent) must abort BEFORE
  # the opencode launch - an overnight run without the hardened permission
  # payload would auto-approve destructive commands. NODE_BIN points at a
  # path that does not exist, so the tokenizer subprocess exits 127 and the
  # script's `||` guard fires. No require_node: the point is node NOT working.
  fakes="$BATS_TEST_TMPDIR/fakes"
  install_fake_opencode "$fakes"
  tree="$(setup_tree)"

  run env PATH="$fakes:/usr/bin:/bin" NODE_BIN="$BATS_TEST_TMPDIR/no-such-node" bash "$tree/scripts/overnight.sh"

  assert_status 1
  assert_output_contains "error: failed to extract the permission block"
  assert_output_not_contains "ARGS:"
}

@test "overnight: fails closed when the profile has no permission block (never launches)" {
  # ai-auditor suggestion-accepted fail-closed gap (DIA-126a): the launcher
  # must refuse a drifted payload that carries NO permission block (e.g. a
  # stale/regenerated profile), not just a missing file. The tokenizer emits
  # `null` for a permission-less profile and the script exits 1 with the
  # "no permission block found" error before exec'ing opencode.
  require_node
  fakes="$BATS_TEST_TMPDIR/fakes"
  install_fake_opencode "$fakes"
  tree="$BATS_TEST_TMPDIR/tree-nopermission"
  mkdir -p "$tree/scripts" "$tree/.opencode"
  cp "$REPO_ROOT/scripts/overnight.sh" "$tree/scripts/overnight.sh"
  cat > "$tree/.opencode/opencode-overnight.jsonc" <<'JSONC'
{
  "$schema": "https://opencode.ai/config.json"
  // drifted payload: no top-level permission block
}
JSONC

  run env PATH="$fakes:/usr/bin:/bin" NODE_BIN="$NODE_BIN" bash "$tree/scripts/overnight.sh"

  assert_status 1
  assert_output_contains "error: no permission block found"
  assert_output_not_contains "ARGS:"
}

# --- DIA-134 S1: overnight destructive command baseline v1 (11 deny rules) ---

@test "overnight: DIA-134 S1 - all 11 baseline v1 deny rules resolve to deny in the exported payload" {
  # S1 acceptance: the profile carries the full developer-approved baseline
  # (5 inherited + 6 data+git). End-to-end through the launcher: the fake
  # prints OPENCODE_PERMISSION=<json>, and every baseline v1 rule key must
  # appear with value "deny" inside it (also proves the S2 happy path still
  # exits 0 and launches).
  require_node
  fakes="$BATS_TEST_TMPDIR/fakes"
  install_fake_opencode "$fakes"
  tree="$(setup_tree)"

  run env PATH="$fakes:/usr/bin:/bin" NODE_BIN="$NODE_BIN" bash "$tree/scripts/overnight.sh"

  assert_status 0
  local baseline=(
    'rm *'
    'rm -rf *'
    'rmdir *'
    'chmod *'
    'chown *'
    'docker volume rm *'
    'docker system prune *'
    'docker system prune -af*'
    'git reset --hard *'
    'git clean -fd*'
    'git push --force*'
  )
  local rule
  for rule in "${baseline[@]}"; do
    assert_output_contains "\"${rule}\":\"deny\""
  done
}

# --- DIA-134 S2: payload shape validation (fail closed on drift) -----------

@test "overnight: DIA-134 S2 - empty permission.bash payload ({}) exits 1 and never launches" {
  # ai-auditor S2 gap (DIA-134): a drifted payload whose permission.bash is {}
  # passes the old existence-only check. The shape validation must refuse it
  # naming the first missing baseline rule.
  require_node
  fakes="$BATS_TEST_TMPDIR/fakes"
  install_fake_opencode "$fakes"
  tree="$BATS_TEST_TMPDIR/tree-empty-payload"
  mkdir -p "$tree/scripts" "$tree/.opencode"
  cp "$REPO_ROOT/scripts/overnight.sh" "$tree/scripts/overnight.sh"
  cat > "$tree/.opencode/opencode-overnight.jsonc" <<'JSONC'
{
  "permission": {
    "bash": {}
  }
}
JSONC

  run env PATH="$fakes:/usr/bin:/bin" NODE_BIN="$NODE_BIN" bash "$tree/scripts/overnight.sh"

  assert_status 1
  assert_output_contains 'overnight.sh: payload missing deny rule "rm *" - refusing to launch'
  assert_output_not_contains "ARGS:"
}

@test "overnight: DIA-134 S2 - softened deny rule (ask) exits 1 naming the rule and never launches" {
  # ai-auditor S2 gap (DIA-134): a payload whose deny rules were reverted to
  # ask silently un-hardens the run. The shape validation must refuse it with
  # a rule-specific error. The fixture carries the 5 inherited rules as deny
  # plus the 6th baseline rule softened to ask, so validation reaches it and
  # the error names "docker volume rm *".
  require_node
  fakes="$BATS_TEST_TMPDIR/fakes"
  install_fake_opencode "$fakes"
  tree="$BATS_TEST_TMPDIR/tree-softened-payload"
  mkdir -p "$tree/scripts" "$tree/.opencode"
  cp "$REPO_ROOT/scripts/overnight.sh" "$tree/scripts/overnight.sh"
  cat > "$tree/.opencode/opencode-overnight.jsonc" <<'JSONC'
{
  "permission": {
    "bash": {
      "rm *": "deny",
      "rm -rf *": "deny",
      "rmdir *": "deny",
      "chmod *": "deny",
      "chown *": "deny",
      "docker volume rm *": "ask"
    }
  }
}
JSONC

  run env PATH="$fakes:/usr/bin:/bin" NODE_BIN="$NODE_BIN" bash "$tree/scripts/overnight.sh"

  assert_status 1
  assert_output_contains 'overnight.sh: payload deny rule "docker volume rm *" is "ask" (not "deny") - refusing to launch'
  assert_output_not_contains "ARGS:"
}
