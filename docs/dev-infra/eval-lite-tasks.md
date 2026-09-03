# eval-lite task manifest
# Curated: 2026-08-11
# Curator: coder (dia-086-m1-m5-agent-contracts-eval-lite task 5.1)
# Review cadence: monthly, aligned with DIA ledger sweep
# Fields: ticket-id<TAB>command<TAB>expected-exit-code<TAB>source-suite<TAB>failure-evidence<TAB>container-bound
# container-bound: 'yes' = requires dev container running (skipped with WARN when container down); 'no' = host-runnable
# Manual review gate: one human or agent sanity-reads the 20-task curated set each review cycle
# (council alpha-suggestion, accepted as recorded -- design.md Decision 5).
# Source priority: (1) DIA ticket ledger, (2) vitest editor-engine + phonetics-core,
# (3) pytest api-server + analytics-pipeline, (4) escalated/crisis session-log patterns.
# Expected exit code 0 = command must pass on a healthy tree (host or container context per field 6).
DIA-096	make test-config	0	DIA ledger	DIA-096	no
DIA-063	bash scripts/test-ticket-gate.sh	0	DIA ledger	DIA-063	no
DIA-052	bash .opencode/scripts/validate-skills.sh	0	DIA ledger	DIA-052	no
DIA-044	bash scripts/check-opencode-docker.sh	0	DIA ledger	DIA-044	no
DIA-066	bash scripts/audit-agent-tool-coverage.sh .opencode/opencode.jsonc	0	DIA ledger	DIA-066	no
vitest-editor-engine	pnpm --filter @poetry/editor-engine test	0	vitest editor-engine	editor-engine vitest suite (91 tests)	no
vitest-phonetics-core	pnpm --filter @poetry/phonetics-core test	0	vitest phonetics-core	phonetics-core vitest suite (25 tests)	no
vitest-editor-engine-typecheck	pnpm --filter @poetry/editor-engine typecheck	0	vitest editor-engine	editor-engine typecheck	no
vitest-phonetics-core-typecheck	pnpm --filter @poetry/phonetics-core typecheck	0	vitest phonetics-core	phonetics-core typecheck	no
vitest-editor-engine-lint	pnpm --filter @poetry/editor-engine lint	0	vitest editor-engine	editor-engine lint	no
pytest-api-server	docker compose exec -T dev bash -c 'cd /workspace/apps/api-server && .venv/bin/python -m pytest'	0	pytest api-server	api-server pytest suite (2 tests)	yes
pytest-analytics-pipeline	docker compose exec -T dev bash -c 'cd /workspace/packages/analytics-pipeline && .venv/bin/python -m pytest'	0	pytest analytics-pipeline	analytics-pipeline pytest suite (4 tests)	yes
make-test-python	make test-python	0	pytest api-server + analytics-pipeline	Makefile test-python target (both pytest suites)	yes
ruff-api-server	docker compose exec -T dev bash -c 'cd /workspace/apps/api-server && .venv/bin/ruff check .'	0	pytest api-server	api-server ruff lint	yes
ruff-analytics-pipeline	docker compose exec -T dev bash -c 'cd /workspace/packages/analytics-pipeline && .venv/bin/ruff check .'	0	pytest analytics-pipeline	analytics-pipeline ruff lint	yes
DIA-079	bash scripts/validate-handoff.sh	0	session-log	DIA-079 (handoff write JSON parse error)	no
DIA-068	make jsonl-cross-check	0	session-log	DIA-068 (delegation-observer persistence trigger)	no
ana007-jsonl-stats	make jsonl-stats	0	session-log	ana007 (session-log rollup)	no
ana007-session-log-render	make session-log-render	0	session-log	ana007 (derived messages.md view)	no
DIA-076	bash scripts/test-ticket-gate.sh	0	session-log	DIA-076 (ticket-gate fix regression)	no
