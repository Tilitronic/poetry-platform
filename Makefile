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
#   make test-opencode-docker  static integrity gate for tools/opencode-docker (wired into test-shell)
#   make check-tools  host-runnable tool integrity check (mise vs node/pnpm pins)
#   make test-infra   test-shell + full Docker compose smoke test (heavy)
#   make test-config  validate OpenCode JSONC config syntax + interview + skills gate
#   make test-interview  run scripts/test-interview-enforcement.sh (5 checks)
#   make test-skills  validate .opencode/skills/*/SKILL.md frontmatter (DIA-037)
#   make audit-python  pip-audit both Python packages (requires uv + committed uv.lock)
#   make context7-docs  fetch library docs from Context7 (requires CONTEXT7_API_KEY; dry-run without it)

.PHONY: build up shell opencode dev stack install db-psql logs down clean check-tools gen-jsconfig test-shell test-opencode-docker test-python test-infra test-config test-interview test-skills audit-python context7-docs jsonl-stats

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

# Host-runnable tool integrity check (seam S2; scripts/check-tools.sh). Verifies
# mise is on PATH, .mise.toml exists, `mise install` resolves the pins, and the
# mise-managed node/pnpm match the pinned versions. Deliberately NOT wired into
# test-shell/test-infra (design.md §2.8): it requires mise on PATH — the dev
# container or a host mise install — so it is a developer convenience, not a CI
# gate.
check-tools:
	bash scripts/check-tools.sh

# --- Test infrastructure (dev-infra artifacts) --------------------------------
# Static integrity gate for the tools/opencode-docker subproject (DIA-044).
# Host-runnable (no podman/docker daemon needed): asserts the subproject's
# required files exist, its shell artifacts pass bash -n, bootstrap.py parses,
# config/opencode.json is valid JSON, and its Makefile declares the canonical
# targets. Wired into test-shell so BOTH `make test-shell` and `make test-infra`
# (which pulls in test-shell) exercise it — the subproject can no longer drift
# with zero automated signal.
test-opencode-docker:
	bash scripts/check-opencode-docker.sh

# bats unit tests for scripts/dev-stack.sh + dev-entrypoint.sh. Docker is
# mocked (never started); bats is vendored on first run if not installed.
test-shell: test-opencode-docker
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

# Skill frontmatter validation (.opencode/scripts/validate-skills.sh, DIA-037).
# Walks .opencode/skills/*/SKILL.md — HARD: valid YAML, name+description
# present+non-empty, name==dirname; SOFT (warn-only): activation-phrase prefix,
# license notice. Exit codes: 0 all pass, 1 HARD failure, 2 infra error.
test-skills:
	bash .opencode/scripts/validate-skills.sh

# OpenCode JSONC config syntax validation + interview-enforcement regression
# checks + skill frontmatter gate.
test-config: test-interview test-skills
	bash .opencode/scripts/validate-opencode-config.sh

# Python dependency vulnerability audit via pip-audit (DIA-028). Exports the
# locked runtime dependency set per package with uv (exact pins + hashes) and
# audits it with a pinned pip-audit version. --disable-pip skips pip's resolver,
# so no scratch venv / ensurepip is needed on the host. Requires uv + uvx on the
# host PATH and the committed uv.lock in each package (DIA-029). Both packages
# are always audited — findings are accumulated and the target fails at the end
# if any package has vulnerabilities. Fixing Python vulns is tracked separately;
# this target only establishes the capability.
audit-python:
	@rc=0; \
	for pkg in apps/api-server packages/analytics-pipeline; do \
		f="$$(mktemp)"; \
		uv export --project "$$pkg" --no-dev -o "$$f" && uvx pip-audit@2.10.1 --disable-pip -r "$$f" || rc=1; \
		rm -f "$$f"; \
	done; \
	exit $$rc

# Fetch Context7 library docs for the monorepo's workspace dependencies
# (scripts/context7-docs.mjs -> knowledge/context7-docs/). Developer-triggered,
# deliberately NOT part of test-infra: the free Context7 plan allows 1000
# calls/month, so running this in CI would exhaust the shared quota. Without
# CONTEXT7_API_KEY the script runs in dry-run mode (inventory only, exit 0).
context7-docs:
	node scripts/context7-docs.mjs

# Show messages.jsonl session rollup — on-demand audit reader for the
# orchestrator's machine-readable session log (G9; .opencode/scripts/jsonl-stats.sh).
# Requires jq for detail; degrades to a plain line count otherwise.
jsonl-stats:
	@bash .opencode/scripts/jsonl-stats.sh
