#!/usr/bin/env bash
# Embedded OMO suite gate (DIA-260827-6wvm): bun test + typecheck for
# .opencode/oh-my-opencode-slim. Host- and container-runnable.
# Excluded from pnpm-workspace, so pnpm test does not cover it.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OMO="$ROOT/.opencode/oh-my-opencode-slim"

if [ ! -d "$OMO/src" ]; then
  echo "!! OMO suite not found at $OMO" >&2
  exit 0
fi

# Ensure deps present: OMO node_modules is ignored (.opencode/.gitignore) but
# present on dev machines after initial bun install. If missing, try to install
# when package.json exists; otherwise run tests directly (bun will error with
# missing module, surfacing the real problem).
if [ ! -d "$OMO/node_modules" ] && [ -f "$OMO/package.json" ]; then
  echo "== test-omo: bun install (missing node_modules) =="
  (cd "$OMO" && bun install --frozen-lockfile)
fi

echo "== test-omo: bun test =="
(cd "$OMO" && bun test)

echo "== test-omo: typecheck =="
if [ -f "$OMO/package.json" ]; then
  (cd "$OMO" && bun run typecheck)
else
  # package.json is ignored; run tsc directly against the OMO tsconfig
  npx tsc --noEmit --project "$OMO/tsconfig.json"
fi
