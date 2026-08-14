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
#
# --quick mode (DIA-139 F-4): a fast tier for shell-edit iteration - the bats
# monolith (240 tests in one pass, ~25 s floor) has no quick subset, so every
# `.sh` edit paid the full cost. `bats-wrapper.sh --quick` runs two tiers and
# exits 0 only if BOTH pass:
#   1. syntax tier: `bash -n` over every *.sh under scripts/ and
#      .opencode/scripts/ (the same auto-discovered set as the default run) +
#      `node --check` over every *.mjs under scripts/__tests__/;
#   2. suite tier: bats over the three smallest suites - the "curated list":
#      check-host-jq.bats (3 tests), check-host-lsp.bats (9 tests),
#      validate-skills.bats (23 tests) = 35 tests total. The slow monolith is
#      skipped for fast feedback.
#   Positional args after --quick name alternate suites (design.md DD4 literal
#   list). lint-staged appends the staged *.sh paths to the command line
#   (lint-staged v15 resolveTaskFn: args.concat(files)); any arg that does not
#   resolve to an existing suite file under scripts/__tests__/ is IGNORED, so
#   the staged paths fall through to the curated default. When --quick falls
#   back to the curated default for ANY reason (no args, or no arg resolved to
#   a suite file - e.g. a typo'd suite name), it prints a one-line stderr
#   notice naming the curated suites, so the fallback is visible instead of
#   silently running a different set than the caller asked for (review
#   FALSIFICATION-1/3, DIA-139 fix loop 1). Default mode (no --quick) is
#   unchanged: it runs the full suite.
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

# --- Parse the --quick flag (DIA-139 F-4) ------------------------------------
# Parsed before anything runs so the syntax tier and suite tier below can
# branch on it. Remaining positional args (after the flag) are suite
# basenames per design.md DD4; see the --quick suite tier for how they are
# validated against lint-staged's appended staged-file paths.
QUICK=0
if [ "${1:-}" = "--quick" ]; then
  QUICK=1
  shift
fi

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
#
# Auto-discovered (DIA-125): every *.sh under scripts/ and .opencode/scripts/,
# plus dev-entrypoint.sh (repo root) and the three extension-less artifacts
# scripts/session-log, scripts/__tests__/test-helper.bash, and scripts/tickets
# (the DIA ledger CLI). New shell scripts get syntax-checked for free — no
# hand-maintained list.
#
# Exclusion escape hatch: append path substrings to BASH_N_EXCLUDE for files
# that must NOT be syntax-checked (deliberately non-bash, generated, or
# third-party). Each entry is matched as a substring of the discovered path.
BASH_N_EXCLUDE=(
  # none currently
)

while IFS= read -r -d '' script; do
  for excl in "${BASH_N_EXCLUDE[@]}"; do
    case "$script" in
      *"$excl"*) continue 2 ;;
    esac
  done

  bash -n "$script"
done < <(
  find "$ROOT/scripts" "$ROOT/.opencode/scripts" \
    -type f \( -name '*.sh' -o -name 'test-helper.bash' -o -name 'session-log' -o -name 'tickets' \) -print0
  find "$ROOT" -maxdepth 1 -name '*.sh' -print0
)
echo "ok: shell syntax (bash -n) passed for all scripts under test"

# --- Syntax-check the Node dev-infra script (node --check, not bash -n) -------
node --check "$ROOT/scripts/context7-docs.mjs"
echo "ok: node --check passed for scripts/context7-docs.mjs"

# --quick syntax tier (2): every *.mjs under scripts/__tests__/ (tasks.md 4.1).
if [ "$QUICK" = "1" ]; then
  while IFS= read -r -d '' mjs; do
    node --check "$mjs"
  done < <(find "$TESTS_DIR" -maxdepth 1 -type f -name '*.mjs' -print0)
  echo "ok: node --check passed for all scripts/__tests__/*.mjs"
fi

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

# --- --quick suite tier: curated subset (or explicit list), skip the monolith --
if [ "$QUICK" = "1" ]; then
  suites=("$@")
  quick_files=()
  for s in "${suites[@]}"; do
    # ${s%.bats} normalizes both "check-host-jq" and "check-host-jq.bats".
    # -f filters out lint-staged's appended staged *.sh paths (they never
    # resolve to a suite file under TESTS_DIR).
    f="$TESTS_DIR/${s%.bats}.bats"
    [ -f "$f" ] && quick_files+=("$f")
  done
  if [ "${#quick_files[@]}" -eq 0 ]; then
    # No valid selection: no args, or only non-suite args (lint-staged always
    # appends the staged *.sh paths to the command line; a typo'd suite name
    # lands here too). Fall through to the curated default so a staged shell
    # edit still gets the fast tier. The stderr notice names the curated
    # suites so the fallback is not silent (review FALSIFICATION-1/3, DIA-139
    # fix loop 1).
    echo "note: --quick: no suite args resolved; using curated default (check-host-jq, check-host-lsp, validate-skills)" >&2
    quick_files=(
      "$TESTS_DIR/check-host-jq.bats"
      "$TESTS_DIR/check-host-lsp.bats"
      "$TESTS_DIR/validate-skills.bats"
    )
  fi
  exec "$BATS" --print-output-on-failure "${quick_files[@]}"
fi

exec "$BATS" --print-output-on-failure "$TESTS_DIR"
