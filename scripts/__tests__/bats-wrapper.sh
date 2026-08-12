#!/usr/bin/env bash
# Runs the bats unit tests for dev-infra shell scripts (`make test-shell`).
#
# Self-contained: uses a system `bats` if present, otherwise vendors bats-core
# (a plain bash script) into scripts/__tests__/vendor/ on first run. The vendor
# dir is git-ignored — documented choice: avoid committing a third-party test
# runner; one shallow clone per developer machine is enough.
#
# Every run re-validates an existing vendor dir against the pinned version
# (DIA-121): a drifted checkout is warned about on stderr but does not block
# the suite (see the drift-check block below).
#
# Also runs `bash -n` over every shell artifact so syntax errors surface before
# the test suite (cheap, and bats errors are less readable than bash -n's).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TESTS_DIR="$ROOT/scripts/__tests__"
VENDOR_DIR="$TESTS_DIR/vendor/bats-core"
# BATS_VENDOR_VERSION is the SINGLE source of truth for the pinned bats
# version, in package.json format (no leading "v"; the git tag is "v1.14.0").
# Re-pinned from v1.11.0 to v1.14.0 on 2026-08-12 (DIA-121): the git-ignored
# vendor dir on this machine had drifted to v1.14.0 (upstream
# docs/CHANGELOG.md: "## [1.14.0] - 2026-07-21") and the developer accepted
# that as the new baseline. The clone below uses "v${BATS_VENDOR_VERSION}" and
# check-bats-vendor-drift.sh re-validates the vendored checkout against this
# constant on every run so future drift is detected.
BATS_VENDOR_VERSION="1.14.0"

# --- Re-validate the vendored bats checkout against the pin (DIA-121) --------
# The vendor dir is cloned once and git-ignored; without this check a machine
# can silently drift to a different bats version (shifting test numbering and
# runner behavior) with no detection. When the dir exists, compare its
# package.json version against BATS_VENDOR_VERSION.
#
# Design decision (warn-and-continue, NOT re-clone and NOT fail): a mismatch
# is a hygiene issue, not a blocker - the drifted runner still executes the
# suite. Auto-re-cloning would be destructive and needs network access (and
# would surprise offline machines); hard-failing would lock developers out of
# `make test-shell` until they manually fix the vendor dir. The check script
# prints a clear stderr warning; `|| true` keeps set -e from propagating the
# non-zero exit while the suite still runs.
if [ -d "$VENDOR_DIR" ]; then
  bash "$TESTS_DIR/check-bats-vendor-drift.sh" "$BATS_VENDOR_VERSION" "$VENDOR_DIR" || true
fi

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
  "$ROOT/scripts/check-pin-sync.sh" \
  "$ROOT/scripts/check-tools.sh" \
  "$ROOT/scripts/check-host-jq.sh" \
  "$ROOT/scripts/check-host-lsp.sh" \
  "$ROOT/scripts/install-host-lsp.sh" \
  "$ROOT/scripts/session-log" \
  "$ROOT/scripts/check-opencode-docker.sh" \
  "$ROOT/scripts/author-studio-probe-guard.sh" \
  "$ROOT/scripts/validate-handoff.sh" \
  "$ROOT/scripts/validate-agent-names.sh" \
  "$ROOT/scripts/eval-lite.sh" \
  "$ROOT/scripts/worktrees.sh" \
  "$ROOT/.opencode/scripts/validate-skills.sh" \
  "$ROOT/.opencode/scripts/jsonl-cross-check.sh" \
  "$ROOT/scripts/__tests__/test-helper.bash" \
  "$ROOT/scripts/__tests__/check-bats-vendor-drift.sh"; do
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
    # Pinned to the BATS_VENDOR_VERSION constant above (v1.14.0, verified as a
    # real released tag per upstream docs/CHANGELOG.md: "## [1.14.0] -
    # 2026-07-21"). Pinning keeps the vendored runner's behavior stable across
    # machines instead of tracking HEAD; the drift check at the top of this
    # script re-validates the checkout against the same constant on every run.
    git clone --depth 1 --branch "v${BATS_VENDOR_VERSION}" https://github.com/bats-core/bats-core "$VENDOR_DIR" >/dev/null 2>&1
  fi
  BATS="$VENDOR_DIR/bin/bats"
  echo "ok: using vendored bats: $BATS"
fi

exec "$BATS" --print-output-on-failure "$TESTS_DIR"
