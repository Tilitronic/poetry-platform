#!/usr/bin/env bash
# author-studio-probe-guard.sh — freshness guard for the author-studio smoke
# probe (DIA-048 Fix b).
#
# WHY: the old inline guard in scripts/test-docker-smoke.sh checked only that
# the `turbo` binary exists under /workspace/node_modules/.bin. With the
# persistent pnpm_store named volume (docker-compose.yml:37-39), that
# presence-only check passes on a STALE tree — turbo is present but
# @quasar/app-vite is missing — and the probe then either crashes with
# MODULE_NOT_FOUND or, when node_modules is absent entirely, the probe is
# skipped with exit 0 (a false-green: the smoke test reports PASS without ever
# exercising the app).
#
# This guard replaces presence with FRESHNESS: it also verifies a representative
# dev-toolchain dependency (@quasar/app-vite) resolves through the installed
# tree, and FAILS LOUDLY (exit 1) when the tree is present but stale or
# incomplete instead of silently skipping.
#
# The script is host-testable: it takes the workspace root as its first
# argument (defaults to /workspace, the in-container contract), so bats unit
# tests can point it at fixture trees (scripts/__tests__/author-studio-probe-guard.bats).
#
# Exit codes:
#   0  toolchain present + resolvable — run the probe
#   1  node_modules present but stale/incomplete (@quasar/app-vite missing) —
#      the pnpm_store named volume needs refresh; fail loudly, no silent skip
#   2  node_modules absent — fresh-clone path (before `make install`); skip the
#      probe (intentional, documented design choice for the stack-health smoke
#      test)
set -euo pipefail

WS="${1:-/workspace}"
TURBO_BIN="$WS/node_modules/.bin/turbo"
QUASAR_APP_VITE="$WS/apps/author-studio/node_modules/@quasar/app-vite"

# Absent tree — fresh clone before `make install`. Deliberate skip: the smoke
# test is a stack-health gate, not an installer; the pointer tells the
# developer how to enable the probe (behavior kept from the pre-DIA-048 guard).
if [ ! -x "$TURBO_BIN" ]; then
  echo "skip: node_modules not installed yet; run make install then re-run the smoke test to probe author-studio"
  exit 2
fi

# Present-but-stale tree — the DIA-048 defect. `test -e` follows the pnpm
# symlink apps/author-studio/node_modules/@quasar/app-vite -> ../../../../node_modules/.pnpm/...,
# so it resolves THROUGH the pnpm_store named volume: a volume that drifted from
# the lockfile leaves the symlink dangling and this check fails. Fail loudly
# instead of exit 0 — a stale tree is a real gate failure, not a skip.
if [ ! -e "$QUASAR_APP_VITE" ]; then
  echo "error: node_modules is present but @quasar/app-vite is not resolvable in the installed tree (stale pnpm_store volume or incomplete install)." >&2
  echo "error: refresh the volume: docker compose down && docker volume rm pnpm_store && docker compose up -d --build && docker compose run --rm dev pnpm install" >&2
  exit 1
fi

echo "ok: author-studio toolchain fresh (turbo + @quasar/app-vite resolvable)"
exit 0
