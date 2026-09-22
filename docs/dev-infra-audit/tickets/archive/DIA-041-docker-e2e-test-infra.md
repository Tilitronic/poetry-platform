# DIA-041 — Docker E2E — full make test-infra

---

id: DIA-041
title: "Docker E2E — full make test-infra"
area: docker
severity: Medium
status: VERIFIED
blocked_by: []
discovered:
source: baseline
date: 2026-08-04
created: 2026-08-04
updated: 2026-08-04

---

## Description

Owner-approved **FULL** run of `make test-infra` for this campaign (estimated
~18h; rebuilds the dev image; ends with `docker compose down`). Recipe
(Makefile:87–91):

`gen-jsconfig` → `test-shell` → `bash scripts/test-docker-smoke.sh` →
`docker compose up -d --build` → `$(MAKE) test-python` → `docker compose down`.

This exercises the whole chain: jsconfig regeneration, bats suites, the heavy
self-contained Docker smoke test (build + healthchecks + runtimes + secrets
mounts + Playwright probes + openspec + make + pg_isready + Xvfb + tini PID1 +
author-studio :9000), then a layer-cached restart so the container pytest suite
(api-server + analytics-pipeline) has a stack, then teardown.

**RUNTIME NOTE:** the gate ends with the stack **down**. Before the browser E2E
(DIA-042), the stack must be restored with `make up`.

## Verification

1. `make test-infra` → exit 0 end-to-end.
2. Record phase timings: gen-jsconfig, test-shell, smoke, `up -d --build`, test-python, down.
3. Confirm `docker compose ps` shows no running containers after (stack down, per recipe).
4. Restore the stack with `make up` so DIA-042 can run browser flows.
5. Record exit code + summary lines in Re-verify.

## Fix

> To be filled at fix time.

## Re-verify

Full make test-infra PASS after volume refresh (2026-08-04, cod-12 + cod-14):
phases 1/2/4/5/6 exit 0; Phase 3 test-docker-smoke exit 0 on re-run
(author-studio :9000 HTTP 200) after stale pnpm_store volume refresh via
`docker compose run --rm dev pnpm install`; image
poetry-platform-dev@sha256:fa324799…; pytest 6/6 (2 api-server + 4
analytics-pipeline); compose down exit 0.
