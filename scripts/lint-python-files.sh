#!/usr/bin/env bash
# lint-staged bridge for Python files (pre-commit autofix). lint-staged runs
# commands from the repo root where ruff is not on PATH (it lives in
# apps/api-server/.venv/bin/ruff), and ruff resolves its config from the
# closest pyproject.toml, so we cd into the api-server package first.
#
# Path handling: lint-staged passes repo-root-relative paths
# (apps/api-server/app/...); after the cd those must be rebased to
# package-relative paths. Anything not under apps/api-server is out of scope
# (ruff's config lives only in apps/api-server/pyproject.toml) and is skipped
# with a diagnostic instead of being forwarded to ruff as an unresolvable path.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/apps/api-server"

local_args=()
for f in "$@"; do
  case "$f" in
    apps/api-server/*) local_args+=("${f#apps/api-server/}") ;;
    *) echo "lint-python-files: skipping out-of-scope path: $f" >&2 ;;
  esac
done

# Same venv bootstrap as verify-python.sh: reuse the existing venv or create
# it on first run. `uv pip install -e ".[dev]"` is idempotent — a no-op when
# ruff (a [dev] extra) is already present.
{ test -x .venv/bin/python || uv venv .venv; } >/dev/null
uv pip install --python .venv/bin/python -q -e ".[dev]"

# All staged paths out of scope -> do not invoke ruff at all: `ruff check --fix`
# with no paths would lint-and-fix the entire api-server package from this cwd.
if [ "${#local_args[@]}" -gt 0 ]; then
  .venv/bin/ruff check --fix "${local_args[@]}"
  .venv/bin/ruff format "${local_args[@]}"
fi
