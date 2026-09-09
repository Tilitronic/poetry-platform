#!/usr/bin/env bats
# budget-gate-range-exemption.bats: pre-gate-history exemption for --range.
#
# GREEN-owned companion to the RED budget-gate.bats battery (which this lane
# must not edit): proves the obs1 exemption -- a pushed range mixing a commit
# whose tree predates scripts/budget-baselines.json with a clean backed
# commit exits 0, skipping the pre-manifest commit WITH a mandatory warn
# line, while commits whose tree HAS the manifest keep fail-closed behavior
# (covered by the RED range cases: regression-1/2/3r).
#
# Hermetic fixture pattern mirrors budget-gate.bats: a REAL isolated git repo
# under $BATS_TEST_TMPDIR; the real repo is never touched.

load test-helper

bats_require_minimum_version 1.5.0

GATE="$REPO_ROOT/scripts/check-budget-gate.sh"

APPROVED_CAMPAIGNS='{"ticket": "DIA-260903-o7n0", "scope": "refactor", "status": "approved"}'

write_manifest() {
  cat > "$1/manifest.json" <<EOF
{
  "prod_ceiling": $2,
  "shell_ceiling": $3,
  "patterns": [
    {"id": "opencode-mock", "canonical": "mock.module(\"@opencode-ai/plugin\",", "baseline_count": 0, "authorized_site": "plugin-harness.mjs"}
  ],
  "campaigns": [$4],
  "mode": "blocking"
}
EOF
}

seed_campaign_ticket() {
  local file="$BATS_TEST_TMPDIR/tickets/DIA-260903-o7n0-zz-campaign.md"
  cat > "$file" <<'EOF'
---
status: OPEN
---
# DIA-260903-o7n0 campaign fixture (range-exemption suite)
EOF
}

# setup_prehistory_repo: init WITHOUT a manifest, land a scoped refactor
# commit (pre-manifest history), then add the manifest + campaign backing as
# a clean backed commit. Echoes the tree root.
setup_prehistory_repo() {
  local tree="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$tree/plug/lib" "$BATS_TEST_TMPDIR/tickets" "$tree/scripts/guards"
  cp "$REPO_ROOT/scripts/guards/home-qualt.sh" "$tree/scripts/guards/home-qualt.sh"
  seq 1 10 > "$tree/plug/delegation-observer.ts"
  seq 1 10 > "$tree/plug/lib/util.ts"
  if ! git -C "$tree" init -q -b main 2>/dev/null; then
    git -C "$tree" init -q
    git -C "$tree" symbolic-ref HEAD refs/heads/main
  fi
  git -C "$tree" config user.email "bats@example.com"
  git -C "$tree" config user.name "bats test"
  git -C "$tree" add -A
  git -C "$tree" commit -q -m init
  # Commit A (pre-manifest): touches a scoped prod path, same LOC, refactor
  # trailer. Without the exemption this commit fails closed (scoped change,
  # no manifest in tree); with it, it is skipped with a warn.
  seq 1 10 | sed 's/^/\/\/ pre-gate-history rewrite /' > "$tree/plug/lib/util.ts"
  git -C "$tree" add plug/lib/util.ts
  git -C "$tree" commit -q -m "pre-manifest refactor

Budget-Scope: refactor"
  # Commit B (clean backed): adds the manifest; prod 20/20 shell 10/10 sit
  # exactly at the ceilings with real ledger backing.
  seed_campaign_ticket
  write_manifest "$tree" 20 10 "$APPROVED_CAMPAIGNS"
  git -C "$tree" add manifest.json
  git -C "$tree" commit -q -m "add budget baselines

Budget-Scope: refactor"
  cp "$GATE" "$tree/gate-under-test.sh" 2>/dev/null || true
  echo "$tree"
}

@test "range-exemption (obs1): range mixing a pre-manifest commit with a clean backed commit exits 0 with a mandatory warn" {
  tree="$(setup_prehistory_repo)"
  local root_sha
  root_sha="$(git -C "$tree" rev-list --max-parents=0 HEAD)"

  run env BUDGET_MANIFEST="manifest.json" TICKETS_DIR="$BATS_TEST_TMPDIR/tickets" BUDGET_PLUGIN_ROOT="$tree/plug" bash -c "cd '$tree' && exec bash '$tree/gate-under-test.sh' --range '$root_sha..HEAD'"

  assert_status 0
  # the pre-manifest commit is SKIPPED, never silently: warn line mandatory
  assert_output_contains "warn:"
  assert_output_contains "pre-gate-history"
  # the clean backed commit is really evaluated (not blanket-passed)
  assert_output_contains "backed"
}

# setup_malformed_repo: baseline WITHOUT a manifest (like the prehistory
# setup), then a commit that ADDS a malformed manifest alongside a scoped
# edit. The manifest is PRESENT in that commit's tree, so the obs1 exemption
# must NOT fire: a broken manifest fails closed exactly like hook mode.
# Echoes the tree root.
setup_malformed_repo() {
  local tree="$BATS_TEST_TMPDIR/malformed"
  mkdir -p "$tree/plug/lib" "$BATS_TEST_TMPDIR/tickets" "$tree/scripts/guards"
  cp "$REPO_ROOT/scripts/guards/home-qualt.sh" "$tree/scripts/guards/home-qualt.sh"
  seq 1 10 > "$tree/plug/delegation-observer.ts"
  seq 1 10 > "$tree/plug/lib/util.ts"
  if ! git -C "$tree" init -q -b main 2>/dev/null; then
    git -C "$tree" init -q
    git -C "$tree" symbolic-ref HEAD refs/heads/main
  fi
  git -C "$tree" config user.email "bats@example.com"
  git -C "$tree" config user.name "bats test"
  git -C "$tree" add -A
  git -C "$tree" commit -q -m init
  seed_campaign_ticket
  printf '{broken json\n' > "$tree/manifest.json"
  seq 1 15 > "$tree/plug/lib/util.ts"
  git -C "$tree" add manifest.json plug/lib/util.ts
  git -C "$tree" commit -q -m "malformed manifest + growth

Budget-Scope: refactor"
  cp "$GATE" "$tree/gate-under-test.sh" 2>/dev/null || true
  echo "$tree"
}

@test "range-exemption (obs1): manifest PRESENT but malformed in a range commit fails closed (no exemption)" {
  tree="$(setup_malformed_repo)"
  local root_sha
  root_sha="$(git -C "$tree" rev-list --max-parents=0 HEAD)"

  run env BUDGET_MANIFEST="manifest.json" TICKETS_DIR="$BATS_TEST_TMPDIR/tickets" BUDGET_PLUGIN_ROOT="$tree/plug" bash -c "cd '$tree' && exec bash '$tree/gate-under-test.sh' --range '$root_sha..HEAD'"

  assert_status 1
  # no pre-gate-history skip for a tree that HAS the manifest
  assert_output_not_contains "pre-gate-history"
  # fail-closed names the load failure
  assert_output_contains "FAIL:"
}
