#!/usr/bin/env bash
# One-command dev stack bootstrap (host-side).
#
# Collapses the 5-step flow (cp .env -> compose up -> shell -> install -> dev)
# into a single command. Run from the repo root:
#   make stack     (or: pnpm stack, or: bash scripts/dev-stack.sh)
#
# Why this lives on the HOST: turbo runs inside the `dev` container, but
# .env creation and `docker compose` are host operations. Turbo can't do them,
# so this script is the host-side orchestration layer that hands off to turbo.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# --- 1. Create .env from template if missing --------------------------------
if [ ! -f .env ]; then
  cp .env.example .env
  echo "ok: created .env from .env.example"
else
  echo "ok: .env already present"
fi

# --- 2. Build dev image + start dev & postgres containers --------------------
if ! docker info >/dev/null 2>&1; then
  echo "error: Docker daemon is not running; start it and rerun the stack." >&2
  exit 1
fi
echo "-> building dev image and starting postgres (first run takes a while)..."
docker compose up -d --build

# --- 3. Install deps inside the container on first run -----------------------
# node_modules lives in a named volume; turbo binary only exists after install.
# test -x, not -d: node_modules/.bin/turbo is a file (pnpm shim), and -d is
# always false for it — which made this branch always re-run pnpm install.
if docker compose exec -T --user dev dev test -x node_modules/.bin/turbo; then
  echo "ok: dependencies already installed"
else
  echo "-> installing dependencies (pnpm install)..."
  docker compose exec -T --user dev dev pnpm install
fi

# --- 4. Start author-studio via turbo ----------------------------------------
# turbo (`pnpm dev`) starts ONLY author-studio — the only app with a `dev`
# script (docs/docker-dev.md:14-18). api-server (FastAPI/uvicorn) and
# publishing-platform (no dev script) are started separately; see
# docs/docker-dev.md for the manual commands. E4: doc-path pointers are allowed
# in the human-readable note; they must not appear inside URL lines.
echo "-> starting author-studio via turbo (pnpm dev)..."
echo "   author-studio : http://localhost:9000"
echo "   (api-server and publishing-platform are NOT started by turbo;"
echo "    start them separately — see docs/docker-dev.md)"
docker compose exec -it --user dev dev pnpm dev
