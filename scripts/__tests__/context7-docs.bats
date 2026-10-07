#!/usr/bin/env bats
# Unit tests for scripts/context7-docs.mjs (dev-infra docs fetcher).
#
# Two network-free layers, matching the seams in openspec/changes/
# context7-docs-pipeline/design.md:
#   1. Dry-run (no CONTEXT7_API_KEY) -> workspace scan + dedup + inventory only.
#   2. Mock mode (CONTEXT7_MOCK=1 + test key) -> API calls are served from
#      fixtures under scripts/__tests__/fixtures/context7-mock/.
#
# Fixtures are synthetic workspaces in $BATS_TEST_TMPDIR (never the real repo),
# so dedup/status logic is tested in isolation from the real monorepo layout.

load test-helper

setup() {
  command -v jq >/dev/null 2>&1 || skip "jq is required for context7-docs tests"
}

# ---------------------------------------------------------------------------
# Fixture builders
# ---------------------------------------------------------------------------

# setup_fixture_workspace: the T1 dry-run fixture — two workspaces with a
# deliberate version skew (codemirror ^6.0.1 vs ^6.0.3), plus exclusions
# (@poetry/* workspace package and a node:* builtin that must never appear
# in the inventory).
setup_fixture_workspace() {
  local root="$1"
  mkdir -p "$root/packages/test-pkg-a" "$root/packages/test-pkg-b"
  cat > "$root/pnpm-workspace.yaml" <<'YAML'
packages:
  - "packages/*"
YAML
  cat > "$root/packages/test-pkg-a/package.json" <<'JSON'
{
  "name": "@poetry/test-pkg-a",
  "dependencies": {
    "codemirror": "^6.0.1",
    "next": "^14.0.0",
    "@poetry/editor-engine": "workspace:*",
    "node:fs": "1.0.0"
  }
}
JSON
  cat > "$root/packages/test-pkg-b/package.json" <<'JSON'
{
  "name": "@poetry/test-pkg-b",
  "dependencies": {
    "codemirror": "^6.0.3",
    "vue": "^3.4.0"
  }
}
JSON
}

# setup_mock_fixture_workspace: the T2 mock fixture — one workspace whose deps
# map 1:1 onto the mock fixtures by package name:
#   next          -> search-next.json + context-vercel-next.js.txt (succeeded)
#   codemirror    -> search-codemirror.json + context-vercel-codemirror.txt (succeeded)
#   vue           -> no fixture (skipped: mock fixture missing)
#   not-found     -> search-not-found.json, empty results (skipped)
#   not-finalized -> search-not-finalized.json, state "processing" -> 202 x2
#                    then success on the 3rd attempt (succeeded)
setup_mock_fixture_workspace() {
  local root="$1"
  mkdir -p "$root/packages/mock-a"
  cat > "$root/pnpm-workspace.yaml" <<'YAML'
packages:
  - "packages/*"
YAML
  cat > "$root/packages/mock-a/package.json" <<'JSON'
{
  "name": "@poetry/mock-a",
  "dependencies": {
    "next": "^14.0.0",
    "codemirror": "^6.0.3",
    "vue": "^3.4.0",
    "not-found": "^1.0.0",
    "not-finalized": "^2.0.0"
  }
}
JSON
}

# setup_mock_redirect_fixture_workspace: the T3 mock fixture for 301 handling —
#   moved        -> search-moved.json returns 301 with redirectUrl "/moved/example"
#                   -> context-moved-example.txt (succeeded at moved-example.md)
#   fetch-moved  -> search-fetch-moved.json resolves normally, then
#                   context-owner-fetchmoved.txt returns 301 WITHOUT a
#                   redirectUrl (skipped, not failed)
setup_mock_redirect_fixture_workspace() {
  local root="$1"
  mkdir -p "$root/packages/mock-301"
  cat > "$root/pnpm-workspace.yaml" <<'YAML'
packages:
  - "packages/*"
YAML
  cat > "$root/packages/mock-301/package.json" <<'JSON'
{
  "name": "@poetry/mock-301",
  "dependencies": {
    "moved": "^1.0.0",
    "fetch-moved": "^1.0.0"
  }
}
JSON
}

# run_context7: run the script against a fixture workspace root. Forces
# CONTEXT7_RETRY_DELAY_MS=1 so the 202 backoff (nominally 5s/15s/45s) never
# sleeps in tests; the caller controls CONTEXT7_API_KEY / CONTEXT7_MOCK.
run_context7() {
  local root="$1"
  CONTEXT7_WORKSPACE_ROOT="$root" CONTEXT7_RETRY_DELAY_MS=1 run node "$SCRIPTS_DIR/context7-docs.mjs"
}

inventory() {
  echo "$1/knowledge/context7-docs/_inventory.json"
}

# ---------------------------------------------------------------------------
# T1 — dry-run path (workspace scan + dedup + inventory)
# ---------------------------------------------------------------------------

@test "context7-docs: dry-run without a key exits 0 and reports dry-run mode" {
  local fixture="$BATS_TEST_TMPDIR/ws"
  setup_fixture_workspace "$fixture"
  unset CONTEXT7_API_KEY
  unset CONTEXT7_MOCK

  run_context7 "$fixture"

  assert_status 0
  assert_output_contains "No Context7 API key — running in dry-run mode"
  assert_output_contains "unique libraries: 3"
}

@test "context7-docs: dry-run inventory is valid JSON" {
  local fixture="$BATS_TEST_TMPDIR/ws"
  setup_fixture_workspace "$fixture"
  unset CONTEXT7_API_KEY

  run_context7 "$fixture"
  assert_status 0

  run jq -e . "$(inventory "$fixture")"
  assert_status 0
}

@test "context7-docs: scans both fixture workspaces" {
  local fixture="$BATS_TEST_TMPDIR/ws"
  setup_fixture_workspace "$fixture"
  unset CONTEXT7_API_KEY

  run_context7 "$fixture"
  assert_status 0

  run jq -e '.workspacesScanned == ["packages/test-pkg-a", "packages/test-pkg-b"]' "$(inventory "$fixture")"
  assert_status 0
}

@test "context7-docs: deduplicates codemirror to 3 unique libraries" {
  local fixture="$BATS_TEST_TMPDIR/ws"
  setup_fixture_workspace "$fixture"
  unset CONTEXT7_API_KEY

  run_context7 "$fixture"
  assert_status 0

  run jq -e '.uniqueLibraries == 3 and (.libraries | length) == 3' "$(inventory "$fixture")"
  assert_status 0
}

@test "context7-docs: resolves codemirror to the highest version 6.0.3" {
  local fixture="$BATS_TEST_TMPDIR/ws"
  setup_fixture_workspace "$fixture"
  unset CONTEXT7_API_KEY

  run_context7 "$fixture"
  assert_status 0

  run jq -e '.libraries[] | select(.packageName == "codemirror") | .resolvedVersion == "6.0.3"' "$(inventory "$fixture")"
  assert_status 0
}

@test "context7-docs: logs a version skew warning for codemirror" {
  local fixture="$BATS_TEST_TMPDIR/ws"
  setup_fixture_workspace "$fixture"
  unset CONTEXT7_API_KEY

  run_context7 "$fixture"
  assert_status 0

  assert_output_contains "WARN: version skew for codemirror"
  assert_output_contains "packages/test-pkg-a has ^6.0.1"
  assert_output_contains "packages/test-pkg-b has ^6.0.3"
  run jq -e '.versionSkewWarnings[] | select(.package == "codemirror") | (.resolved == "6.0.3")' "$(inventory "$fixture")"
  assert_status 0
}

@test "context7-docs: dry-run summary counts are all zero" {
  local fixture="$BATS_TEST_TMPDIR/ws"
  setup_fixture_workspace "$fixture"
  unset CONTEXT7_API_KEY

  run_context7 "$fixture"
  assert_status 0

  run jq -e '.summary == {"succeeded": 0, "skipped": 0, "failed": 0}' "$(inventory "$fixture")"
  assert_status 0
}

@test "context7-docs: dry-run inventory mode is dry-run with dry-run statuses" {
  local fixture="$BATS_TEST_TMPDIR/ws"
  setup_fixture_workspace "$fixture"
  unset CONTEXT7_API_KEY

  run_context7 "$fixture"
  assert_status 0

  run jq -e '.mode == "dry-run" and ([.libraries[].status] | unique) == ["dry-run"]' "$(inventory "$fixture")"
  assert_status 0
}

@test "context7-docs: excludes @poetry/* workspace packages and node:* builtins" {
  local fixture="$BATS_TEST_TMPDIR/ws"
  setup_fixture_workspace "$fixture"
  unset CONTEXT7_API_KEY

  run_context7 "$fixture"
  assert_status 0

  run jq -e '([.libraries[].packageName] | index("@poetry/editor-engine")) == null and ([.libraries[].packageName] | index("node:fs")) == null' "$(inventory "$fixture")"
  assert_status 0
}

# ---------------------------------------------------------------------------
# T2 — mock mode (API client + markdown writer)
# ---------------------------------------------------------------------------

@test "context7-docs: mock mode produces markdown files with YAML frontmatter" {
  local fixture="$BATS_TEST_TMPDIR/ws"
  setup_mock_fixture_workspace "$fixture"
  export CONTEXT7_API_KEY="test-key"
  export CONTEXT7_MOCK=1

  run_context7 "$fixture"

  assert_status 0
  assert_output_contains "MOCK MODE"

  local md="$fixture/knowledge/context7-docs/vercel-next.js.md"
  assert_file_exists "$md"
  assert_file_exists "$fixture/knowledge/context7-docs/vercel-codemirror.md"
  # first line is the frontmatter opener
  run head -1 "$md"
  assert_status 0
  assert_output_contains "---"
  assert_file_contains "$md" "libraryId: /vercel/next.js"
  assert_file_contains "$md" "packageName: next"
  assert_file_contains "$md" "resolvedVersion: 14.0.0"
  assert_file_contains "$md" "fetchedAt:"
  # body matches the fixture markdown
  assert_file_contains "$md" "### Introduction"
}

@test "context7-docs: mock mode inventory reports per-library statuses" {
  local fixture="$BATS_TEST_TMPDIR/ws"
  setup_mock_fixture_workspace "$fixture"
  export CONTEXT7_API_KEY="test-key"
  export CONTEXT7_MOCK=1

  run_context7 "$fixture"
  assert_status 0

  local inv
  inv="$(inventory "$fixture")"
  run jq -e '.mode == "mock"' "$inv"
  assert_status 0
  run jq -e '.libraries[] | select(.packageName == "next") | .status == "succeeded" and .outputFile == "vercel-next.js.md"' "$inv"
  assert_status 0
  run jq -e '.libraries[] | select(.packageName == "codemirror") | .status == "succeeded"' "$inv"
  assert_status 0
  run jq -e '.libraries[] | select(.packageName == "vue") | .status == "skipped"' "$inv"
  assert_status 0
  run jq -e '.libraries[] | select(.packageName == "not-found") | .status == "skipped"' "$inv"
  assert_status 0
}

@test "context7-docs: mock mode summary counts sum to uniqueLibraries" {
  local fixture="$BATS_TEST_TMPDIR/ws"
  setup_mock_fixture_workspace "$fixture"
  export CONTEXT7_API_KEY="test-key"
  export CONTEXT7_MOCK=1

  run_context7 "$fixture"
  assert_status 0

  run jq -e '(.summary.succeeded + .summary.skipped + .summary.failed) == .uniqueLibraries and .summary.succeeded == 3 and .summary.skipped == 2 and .summary.failed == 0' "$(inventory "$fixture")"
  assert_status 0
}

@test "context7-docs: mock mode retries a not-finalized library then succeeds" {
  local fixture="$BATS_TEST_TMPDIR/ws"
  setup_mock_fixture_workspace "$fixture"
  export CONTEXT7_API_KEY="test-key"
  export CONTEXT7_MOCK=1

  run_context7 "$fixture"

  assert_status 0
  assert_output_contains "202 (library not finalized)"
  assert_file_exists "$fixture/knowledge/context7-docs/pending-example.md"
  run jq -e '.libraries[] | select(.packageName == "not-finalized") | .status == "succeeded"' "$(inventory "$fixture")"
  assert_status 0
}

@test "context7-docs: mock mode aborts non-zero on a 401 invalid key" {
  local fixture="$BATS_TEST_TMPDIR/ws"
  setup_mock_fixture_workspace "$fixture"
  export CONTEXT7_API_KEY="invalid-key"
  export CONTEXT7_MOCK=1

  run_context7 "$fixture"

  assert_status 1
  assert_output_contains "invalid API key"
}

# ---------------------------------------------------------------------------
# T3 — 301 handling (search redirect + 301-without-redirectUrl)
# ---------------------------------------------------------------------------

@test "context7-docs: follows a 301 search redirect and writes the redirected slug" {
  local fixture="$BATS_TEST_TMPDIR/ws"
  setup_mock_redirect_fixture_workspace "$fixture"
  export CONTEXT7_API_KEY="test-key"
  export CONTEXT7_MOCK=1

  run_context7 "$fixture"

  assert_status 0
  assert_output_contains "301 — following redirect to /moved/example"
  assert_file_exists "$fixture/knowledge/context7-docs/moved-example.md"
  run jq -e '.libraries[] | select(.packageName == "moved") | .status == "succeeded" and .outputFile == "moved-example.md"' "$(inventory "$fixture")"
  assert_status 0
}

@test "context7-docs: marks a 301-without-redirectUrl as skipped, not failed" {
  local fixture="$BATS_TEST_TMPDIR/ws"
  setup_mock_redirect_fixture_workspace "$fixture"
  export CONTEXT7_API_KEY="test-key"
  export CONTEXT7_MOCK=1

  run_context7 "$fixture"

  assert_status 0
  assert_output_contains "fetch-moved (/owner/fetchmoved) — fetch(/owner/fetchmoved) returned 301 without redirectUrl"
  run jq -e '.libraries[] | select(.packageName == "fetch-moved") | .status == "skipped"' "$(inventory "$fixture")"
  assert_status 0
  run jq -e '.summary.failed == 0' "$(inventory "$fixture")"
  assert_status 0
}
