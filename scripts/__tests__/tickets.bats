#!/usr/bin/env bats
# DIA-125 keep-local ticket automation: unit tests for scripts/tickets
# (2026-08-13, implementation lane).
#
# Isolation strategy (check-host-jq.bats / overnight.bats conventions):
# scripts/tickets is copied into an isolated temp tree together with a fake
# ledger (4 fixture tickets DIA-130..133, a _TEMPLATE.md, and a README whose
# count tables are deliberately ALL-ZERO so recomputation is observable). The
# REAL ledger at docs/dev-infra-audit/tickets/ is NEVER touched: every test
# resolves the ledger via the script's BASH_SOURCE[0]-relative ROOT inside
# the fixture tree.
#
# The script needs no external tools beyond coreutils (date/grep/sed/sort/tr/
# mktemp), so no FAKE-mock is required; the fixture files are the seam.

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
TODAY="$(date +%F)"

# setup_tree: build an isolated fixture tree. Echoes the tree root.
#   tree/scripts/tickets                  (copy of the script under test)
#   tree/docs/dev-infra-audit/tickets/    (fake ledger)
#     _TEMPLATE.md                        (copy of the real template)
#     README.md                           (index + all-zero stale counts)
#     DIA-130-alpha.md  Major/OPEN
#     DIA-131-beta.md   Low/OPEN    blocked_by [DIA-130]
#     DIA-132-gamma.md  Medium/CLOSED
#     DIA-133-delta.md  Critical/OPEN
setup_tree() {
  local tree="$BATS_TEST_TMPDIR/tree"
  mkdir -p "$tree/scripts" "$tree/docs/dev-infra-audit/tickets"
  cp "$REPO_ROOT/scripts/tickets" "$tree/scripts/tickets"
  cp "$REPO_ROOT/docs/dev-infra-audit/tickets/_TEMPLATE.md" \
    "$tree/docs/dev-infra-audit/tickets/_TEMPLATE.md"
  cat > "$tree/docs/dev-infra-audit/tickets/README.md" <<'README'
# Dev-Infra Audit - Ticket Ledger

## Index

| ID      | Title       | Area | Severity | Status | Ticket file                    |
| ----- | ----- | ---- | -------- | ------ | ------------------------------- |
| DIA-130 | alpha ticket | docs | Major    | OPEN   | [DIA-130-alpha.md](DIA-130-alpha.md) |
| DIA-131 | beta ticket  | docs | Low      | OPEN   | [DIA-131-beta.md](DIA-131-beta.md)   |
| DIA-132 | gamma ticket | docs | Medium   | CLOSED | [DIA-132-gamma.md](DIA-132-gamma.md) |
| DIA-133 | delta ticket | docs | Critical | OPEN   | [DIA-133-delta.md](DIA-133-delta.md) |

## Status summary

| Severity | Count |
| -------- | ----- |
| Blocker  | 0     |
| Critical | 0     |
| Major    | 0     |
| Medium   | 0     |
| Minor    | 0     |
| Low      | 0     |
| Info     | 0     |

| Status      | Count |
| ----------- | ----- |
| OPEN        | 0     |
| DONE        | 0     |
| VALIDATE    | 0     |
| E2E         | 0     |
| DEFERRED    | 0     |
| MONITOR     | 0     |
| FIXED       | 0     |
| IMPLEMENTED | 0     |
| VERIFIED    | 0     |
| CLOSED      | 0     |
| BLOCKED     | 0     |
| DISPATCHED  | 0     |
| RUNNING     | 0     |
| COMPLETE    | 0     |
README

  # fixture tickets (frontmatter mirrors _TEMPLATE.md conventions)
  cat > "$tree/docs/dev-infra-audit/tickets/DIA-130-alpha.md" <<'TICKET'
---
id: DIA-130
title: "alpha ticket"
area: docs
severity: Major
status: OPEN
blocked_by: []
discovered: 2026-08-13
source: inventory
date: 2026-08-13
created: 2026-08-13
updated: 2026-08-13

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

fixture
TICKET
  cat > "$tree/docs/dev-infra-audit/tickets/DIA-131-beta.md" <<'TICKET'
---
id: DIA-131
title: "beta ticket"
area: docs
severity: Low
status: OPEN
blocked_by: [DIA-130]
discovered: 2026-08-13
source: inventory
date: 2026-08-13
created: 2026-08-13
updated: 2026-08-13

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

fixture
TICKET
  cat > "$tree/docs/dev-infra-audit/tickets/DIA-132-gamma.md" <<'TICKET'
---
id: DIA-132
title: "gamma ticket"
area: docs
severity: Medium
status: CLOSED
blocked_by: []
discovered: 2026-08-13
source: inventory
date: 2026-08-13
created: 2026-08-13
updated: 2026-08-13

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

fixture
TICKET
  cat > "$tree/docs/dev-infra-audit/tickets/DIA-133-delta.md" <<'TICKET'
---
id: DIA-133
title: "delta ticket"
area: docs
severity: Critical
status: OPEN
blocked_by: []
discovered: 2026-08-13
source: inventory
date: 2026-08-13
created: 2026-08-13
updated: 2026-08-13

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

fixture
TICKET
  echo "$tree"
}

# ---------------------------------------------------------------------------
# help / usage
# ---------------------------------------------------------------------------

@test "tickets: help prints usage and exits 0" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" help

  assert_status 0
  assert_output_contains "usage: tickets <command> [options]"
  assert_output_contains "new <title>"
  assert_output_contains "rollup"
  assert_output_contains "frontier"
}

@test "tickets: --help and no-arguments also show usage" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" --help
  assert_status 0
  assert_output_contains "usage: tickets"

  run bash "$tree/scripts/tickets"
  assert_status 2
  assert_output_contains "usage: tickets"
}

@test "tickets: unknown command fails loudly" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" frobnicate

  assert_status 1
  assert_output_contains "unknown command 'frobnicate'"
}

# ---------------------------------------------------------------------------
# new
# ---------------------------------------------------------------------------

@test "tickets new: allocates the next free number (DIA-130..133 -> DIA-134)" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" new "Fix Auth Bug!" --area docs --severity Major

  assert_status 0
  assert_output_contains "created: docs/dev-infra-audit/tickets/DIA-134-fix-auth-bug.md"
  assert_output_contains "id: DIA-134"
  assert_file_exists "$tree/docs/dev-infra-audit/tickets/DIA-134-fix-auth-bug.md"
}

@test "tickets new: creates correct frontmatter (id/title/area/severity/status/created)" {
  tree="$(setup_tree)"
  file="$tree/docs/dev-infra-audit/tickets/DIA-134-fix-auth-bug.md"

  run bash "$tree/scripts/tickets" new "Fix Auth Bug!" --area docs --severity Major

  assert_status 0
  assert_file_contains "$file" "id: DIA-134"
  assert_file_contains "$file" 'title: "Fix Auth Bug!"'
  assert_file_contains "$file" "area: docs"
  assert_file_contains "$file" "severity: Major"
  assert_file_contains "$file" "status: OPEN"
  assert_file_contains "$file" "created: $TODAY"
  # default source is inventory; parent_epic is ALWAYS emitted (empty when
  # not provided) so the frontmatter schema is stable across new tickets
  assert_file_contains "$file" "source: inventory"
  assert_file_contains "$file" 'parent_epic: ""'
  assert_file_contains "$file" "lease_expires_at: \"\""
  assert_file_contains "$file" "## Description"
  assert_file_contains "$file" "## Verification"
  assert_file_contains "$file" "## Fix"
  assert_file_contains "$file" "## Re-verify"
}

@test "tickets new: --source flag lands in frontmatter; invalid source rejected" {
  tree="$(setup_tree)"
  file="$tree/docs/dev-infra-audit/tickets/DIA-134-fix-auth-bug.md"

  run bash "$tree/scripts/tickets" new "Fix Auth Bug!" --area docs --severity Major --source test-lane

  assert_status 0
  assert_file_contains "$file" "source: test-lane"

  run bash "$tree/scripts/tickets" new "Another Bug" --area docs --severity Major --source owner-reported
  assert_status 1
  assert_output_contains "invalid source 'owner-reported'"
}

@test "tickets new: slugifies the title (kebab-case, non-alphanumerics stripped)" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" new "Fix Auth Bug!" --area docs --severity Major

  assert_status 0
  assert_file_exists "$tree/docs/dev-infra-audit/tickets/DIA-134-fix-auth-bug.md"

  # a second title with mixed case and punctuation gets a deterministic slug
  run bash "$tree/scripts/tickets" new "E2E: Verify HTTPS (TLS 1.3)" --area docs --severity Low
  assert_status 0
  assert_file_exists "$tree/docs/dev-infra-audit/tickets/DIA-135-e2e-verify-https-tls-1-3.md"
}

@test "tickets new: inserts the README row in DIA sort position and recomputes counts" {
  tree="$(setup_tree)"
  readme="$tree/docs/dev-infra-audit/tickets/README.md"

  run bash "$tree/scripts/tickets" new "Fix Auth Bug!" --area docs --severity Major

  assert_status 0
  # the new row lands after DIA-133 (sort position), with the table formatting
  assert_file_contains "$readme" \
    "| DIA-134 | Fix Auth Bug! | docs | Major    | OPEN   | [DIA-134-fix-auth-bug.md](DIA-134-fix-auth-bug.md) |"
  line133="$(grep -n '| DIA-133 |' "$readme" | cut -d: -f1)"
  line134="$(grep -n '| DIA-134 |' "$readme" | cut -d: -f1)"
  [ "$line134" -gt "$line133" ]
  # counts recomputed from the actual files (130+134 Major, 133 Critical,
  # 132 Medium, 131 Low; OPEN = 130/131/133/134, CLOSED = 132)
  assert_file_contains "$readme" "| Major    | 2     |"
  assert_file_contains "$readme" "| Critical | 1     |"
  assert_file_contains "$readme" "| OPEN        | 4     |"
  assert_file_contains "$readme" "| CLOSED      | 1     |"
}

@test "tickets new: blocked-by and parent-epic land in frontmatter" {
  tree="$(setup_tree)"
  file="$tree/docs/dev-infra-audit/tickets/DIA-134-fix-auth-bug.md"

  run bash "$tree/scripts/tickets" new "Fix Auth Bug!" --area docs --severity Major \
    --blocked-by "DIA-133" --parent-epic "DIA-130"

  assert_status 0
  assert_file_contains "$file" "blocked_by: [DIA-133] # DIA-NNN refs, or empty"
  assert_file_contains "$file" "parent_epic: DIA-130"
}

@test "tickets: a title containing '#' round-trips through fm_field" {
  # fm_field must strip the inline comment ONLY when the value is unquoted:
  # a '#' INSIDE a double-quoted title is literal data, not a comment
  # (scripts/tickets: "title: \"Fix #42 regression\"" -> "Fix #42 regression").
  tree="$(setup_tree)"
  cat > "$tree/docs/dev-infra-audit/tickets/DIA-140-hash-title.md" <<'TICKET'
---
id: DIA-140
title: "Fix #42 regression"
area: docs
severity: Medium
status: OPEN
blocked_by: []
discovered: 2026-08-13
source: inventory
date: 2026-08-13
created: 2026-08-13
updated: 2026-08-13

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

fixture
TICKET

  # frontier prints the parsed title; a truncated value ("Fix") would fail
  # the exact-substring assertion below
  run bash "$tree/scripts/tickets" frontier

  assert_status 0
  assert_output_contains "DIA-140 - Fix #42 regression"
}

@test "tickets new: ASCII guard rejects a non-ASCII title (DIA-079)" {
  tree="$(setup_tree)"
  # non-ASCII input is built via escape so the TEST FILE itself stays
  # ASCII-only (DIA-079): \xC3\xA9 is the UTF-8 encoding of the
  # "e-acute" character
  local bad_title=$'caf\xC3\xA9 bug'

  run bash "$tree/scripts/tickets" new "$bad_title" --area docs --severity Major

  assert_status 1
  assert_output_contains "non-ASCII"
  assert_file_not_exists "$tree/docs/dev-infra-audit/tickets/DIA-134-caf-bug.md"
}

@test "tickets new: invalid severity is rejected" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" new "some bug" --area docs --severity Bogus

  assert_status 1
  assert_output_contains "invalid severity 'Bogus'"
}

@test "tickets new: never overwrites an existing ticket file (collision safety)" {
  tree="$(setup_tree)"
  # This test exercises next_dia()'s max-scan: the pre-existing
  # DIA-134-fix-auth-bug.md is a gate-readable ticket file, so the max-scan
  # (filenames + README rows) sees DIA-134 and allocates DIA-135 - the
  # existing file is never touched. The collision guard in scripts/tickets
  # (the `-e "$path"` hard-fail) is a SEPARATE safety net for the
  # concurrent-creation race (two sessions computing the same number before
  # either write); with correct max+1 allocation it is unreachable
  # deterministically, so this test pins the no-overwrite invariant from
  # the outside instead of exercising the guard branch directly.
  printf '%s\n' "KEEP" > "$tree/docs/dev-infra-audit/tickets/DIA-134-fix-auth-bug.md"

  run bash "$tree/scripts/tickets" new "Fix Auth Bug!" --area docs --severity Major

  assert_status 0
  assert_file_exists "$tree/docs/dev-infra-audit/tickets/DIA-135-fix-auth-bug.md"
  assert_file_contains "$tree/docs/dev-infra-audit/tickets/DIA-134-fix-auth-bug.md" "KEEP"
}

# ---------------------------------------------------------------------------
# rollup
# ---------------------------------------------------------------------------

@test "tickets rollup: recomputes stale counts to match the actual rows" {
  tree="$(setup_tree)"
  readme="$tree/docs/dev-infra-audit/tickets/README.md"

  run bash "$tree/scripts/tickets" rollup

  assert_status 0
  assert_output_contains "rollup: README updated"
  assert_file_contains "$readme" "| Major    | 1     |"
  assert_file_contains "$readme" "| Critical | 1     |"
  assert_file_contains "$readme" "| Medium   | 1     |"
  assert_file_contains "$readme" "| Low      | 1     |"
  assert_file_contains "$readme" "| OPEN        | 3     |"
  assert_file_contains "$readme" "| CLOSED      | 1     |"
  # the v2 lifecycle statuses are canonical: their rows exist (count 0 in
  # this fixture) and rollup never appends extra_status rows for them
  assert_file_contains "$readme" "| DISPATCHED  | 0     |"
  assert_file_contains "$readme" "| RUNNING     | 0     |"
  assert_file_contains "$readme" "| COMPLETE    | 0     |"
}

@test "tickets rollup --check: stale counts exit 1 and never write" {
  tree="$(setup_tree)"
  readme="$tree/docs/dev-infra-audit/tickets/README.md"
  before="$(cat "$readme")"

  run bash "$tree/scripts/tickets" rollup --check

  assert_status 1
  assert_output_contains "counts are STALE"
  assert_output_contains "Major        0 -> 1"
  # README byte-identical: --check never writes
  [ "$(cat "$readme")" = "$before" ]
}

@test "tickets rollup: no-op when counts already match" {
  tree="$(setup_tree)"

  # first run converges the zeroed fixture
  run bash "$tree/scripts/tickets" rollup
  assert_status 0

  # second run is a no-op in both modes
  run bash "$tree/scripts/tickets" rollup
  assert_status 0
  assert_output_contains "rollup: counts already match - README unchanged"

  run bash "$tree/scripts/tickets" rollup --check
  assert_status 0
  assert_output_contains "rollup: counts already match - README unchanged"
}

# ---------------------------------------------------------------------------
# frontier
# ---------------------------------------------------------------------------

@test "tickets frontier: unblocked OPEN tickets listed before blocked ones" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" frontier

  assert_status 0
  # frontier = OPEN tickets with no OPEN blockers: DIA-133 (Critical) sorts
  # before DIA-130 (Major) by severity
  assert_output_contains "frontier (2 ticket(s) you can start):"
  assert_output_contains "  DIA-133 - delta ticket"
  assert_output_contains "  DIA-130 - alpha ticket"
  # blocked list shows the blocked ticket and its blockers with status
  assert_output_contains "blocked (1 ticket(s) waiting on open blockers):"
  assert_output_contains "  DIA-131 - beta ticket (blocked by: DIA-130 (OPEN))"
}

@test "tickets frontier: a ticket whose blocker is CLOSED is startable" {
  tree="$(setup_tree)"
  # flip DIA-130 to CLOSED: DIA-131's only blocker becomes non-OPEN
  sed -i 's/^status: OPEN/status: CLOSED/' "$tree/docs/dev-infra-audit/tickets/DIA-130-alpha.md"

  run bash "$tree/scripts/tickets" frontier

  assert_status 0
  assert_output_contains "  DIA-131 - beta ticket"
  assert_output_not_contains "blocked by:"
}

# ---------------------------------------------------------------------------
# cwd independence
# ---------------------------------------------------------------------------

@test "tickets: resolves the ledger from a different cwd" {
  tree="$(setup_tree)"
  mkdir -p "$BATS_TEST_TMPDIR/elsewhere"

  run bash -c 'cd "$1" && exec bash "$2" frontier' _ \
    "$BATS_TEST_TMPDIR/elsewhere" "$tree/scripts/tickets"

  assert_status 0
  assert_output_contains "frontier"
  assert_output_contains "DIA-130"
}
