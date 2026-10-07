#!/usr/bin/env bash
# Runs the Python verification suite for both Python packages
# (apps/api-server + packages/analytics-pipeline): ruff lint + format
# check, then pytest. Invoked from the repo root by `pnpm verify:python` —
# which the pre-push hook runs inside the dev container. Debian's system
# python is PEP 668 externally-managed, so deps go into a project-local venv
# (.venv) bootstrapped on demand via uv — never the system site-packages.
# Re-runs reuse the existing venv.
#
# Ruff runs BEFORE pytest (D5): it is fast (<1s on this codebase) and catches
# formatting/lint issues that would waste pytest time on code that would not
# pass review. A ruff failure aborts via set -e, so pytest never runs on
# unlinted code.
#
# DIA-013: the analytics-pipeline was previously outside all Python gates; it
# now runs the same ruff + pytest sequence as the api-server.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# DIA-260827-48iw: handle uv cache permission (root-owned /home/dev/.cache/uv)
export UV_CACHE_DIR="${UV_CACHE_DIR:-/tmp/uv-cache}"
mkdir -p "$UV_CACHE_DIR" 2>/dev/null || true

# verify_package <relative-package-dir>: bootstrap the project-local venv,
# install the dev extra, lint + format-check with ruff, then run pytest.
verify_package() {
  local pkg="$1"
  echo "==> verify-python: $pkg"
  cd "$ROOT/$pkg"

  { test -x .venv/bin/python || uv venv .venv; } >/dev/null
  uv pip install --python .venv/bin/python -q -e ".[dev]"

  .venv/bin/ruff check .
  .venv/bin/ruff format --check .

  .venv/bin/python -m pytest
}

verify_package "apps/api-server"
verify_package "packages/analytics-pipeline"
verify_package "packages/phonetics-core"
