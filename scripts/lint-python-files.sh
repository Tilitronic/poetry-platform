#!/usr/bin/env bash
# lint-staged bridge for Python files (pre-commit autofix). lint-staged runs
# commands from the repo root where ruff is not on PATH (it lives in
# apps/api-server/.venv/bin/ruff), and ruff resolves its config from the
# closest pyproject.toml, so we cd into each package root before invoking it.
#
# Path handling: lint-staged passes repo-root-relative paths
# (apps/api-server/app/... or packages/analytics-pipeline/src/...). For each
# file we rebase to the package it belongs to, cd to that package root, and
# run ruff there so per-package config is picked up. Files outside the two
# Python packages are out of scope (no ruff config) and are skipped with a
# diagnostic instead of being forwarded to ruff as an unresolvable path.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Group staged files by package: api-server paths are rebased to
# package-relative paths, analytics-pipeline paths likewise. Anything else is
# out of scope and skipped.
api_files=()
pipeline_files=()

for f in "$@"; do
  case "$f" in
    apps/api-server/*) api_files+=("${f#apps/api-server/}") ;;
    packages/analytics-pipeline/*) pipeline_files+=("${f#packages/analytics-pipeline/}") ;;
    *) echo "lint-python-files: skipping out-of-scope path: $f" >&2 ;;
  esac
done

# Same venv bootstrap as verify-python.sh: reuse the existing venv or create
# it on first run. `uv pip install -e ".[dev]"` is idempotent — a no-op when
# ruff (a [dev] extra) is already present. Only api-server owns a venv; the
# pipeline package reuses its ruff binary.
API_VENV="$ROOT/apps/api-server/.venv"
if [ ! -x "$API_VENV/bin/python" ]; then
  (cd "$ROOT/apps/api-server" && uv venv .venv) >/dev/null
fi
(cd "$ROOT/apps/api-server" && uv pip install --python .venv/bin/python -q -e ".[dev]")

# run_ruff <pkg> <file...>: runs ruff check --fix + format from the package
# root so per-package pyproject.toml config applies.
run_ruff() {
  local pkg="$1"
  shift
  if [ "$#" -gt 0 ]; then
    (cd "$ROOT/$pkg" && "$ROOT/apps/api-server/.venv/bin/ruff" check --fix "$@")
    (cd "$ROOT/$pkg" && "$ROOT/apps/api-server/.venv/bin/ruff" format "$@")
  fi
}

# All staged paths out of scope -> do not invoke ruff at all: `ruff check --fix`
# with no paths would lint-and-fix the entire package from that cwd.
run_ruff apps/api-server "${api_files[@]}"
run_ruff packages/analytics-pipeline "${pipeline_files[@]}"
