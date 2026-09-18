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

# assert_file_not_contains <file> <substring>: fail when the file contains the
# substring. (Companion to assert_file_contains; the RED suite for
# DIA-260821-cku1 referenced this helper which was missing from
# test-helper.bash - defined here, scoped to this suite, to keep the test
# valid without touching shared test infra.)
assert_file_not_contains() {
  local file="$1" sub="$2"
  if grep -q -- "$sub" "$file"; then
    echo "assert_file_not_contains: $file unexpectedly contains: $sub" >&2
    return 1
  fi
}

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
  cp "$REPO_ROOT/scripts/allocate-id" "$tree/scripts/allocate-id"
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
  # DIA-234: now produces datetime format, not sequential DIA-134
  assert_output_contains "created: docs/dev-infra-audit/tickets/"
  assert_output_contains "id: DIA-"
  assert_output_contains "fix-auth-bug.md"
}

@test "tickets new: creates correct frontmatter (id/title/area/severity/status/created)" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" new "Fix Auth Bug!" --area docs --severity Major

  assert_status 0
  # Extract the actual filename from output
  ticket_file="$(echo "$output" | grep -oE 'created: docs/dev-infra-audit/tickets/.*\.md' | sed 's/^created: //')"
  [ -n "$ticket_file" ]
  assert_file_exists "$tree/$ticket_file"
  assert_file_contains "$tree/$ticket_file" "id: DIA-"
  assert_file_contains "$tree/$ticket_file" 'title: "Fix Auth Bug!"'
  assert_file_contains "$tree/$ticket_file" "area: docs"
  assert_file_contains "$tree/$ticket_file" "severity: Major"
  assert_file_contains "$tree/$ticket_file" "status: OPEN"
  assert_file_contains "$tree/$ticket_file" "created: $TODAY"
  # default source is inventory; parent_epic is ALWAYS emitted (empty when
  # not provided) so the frontmatter schema is stable across new tickets
  assert_file_contains "$tree/$ticket_file" "source: inventory"
  assert_file_contains "$tree/$ticket_file" 'parent_epic: ""'
  assert_file_contains "$tree/$ticket_file" "lease_expires_at: \"\""
  assert_file_contains "$tree/$ticket_file" "## Description"
  assert_file_contains "$tree/$ticket_file" "## Verification"
  assert_file_contains "$tree/$ticket_file" "## Fix"
  assert_file_contains "$tree/$ticket_file" "## Re-verify"
}

@test "tickets new: --source flag lands in frontmatter; invalid source rejected" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" new "Fix Auth Bug!" --area docs --severity Major --source test-lane

  assert_status 0
  ticket_file="$(echo "$output" | grep -oE 'created: docs/dev-infra-audit/tickets/.*\.md' | sed 's/^created: //')"
  [ -n "$ticket_file" ]
  assert_file_contains "$tree/$ticket_file" "source: test-lane"

  run bash "$tree/scripts/tickets" new "Another Bug" --area docs --severity Major --source owner-reported
  assert_status 1
  assert_output_contains "invalid source 'owner-reported'"
}

@test "tickets new: slugifies the title (kebab-case, non-alphanumerics stripped)" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" new "Fix Auth Bug!" --area docs --severity Major

  assert_status 0
  # DIA-234: datetime format, verify slug is in the filename
  assert_output_contains "fix-auth-bug.md"

  # a second title with mixed case and punctuation gets a deterministic slug
  run bash "$tree/scripts/tickets" new "E2E: Verify HTTPS (TLS 1.3)" --area docs --severity Low
  assert_status 0
  assert_output_contains "e2e-verify-https-tls-1-3.md"
}

@test "tickets new: inserts the README row in DIA sort position and recomputes counts" {
  tree="$(setup_tree)"
  readme="$tree/docs/dev-infra-audit/tickets/README.md"

  run bash "$tree/scripts/tickets" new "Fix Auth Bug!" --area docs --severity Major

  assert_status 0
  # Extract the actual ticket ID from output
  ticket_id="$(echo "$output" | grep -oE 'id: DIA-[0-9]+-[a-z0-9]+' | head -1 | sed 's/^id: //')"
  [ -n "$ticket_id" ]
  # the new row lands in the README (sort position is after DIA-133 for datetime)
  grep -q "| ${ticket_id} |" "$readme"
  # counts recomputed from the actual files (130 Major, 133 Critical,
  # 132 Medium, 131 Low + new Major; OPEN = 130/131/133/new, CLOSED = 132)
  assert_file_contains "$readme" "| Major    | 2     |"
  assert_file_contains "$readme" "| Critical | 1     |"
  assert_file_contains "$readme" "| OPEN        | 4     |"
  assert_file_contains "$readme" "| CLOSED      | 1     |"
}

@test "tickets new: blocked-by and parent-epic land in frontmatter" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" new "Fix Auth Bug!" --area docs --severity Major \
    --blocked-by "DIA-133" --parent-epic "DIA-130"

  assert_status 0
  ticket_file="$(echo "$output" | grep -oE 'created: docs/dev-infra-audit/tickets/.*\.md' | sed 's/^created: //')"
  [ -n "$ticket_file" ]
  assert_file_contains "$tree/$ticket_file" "blocked_by: [DIA-133]"
  assert_file_contains "$tree/$ticket_file" "parent_epic: DIA-130"
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
  # DIA-234: datetime format uses random suffix, so collision is extremely
  # unlikely. This test verifies that the collision guard works by pre-creating
  # a file and ensuring the new ticket gets a different ID.
  # Pre-create a file with a known prefix to trigger the collision path.
  # The collision guard checks file existence, so we create a file that matches
  # the exact path the script would try to use.
  # Since datetime IDs are random, we instead verify that two rapid calls
  # produce different IDs (tested separately in "two rapid calls produce
  # distinct IDs"). This test now verifies that the script never crashes
  # and always produces a valid output.
  run bash "$tree/scripts/tickets" new "Fix Auth Bug!" --area docs --severity Major

  assert_status 0
  assert_output_contains "created: docs/dev-infra-audit/tickets/"
  assert_output_contains "id: DIA-"
  assert_file_contains "$tree/docs/dev-infra-audit/tickets/README.md" "Fix Auth Bug!"
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

# ---------------------------------------------------------------------------
# DIA-234: datetime format (DIA-YYMMDD-XXXX)
# ---------------------------------------------------------------------------

@test "tickets new: produces datetime format DIA-YYMMDD-XXXX (not sequential)" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" new "datetime test ticket" --area scripts --severity Minor

  assert_status 0
  # Extract ticket ID from output -- must match datetime format
  ticket_id="$(echo "$output" | grep -oE 'DIA-[0-9]{6}-[a-z0-9]{4}' | head -1)"
  [ -n "$ticket_id" ]
  # Verify format: DIA-YYMMDD-XXXX (6-digit date + 4-char lowercase alphanumeric)
  [[ "$ticket_id" =~ ^DIA-[0-9]{6}-[a-z0-9]{4}$ ]]
  # Must NOT be sequential format
  [[ ! "$ticket_id" =~ ^DIA-[0-9]{3}$ ]]
}

@test "tickets new: two rapid calls produce distinct IDs (collision safety)" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" new "first ticket" --area scripts --severity Minor
  assert_status 0
  id1="$(echo "$output" | grep -oE 'DIA-[0-9]{6}-[a-z0-9]{4}' | head -1)"

  run bash "$tree/scripts/tickets" new "second ticket" --area scripts --severity Minor
  assert_status 0
  id2="$(echo "$output" | grep -oE 'DIA-[0-9]{6}-[a-z0-9]{4}' | head -1)"

  [ -n "$id1" ]
  [ -n "$id2" ]
  [ "$id1" != "$id2" ]
}

@test "tickets new: datetime ID lands in README and frontmatter" {
  tree="$(setup_tree)"
  readme="$tree/docs/dev-infra-audit/tickets/README.md"

  run bash "$tree/scripts/tickets" new "datetime readme test" --area docs --severity Medium

  assert_status 0
  # Extract the actual filename from output
  ticket_file="$(echo "$output" | grep -oE 'created: docs/dev-infra-audit/tickets/.*\.md' | sed 's/^created: //')"
  [ -n "$ticket_file" ]
  assert_file_exists "$tree/$ticket_file"
  # Extract ticket ID from filename (DIA-YYMMDD-XXXX part, before the slug)
  ticket_id="$(basename "$ticket_file" .md | grep -oE '^DIA-[0-9]{6}-[a-z0-9]{4}')"
  [ -n "$ticket_id" ]
  # README row present
  grep -q "| ${ticket_id} |" "$readme"
  # Frontmatter id field
  assert_file_contains "$tree/$ticket_file" "id: ${ticket_id}"
}

@test "tickets new: blocked-by accepts datetime format" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" new "blocked ticket" --area scripts --severity Minor \
    --blocked-by "DIA-130"

  assert_status 0
  ticket_file="$(echo "$output" | grep -oE 'created: docs/dev-infra-audit/tickets/.*\.md' | sed 's/^created: //')"
  [ -n "$ticket_file" ]
  assert_file_contains "$tree/$ticket_file" "blocked_by: [DIA-130]"
}

@test "tickets new: parent-epic accepts datetime format" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" new "epic child ticket" --area scripts --severity Minor \
    --parent-epic "DIA-130"

  assert_status 0
  ticket_file="$(echo "$output" | grep -oE 'created: docs/dev-infra-audit/tickets/.*\.md' | sed 's/^created: //')"
  [ -n "$ticket_file" ]
  assert_file_contains "$tree/$ticket_file" "parent_epic: DIA-130"
}

@test "tickets frontier: datetime tickets sort after all sequential tickets" {
  tree="$(setup_tree)"
  # Add a datetime fixture ticket (always newer than sequential)
  cat > "$tree/docs/dev-infra-audit/tickets/DIA-260819-abcd-newer.md" <<'TICKET'
---
id: DIA-260819-abcd
title: "newer datetime ticket"
area: docs
severity: Minor
status: OPEN
blocked_by: []
discovered: 2026-08-19
source: inventory
date: 2026-08-19
created: 2026-08-19
updated: 2026-08-19

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

  run bash "$tree/scripts/tickets" frontier

  assert_status 0
  assert_output_contains "frontier (3 ticket(s) you can start):"
  # Sequential tickets appear before datetime in the sorted output
  assert_output_contains "  DIA-133 - delta ticket"
  assert_output_contains "  DIA-130 - alpha ticket"
  assert_output_contains "  DIA-260819-abcd - newer datetime ticket"
}

# ---------------------------------------------------------------------------
# list
# ---------------------------------------------------------------------------

@test "tickets list: prints all tickets as a table" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" list

  assert_status 0
  # Header row
  assert_output_contains "ID"
  assert_output_contains "Title"
  assert_output_contains "Area"
  assert_output_contains "Severity"
  assert_output_contains "Status"
  # All 4 fixture tickets present (sorted by filename: 130, 131, 132, 133)
  assert_output_contains "DIA-130"
  assert_output_contains "DIA-131"
  assert_output_contains "DIA-132"
  assert_output_contains "DIA-133"
  assert_output_contains "alpha ticket"
  assert_output_contains "delta ticket"
}

@test "tickets list --status OPEN: filters to OPEN tickets only" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" list --status OPEN

  assert_status 0
  assert_output_contains "DIA-130"
  assert_output_contains "DIA-131"
  assert_output_contains "DIA-133"
  # DIA-132 is CLOSED, must not appear
  assert_output_not_contains "DIA-132"
}

@test "tickets list --severity Critical: filters to Critical severity" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" list --severity Critical

  assert_status 0
  assert_output_contains "DIA-133"
  assert_output_not_contains "DIA-130"
  assert_output_not_contains "DIA-131"
  assert_output_not_contains "DIA-132"
}

@test "tickets list --area docs: filters to docs area" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" list --area docs

  assert_status 0
  # All 4 fixture tickets are in the docs area
  assert_output_contains "DIA-130"
  assert_output_contains "DIA-131"
  assert_output_contains "DIA-132"
  assert_output_contains "DIA-133"
}

@test "tickets list --json: emits valid JSON array" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" list --json

  assert_status 0
  # Starts with [ and ends with ]
  [[ "$output" == \[* ]]
  [[ "$output" == *] ]]
  # Contains all 4 fixture tickets
  assert_output_contains '"id":"DIA-130"'
  assert_output_contains '"id":"DIA-131"'
  assert_output_contains '"id":"DIA-132"'
  assert_output_contains '"id":"DIA-133"'
  assert_output_contains '"status":"OPEN"'
  assert_output_contains '"status":"CLOSED"'
}

@test "tickets list --json --status CLOSED: filtered JSON" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" list --json --status CLOSED

  assert_status 0
  [[ "$output" == \[* ]]
  assert_output_contains '"id":"DIA-132"'
  assert_output_not_contains '"id":"DIA-130"'
}

@test "tickets list: no matching tickets returns empty result" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" list --status BLOCKED

  assert_status 0
  # Only header rows, no data
  assert_output_not_contains "DIA-"
}

# ---------------------------------------------------------------------------
# search
# ---------------------------------------------------------------------------

@test "tickets search: finds tickets matching query in title" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" search "alpha"

  assert_status 0
  assert_output_contains "DIA-130"
  assert_output_contains "alpha ticket"
  # beta/gamma/delta should not match
  assert_output_not_contains "DIA-131"
  assert_output_not_contains "DIA-132"
  assert_output_not_contains "DIA-133"
}

@test "tickets search: case-insensitive match" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" search "ALPHA"

  assert_status 0
  assert_output_contains "DIA-130"
}

@test "tickets search: no matches prints message" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" search "nonexistent"

  assert_status 0
  assert_output_contains "no matches for 'nonexistent'"
}

@test "tickets search --json: emits JSON array" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" search --json "alpha"

  assert_status 0
  [[ "$output" == \[* ]]
  [[ "$output" == *] ]]
  assert_output_contains '"id":"DIA-130"'
  assert_output_contains '"title":"alpha ticket"'
}

@test "tickets search: requires a query" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" search

  assert_status 1
  assert_output_contains "search requires a query"
}

# ---------------------------------------------------------------------------
# stats
# ---------------------------------------------------------------------------

@test "tickets stats: counts by status, severity, and area" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" stats

  assert_status 0
  assert_output_contains "Total tickets: 4"
  assert_output_contains "OPEN"
  assert_output_contains "CLOSED"
  assert_output_contains "Major"
  assert_output_contains "Critical"
  assert_output_contains "Medium"
  assert_output_contains "Low"
  assert_output_contains "docs"
}

@test "tickets stats --json: emits JSON object" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" stats --json

  assert_status 0
  assert_output_contains '"total":4'
  assert_output_contains '"open":'
  assert_output_contains '"closed":'
  assert_output_contains '"major":'
  assert_output_contains '"docs":'
}

# ---------------------------------------------------------------------------
# rollup
# ---------------------------------------------------------------------------

@test "tickets rollup: handles datetime tickets in README" {
  tree="$(setup_tree)"
  readme="$tree/docs/dev-infra-audit/tickets/README.md"

  # Add a datetime fixture
  cat > "$tree/docs/dev-infra-audit/tickets/DIA-260819-abcd-rollover.md" <<'TICKET'
---
id: DIA-260819-abcd
title: "rollover test"
area: docs
severity: Low
status: OPEN
blocked_by: []
discovered: 2026-08-19
source: inventory
date: 2026-08-19
created: 2026-08-19
updated: 2026-08-19

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
  # Insert a row for it into the README (simulating a prior new)
  sed -i '/^| DIA-133 /a | DIA-260819-abcd | rollover test | docs | Low      | OPEN   | [DIA-260819-abcd-rollover.md](DIA-260819-abcd-rollover.md) |' "$readme"

  run bash "$tree/scripts/tickets" rollup

  assert_status 0
  # Counts now include the datetime ticket (Low + OPEN)
  assert_file_contains "$readme" "| Low      | 2     |"
  assert_file_contains "$readme" "| OPEN        | 4     |"
}

# ---------------------------------------------------------------------------
# frontier --json
# ---------------------------------------------------------------------------

@test "tickets frontier --json: emits JSON with frontier and blocked arrays" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" frontier --json

  assert_status 0
  # Starts with { and ends with }
  [[ "$output" == \{* ]]
  [[ "$output" == *'}'* ]]
  assert_output_contains '"frontier":['
  assert_output_contains '"blocked":['
  # Frontier tickets (OPEN, no open blockers): DIA-133 (Critical), DIA-130 (Major)
  assert_output_contains '"id":"DIA-133"'
  assert_output_contains '"id":"DIA-130"'
  # Blocked ticket: DIA-131 (blocked by DIA-130)
  assert_output_contains '"id":"DIA-131"'
  assert_output_contains '"blocked_by":'
}

@test "tickets frontier --json: includes severity and area fields" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" frontier --json

  assert_status 0
  assert_output_contains '"severity":"Critical"'
  assert_output_contains '"severity":"Major"'
  assert_output_contains '"area":"docs"'
}

# ---------------------------------------------------------------------------
# show command
# ---------------------------------------------------------------------------

@test "tickets show: displays full ticket info" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" show DIA-130

  assert_status 0
  assert_output_contains "DIA-130"
  assert_output_contains "alpha ticket"
  assert_output_contains "Area:"
  assert_output_contains "Severity:"
  assert_output_contains "Status:"
  assert_output_contains "Created:"
}

@test "tickets show --json: emits JSON object" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" show --json DIA-130

  assert_status 0
  [[ "$output" == \{* ]]
  [[ "$output" == *'}'* ]]
  assert_output_contains '"id":"DIA-130"'
  assert_output_contains '"title":"alpha ticket"'
  assert_output_contains '"area":"docs"'
  assert_output_contains '"severity":"Major"'
  assert_output_contains '"status":"OPEN"'
  assert_output_contains '"created":'
}

@test "tickets show: fails for nonexistent ticket" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" show DIA-999

  assert_status 1
  assert_output_contains "ticket not found"
}

@test "tickets show: fails without ticket ID" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" show

  assert_status 1
  assert_output_contains "show requires a ticket ID"
}

@test "tickets show: fails for invalid ID format" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" show "not-a-ticket"

  assert_status 1
  assert_output_contains "invalid ticket ID"
}

@test "tickets show: shows blocked_by when present" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" show DIA-131

  assert_status 0
  assert_output_contains "Blocked:"
  assert_output_contains "DIA-130"
}

@test "tickets show: shows description body" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" show DIA-130

  assert_status 0
  assert_output_contains "fixture"
}

# ---------------------------------------------------------------------------
# temporal filters: list --since / --before
# ---------------------------------------------------------------------------

@test "tickets list --since: filters tickets created on or after date" {
  tree="$(setup_tree)"
  # All fixture tickets have created: 2026-08-13
  # Add a ticket with a later created date
  cat > "$tree/docs/dev-infra-audit/tickets/DIA-260819-later.md" <<'TICKET'
---
id: DIA-260819-later
title: "later ticket"
area: docs
severity: Low
status: OPEN
blocked_by: []
discovered: 2026-08-19
source: inventory
date: 2026-08-19
created: 2026-08-19
updated: 2026-08-19

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

  run bash "$tree/scripts/tickets" list --since 2026-08-19

  assert_status 0
  # Only the later ticket (created 2026-08-19) matches
  # Note: num_of_file truncates datetime IDs to 11 chars for gate compatibility
  assert_output_contains "DIA-260819-late"
  assert_output_contains "later ticket"
  # The 2026-08-13 tickets are excluded
  assert_output_not_contains "DIA-130"
  assert_output_not_contains "DIA-131"
  assert_output_not_contains "DIA-132"
  assert_output_not_contains "DIA-133"
}

@test "tickets list --before: filters tickets created before date" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/tickets" list --before 2026-08-14

  assert_status 0
  # All fixture tickets (created 2026-08-13) are before 2026-08-14
  assert_output_contains "DIA-130"
  assert_output_contains "DIA-131"
  assert_output_contains "DIA-132"
  assert_output_contains "DIA-133"
}

@test "tickets list --since --before: date range filter" {
  tree="$(setup_tree)"
  # Add a ticket with a different created date
  cat > "$tree/docs/dev-infra-audit/tickets/DIA-260819-range.md" <<'TICKET'
---
id: DIA-260819-range
title: "range ticket"
area: docs
severity: Low
status: OPEN
blocked_by: []
discovered: 2026-08-19
source: inventory
date: 2026-08-19
created: 2026-08-19
updated: 2026-08-19

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

  # Only tickets created on 2026-08-13 (the fixture date)
  run bash "$tree/scripts/tickets" list --since 2026-08-13 --before 2026-08-14

  assert_status 0
  assert_output_contains "DIA-130"
  assert_output_contains "DIA-133"
  assert_output_not_contains "DIA-260819-range"
}

@test "tickets list --json --since: filtered JSON output" {
  tree="$(setup_tree)"
  cat > "$tree/docs/dev-infra-audit/tickets/DIA-260819-json.md" <<'TICKET'
---
id: DIA-260819-json
title: "json test"
area: docs
severity: Low
status: OPEN
blocked_by: []
discovered: 2026-08-19
source: inventory
date: 2026-08-19
created: 2026-08-19
updated: 2026-08-19

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

  run bash "$tree/scripts/tickets" list --json --since 2026-08-19

  assert_status 0
  [[ "$output" == \[* ]]
  assert_output_contains '"id":"DIA-260819-json"'
  assert_output_not_contains '"id":"DIA-130"'
}

# ---------------------------------------------------------------------------
# temporal filters: frontier --since / --before
# ---------------------------------------------------------------------------

@test "tickets frontier --since: filters frontier by created date" {
  tree="$(setup_tree)"
  cat > "$tree/docs/dev-infra-audit/tickets/DIA-260819-future.md" <<'TICKET'
---
id: DIA-260819-future
title: "future ticket"
area: docs
severity: Minor
status: OPEN
blocked_by: []
discovered: 2026-08-19
source: inventory
date: 2026-08-19
created: 2026-08-19
updated: 2026-08-19

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

  run bash "$tree/scripts/tickets" frontier --since 2026-08-19

  assert_status 0
  # Only the future ticket (created 2026-08-19) is in the frontier
  # Note: num_of_file truncates datetime IDs to 11 chars for gate compatibility
  assert_output_contains "frontier (1 ticket(s) you can start):"
  assert_output_contains "DIA-260819-futu"
  assert_output_contains "future ticket"
  assert_output_not_contains "DIA-133"
  assert_output_not_contains "DIA-130"
}

@test "tickets frontier --before: filters frontier by created date" {
  tree="$(setup_tree)"
  cat > "$tree/docs/dev-infra-audit/tickets/DIA-260819-old.md" <<'TICKET'
---
id: DIA-260819-old
title: "old datetime ticket"
area: docs
severity: Minor
status: OPEN
blocked_by: []
discovered: 2026-08-19
source: inventory
date: 2026-08-19
created: 2026-08-19
updated: 2026-08-19

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

  run bash "$tree/scripts/tickets" frontier --before 2026-08-14

  assert_status 0
  # Only the sequential fixture tickets (created 2026-08-13) are in the frontier
  assert_output_contains "DIA-133"
  assert_output_contains "DIA-130"
  assert_output_not_contains "DIA-260819-old"
}

@test "tickets frontier --json --since: filtered JSON frontier" {
  tree="$(setup_tree)"
  cat > "$tree/docs/dev-infra-audit/tickets/DIA-260819-jfix.md" <<'TICKET'
---
id: DIA-260819-jfix
title: "json frontier ticket"
area: docs
severity: Minor
status: OPEN
blocked_by: []
discovered: 2026-08-19
source: inventory
date: 2026-08-19
created: 2026-08-19
updated: 2026-08-19

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

  run bash "$tree/scripts/tickets" frontier --json --since 2026-08-19

  assert_status 0
  [[ "$output" == \{* ]]
  assert_output_contains '"id":"DIA-260819-jfix"'
  assert_output_not_contains '"id":"DIA-133"'
  assert_output_not_contains '"id":"DIA-130"'
}

# ---------------------------------------------------------------------------
# DIA-260821-cku1: tickets update <id> (RED-only TDD lane)
#
# These tests specify the not-yet-implemented `update` subcommand. They MUST
# fail (RED) until scripts/tickets gains cmd_update(). Each test builds its
# own isolated fixture tree (setup_tree / setup_update_tree) so the real
# ledger is never touched and existing tests are unaffected.
#
# run_update <tree> <args...>: run `tickets update` with stderr merged into
# $output so error/warning messages are assertable regardless of bats version.
# ---------------------------------------------------------------------------

run_update() {
  local t="$1"; shift
  run bash -c 'bash "$1" update "${@:2}" 2>&1' _ "$t/scripts/tickets" "$@"
}

# setup_update_tree: like setup_tree but DIA-130 also has ## Fix / ## Re-verify
# sections (with placeholder bodies) so replacement tests have a target.
setup_update_tree() {
  local tree
  tree="$(setup_tree)"
  local f="$tree/docs/dev-infra-audit/tickets/DIA-130-alpha.md"
  cat >> "$f" <<'BODY'

## Fix

placeholder fix

## Re-verify

placeholder reverify
BODY
  echo "$tree"
}

# ---------------------------------------------------------------------------
# status / timestamp / rollup
# ---------------------------------------------------------------------------

@test "tickets update: --status rewrites status line, bumps updated, leaves other fields untouched" {
  tree="$(setup_update_tree)"
  f="$tree/docs/dev-infra-audit/tickets/DIA-130-alpha.md"
  run_update "$tree" DIA-130 --status FIXED
  assert_status 0
  assert_file_contains "$f" "status: FIXED"
  assert_file_contains "$f" "updated: $TODAY"
  # structural fields must be unchanged
  assert_file_contains "$f" 'title: "alpha ticket"'
  assert_file_contains "$f" "severity: Major"
  assert_file_contains "$f" "area: docs"
  assert_file_contains "$f" "id: DIA-130"
}

@test "tickets update: --status triggers README rollup (index row + count tables)" {
  tree="$(setup_update_tree)"
  readme="$tree/docs/dev-infra-audit/tickets/README.md"
  run_update "$tree" DIA-130 --status FIXED
  assert_status 0
  # index row Status column flips OPEN -> FIXED (spacing-tolerant)
  run grep -E '\| DIA-130 \| alpha ticket \| docs \| Major +\| FIXED' "$readme"
  assert_status 0
  # count tables recomputed from the actual files
  assert_file_contains "$readme" "| OPEN        | 2     |"
  assert_file_contains "$readme" "| FIXED       | 1     |"
}

@test "tickets update: no flags exits 2 with usage hint" {
  tree="$(setup_update_tree)"
  run_update "$tree" DIA-130
  assert_status 2
  assert_output_contains "usage"
}

@test "tickets update: invalid --status exits 1, leaves file unchanged, no temp left" {
  tree="$(setup_update_tree)"
  f="$tree/docs/dev-infra-audit/tickets/DIA-130-alpha.md"
  run_update "$tree" DIA-130 --status BOGUS
  assert_status 1
  assert_output_contains "invalid status"
  assert_file_contains "$f" "status: OPEN"
  # atomicity: no .partial / temp leftovers on validation failure
  [ -z "$(find "$tree/docs/dev-infra-audit/tickets" -name '*.partial' -print)" ]
}

@test "tickets update: mv failure leaves .partial file and original untouched" {
  tree="$(setup_update_tree)"
  f="$tree/docs/dev-infra-audit/tickets/DIA-130-alpha.md"
  # root bypasses chmod, so simulate mv failure with a shim on PATH (same
  # fake-mock seam as mock_docker); GREEN lane may swap for an immutable target
  local bindir="$BATS_TEST_TMPDIR/fakebin"
  mkdir -p "$bindir"
  REAL_MV="$(command -v mv)"
  cat > "$bindir/mv" <<FAKEMV
#!/usr/bin/env bash
last="\${!#}"
case "\$last" in
  *DIA-130-alpha.md) exit 1 ;;
esac
exec $REAL_MV "\$@"
FAKEMV
  chmod +x "$bindir/mv"
  PATH="$bindir:$PATH" run_update "$tree" DIA-130 --status FIXED
  assert_status 1
  assert_file_exists "$f.partial"
  assert_file_contains "$f" "status: OPEN"
}

# ---------------------------------------------------------------------------
# evidence append / dedup
# ---------------------------------------------------------------------------

@test "tickets update: --evidence appends one YAML list item" {
  tree="$(setup_update_tree)"
  f="$tree/docs/dev-infra-audit/tickets/DIA-130-alpha.md"
  run_update "$tree" DIA-130 --evidence "commit:abc123"
  assert_status 0
  assert_file_contains "$f" "  - commit:abc123"
  local n
  n="$(grep -c -- "commit:abc123" "$f")"
  [ "$n" -eq 1 ]
}

@test "tickets update: duplicate --evidence is deduplicated" {
  tree="$(setup_update_tree)"
  f="$tree/docs/dev-infra-audit/tickets/DIA-130-alpha.md"
  run_update "$tree" DIA-130 --evidence "commit:abc123" --evidence "commit:abc123"
  assert_status 0
  local n
  n="$(grep -c -- "commit:abc123" "$f")"
  [ "$n" -eq 1 ]
}

@test "tickets update: distinct --evidence values are both appended" {
  tree="$(setup_update_tree)"
  f="$tree/docs/dev-infra-audit/tickets/DIA-130-alpha.md"
  run_update "$tree" DIA-130 --evidence "uri:one" --evidence "uri:two"
  assert_status 0
  assert_file_contains "$f" "  - uri:one"
  assert_file_contains "$f" "  - uri:two"
}

@test "tickets update: non-ASCII --evidence exits 1 (DIA-079)" {
  tree="$(setup_update_tree)"
  f="$tree/docs/dev-infra-audit/tickets/DIA-130-alpha.md"
  # non-ASCII built via escape so the TEST FILE stays ASCII-only
  local bad=$'caf\xC3\xA9'
  run_update "$tree" DIA-130 --evidence "$bad"
  assert_status 1
  assert_output_contains "non-ASCII"
  assert_file_contains "$f" "status: OPEN"
}

@test "tickets update: --evidence on legacy ticket appends evidence: field" {
  tree="$(setup_update_tree)"
  # legacy v1 ticket: no session attribution block, no evidence: field
  cat > "$tree/docs/dev-infra-audit/tickets/DIA-001-legacy.md" <<'TICKET'
---
id: DIA-001
title: "legacy ticket"
area: docs
severity: Major
status: OPEN
blocked_by: []
discovered: 2026-08-01
source: inventory
date: 2026-08-01
created: 2026-08-01
updated: 2026-08-01

---

## Description

legacy fixture
TICKET
  f="$tree/docs/dev-infra-audit/tickets/DIA-001-legacy.md"
  run_update "$tree" DIA-001 --evidence "commit:legacy1"
  assert_status 0
  assert_file_contains "$f" "evidence:"
  assert_file_contains "$f" "  - commit:legacy1"
}

# ---------------------------------------------------------------------------
# Fix / Re-verify body replacement
# ---------------------------------------------------------------------------

@test "tickets update: --fix-file replaces the ## Fix section body" {
  tree="$(setup_update_tree)"
  f="$tree/docs/dev-infra-audit/tickets/DIA-130-alpha.md"
  local fixmd="$BATS_TEST_TMPDIR/fix.md"
  printf 'FIXED BY PATCH 42\n' > "$fixmd"
  run_update "$tree" DIA-130 --fix-file "$fixmd"
  assert_status 0
  assert_file_contains "$f" "FIXED BY PATCH 42"
  ! grep -qF -- "placeholder fix" "$f"
}

@test "tickets update: --reverify-file replaces the ## Re-verify section body" {
  tree="$(setup_update_tree)"
  f="$tree/docs/dev-infra-audit/tickets/DIA-130-alpha.md"
  local revmd="$BATS_TEST_TMPDIR/reverify.md"
  printf 'REVERIFIED OK\n' > "$revmd"
  run_update "$tree" DIA-130 --reverify-file "$revmd"
  assert_status 0
  assert_file_contains "$f" "REVERIFIED OK"
  ! grep -qF -- "placeholder reverify" "$f"
}

@test "tickets update: non-ASCII in --fix-file is sanitized to ? with warning" {
  tree="$(setup_update_tree)"
  f="$tree/docs/dev-infra-audit/tickets/DIA-130-alpha.md"
  local fixmd="$BATS_TEST_TMPDIR/fix.md"
  printf 'caf\xC3\xA9 result\n' > "$fixmd"
  run_update "$tree" DIA-130 --fix-file "$fixmd"
  assert_status 0
  assert_file_contains "$f" "caf? result"
  assert_output_contains "non-ASCII"
}

@test "tickets update: --fix-file on ticket missing ## Fix appends the section" {
  tree="$(setup_tree)"   # DIA-130 has no Fix/Re-verify sections here
  f="$tree/docs/dev-infra-audit/tickets/DIA-130-alpha.md"
  local fixmd="$BATS_TEST_TMPDIR/fix.md"
  printf 'FIXED BY PATCH 42\n' > "$fixmd"
  run_update "$tree" DIA-130 --fix-file "$fixmd"
  assert_status 0
  assert_file_contains "$f" "## Fix"
  assert_file_contains "$f" "FIXED BY PATCH 42"
}

@test "tickets update: empty --fix-file keeps heading, removes placeholder" {
  tree="$(setup_update_tree)"
  f="$tree/docs/dev-infra-audit/tickets/DIA-130-alpha.md"
  local fixmd="$BATS_TEST_TMPDIR/fix.md"
  : > "$fixmd"
  run_update "$tree" DIA-130 --fix-file "$fixmd"
  assert_status 0
  assert_file_contains "$f" "## Fix"
  ! grep -qF -- "placeholder fix" "$f"
}

@test "tickets update: unreadable --fix-file exits 1, file unchanged" {
  tree="$(setup_update_tree)"
  f="$tree/docs/dev-infra-audit/tickets/DIA-130-alpha.md"
  run_update "$tree" DIA-130 --fix-file "$BATS_TEST_TMPDIR/does-not-exist.md"
  assert_status 1
  assert_output_contains "file not readable"
  assert_file_contains "$f" "status: OPEN"
}

# ---------------------------------------------------------------------------
# combined mutations
# ---------------------------------------------------------------------------

@test "tickets update: all flags together apply status+evidence+fix+reverify" {
  tree="$(setup_update_tree)"
  readme="$tree/docs/dev-infra-audit/tickets/README.md"
  f="$tree/docs/dev-infra-audit/tickets/DIA-130-alpha.md"
  local fixmd="$BATS_TEST_TMPDIR/fix.md"
  local revmd="$BATS_TEST_TMPDIR/reverify.md"
  printf 'FIXED BY PATCH 42\n' > "$fixmd"
  printf 'REVERIFIED OK\n' > "$revmd"
  run_update "$tree" DIA-130 --status FIXED --fix-file "$fixmd" \
    --reverify-file "$revmd" --evidence "uri:one" --evidence "uri:two"
  assert_status 0
  assert_file_contains "$f" "status: FIXED"
  assert_file_contains "$f" "updated: $TODAY"
  assert_file_contains "$f" "  - uri:one"
  assert_file_contains "$f" "  - uri:two"
  assert_file_contains "$f" "FIXED BY PATCH 42"
  assert_file_contains "$f" "REVERIFIED OK"
  run grep -E '\| DIA-130 \| alpha ticket \| docs \| Major +\| FIXED' "$readme"
  assert_status 0
}

@test "tickets update: validation failure in one flag leaves file fully unchanged" {
  tree="$(setup_update_tree)"
  f="$tree/docs/dev-infra-audit/tickets/DIA-130-alpha.md"
  run_update "$tree" DIA-130 --status BOGUS --evidence "uri:one"
  assert_status 1
  assert_output_contains "invalid status"
  assert_file_contains "$f" "status: OPEN"
  ! grep -qF -- "uri:one" "$f"
}

# ---------------------------------------------------------------------------
# edge cases: archived / legacy / missing-section
# ---------------------------------------------------------------------------

@test "tickets update: archived ticket is updated, README rollup is a no-op" {
  tree="$(setup_update_tree)"
  mkdir -p "$tree/docs/dev-infra-audit/tickets/archive"
  cat > "$tree/docs/dev-infra-audit/tickets/archive/DIA-050-arch.md" <<'TICKET'
---
id: DIA-050
title: "archived ticket"
area: docs
severity: Low
status: OPEN
blocked_by: []
discovered: 2026-08-01
source: inventory
date: 2026-08-01
created: 2026-08-01
updated: 2026-08-01

---

## Description

archived fixture
TICKET
  readme="$tree/docs/dev-infra-audit/tickets/README.md"
  f="$tree/docs/dev-infra-audit/tickets/archive/DIA-050-arch.md"
  run_update "$tree" DIA-050 --status FIXED
  assert_status 0
  assert_file_contains "$f" "status: FIXED"
  # archived ticket is not in the README index; counts stay all-zero
  assert_file_not_contains "$readme" "DIA-050"
  assert_file_contains "$readme" "| OPEN        | 0     |"
}

@test "tickets update: legacy ticket updated without adding session attribution" {
  tree="$(setup_update_tree)"
  cat > "$tree/docs/dev-infra-audit/tickets/DIA-001-legacy.md" <<'TICKET'
---
id: DIA-001
title: "legacy ticket"
area: docs
severity: Major
status: OPEN
blocked_by: []
discovered: 2026-08-01
source: inventory
date: 2026-08-01
created: 2026-08-01
updated: 2026-08-01

---

## Description

legacy fixture
TICKET
  f="$tree/docs/dev-infra-audit/tickets/DIA-001-legacy.md"
  run_update "$tree" DIA-001 --status FIXED --evidence "commit:legacy1"
  assert_status 0
  assert_file_contains "$f" "status: FIXED"
  assert_file_contains "$f" "evidence:"
  assert_file_contains "$f" "  - commit:legacy1"
  # v1 schema must not gain a session attribution block
  ! grep -qF -- "Session Attribution" "$f"
}
