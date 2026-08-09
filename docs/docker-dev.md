# Dev Environment (Docker)

One dev workstation container + one stateful service container (PostgreSQL).
OpenWebUI intentionally runs per-developer (locally in WSL Docker) — not here.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  dev container (poetry-dev)                                   │
│  opencode + OMO slim · Node 24 · Python 3 · pnpm · bun · mise│
│   uv · Rust (wasm32) · Playwright · crawl4ai                 │
│   /workspace = this monorepo (bind mount)                    │
│   pnpm dev  →  turbo runs author-studio (Quasar dev server)  │
│                → :9000                                       │
│   api-server (FastAPI) and publishing-platform (Nuxt) are    │
│   NOT started by turbo: api-server is Python (start it with  │
│   uvicorn), publishing-platform has no `dev` script.         │
└──────────────────────────┬───────────────────────────────────┘
                           │ compose network
┌──────────────────────────▼───────────────────────────────────┐
│  postgres container (poetry-postgres)  postgres:16-alpine    │
│  named volume `pgdata` — data survives restarts              │
│  reachable from dev as `postgres:5432`                       │
└──────────────────────────────────────────────────────────────┘
```

## Quick Start

**Prerequisite:** `make` must be installed on the host. On Debian/Ubuntu:
`sudo apt-get install make`. The container has `make` for in-container use; the
host needs it to run the Makefile targets (`make up`, `make shell`, etc.).

```bash
cp .env.example .env            # configure ports / postgres creds
# optionally drop API keys into secrets/ (see secrets/README.md)
make up                         # build dev image + start postgres + dev
make shell                      # shell into the workstation container
make install                    # pnpm install (first time / after dep changes)
make dev                        # start author-studio only (turbo run dev)
```

`make dev` starts **author-studio** only — it is the only app with a `dev`
script. Start the others manually inside the container:

```bash
# api-server (Python/FastAPI) — NOT started by turbo
docker compose exec dev bash -c 'cd /workspace/apps/api-server && uv run uvicorn app.main:app --host 0.0.0.0 --port 8000'
# publishing-platform (Nuxt) has no `dev` script yet
```

Open in browser: `http://localhost:9000` (author-studio), `:8000` (api), `:3000` (publishing).

## Make Targets

| Target          | What it does                                                           |
| --------------- | ---------------------------------------------------------------------- |
| `make build`    | Build the dev image                                                    |
| `make up`       | Start dev + postgres in background                                     |
| `make shell`    | Open a bash shell in the dev container                                 |
| `make opencode` | Run `opencode` in the dev container                                    |
| `make dev`      | `pnpm dev` → turbo starts author-studio (only app with a `dev` script) |
| `make install`  | `pnpm install` inside the dev container                                |
| `make db-psql`  | `psql` into postgres                                                   |
| `make logs`     | Follow compose logs                                                    |
| `make down`     | Stop containers (keep data)                                            |
| `make clean`    | Stop containers + wipe volumes (postgres data, pnpm store)             |

## Secrets

API keys live as files in `secrets/` (git-ignored), mounted read-only into the
container at `/run/secrets`. The entrypoint loads only whitelisted names into
env. See `secrets/README.md` for the full list.

```bash
echo "sk-ant-..." > secrets/anthropic_api_key
make up   # or: docker compose up -d
```

## The `dev` container image

Built from `Dockerfile.dev` (Debian 13 slim, pinned + SHA256-verified
installers). It is intentionally **not** distroless and not read-only — dev
must write (pnpm install, WASM builds, dev-server caches). It runs as
non-root user `dev` (UID/GID 1000). Playwright + crawl4ai are pre-installed for
browser automation under a virtual X display (Xvfb).

## Notes

- `node_modules` lives in a named volume (`pnpm_store`), not on the host — the
  host repo stays clean and the container keeps its own dependency tree.
- Postgres data lives in named volume `pgdata`. `make clean` wipes it.
- To run opencode interactively inside the container: `make opencode`.
- For a full end-to-end stack in one shot (author-studio + opencode), use two
  terminals: `make dev` in one, `make opencode` in the other.
