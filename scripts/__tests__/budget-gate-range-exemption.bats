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

# ---------------------------------------------------------------------------
# Range ticket-status rule (DIA-260901-91qy RED lane): range mode reads the
# manifest campaign AND the ticket status from the EVALUATED commit tree
# ($EVAL_SHA); commit-msg mode keeps the current staged-tree + OPEN-today
# requirement. Real field case: historical refactor commit f9ec224 was
# legitimate when created (manifest campaign approved, ticket OPEN then) but
# fails range today because DIA-260903-o7n0 is CLOSED on current disk.
#
# Fixture seam: the ticket ledger lives INSIDE the fixture repo
# ($tree/tickets, TICKETS_DIR pointed there), so each commit tree carries its
# own ticket status and disk-today can differ from status-at-commit. (The
# obs1 tests above keep the ledger outside the repo; that cannot model
# per-commit status, hence the deliberate deviation here.)
# ---------------------------------------------------------------------------

# write_ticket_status <tree> <OPEN|CLOSED>
write_ticket_status() {
  local status="$2"
  cat > "$1/tickets/DIA-260903-o7n0-zz-campaign.md" <<EOF
---
status: $status
---
# DIA-260903-o7n0 campaign fixture (range ticket-status suite)
EOF
}

# setup_ticket_history_repo <tickets-at-H: OPEN|CLOSED> <tickets-today: OPEN|CLOSED>:
# init (baseline prod 20/20 + manifest + tickets) -> clean backed refactor
# commit H (scoped rewrite at ceilings, Budget-Scope: refactor) with the
# ticket at the first status in H's tree -> ticket-only commit flipping to
# the second status (committed, so disk-today reads it). Echoes "tree H-sha".
setup_ticket_history_repo() {
  local tree="$BATS_TEST_TMPDIR/tickethist"
  mkdir -p "$tree/plug/lib" "$tree/tickets" "$tree/scripts/guards"
  cp "$REPO_ROOT/scripts/guards/home-qualt.sh" "$tree/scripts/guards/home-qualt.sh"
  seq 1 10 > "$tree/plug/delegation-observer.ts"
  seq 1 10 > "$tree/plug/lib/util.ts"
  write_manifest "$tree" 20 10 "$APPROVED_CAMPAIGNS"
  write_ticket_status "$tree" "$1"
  if ! git -C "$tree" init -q -b main 2>/dev/null; then
    git -C "$tree" init -q
    git -C "$tree" symbolic-ref HEAD refs/heads/main
  fi
  git -C "$tree" config user.email "bats@example.com"
  git -C "$tree" config user.name "bats test"
  git -C "$tree" add -A
  git -C "$tree" commit -q -m init
  # Commit H: clean backed refactor (prod stays 20/20, shell 10/10).
  seq 1 10 | sed 's/^/\/\/ clean rewrite /' > "$tree/plug/lib/util.ts"
  git -C "$tree" add plug/lib/util.ts
  git -C "$tree" commit -q -m "historical refactor

Budget-Scope: refactor"
  local h_sha
  h_sha="$(git -C "$tree" rev-parse HEAD)"
  # Ledger moves on: flip the ticket record and commit, so disk-today reads
  # the second status while H's tree keeps the first.
  write_ticket_status "$tree" "$2"
  git -C "$tree" add tickets/DIA-260903-o7n0-zz-campaign.md
  git -C "$tree" commit -q -m "ledger moves on: ticket now $2"
  cp "$GATE" "$tree/gate-under-test.sh" 2>/dev/null || true
  printf '%s %s\n' "$tree" "$h_sha"
}

@test "range ticket-status (DIA-260901-91qy): OPEN at the historical commit, CLOSED today -> range PASSES" {
  local tree h_sha
  read -r tree h_sha <<< "$(setup_ticket_history_repo OPEN CLOSED)"

  run env BUDGET_MANIFEST="manifest.json" TICKETS_DIR="$tree/tickets" BUDGET_PLUGIN_ROOT="$tree/plug" bash -c "cd '$tree' && exec bash '$tree/gate-under-test.sh' --range '$h_sha~1..$h_sha'"

  # RED against current gate code (reads CLOSED from current disk ledger):
  # exit 1 "no approved backing campaign". Post-fix (commit-tree status):
  # the campaign was approved and the ticket OPEN at H, budgets clean.
  assert_status 0
  assert_output_contains "ok:"
}

@test "range ticket-status (DIA-260901-91qy): CLOSED already at the historical commit -> range FAILS" {
  local tree h_sha
  read -r tree h_sha <<< "$(setup_ticket_history_repo CLOSED OPEN)"

  run env BUDGET_MANIFEST="manifest.json" TICKETS_DIR="$tree/tickets" BUDGET_PLUGIN_ROOT="$tree/plug" bash -c "cd '$tree' && exec bash '$tree/gate-under-test.sh' --range '$h_sha~1..$h_sha'"

  # RED against current gate code (reads OPEN from current disk ledger):
  # exit 0 "ok: scope refactor backed". Post-fix (commit-tree status):
  # the ticket was already CLOSED at H, so the scope claim has no backing.
  assert_status 1
  assert_output_contains "FAIL:"
}

@test "range exception expiry (F-01) and out-of-repo fallback warn (F-3): valid at H, expired today -> range PASSES" {
  # Phase 1: expiry at commit time vs wall-clock today
  local tree="$BATS_TEST_TMPDIR/expiry"
  rm -rf "$tree"
  mkdir -p "$tree/plug/lib" "$tree/tickets" "$tree/scripts/guards"
  cp "$REPO_ROOT/scripts/guards/home-qualt.sh" "$tree/scripts/guards/home-qualt.sh"
  seq 1 10 > "$tree/plug/delegation-observer.ts"
  seq 1 10 > "$tree/plug/lib/util.ts"
  write_manifest "$tree" 20 10 "$APPROVED_CAMPAIGNS"
  # Exception ticket valid at H (expiry 2026-02-01) but expired on wall-clock today (2026-09-09).
  # H will be committed with date 2026-01-01, so expiry is after H and range should PASS
  # even though expiry is before today. Pre-fix would compare against today and FAIL.
  cat > "$tree/tickets/DIA-260903-o7n0-exception.md" <<'EOF'
---
status: OPEN
---
Exception-Reason: test reason
Exception-Delta: A +5
Exception-Paths: plug/lib/util.ts
Exception-Applicability: expiry 2026-02-01
EOF
  if ! git -C "$tree" init -q -b main 2>/dev/null; then
    git -C "$tree" init -q
    git -C "$tree" symbolic-ref HEAD refs/heads/main
  fi
  git -C "$tree" config user.email "bats@example.com"
  git -C "$tree" config user.name "bats test"
  git -C "$tree" add -A
  git -C "$tree" commit -q -m init
  # Commit H: scoped growth that violates prod ceiling, rescued by the exception
  # valid at H's committer date. Use a fixed past committer date so expiry is after H.
  seq 1 15 > "$tree/plug/lib/util.ts"
  git -C "$tree" add plug/lib/util.ts
  GIT_AUTHOR_DATE="2026-01-01T12:00:00+00:00" GIT_COMMITTER_DATE="2026-01-01T12:00:00+00:00" \
    git -C "$tree" commit -q -m "historical refactor with exception

Budget-Scope: refactor
Budget-Exception: DIA-260903-o7n0"
  local h_sha
  h_sha="$(git -C "$tree" rev-parse HEAD)"
  cp "$GATE" "$tree/gate-under-test.sh" 2>/dev/null || true

  run env BUDGET_MANIFEST="manifest.json" TICKETS_DIR="$tree/tickets" BUDGET_PLUGIN_ROOT="$tree/plug" bash -c "cd '$tree' && exec bash '$tree/gate-under-test.sh' --range '$h_sha~1..$h_sha'"

  assert_status 0
  assert_output_contains "ok:"
  assert_output_contains "exception"

  # Phase 2: F-3 - out-of-repo TICKETS_DIR in range mode must emit fallback warn
  local tree2
  tree2="$(setup_prehistory_repo)"
  local root_sha
  root_sha="$(git -C "$tree2" rev-list --max-parents=0 HEAD)"
  run env BUDGET_MANIFEST="manifest.json" TICKETS_DIR="$BATS_TEST_TMPDIR/tickets" BUDGET_PLUGIN_ROOT="$tree2/plug" bash -c "cd '$tree2' && exec bash '$tree2/gate-under-test.sh' --range '$root_sha..HEAD'"
  assert_output_contains "warn:"
  assert_output_contains "outside gated repo"
  assert_output_contains "falling back to disk"
}
