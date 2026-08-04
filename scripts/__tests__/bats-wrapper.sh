#!/usr/bin/env bash
# Runs the bats unit tests for dev-infra shell scripts (`make test-shell`).
#
# Self-contained: uses a system `bats` if present, otherwise vendors bats-core
# (a plain bash script) into scripts/__tests__/vendor/ on first run. The vendor
# dir is git-ignored — documented choice: avoid committing a third-party test
# runner; one shallow clone per developer machine is enough.
#
# Also runs `bash -n` over every shell artifact so syntax errors surface before
# the test suite (cheap, and bats errors are less readable than bash -n's).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TESTS_DIR="$ROOT/scripts/__tests__"
VENDOR_DIR="$TESTS_DIR/vendor/bats-core"

# --- Syntax-check every plain shell artifact we test -------------------------
# (.bats files use bats' @test preprocessor syntax and are NOT valid bash —
# bats itself reports syntax errors in them.)
for script in \
  "$ROOT/scripts/dev-stack.sh" \
  "$ROOT/dev-entrypoint.sh" \
  "$ROOT/scripts/dev-secrets-profile.sh" \
  "$ROOT/scripts/test-docker-smoke.sh" \
  "$ROOT/scripts/gen-jsconfig.sh" \
  "$ROOT/scripts/verify-pre-push.sh" \
  "$ROOT/scripts/verify-pre-commit.sh" \
  "$ROOT/scripts/verify-python.sh" \
  "$ROOT/scripts/lint-python-files.sh" \
  "$ROOT/scripts/check-tools.sh" \
  "$ROOT/scripts/check-opencode-docker.sh" \
  "$ROOT/scripts/author-studio-probe-guard.sh" \
  "$ROOT/.opencode/scripts/validate-skills.sh" \
  "$ROOT/scripts/__tests__/test-helper.bash"; do
  bash -n "$script"
done
echo "ok: shell syntax (bash -n) passed for all scripts under test"

# --- Syntax-check the Node dev-infra script (node --check, not bash -n) -------
node --check "$ROOT/scripts/context7-docs.mjs"
echo "ok: node --check passed for scripts/context7-docs.mjs"

# --- Locate (or vendor) bats -------------------------------------------------
BATS=""
if command -v bats >/dev/null 2>&1; then
  BATS="$(command -v bats)"
  echo "ok: using system bats: $BATS"
else
  if [ ! -x "$VENDOR_DIR/bin/bats" ]; then
    echo "-> bats not found; vendoring bats-core into $VENDOR_DIR (git-ignored)..."
    mkdir -p "$TESTS_DIR/vendor"
    # Pinned to v1.11.0, verified as a real released tag on 2026-08-01 (see the
    # upstream docs/CHANGELOG.md: "## [1.11.0] - 2024-03-24"). Pinning keeps the
    # vendored runner's behavior stable across machines instead of tracking HEAD.
    git clone --depth 1 --branch v1.11.0 https://github.com/bats-core/bats-core "$VENDOR_DIR" >/dev/null 2>&1
  fi
  BATS="$VENDOR_DIR/bin/bats"
  echo "ok: using vendored bats: $BATS"
fi

exec "$BATS" --print-output-on-failure "$TESTS_DIR"
