# Poetry Platform — Dev Environment Makefile
# One dev workstation container + postgres service container.
#
#   make build        build the dev image
#   make up           start dev + postgres in background
#   make shell        open a shell in the dev container
#   make opencode     run opencode in the dev container
#   make dev          start all app services (turbo run dev)
#   make install      pnpm install inside the dev container
#   make db-psql      psql into postgres
#   make logs         follow compose logs
#   make down         stop containers (keep data)
#   make clean        stop containers + wipe volumes (postgres data, pnpm store)
#
#   make test-shell   unit-test dev-infra shell scripts (bats; Docker mocked)
#   make test-infra   test-shell + full Docker compose smoke test (heavy)
#   make test-config  validate OpenCode JSONC config syntax + interview enforcement
#   make test-interview  run scripts/test-interview-enforcement.sh (5 checks)
#   make context7-docs  fetch library docs from Context7 (requires CONTEXT7_API_KEY; dry-run without it)

.PHONY: build up shell opencode dev stack install db-psql logs down clean gen-jsconfig test-shell test-python test-infra test-config test-interview context7-docs

stack:
	bash scripts/dev-stack.sh

build:
	docker compose build dev

up:
	docker compose up -d

shell:
	docker compose exec dev bash

opencode:
	docker compose exec -it dev opencode

dev:
	docker compose exec -it dev pnpm dev

install:
	docker compose exec -it dev pnpm install

db-psql:
	docker compose exec postgres psql -U $${POSTGRES_USER:-poetry} -d $${POSTGRES_DB:-poetry}

logs:
	docker compose logs -f

down:
	docker compose down

clean:
	docker compose down -v

# --- Test infrastructure (dev-infra artifacts) --------------------------------
# bats unit tests for scripts/dev-stack.sh + dev-entrypoint.sh. Docker is
# mocked (never started); bats is vendored on first run if not installed.
test-shell:
	bash scripts/__tests__/bats-wrapper.sh

# Regenerate jsconfig.json from the current workspace layout (pnpm-workspace.yaml
# + packages/*). Output is gitignored; run on every devcontainer create via
# postCreateCommand and before test-infra so tests validate a fresh file.
gen-jsconfig:
	bash scripts/gen-jsconfig.sh > jsconfig.json

# Full dev-infra validation: regenerate jsconfig.json, unit shell tests,
# build+start the stack, run the heavy Docker smoke test, then the api-server
# pytest suite (which requires the stack to be UP — this is the M1 ordering
# fix; test-python used to run as a prerequisite on a cold start and failed).
# The smoke test is self-contained (builds/probes/tears down); the extra
# up --build after it is a cheap layer-cached restart so test-python has a
# stack, then we tear down. Requires a running Docker daemon.
test-infra: gen-jsconfig test-shell
	bash scripts/test-docker-smoke.sh
	docker compose up -d --build
	$(MAKE) test-python
	docker compose down

# Unit tests for the Python packages (pytest): apps/api-server + the
# analytics-pipeline (DIA-013 — it was previously outside all Python gates).
# Runs inside the dev container. Debian's system python3 is PEP 668
# externally-managed, so deps go into a project-local venv (.venv) bootstrapped
# on demand via uv — never the system site-packages. Re-runs reuse the venv.
test-python:
	docker compose exec -T dev bash -c 'cd /workspace/apps/api-server && { test -x .venv/bin/python || uv venv .venv; } && uv pip install --python .venv/bin/python -e ".[dev]"'
	docker compose exec -T dev bash -c 'cd /workspace/apps/api-server && .venv/bin/python -m pytest'
	docker compose exec -T dev bash -c 'cd /workspace/packages/analytics-pipeline && { test -x .venv/bin/python || uv venv .venv; } && uv pip install --python .venv/bin/python -e ".[dev]"'
	docker compose exec -T dev bash -c 'cd /workspace/packages/analytics-pipeline && .venv/bin/python -m pytest'

# Interview-first spec-authoring enforcement (scripts/test-interview-enforcement.sh,
# 5 grep/python checks). DIA-009: the script was orphaned — the CHANGELOG claimed
# Makefile registration that did not exist; this target makes that claim true and
# is wired into test-config below.
test-interview:
	bash scripts/test-interview-enforcement.sh

# OpenCode JSONC config syntax validation + interview-enforcement regression checks.
test-config: test-interview
	bash .opencode/scripts/validate-opencode-config.sh

# Fetch Context7 library docs for the monorepo's workspace dependencies
# (scripts/context7-docs.mjs -> knowledge/context7-docs/). Developer-triggered,
# deliberately NOT part of test-infra: the free Context7 plan allows 1000
# calls/month, so running this in CI would exhaust the shared quota. Without
# CONTEXT7_API_KEY the script runs in dry-run mode (inventory only, exit 0).
context7-docs:
	node scripts/context7-docs.mjs
