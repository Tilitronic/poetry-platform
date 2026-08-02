#!/usr/bin/env bash
# Runs the Python verification suite (apps/api-server): ruff lint + format
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
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/apps/api-server"

{ test -x .venv/bin/python || uv venv .venv; } >/dev/null
uv pip install --python .venv/bin/python -q -e ".[dev]"

.venv/bin/ruff check .
.venv/bin/ruff format --check .

exec .venv/bin/python -m pytest
