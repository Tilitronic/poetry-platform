#!/usr/bin/env bats
# budget-gate.bats: hermetic battery for the commit budget gate.
#
# RED lane (campaign ticket DIA-260903-o7n0): test-author only. This file
# defines the contract; a separate GREEN instance writes
# scripts/check-budget-gate.sh, scripts/budget-baselines.json, and the
# .husky/commit-msg wiring. Every functional test below MUST fail until
# the gate script exists (missing script => bash exit 127, never the
# asserted 0/1), and every wiring test MUST fail until the hook wiring
# lands. That all-RED run is the RED proof, not a defect.
#
# Assumed contract (GREEN implements; design.md Seams + Test strategy):
#   CLI:  check-budget-gate.sh <message-file>   (commit-msg hook mode)
#         check-budget-gate.sh --range <rev>    (pre-push/CI mode, always blocking)
#   Env:  BUDGET_MANIFEST    manifest path (default scripts/budget-baselines.json)
#         TICKETS_DIR        ticket ledger dir override
#         BUDGET_PLUGIN_ROOT plugin tree root override so fixtures stay small;
#                            a staged path is scoped iff it sits under this root,
#                            role by suffix: delegation-observer.ts = prod+shell,
#                            lib/ = prod, __tests__/ = test.
#         BUDGET_GATE_MODE=report  kill-switch: hook mode only, never off,
#                            always warns; range mode ignores it.
#   Output: ok: line on pass; FAIL: line naming the cause on block;
#         warn: line naming BUDGET_GATE_MODE when the switch is active.
#   Exit: 0 pass (or report-only allow), 1 block.
#
# Fixture pattern follows post-push.bats: a REAL isolated git repo under
# $BATS_TEST_TMPDIR with the gate copied in; the real repo is never
# touched (wiring tests only grep it read-only).

load test-helper

bats_require_minimum_version 1.5.0

GATE="$REPO_ROOT/scripts/check-budget-gate.sh"

APPROVED_CAMPAIGNS='{"ticket": "DIA-260903-o7n0", "scope": "refactor", "status": "approved"}, {"ticket": "DIA-260903-o7n0", "scope": "test-debloat", "status": "approved"}'
TICKET_NAME="DIA-260903-o7n0-test-exception.md"

# ---------------------------------------------------------------------------
# Fixture helpers (suite-local, not shared)
# ---------------------------------------------------------------------------

# write_manifest <tree> <prod> <shell> <basecount> <campaigns-json-or-empty>
write_manifest() {
  cat > "$1/manifest.json" <<EOF
{
  "prod_ceiling": $2,
  "shell_ceiling": $3,
  "patterns": [
    {"id": "opencode-mock", "canonical": "mock.module(\"@opencode-ai/plugin\",", "baseline_count": $4, "authorized_site": "plugin-harness.mjs"}
  ],
  "campaigns": [$5],
  "mode": "blocking"
}
EOF
}

# setup_budget_repo: baseline tree (observer 10 LOC + lib 10 LOC = prod 20,
# shell 10; one grandfathered scaffold copy + one authorized-site copy).
# Echoes the tree root.
setup_budget_repo() {
  local tree="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$tree/plug/lib" "$tree/plug/__tests__" "$BATS_TEST_TMPDIR/tickets"
  seq 1 10 > "$tree/plug/delegation-observer.ts"
  seq 1 10 > "$tree/plug/lib/util.ts"
  cat > "$tree/plug/__tests__/file1.mjs" <<'EOF'
import { harness } from './plugin-harness.mjs';
mock.module("@opencode-ai/plugin", () => ({}));
export const a = 1;
EOF
  cat > "$tree/plug/__tests__/plugin-harness.mjs" <<'EOF'
mock.module("@opencode-ai/plugin", () => ({}));
export const harness = {};
EOF
  write_manifest "$tree" 20 10 1 "$APPROVED_CAMPAIGNS"
  if ! git -C "$tree" init -q -b main 2>/dev/null; then
    git -C "$tree" init -q
    git -C "$tree" symbolic-ref HEAD refs/heads/main
  fi
  git -C "$tree" config user.email "bats@example.com"
  git -C "$tree" config user.name "bats test"
  git -C "$tree" add -A
  git -C "$tree" commit -q -m init
  cp "$GATE" "$tree/gate-under-test.sh" 2>/dev/null || true
  echo "$tree"
}

# write_msg <file> [scope] [exception-trailer]
write_msg() {
  local file="$1" scope="${2:-}" exc="${3:-}"
  {
    printf 'budget gate test commit\n\n'
    [ -n "$scope" ] && printf 'Budget-Scope: %s\n' "$scope"
    [ -n "$exc" ] && printf 'Budget-Exception: %s\n' "$exc"
    return 0
  } > "$file"
}

# run_gate <tree> <msgfile> [extra env assignments...]
run_gate() {
  local tree="$1" msg="$2"; shift 2
  local manifest="${BUDGET_MANIFEST_OVERRIDE:-$tree/manifest.json}"
  run env BUDGET_MANIFEST="$manifest" TICKETS_DIR="$BATS_TEST_TMPDIR/tickets" BUDGET_PLUGIN_ROOT="$tree/plug" "$@" bash "$tree/gate-under-test.sh" "$msg"
}

# write_exception_ticket <name> <reason|SKIP> <delta|SKIP> <paths|SKIP> <applicability|SKIP>
write_exception_ticket() {
  local file="$BATS_TEST_TMPDIR/tickets/$1"
  {
    printf -- '---\nstatus: OPEN\n---\n'
    [ "$2" != "SKIP" ] && printf 'Exception-Reason: %s\n' "$2"
    [ "$3" != "SKIP" ] && printf 'Exception-Delta: %s\n' "$3"
    [ "$4" != "SKIP" ] && printf 'Exception-Paths: %s\n' "$4"
    [ "$5" != "SKIP" ] && printf 'Exception-Applicability: %s\n' "$5"
    return 0
  } > "$file"
}

write_full_ticket() {
  write_exception_ticket "$1" "test reason" "A +5" "plug/lib/util.ts" "expiry 2099-12-31"
}

grow_lib() {
  seq 1 15 > "$1/plug/lib/util.ts"
  git -C "$1" add plug/lib/util.ts
}

# ---------------------------------------------------------------------------
# Mandated fixtures (a)-(d)
# ---------------------------------------------------------------------------

@test "fixture-a: manifest-backed refactor growing prod LOC blocks, FAIL names ceiling" {
  tree="$(setup_budget_repo)"
  grow_lib "$tree"
  write_msg "$BATS_TEST_TMPDIR/msg" "refactor"

  run_gate "$tree" "$BATS_TEST_TMPDIR/msg"

  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "ceiling"
  assert_output_contains "20"
}

@test "fixture-b: trailer-less feature commit with same growth passes with report" {
  tree="$(setup_budget_repo)"
  grow_lib "$tree"
  write_msg "$BATS_TEST_TMPDIR/msg"

  run_gate "$tree" "$BATS_TEST_TMPDIR/msg"

  assert_status 0
  assert_output_contains "ok:"
  assert_output_contains "20"
}

@test "fixture-c: complete exception record passes with exception line" {
  tree="$(setup_budget_repo)"
  grow_lib "$tree"
  write_full_ticket "$TICKET_NAME"
  write_msg "$BATS_TEST_TMPDIR/msg" "refactor" "DIA-260903-o7n0"

  run_gate "$tree" "$BATS_TEST_TMPDIR/msg"

  assert_status 0
  assert_output_contains "Exception"
}

@test "fixture-d: re-indented quote-flipped line-split duplicate still blocks" {
  tree="$(setup_budget_repo)"
  cat > "$tree/plug/__tests__/file2.mjs" <<'EOF'
import { harness } from './plugin-harness.mjs';
const m = mock.module(
  '@opencode-ai/plugin',
  () => ({})
);
export const b = 2;
EOF
  git -C "$tree" add plug/__tests__/file2.mjs
  write_msg "$BATS_TEST_TMPDIR/msg" "feature"

  run_gate "$tree" "$BATS_TEST_TMPDIR/msg"

  assert_status 1
  assert_output_contains "FAIL:"
}

# ---------------------------------------------------------------------------
# Fail-closed edges
# ---------------------------------------------------------------------------

@test "scope: refactor trailer without manifest backing blocks" {
  tree="$(setup_budget_repo)"
  write_manifest "$tree" 20 10 1 ""
  git -C "$tree" add manifest.json
  grow_lib "$tree"
  write_msg "$BATS_TEST_TMPDIR/msg" "refactor"

  run_gate "$tree" "$BATS_TEST_TMPDIR/msg"

  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "backing"
}

@test "manifest: malformed manifest blocks scoped commits" {
  tree="$(setup_budget_repo)"
  printf '{broken json\n' > "$tree/manifest.json"
  grow_lib "$tree"
  write_msg "$BATS_TEST_TMPDIR/msg" "refactor"

  run_gate "$tree" "$BATS_TEST_TMPDIR/msg"

  assert_status 1
  assert_output_contains "FAIL:"
}

@test "manifest: missing manifest blocks scoped commits" {
  tree="$(setup_budget_repo)"
  grow_lib "$tree"
  write_msg "$BATS_TEST_TMPDIR/msg" "refactor"

  BUDGET_MANIFEST_OVERRIDE="$BATS_TEST_TMPDIR/nonexistent.json" run_gate "$tree" "$BATS_TEST_TMPDIR/msg"

  assert_status 1
  assert_output_contains "FAIL:"
}

@test "exception: exception trailer without scope trailer blocks" {
  tree="$(setup_budget_repo)"
  cat > "$tree/plug/__tests__/file2.mjs" <<'EOF'
import { harness } from './plugin-harness.mjs';
mock.module("@opencode-ai/plugin", () => ({}));
export const b = 2;
EOF
  git -C "$tree" add plug/__tests__/file2.mjs
  write_full_ticket "$TICKET_NAME"
  write_msg "$BATS_TEST_TMPDIR/msg" "" "DIA-260903-o7n0"

  run_gate "$tree" "$BATS_TEST_TMPDIR/msg"

  assert_status 1
  assert_output_contains "FAIL:"
}

@test "exception: record missing any required field blocks and names the line" {
  tree="$(setup_budget_repo)"
  grow_lib "$tree"
  write_msg "$BATS_TEST_TMPDIR/msg" "refactor" "DIA-260903-o7n0"

  write_exception_ticket "$TICKET_NAME" "SKIP" "A +5" "plug/lib/util.ts" "expiry 2099-12-31"
  run_gate "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "Exception-Reason"

  write_exception_ticket "$TICKET_NAME" "test reason" "SKIP" "plug/lib/util.ts" "expiry 2099-12-31"
  run_gate "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 1
  assert_output_contains "Exception-Delta"

  write_exception_ticket "$TICKET_NAME" "test reason" "A +5" "SKIP" "expiry 2099-12-31"
  run_gate "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 1
  assert_output_contains "Exception-Paths"

  write_exception_ticket "$TICKET_NAME" "test reason" "A +5" "plug/lib/util.ts" "SKIP"
  run_gate "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 1
  assert_output_contains "Exception-Applicability"
}

@test "exception: past expiry blocks" {
  tree="$(setup_budget_repo)"
  grow_lib "$tree"
  write_exception_ticket "$TICKET_NAME" "test reason" "A +5" "plug/lib/util.ts" "expiry 2000-01-01"
  write_msg "$BATS_TEST_TMPDIR/msg" "refactor" "DIA-260903-o7n0"

  run_gate "$tree" "$BATS_TEST_TMPDIR/msg"

  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "expiry"
}

# ---------------------------------------------------------------------------
# Boundary edges: both directions per sub-gate
# ---------------------------------------------------------------------------

@test "boundary: refactor exactly at ceilings and baseline counts passes" {
  tree="$(setup_budget_repo)"
  write_msg "$BATS_TEST_TMPDIR/msg" "refactor"

  run_gate "$tree" "$BATS_TEST_TMPDIR/msg"

  assert_status 0
  assert_output_contains "ok:"
}

@test "boundary: untouched paths exit 0 without reading the manifest" {
  tree="$(setup_budget_repo)"
  printf 'docs\n' > "$tree/README.md"
  git -C "$tree" add README.md
  write_msg "$BATS_TEST_TMPDIR/msg" "refactor"

  BUDGET_MANIFEST_OVERRIDE="$BATS_TEST_TMPDIR/nonexistent.json" run_gate "$tree" "$BATS_TEST_TMPDIR/msg"

  assert_status 0
}

@test "staged-seam: unstaged drift does not affect the verdict" {
  tree="$(setup_budget_repo)"
  seq 1 99 > "$tree/plug/lib/util.ts"
  write_msg "$BATS_TEST_TMPDIR/msg" "refactor"

  run_gate "$tree" "$BATS_TEST_TMPDIR/msg"

  assert_status 0
}

@test "staged-seam: staged growth blocks even when the worktree reverts it" {
  tree="$(setup_budget_repo)"
  grow_lib "$tree"
  seq 1 10 > "$tree/plug/lib/util.ts"
  write_msg "$BATS_TEST_TMPDIR/msg" "refactor"

  run_gate "$tree" "$BATS_TEST_TMPDIR/msg"

  assert_status 1
  assert_output_contains "FAIL:"
}

@test "manifest-edit: manifest change without refactor trailer blocks" {
  tree="$(setup_budget_repo)"
  write_manifest "$tree" 9999 9999 1 "$APPROVED_CAMPAIGNS"
  git -C "$tree" add manifest.json
  write_msg "$BATS_TEST_TMPDIR/msg" "feature"

  run_gate "$tree" "$BATS_TEST_TMPDIR/msg"

  assert_status 1
  assert_output_contains "FAIL:"
}

@test "manifest-edit: exception trailer alone never authorizes a manifest edit" {
  tree="$(setup_budget_repo)"
  write_manifest "$tree" 9999 9999 1 "$APPROVED_CAMPAIGNS"
  git -C "$tree" add manifest.json
  write_full_ticket "$TICKET_NAME"
  write_msg "$BATS_TEST_TMPDIR/msg" "" "DIA-260903-o7n0"

  run_gate "$tree" "$BATS_TEST_TMPDIR/msg"

  assert_status 1
  assert_output_contains "FAIL:"
}

@test "manifest-edit: manifest change with refactor trailer passes" {
  tree="$(setup_budget_repo)"
  write_manifest "$tree" 9999 9999 1 "$APPROVED_CAMPAIGNS"
  git -C "$tree" add manifest.json
  write_msg "$BATS_TEST_TMPDIR/msg" "refactor"

  run_gate "$tree" "$BATS_TEST_TMPDIR/msg"

  assert_status 0
  assert_output_contains "ok:"
}

@test "duplication: third copy blocks on a feature commit (B is unconditional)" {
  tree="$(setup_budget_repo)"
  cat > "$tree/plug/__tests__/file2.mjs" <<'EOF'
import { harness } from './plugin-harness.mjs';
mock.module("@opencode-ai/plugin", () => ({}));
export const b = 2;
EOF
  git -C "$tree" add plug/__tests__/file2.mjs
  write_msg "$BATS_TEST_TMPDIR/msg" "feature"

  run_gate "$tree" "$BATS_TEST_TMPDIR/msg"

  assert_status 1
  assert_output_contains "FAIL:"
}

@test "duplication: authorized-site occurrences never count" {
  tree="$(setup_budget_repo)"
  cat >> "$tree/plug/__tests__/plugin-harness.mjs" <<'EOF'
mock.module("@opencode-ai/plugin", () => ({}));
EOF
  git -C "$tree" add plug/__tests__/plugin-harness.mjs
  write_msg "$BATS_TEST_TMPDIR/msg" "feature"

  run_gate "$tree" "$BATS_TEST_TMPDIR/msg"

  assert_status 0
  assert_output_contains "ok:"
}

@test "shell-ceiling: refactor growing shell LOC blocks" {
  tree="$(setup_budget_repo)"
  write_manifest "$tree" 9999 10 1 "$APPROVED_CAMPAIGNS"
  git -C "$tree" add manifest.json
  seq 1 15 > "$tree/plug/delegation-observer.ts"
  git -C "$tree" add plug/delegation-observer.ts
  write_msg "$BATS_TEST_TMPDIR/msg" "refactor"

  run_gate "$tree" "$BATS_TEST_TMPDIR/msg"

  assert_status 1
  assert_output_contains "FAIL:"
}

# ---------------------------------------------------------------------------
# Kill-switch and range mode
# ---------------------------------------------------------------------------

@test "kill-switch: report mode allows but prints violation plus switch warning" {
  tree="$(setup_budget_repo)"
  grow_lib "$tree"
  write_msg "$BATS_TEST_TMPDIR/msg" "refactor"

  run_gate "$tree" "$BATS_TEST_TMPDIR/msg" "BUDGET_GATE_MODE=report"

  assert_status 0
  assert_output_contains "FAIL:"
  assert_output_contains "warn:"
  assert_output_contains "BUDGET_GATE_MODE"
}

@test "range-mode: pushed range ignores the kill-switch and blocks" {
  tree="$(setup_budget_repo)"
  grow_lib "$tree"
  git -C "$tree" commit -q -m "budget gate test commit

Budget-Scope: refactor"

  run env BUDGET_MANIFEST="$tree/manifest.json" TICKETS_DIR="$BATS_TEST_TMPDIR/tickets" BUDGET_PLUGIN_ROOT="$tree/plug" BUDGET_GATE_MODE=report bash "$tree/gate-under-test.sh" --range HEAD~1..HEAD

  assert_status 1
  assert_output_contains "FAIL:"
}

# ---------------------------------------------------------------------------
# Wiring assertions (real repo, read-only)
# ---------------------------------------------------------------------------

@test "wiring: .husky/commit-msg invokes the budget gate" {
  assert_file_contains "$REPO_ROOT/.husky/commit-msg" "check-budget-gate.sh"
}

@test "wiring: verify-pre-push.sh invokes the gate in range mode" {
  assert_file_contains "$REPO_ROOT/scripts/verify-pre-push.sh" "check-budget-gate.sh"
  assert_file_contains "$REPO_ROOT/scripts/verify-pre-push.sh" "--range"
}

@test "wiring: worktrees.sh copy list includes commit-msg" {
  assert_file_contains "$REPO_ROOT/scripts/worktrees.sh" "commit-msg"
}

@test "wiring: pre-commit does not host the budget gate" {
  run grep -F "check-budget-gate" "$REPO_ROOT/.husky/pre-commit"
  assert_status 1
}
