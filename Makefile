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
#   make test-config  validate OpenCode JSONC config syntax + interview + skills gate + docker-compose.yml
#   make test-interview  run scripts/test-interview-enforcement.sh (5 checks)
#   make test-skills  validate .opencode/skills/*/SKILL.md frontmatter (DIA-037)
#   make audit-python  pip-audit both Python packages (requires uv + committed uv.lock)
#   make context7-docs  fetch library docs from Context7 (requires CONTEXT7_API_KEY; dry-run without it)
#   make session-query  read-only SQL query over session records (node:sqlite :memory:; ARGS pass-through)
#   make session-analytics  canned analytics over native OpenCode telemetry (opencode stats/db; ARGS pass-through)
#   make test-harness  C5 scenario replay (bats) + bun plugin tests (requires Docker)

.PHONY: build up shell opencode dev stack install db-psql logs down clean check-pin-sync check-tools check-host-jq check-host-lsp gen-jsconfig test-shell test-opencode-docker test-python test-infra test-config test-interview test-skills eval-lite audit-python context7-docs jsonl-stats session-log-render jsonl-cross-check session-query session-analytics test-harness

stack:
	bash scripts/dev-stack.sh

build:
	docker compose build dev

UID := $(shell id -u)
GID := $(shell id -g)
export UID
export GID

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

# Standalone source-parity validator (scripts/check-pin-sync.sh). Asserts
# .mise.toml ↔ Dockerfile parity (Dockerfile.dev + tools/opencode-docker/Dockerfile)
# for node/pnpm. Exit precedence 2>1>0 (INFRA>mismatch>match). 4 comparisons
# total (2 pins × 2 Dockerfiles). See openspec/changes/dev-infra-pin-sync/.
check-pin-sync:
	bash scripts/check-pin-sync.sh

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

# Host-runnable LSP integrity check (scripts/check-host-lsp.sh). Verifies the
# three LS binaries (TS/Python/Rust) are on PATH at the pinned versions from
# scripts/lsp-versions.env. Wired into test-shell so `make test-shell` fails
# fast on host-tool drift — Gate B of the host-scope 3-gate acceptance
# (proposal.md). rust-analyzer is skippable via SKIP_RUST=1 (see
# docs/dev-infra/host-lsp-setup.md).
check-host-lsp:
	bash scripts/check-host-lsp.sh

# Host-runnable jq integrity check (scripts/check-host-jq.sh). Verifies jq is on
# PATH and functional (jq -n '1+1' returns 2). Wired into test-shell so `make
# test-shell` fails fast on host-tool drift — Gate B of the jq probe acceptance
# (proposal.md). No version pin; presence + functional smoke only. See
# docs/dev-infra/host-lsp-setup.md.
check-host-jq:
	bash scripts/check-host-jq.sh

# bats unit tests for scripts/dev-stack.sh + dev-entrypoint.sh. Docker is
# mocked (never started); bats is vendored on first run if not installed.
test-shell: check-pin-sync check-host-jq check-host-lsp test-opencode-docker
	bash scripts/__tests__/bats-wrapper.sh

# Eval-lite harness (scripts/eval-lite.sh, change dia-086 task 8.1; design.md
# Decision 7). Runs the 20-task curated sweep from
# docs/dev-infra/eval-lite-tasks.md. Host-runnable (DIA-094 exemption, same
# category as test-config/test-shell) and container-aware: tasks whose 6th
# field is `yes` are skipped with a WARN when the dev container is down.
# Deliberately NOT wired into verify-pre-commit.sh (locked decision #4) and
# NOT wired into CI. Exit codes: 0 all non-skipped pass, 1 any fail,
# 2 manifest missing, 3 no tasks defined.
eval-lite:
	bash scripts/eval-lite.sh

# Regenerate jsconfig.json from the current workspace layout (pnpm-workspace.yaml
# + packages/*). Output is gitignored; run on every devcontainer create via
# postCreateCommand and before test-infra so tests validate a fresh file.
gen-jsconfig:
	bash scripts/gen-jsconfig.sh > jsconfig.json

# Full dev-infra validation: regenerate jsconfig.json, unit shell tests,
# build+start the stack, run the heavy Docker smoke test, then the api-server
# pytest suite (which requires the stack to be UP — this is the M1 ordering
# fix; test-python used to run as a prerequisite on a cold start and failed).
# Single rebuild: smoke test leaves the stack up for test-python (SMOKE_LEAVE_UP=1,
# F-3, DIA-139) -- it is the sole bring-up; there is no second up --build.
# Requires a running Docker daemon.
test-infra: gen-jsconfig test-shell test-harness
	SMOKE_LEAVE_UP=1 bash scripts/test-docker-smoke.sh
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
# checks + skill frontmatter gate + agent-name cross-reference + HANDOFF
# prognosis-schema gate (change dev-infra-config-validators, T4) +
# decision-variants EBDV gate (DIA-115 item 1: scripts/validate-decision-variants.sh,
# wired alongside the other validate-*.sh scripts) + grilling-gate marker
# validator (DIA-104: scripts/validate-grilling-gate.sh, warn-not-fail on
# legacy tickets - absent gate_state = grandfathered, hard-fail only on
# invalid state or bypassed-without-override) + tool-coverage audit
# (change dia-066-tool-coverage-audit, T6) + memory-shelf JSON Schema gate
# (DIA-180 A2: scripts/validate-memory-shelf.sh validates
# .opencode/memory-shelf.yaml against scripts/schemas/memory-shelf.schema.json -
# the first agent-written YAML artifact under a machine-enforced shape
# contract) + changelog ledger schema gate (DIA-194 Variant B:
# scripts/validate-changelog.sh validates .opencode/CHANGELOG.yaml against
# scripts/schemas/changelog.schema.json - the second YAML artifact under
# contract, extension of the Deliverable-A pattern) + docker-compose.yml syntax (DIA-124: `docker compose config
# --quiet` so compose drift fails the config gate without the heavy
# test-infra). Invariant: test-config passes
# iff no HARD write-capable gaps remain — WARN-only gaps (the ~440 unlisted
# default-allow non-write-capable tools) do NOT break the gate (Decision 6
# scoping; see scripts/audit-agent-tool-coverage.sh).
test-config: test-interview test-skills
	docker compose config --quiet
	bash .opencode/scripts/validate-opencode-config.sh
	bash scripts/validate-agent-names.sh
	bash scripts/validate-output-contracts.sh
	bash scripts/validate-reviewer-sections.sh
	bash scripts/validate-decision-variants.sh
	bash scripts/validate-grilling-gate.sh
	bash scripts/check-orchestrator-prompt-drift.sh
	bash scripts/validate-handoff.sh
	bash scripts/test-ticket-gate.sh
	bash scripts/validate-memory-shelf.sh
	bash scripts/validate-changelog.sh
	bash scripts/audit-agent-tool-coverage.sh .opencode/opencode.jsonc
	bash scripts/audit-agent-tool-coverage.sh tools/opencode-docker/config/opencode.json
	# DIA-134 item 2: persistent behavioral suite (replaces DIA-132 throwaway
	# /tmp tests). Tracked since DIA-136 F2 - design.md DD2's gitignore rationale
	# (session-local reconstruction) did not hold: the suite asserts committed
	# files only, so a fresh clone must be able to run it. Regenerate the suite
	# when the plugin/config invariants it asserts evolve.
	node scripts/__tests__/batch-d-infra.test.mjs

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

# Regenerate the derived messages.md view from messages.jsonl (ana007 Option E
# Phase 2 — silent session logging: messages.jsonl is the canonical source of
# truth written by the delegation-observer plugin; messages.md is derived, never
# hand-edited). On-demand CLI (scripts/session-log); deliberately NOT wired into
# test-shell/test-infra/test-config, consistent with the jsonl-stats precedent.
session-log-render:
	@bash scripts/session-log render

# Cross-check messages.jsonl against registry.jsonl (ana007 Option E Phase 5 —
# silent session logging: every plugin delegation in registry.jsonl must be
# present in messages.jsonl within the ±5s timestamp tolerance; target >=99%).
# On-demand CLI (.opencode/scripts/jsonl-cross-check.sh); deliberately NOT
# wired into test-shell/test-infra/test-config, consistent with the jsonl-stats
# and session-log-render precedent.
jsonl-cross-check:
	@bash .opencode/scripts/jsonl-cross-check.sh

# Read-only SQL query layer over the orchestrator session records (DIA-156:
# scripts/session-query.mjs, node:sqlite :memory:, zero deps). Loads
# registry.jsonl + messages.jsonl into an in-memory sqlite DB and prints only
# the filtered/aggregated rows requested — the token-economy win over full-file
# greps. JSONL stays the canonical committed source of truth; no binary DB file
# is ever created. On-demand CLI, deliberately NOT wired into test-shell/
# test-infra/test-config (consistent with the jsonl-stats precedent); the bats
# suite for it lives at scripts/__tests__/session-query.bats and IS
# auto-discovered by test-shell. Usage:
#   make session-query ARGS="--session ses_xxx"
#   make session-query ARGS="--count-by status --table registry"
session-query:
	@node scripts/session-query.mjs $(ARGS)

# Canned analytics over OpenCode's NATIVE telemetry surface (DIA-182:
# scripts/session-analytics.sh — per-agent cost/tokens over subagent
# sessions, top-N model/tool usage, delegation-chain sanity via `opencode
# stats` + `opencode db`). Read-only, idempotent, zero new runtime deps
# (bash + opencode CLI). Deliberately NOT wired into test-shell/test-infra/
# test-config (consistent with the jsonl-stats precedent); the bats suite
# (scripts/__tests__/session-analytics.bats) IS auto-discovered by
# test-shell. Usage:
#   make session-analytics
#   make session-analytics ARGS="--view models --top 5"
session-analytics:
	@bash scripts/session-analytics.sh $(ARGS)

# C5 scenario replay tests (DIA-226): bats regression tests from the incident
# corpus (DIA-206 empty returns, DIA-085 clobber scenarios) driving the real
# delegation-observer plugin via bun scenario scripts inside the container.
# Two-part gate: (1) bats scenarios on the host exercise the plugin via docker
# compose exec + bun, (2) bun plugin tests inside the container validate the
# C1-C4 contracts. Both must pass for the target to exit 0.
test-harness:
	bash scripts/__tests__/bats-wrapper.sh --filter harness-scenario-replay
	docker compose exec -T dev bash -lc 'cd /workspace/.opencode/plugins/__tests__ && bun test'
