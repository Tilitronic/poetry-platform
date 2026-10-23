#!/usr/bin/env bats
# budget-gate.bats: hermetic battery for the shrunk commit budget gate
# (DIA-261023-jdx3). Covers the load-bearing core only: both measurement sets
# (prod = observer + single-level lib; shell = observer alone), hook + range
# modes (staged index / per-commit tree), the unconditional duplication
# detector (incl. both SIGPIPE regressions), the manifest-edit guard, minimal
# OPEN-ticket backing, the pre-manifest range exemption, the report
# kill-switch, wiring, and the exit-code contract (1 = blocked). Shared
# budget primitives live in test-helper.bash (DIA-260909-9i1o).

load test-helper

bats_require_minimum_version 1.5.0

GATE="$REPO_ROOT/scripts/check-budget-gate.sh"
APPROVED_CAMPAIGNS='{"ticket": "DIA-260903-o7n0", "scope": "refactor", "status": "approved"}'

# setup_budget_repo: prod 20 (observer 10 + lib 10), shell 10, baseline 1,
# grandfathered copy in file1.mjs + authorized site plugin-harness.mjs; seeds
# the OPEN campaign ticket on disk and mirrors the home-qualt guard. Echoes tree.
setup_budget_repo() {
  local tree="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$tree/plug/lib" "$tree/plug/__tests__" "$BATS_TEST_TMPDIR/tickets" "$tree/scripts/guards"
  cp "$REPO_ROOT/scripts/guards/home-qualt.sh" "$tree/scripts/guards/"
  budget_seed_campaign_ticket "$BATS_TEST_TMPDIR/tickets" "budget-gate suite"
  seq 1 10 > "$tree/plug/delegation-observer.ts"; seq 1 10 > "$tree/plug/lib/util.ts"
  printf 'import { harness } from "./plugin-harness.mjs";\nmock.module("@opencode-ai/plugin", () => ({}));\nexport const a = 1;\n' > "$tree/plug/__tests__/file1.mjs"
  printf 'mock.module("@opencode-ai/plugin", () => ({}));\nexport const harness = {};\n' > "$tree/plug/__tests__/plugin-harness.mjs"
  budget_write_manifest "$tree" 20 10 1 "$APPROVED_CAMPAIGNS"
  budget_git_init "$tree"
  git -C "$tree" add -A && git -C "$tree" commit -q -m init; cp "$GATE" "$tree/gate-under-test.sh"
  echo "$tree"
}

# write_msg <file> [scope] [extra-trailer-line]
write_msg() {
  { printf 'budget gate test commit\n\n'
    [ -n "${2:-}" ] && printf 'Budget-Scope: %s\n' "$2"
    [ -n "${3:-}" ] && printf '%s\n' "$3"
    return 0
  } > "$1"
}

@test "hook: backed refactor over the prod or shell ceiling blocks with exit 1" {
  tree="$(setup_budget_repo)"; seq 1 15 > "$tree/plug/lib/util.ts"; git -C "$tree" add plug/lib/util.ts
  write_msg "$BATS_TEST_TMPDIR/msg" refactor; budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 1; assert_output_contains "exceeds prod ceiling"
  assert_output_contains "20"; seq 1 15 > "$tree/plug/delegation-observer.ts"; git -C "$tree" add plug/delegation-observer.ts
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"; assert_status 1
  assert_output_contains "shell LOC 15 exceeds shell ceiling 10"
}

@test "hook: the staged index is the measurement source, never the worktree" {
  tree="$(setup_budget_repo)"; seq 1 15 > "$tree/plug/lib/util.ts"; git -C "$tree" add plug/lib/util.ts
  seq 1 10 > "$tree/plug/lib/util.ts" # worktree reverts the staged growth
  write_msg "$BATS_TEST_TMPDIR/msg" refactor
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"; assert_status 1
  assert_output_contains "exceeds prod ceiling"; git -C "$tree" reset -q --hard
  seq 1 99 > "$tree/plug/lib/util.ts" # unstaged drift alone never blocks
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"; assert_status 0; assert_output_contains "ok:"
}

@test "duplication: authorized site skipped; >64KB early match counted; reformat evasion blocks" {
  tree="$(setup_budget_repo)"; printf 'mock.module("@opencode-ai/plugin", () => ({}));\n' >> "$tree/plug/__tests__/plugin-harness.mjs"
  git -C "$tree" add plug/__tests__/plugin-harness.mjs; write_msg "$BATS_TEST_TMPDIR/msg" feature
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"; assert_status 0 # authorized basename never counts
  { printf 'mock.module("@opencode-ai/plugin", () => ({}));\n'; seq 1 12000 | sed 's/^/\/\/ filler /'; } > "$tree/plug/__tests__/huge.mjs"
  git -C "$tree" add plug/__tests__/huge.mjs; budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 1 # match on line 1 of a >64KB file is still counted (no SIGPIPE undercount)
  assert_output_contains "matched 2 files above baseline 1"
  printf 'const m = mock.module(\n  %s@opencode-ai/plugin%s,\n  () => ({})\n);\n' "'" "'" > "$tree/plug/__tests__/file2.mjs"
  git -C "$tree" add plug/__tests__/file2.mjs; budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 1 # re-indented, quote-flipped, line-split copy still blocks (B unconditional)
  assert_output_contains "matched 3 files above baseline 1"
}

@test "range: in-tree OPEN ticket with early match + >64KB filler backs a refactor (SIGPIPE-safe tree-first)" {
  tree="$(setup_budget_repo)"; mkdir -p "$tree/docs/tickets"
  { printf -- '---\nstatus: OPEN\n---\n# in-tree campaign fixture\n'; seq 1 12000 | sed 's/^/filler /'; } > "$tree/docs/tickets/DIA-260903-o7n0-zz-campaign.md"
  seq 1 10 | sed 's/^/\/\/ clean rewrite /' > "$tree/plug/lib/util.ts"
  git -C "$tree" add plug/lib/util.ts docs/tickets/DIA-260903-o7n0-zz-campaign.md
  git -C "$tree" commit -q -m "clean refactor" -m "Budget-Scope: refactor"
  rm "$tree/docs/tickets/DIA-260903-o7n0-zz-campaign.md" # ledger lives only in the commit tree now
  budget_run_range "$tree" "HEAD~1..HEAD" "TICKETS_DIR=$tree/docs/tickets"; assert_status 0
  assert_output_contains "scope refactor backed"; assert_output_not_contains "no approved backing campaign"
}

@test "manifest edit: staged change without a backed refactor trailer blocks; exception trailer never authorizes" {
  tree="$(setup_budget_repo)"
  budget_write_manifest "$tree" 9999 9999 1 "$APPROVED_CAMPAIGNS"
  git -C "$tree" add manifest.json; write_msg "$BATS_TEST_TMPDIR/msg" "" "Budget-Exception: DIA-260903-o7n0"
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"; assert_status 1
  assert_output_contains "manifest edit requires"; write_msg "$BATS_TEST_TMPDIR/msg" refactor # same edit with a backed refactor trailer passes
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"; assert_status 0
  assert_output_contains "ok:"
}

@test "backing: refactor trailer without an approved campaign fails closed" {
  tree="$(setup_budget_repo)"
  budget_write_manifest "$tree" 20 10 1 ""
  git -C "$tree" add manifest.json; seq 1 10 | sed 's/^/\/\/ clean rewrite /' > "$tree/plug/lib/util.ts"; git -C "$tree" add plug/lib/util.ts
  write_msg "$BATS_TEST_TMPDIR/msg" refactor; budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 1; assert_output_contains "no approved backing campaign"
}

# setup_prehistory_repo: init WITHOUT a manifest, land a scoped refactor
# commit (pre-manifest history), then add manifest + backing as a clean
# backed commit. Echoes the tree root.
setup_prehistory_repo() {
  local tree="$BATS_TEST_TMPDIR/prehist"
  mkdir -p "$tree/plug/lib" "$BATS_TEST_TMPDIR/tickets" "$tree/scripts/guards"; cp "$REPO_ROOT/scripts/guards/home-qualt.sh" "$tree/scripts/guards/"
  seq 1 10 > "$tree/plug/delegation-observer.ts"; seq 1 10 > "$tree/plug/lib/util.ts"
  budget_git_init "$tree"
  git -C "$tree" add -A && git -C "$tree" commit -q -m init; seq 1 10 | sed 's/^/\/\/ pre-gate-history rewrite /' > "$tree/plug/lib/util.ts"
  git -C "$tree" add plug/lib/util.ts; git -C "$tree" commit -q -m "pre-manifest refactor" -m "Budget-Scope: refactor"
  budget_seed_campaign_ticket "$BATS_TEST_TMPDIR/tickets" "prehistory"
  budget_write_manifest "$tree" 20 10 0 "$APPROVED_CAMPAIGNS"
  git -C "$tree" add manifest.json; git -C "$tree" commit -q -m "add baselines" -m "Budget-Scope: refactor"
  cp "$GATE" "$tree/gate-under-test.sh"
  echo "$tree"
}

@test "range: pre-manifest commit skipped with mandatory warn; backed commit evaluated" {
  tree="$(setup_prehistory_repo)"; budget_run_range_in_repo "$tree" "$(git -C "$tree" rev-list --max-parents=0 HEAD)..HEAD"
  assert_status 0; assert_output_contains "warn:"
  assert_output_contains "pre-gate-history"; assert_output_contains "backed"
}

@test "range: f9ec224-style OPEN-at-commit, CLOSED-today passes" {
  tree="$BATS_TEST_TMPDIR/hist"; mkdir -p "$tree/plug/lib" "$tree/tickets" "$tree/scripts/guards"
  cp "$REPO_ROOT/scripts/guards/home-qualt.sh" "$tree/scripts/guards/"
  seq 1 10 > "$tree/plug/delegation-observer.ts"; seq 1 10 > "$tree/plug/lib/util.ts"
  budget_write_manifest "$tree" 20 10 0 "$APPROVED_CAMPAIGNS"
  printf -- '---\nstatus: OPEN\n---\n# campaign fixture\n' > "$tree/tickets/DIA-260903-o7n0-zz-campaign.md"
  budget_git_init "$tree"
  git -C "$tree" add -A && git -C "$tree" commit -q -m init; seq 1 10 | sed 's/^/\/\/ clean rewrite /' > "$tree/plug/lib/util.ts"
  git -C "$tree" add plug/lib/util.ts; git -C "$tree" commit -q -m "historical refactor" -m "Budget-Scope: refactor"
  h_sha="$(git -C "$tree" rev-parse HEAD)"
  printf -- '---\nstatus: CLOSED\n---\n# campaign fixture\n' > "$tree/tickets/DIA-260903-o7n0-zz-campaign.md"
  git -C "$tree" add tickets/DIA-260903-o7n0-zz-campaign.md; git -C "$tree" commit -q -m "ledger moves on: CLOSED"
  cp "$GATE" "$tree/gate-under-test.sh"; budget_run_range_in_repo "$tree" "$h_sha~1..$h_sha" "TICKETS_DIR=$tree/tickets"
  assert_status 0; assert_output_contains "scope refactor backed"
}

@test "kill-switch: report mode allows with a warn; --range ignores it and blocks" {
  tree="$(setup_budget_repo)"; seq 1 15 > "$tree/plug/lib/util.ts"; git -C "$tree" add plug/lib/util.ts
  write_msg "$BATS_TEST_TMPDIR/msg" refactor; budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg" "BUDGET_GATE_MODE=report"
  assert_status 0; assert_output_contains "FAIL:"
  assert_output_contains "BUDGET_GATE_MODE"; git -C "$tree" commit -q -F "$BATS_TEST_TMPDIR/msg"
  budget_run_range "$tree" "HEAD~1..HEAD" "BUDGET_GATE_MODE=report"; assert_status 1
  assert_output_contains "exceeds prod ceiling"; assert_output_not_contains "report active"
}

@test "wiring: hook and push surfaces still host the gate" {
  assert_file_contains "$REPO_ROOT/.husky/commit-msg" "check-budget-gate.sh"
  assert_file_contains "$REPO_ROOT/scripts/verify-pre-push.sh" "check-budget-gate.sh"
  assert_file_contains "$REPO_ROOT/scripts/verify-pre-push.sh" "--range"
  assert_file_contains "$REPO_ROOT/scripts/worktrees.sh" "commit-msg"
  run grep -F "check-budget-gate" "$REPO_ROOT/.husky/pre-commit"
  assert_status 1
}
