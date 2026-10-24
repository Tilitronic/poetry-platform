#!/usr/bin/env bats
# budget-gate.bats: hermetic battery for the shrunk commit budget gate
# (DIA-261023-jdx3, review-fix pass). Covers the load-bearing core: both
# measurement sets (prod = observer + single-level lib; shell = observer
# alone), hook + range modes (staged index / per-commit tree), the
# unconditional duplication detector (incl. both SIGPIPE regressions and the
# empty-pattern-set guard), the manifest-edit guard, OPEN-ticket backing,
# the pre-manifest range exemption + its boundaries, the fail-closed edges
# (malformed/missing manifest, unresolvable plugin root, CLOSED in-tree
# ticket), the report kill-switch, wiring, and the exit-code contract.
# Shared budget primitives live in test-helper.bash (DIA-260909-9i1o).

load test-helper

bats_require_minimum_version 1.5.0

GATE="$REPO_ROOT/scripts/check-budget-gate.sh"
APPROVED_CAMPAIGNS='{"ticket": "DIA-260903-o7n0", "scope": "refactor", "status": "approved"}'

# install_qualt_guard <tree>: mirror the shared guard for _in_repo runs
# (CWD=fixture tree sources the fixture copy; plain hook/range runs from the
# real repo root source the real copy and need nothing here - S9).
install_qualt_guard() {
  mkdir -p "$1/scripts/guards"
  cp "$REPO_ROOT/scripts/guards/home-qualt.sh" "$1/scripts/guards/"
}

# setup_budget_repo: prod 20 (observer 10 + lib 10), shell 10, baseline 1,
# grandfathered copy in file1.mjs + authorized site plugin-harness.mjs; seeds
# the OPEN campaign ticket on disk. Echoes the tree root.
setup_budget_repo() {
  local tree="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$tree/plug/lib" "$tree/plug/__tests__" "$BATS_TEST_TMPDIR/tickets"
  budget_seed_campaign_ticket "$BATS_TEST_TMPDIR/tickets" "budget-gate suite"
  seq 1 10 > "$tree/plug/delegation-observer.ts"
  seq 1 10 > "$tree/plug/lib/util.ts"
  printf 'import { harness } from "./plugin-harness.mjs";\nmock.module("@opencode-ai/plugin", () => ({}));\nexport const a = 1;\n' > "$tree/plug/__tests__/file1.mjs"
  printf 'mock.module("@opencode-ai/plugin", () => ({}));\nexport const harness = {};\n' > "$tree/plug/__tests__/plugin-harness.mjs"
  budget_write_manifest "$tree" 20 10 1 "$APPROVED_CAMPAIGNS"
  budget_git_init "$tree"
  git -C "$tree" add -A
  git -C "$tree" commit -q -m init
  cp "$GATE" "$tree/gate-under-test.sh"
  echo "$tree"
}

# write_msg <file> [scope] [extra-trailer-line]
write_msg() {
  {
    printf 'budget gate test commit\n\n'
    [ -n "${2:-}" ] && printf 'Budget-Scope: %s\n' "$2"
    [ -n "${3:-}" ] && printf '%s\n' "$3"
    return 0
  } > "$1"
}

# ---------------------------------------------------------------------------
# Mandated fixtures and boundary edges
# ---------------------------------------------------------------------------

@test "hook: backed refactor over the prod or shell ceiling blocks with exit 1" {
  tree="$(setup_budget_repo)"
  seq 1 15 > "$tree/plug/lib/util.ts"
  git -C "$tree" add plug/lib/util.ts
  write_msg "$BATS_TEST_TMPDIR/msg" refactor
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 1
  assert_output_contains "exceeds prod ceiling"
  assert_output_contains "20"
  seq 1 15 > "$tree/plug/delegation-observer.ts"
  git -C "$tree" add plug/delegation-observer.ts
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 1
  assert_output_contains "shell LOC 15 exceeds shell ceiling 10"
}

@test "hook: feature growth passes with a report line (A/C report-only)" {
  tree="$(setup_budget_repo)"
  seq 1 15 > "$tree/plug/lib/util.ts"
  git -C "$tree" add plug/lib/util.ts
  write_msg "$BATS_TEST_TMPDIR/msg"
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 0
  assert_output_contains "feature scope (report-only)"
  assert_output_contains "25/20"
}

@test "hook: the staged index is the measurement source, never the worktree" {
  tree="$(setup_budget_repo)"
  seq 1 15 > "$tree/plug/lib/util.ts"
  git -C "$tree" add plug/lib/util.ts
  seq 1 10 > "$tree/plug/lib/util.ts" # worktree reverts the staged growth
  write_msg "$BATS_TEST_TMPDIR/msg" refactor
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 1
  assert_output_contains "exceeds prod ceiling"
  git -C "$tree" reset -q --hard
  seq 1 99 > "$tree/plug/lib/util.ts" # unstaged drift alone never blocks
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 0
  assert_output_contains "ok:"
}

@test "fast path: untouched-path commit exits 0 without reading the manifest" {
  tree="$(setup_budget_repo)"
  printf 'docs\n' > "$tree/README.md"
  git -C "$tree" add README.md
  write_msg "$BATS_TEST_TMPDIR/msg" refactor
  # nonexistent manifest can only stay harmless if the fast path returns
  # BEFORE any manifest read (P4 invariant)
  BUDGET_MANIFEST_OVERRIDE="$BATS_TEST_TMPDIR/nonexistent.json" budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 0
  assert_output_contains "no scoped paths touched"
}

@test "hook: loosened unstaged disk manifest does not weaken the staged ceilings" {
  tree="$(setup_budget_repo)"
  seq 1 15 > "$tree/plug/lib/util.ts"
  git -C "$tree" add plug/lib/util.ts
  # loosen ONLY the working-tree manifest; the index still holds ceiling 20
  budget_write_manifest "$tree" 9999 9999 1 "$APPROVED_CAMPAIGNS"
  write_msg "$BATS_TEST_TMPDIR/msg" refactor
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 1
  assert_output_contains "exceeds prod ceiling"
  assert_output_contains "20"
}

# ---------------------------------------------------------------------------
# Fail-closed edges
# ---------------------------------------------------------------------------

@test "hook: malformed manifest in the staged index fails closed" {
  tree="$(setup_budget_repo)"
  printf '{broken json\n' > "$tree/manifest.json"
  git -C "$tree" add manifest.json
  write_msg "$BATS_TEST_TMPDIR/msg" refactor
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 1
  assert_output_contains "failed to load"
}

@test "hook: manifest valid on disk but broken in the index fails closed" {
  tree="$(setup_budget_repo)"
  seq 1 15 > "$tree/plug/lib/util.ts"
  git -C "$tree" add plug/lib/util.ts
  printf '{broken json\n' > "$tree/manifest.json"
  git -C "$tree" add manifest.json
  # restore a VALID manifest on disk; the index keeps the broken blob, so only
  # an index read (git show :path) can fail closed here - a disk read would
  # instead measure staged growth against disk ceiling 20 and name the ceiling
  budget_write_manifest "$tree" 20 10 1 "$APPROVED_CAMPAIGNS"
  write_msg "$BATS_TEST_TMPDIR/msg" refactor
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 1
  assert_output_contains "budget manifest invalid"
  assert_output_not_contains "exceeds prod ceiling"
}

@test "hook: missing manifest fails closed for a scoped commit" {
  tree="$(setup_budget_repo)"
  seq 1 10 | sed 's/^/\/\/ clean rewrite /' > "$tree/plug/lib/util.ts"
  git -C "$tree" add plug/lib/util.ts
  write_msg "$BATS_TEST_TMPDIR/msg" refactor
  BUDGET_MANIFEST_OVERRIDE="$BATS_TEST_TMPDIR/nonexistent.json" budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 1
  assert_output_contains "failed to load"
}

@test "hook: unresolvable BUDGET_PLUGIN_ROOT refuses to guess scope and still blocks" {
  tree="$(setup_budget_repo)"
  install_qualt_guard "$tree"
  seq 1 15 > "$tree/plug/lib/util.ts"
  git -C "$tree" add plug/lib/util.ts
  write_msg "$BATS_TEST_TMPDIR/msg" refactor
  budget_run_hook_in_repo "$tree" "$BATS_TEST_TMPDIR/msg" "BUDGET_PLUGIN_ROOT=no-such-plug"
  assert_status 1
  assert_output_contains "BUDGET_PLUGIN_ROOT override active"
  assert_output_contains "refusing to guess scope"
}

@test "backing: refactor trailer without an approved campaign fails closed" {
  tree="$(setup_budget_repo)"
  budget_write_manifest "$tree" 20 10 1 ""
  git -C "$tree" add manifest.json
  seq 1 10 | sed 's/^/\/\/ clean rewrite /' > "$tree/plug/lib/util.ts"
  git -C "$tree" add plug/lib/util.ts
  write_msg "$BATS_TEST_TMPDIR/msg" refactor
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 1
  assert_output_contains "no approved backing campaign"
}

@test "range: CLOSED in-tree ticket fails closed for a range refactor" {
  tree="$(setup_budget_repo)"
  mkdir -p "$tree/docs/tickets"
  printf -- '---\nstatus: CLOSED\n---\n# in-tree campaign fixture\n' > "$tree/docs/tickets/DIA-260903-o7n0-zz-campaign.md"
  seq 1 10 | sed 's/^/\/\/ clean rewrite /' > "$tree/plug/lib/util.ts"
  git -C "$tree" add plug/lib/util.ts docs/tickets/DIA-260903-o7n0-zz-campaign.md
  git -C "$tree" commit -q -m "clean refactor" -m "Budget-Scope: refactor"
  budget_run_range "$tree" "HEAD~1..HEAD" "TICKETS_DIR=$tree/docs/tickets"
  assert_status 1
  assert_output_contains "no approved backing campaign"
}

# ---------------------------------------------------------------------------
# Duplication detector (B)
# ---------------------------------------------------------------------------

@test "duplication: authorized site skipped; >64KB early match counted; reformat evasion blocks" {
  tree="$(setup_budget_repo)"
  printf 'mock.module("@opencode-ai/plugin", () => ({}));\n' >> "$tree/plug/__tests__/plugin-harness.mjs"
  git -C "$tree" add plug/__tests__/plugin-harness.mjs
  write_msg "$BATS_TEST_TMPDIR/msg" feature
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 0 # authorized basename never counts
  { printf 'mock.module("@opencode-ai/plugin", () => ({}));\n'; seq 1 12000 | sed 's/^/\/\/ filler /'; } > "$tree/plug/__tests__/huge.mjs"
  git -C "$tree" add plug/__tests__/huge.mjs
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 1 # match on line 1 of a >64KB file is still counted (no SIGPIPE undercount)
  assert_output_contains "matched 2 files above baseline 1"
  printf 'const m = mock.module(\n  %s@opencode-ai/plugin%s,\n  () => ({})\n);\n' "'" "'" > "$tree/plug/__tests__/file2.mjs"
  git -C "$tree" add plug/__tests__/file2.mjs
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 1 # re-indented, quote-flipped, line-split copy still blocks (B unconditional)
  assert_output_contains "matched 3 files above baseline 1"
}

@test "empty pattern set: manifest with patterns [] lets a clean backed refactor pass" {
  tree="$(setup_budget_repo)"
  printf '{"prod_ceiling": 20, "shell_ceiling": 10, "patterns": [], "campaigns": [%s], "mode": "blocking"}\n' "$APPROVED_CAMPAIGNS" > "$tree/manifest.json"
  git -C "$tree" add manifest.json
  seq 1 10 | sed 's/^/\/\/ clean rewrite /' > "$tree/plug/lib/util.ts"
  git -C "$tree" add plug/lib/util.ts
  write_msg "$BATS_TEST_TMPDIR/msg" refactor
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 0
  assert_output_contains "scope refactor backed"
  assert_output_not_contains "duplication pattern"
}

@test "empty canonical in a pattern is a schema violation and fails closed" {
  tree="$(setup_budget_repo)"
  printf '{"prod_ceiling": 20, "shell_ceiling": 10, "patterns": [{"id": "empty-canon", "canonical": "", "baseline_count": 0, "authorized_site": "plugin-harness.mjs"}], "campaigns": [%s], "mode": "blocking"}\n' "$APPROVED_CAMPAIGNS" > "$tree/manifest.json"
  git -C "$tree" add manifest.json
  seq 1 10 | sed 's/^/\/\/ clean rewrite /' > "$tree/plug/lib/util.ts"
  git -C "$tree" add plug/lib/util.ts
  write_msg "$BATS_TEST_TMPDIR/msg" refactor
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 1
  assert_output_contains "budget manifest invalid"
}

@test "whitespace-only canonical is a schema violation and fails closed" {
  tree="$(setup_budget_repo)"
  printf '{"prod_ceiling": 20, "shell_ceiling": 10, "patterns": [{"id": "ws-canon", "canonical": " ", "baseline_count": 0, "authorized_site": "plugin-harness.mjs"}], "campaigns": [%s], "mode": "blocking"}\n' "$APPROVED_CAMPAIGNS" > "$tree/manifest.json"
  git -C "$tree" add manifest.json
  seq 1 10 | sed 's/^/\/\/ clean rewrite /' > "$tree/plug/lib/util.ts"
  git -C "$tree" add plug/lib/util.ts
  write_msg "$BATS_TEST_TMPDIR/msg" refactor
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 1
  assert_output_contains "budget manifest invalid"
}

# ---------------------------------------------------------------------------
# Manifest-edit guard
# ---------------------------------------------------------------------------

@test "manifest edit: staged change without a backed refactor trailer blocks; exception trailer never authorizes" {
  tree="$(setup_budget_repo)"
  budget_write_manifest "$tree" 9999 9999 1 "$APPROVED_CAMPAIGNS"
  git -C "$tree" add manifest.json
  write_msg "$BATS_TEST_TMPDIR/msg" "" "Budget-Exception: DIA-260903-o7n0"
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 1
  assert_output_contains "manifest edit requires"
  write_msg "$BATS_TEST_TMPDIR/msg" refactor # same edit with a backed refactor trailer passes
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg"
  assert_status 0
  assert_output_contains "ok:"
}

# ---------------------------------------------------------------------------
# Range mode: SIGPIPE-safe backing, tree-first status, exemptions + boundaries
# ---------------------------------------------------------------------------

@test "range: in-tree OPEN ticket with early match + >64KB filler backs a refactor (SIGPIPE-safe tree-first)" {
  tree="$(setup_budget_repo)"
  mkdir -p "$tree/docs/tickets"
  { printf -- '---\nstatus: OPEN\n---\n# in-tree campaign fixture\n'; seq 1 12000 | sed 's/^/filler /'; } > "$tree/docs/tickets/DIA-260903-o7n0-zz-campaign.md"
  seq 1 10 | sed 's/^/\/\/ clean rewrite /' > "$tree/plug/lib/util.ts"
  git -C "$tree" add plug/lib/util.ts docs/tickets/DIA-260903-o7n0-zz-campaign.md
  git -C "$tree" commit -q -m "clean refactor" -m "Budget-Scope: refactor"
  rm "$tree/docs/tickets/DIA-260903-o7n0-zz-campaign.md" # ledger lives only in the commit tree now
  budget_run_range "$tree" "HEAD~1..HEAD" "TICKETS_DIR=$tree/docs/tickets"
  assert_status 0
  assert_output_contains "scope refactor backed"
  assert_output_not_contains "no approved backing campaign"
}

# setup_prehistory_repo: init WITHOUT a manifest, land a scoped refactor
# commit (pre-manifest history), then add manifest + backing as a clean
# backed commit. Ledger stays OUTSIDE the repo (disk fallback). Echoes tree.
setup_prehistory_repo() {
  local tree="$BATS_TEST_TMPDIR/prehist"
  mkdir -p "$tree/plug/lib" "$BATS_TEST_TMPDIR/tickets"
  install_qualt_guard "$tree"
  seq 1 10 > "$tree/plug/delegation-observer.ts"
  seq 1 10 > "$tree/plug/lib/util.ts"
  budget_git_init "$tree"
  git -C "$tree" add -A
  git -C "$tree" commit -q -m init
  seq 1 10 | sed 's/^/\/\/ pre-gate-history rewrite /' > "$tree/plug/lib/util.ts"
  git -C "$tree" add plug/lib/util.ts
  git -C "$tree" commit -q -m "pre-manifest refactor" -m "Budget-Scope: refactor"
  budget_seed_campaign_ticket "$BATS_TEST_TMPDIR/tickets" "prehistory"
  budget_write_manifest "$tree" 20 10 0 "$APPROVED_CAMPAIGNS"
  git -C "$tree" add manifest.json
  git -C "$tree" commit -q -m "add baselines" -m "Budget-Scope: refactor"
  cp "$GATE" "$tree/gate-under-test.sh"
  echo "$tree"
}

@test "range: pre-manifest commit skipped with mandatory warn; outside-ledger warn; backed commit evaluated" {
  tree="$(setup_prehistory_repo)"
  budget_run_range_in_repo "$tree" "$(git -C "$tree" rev-list --max-parents=0 HEAD)..HEAD"
  assert_status 0
  assert_output_contains "warn:"
  assert_output_contains "pre-gate-history"
  assert_output_contains "outside gated repo" # outside-ledger disk-fallback warn (P5b)
  assert_output_contains "backed"
}

@test "range: present-but-malformed manifest fails closed (no pre-gate-history exemption)" {
  tree="$BATS_TEST_TMPDIR/malformed"
  mkdir -p "$tree/plug/lib" "$BATS_TEST_TMPDIR/tickets"
  install_qualt_guard "$tree"
  seq 1 10 > "$tree/plug/delegation-observer.ts"
  seq 1 10 > "$tree/plug/lib/util.ts"
  budget_git_init "$tree"
  git -C "$tree" add -A
  git -C "$tree" commit -q -m init
  budget_seed_campaign_ticket "$BATS_TEST_TMPDIR/tickets" "malformed suite"
  printf '{broken json\n' > "$tree/manifest.json"
  seq 1 15 > "$tree/plug/lib/util.ts"
  git -C "$tree" add manifest.json plug/lib/util.ts
  git -C "$tree" commit -q -m "malformed manifest + growth" -m "Budget-Scope: refactor"
  cp "$GATE" "$tree/gate-under-test.sh"
  budget_run_range_in_repo "$tree" "$(git -C "$tree" rev-list --max-parents=0 HEAD)..HEAD"
  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_not_contains "pre-gate-history"
}

@test "range: f9ec224-style OPEN-at-commit, CLOSED-today passes" {
  tree="$BATS_TEST_TMPDIR/hist"
  mkdir -p "$tree/plug/lib" "$tree/tickets"
  install_qualt_guard "$tree"
  seq 1 10 > "$tree/plug/delegation-observer.ts"
  seq 1 10 > "$tree/plug/lib/util.ts"
  budget_write_manifest "$tree" 20 10 0 "$APPROVED_CAMPAIGNS"
  printf -- '---\nstatus: OPEN\n---\n# campaign fixture\n' > "$tree/tickets/DIA-260903-o7n0-zz-campaign.md"
  budget_git_init "$tree"
  git -C "$tree" add -A
  git -C "$tree" commit -q -m init
  seq 1 10 | sed 's/^/\/\/ clean rewrite /' > "$tree/plug/lib/util.ts"
  git -C "$tree" add plug/lib/util.ts
  git -C "$tree" commit -q -m "historical refactor" -m "Budget-Scope: refactor"
  h_sha="$(git -C "$tree" rev-parse HEAD)"
  printf -- '---\nstatus: CLOSED\n---\n# campaign fixture\n' > "$tree/tickets/DIA-260903-o7n0-zz-campaign.md"
  git -C "$tree" add tickets/DIA-260903-o7n0-zz-campaign.md
  git -C "$tree" commit -q -m "ledger moves on: CLOSED"
  cp "$GATE" "$tree/gate-under-test.sh"
  budget_run_range_in_repo "$tree" "$h_sha~1..$h_sha" "TICKETS_DIR=$tree/tickets"
  assert_status 0
  assert_output_contains "scope refactor backed"
}

# ---------------------------------------------------------------------------
# Kill-switch and wiring
# ---------------------------------------------------------------------------

@test "kill-switch: report mode allows with a warn; --range ignores it and blocks" {
  tree="$(setup_budget_repo)"
  seq 1 15 > "$tree/plug/lib/util.ts"
  git -C "$tree" add plug/lib/util.ts
  write_msg "$BATS_TEST_TMPDIR/msg" refactor
  budget_run_hook "$tree" "$BATS_TEST_TMPDIR/msg" "BUDGET_GATE_MODE=report"
  assert_status 0
  assert_output_contains "FAIL:"
  assert_output_contains "BUDGET_GATE_MODE"
  git -C "$tree" commit -q -F "$BATS_TEST_TMPDIR/msg"
  budget_run_range "$tree" "HEAD~1..HEAD" "BUDGET_GATE_MODE=report"
  assert_status 1
  assert_output_contains "exceeds prod ceiling"
  assert_output_not_contains "report active"
}

@test "wiring: hook and push surfaces still host the gate" {
  assert_file_contains "$REPO_ROOT/.husky/commit-msg" "check-budget-gate.sh"
  assert_file_contains "$REPO_ROOT/scripts/verify-pre-push.sh" "check-budget-gate.sh"
  assert_file_contains "$REPO_ROOT/scripts/verify-pre-push.sh" "--range"
  assert_file_contains "$REPO_ROOT/scripts/worktrees.sh" "commit-msg"
  run grep -F "check-budget-gate" "$REPO_ROOT/.husky/pre-commit"
  assert_status 1
}
