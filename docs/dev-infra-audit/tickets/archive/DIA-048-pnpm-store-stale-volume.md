# DIA-048 — Stale pnpm_store named volume + presence-only skip guard masks author-studio probe failures

---

id: DIA-048
title: "Stale pnpm_store named volume + presence-only skip guard masks author-studio probe failures"
area: docker
severity: Major
status: VERIFIED
blocked_by: []
discovered:
source: test-lane
date: 2026-08-04
created: 2026-08-04
updated: 2026-08-04

---

## Description

The `make test-infra` Docker smoke test failed its author-studio probe phase with
a Node `MODULE_NOT_FOUND` error for `@quasar/app-vite`. Two interacting root
causes:

1. **Stale `pnpm_store` named volume.** `docker-compose.yml:37–39` mounts the
   named volume `pnpm_store` at `/workspace/node_modules` ("Named volume to keep
   pnpm store + node_modules inside container"; declared at
   `docker-compose.yml:110`). The volume persists across `docker compose down`
   (only the container is removed), so after lockfile/dependency drift the
   mounted `node_modules` is stale — `@quasar/app-vite` (declared
   `^2.5.1` in `apps/author-studio/package.json:43`) was not present in the
   installed tree, and `pnpm dev` (turbo → quasar dev) failed with
   `MODULE_NOT_FOUND: Cannot find module '@quasar/app-vite'`.

2. **Presence-only skip guard at `test-docker-smoke.sh:248`.** The probe that
   should have caught this is guarded by:

   ```bash
   if [ ! -x /workspace/node_modules/.bin/turbo ]; then
     echo "skip: node_modules not installed yet; run make install then re-run the smoke test to probe author-studio"
     exit 0
   fi
   ```

   The guard checks only that the `turbo` binary exists — it does **not** check
   that the installed tree is fresh or that the Quasar toolchain resolves. With
   the stale volume, `turbo` was present (so the guard passed) but
   `@quasar/app-vite` was missing (so the dev server crashed). The guard can also
   **silently skip** the probe entirely (exit 0) when node_modules is absent —
   a false-green: the smoke test reports PASS without ever exercising the app.

Severity **Major**: the smoke gate's probe is either false-green (skip) or
false-red-on-stale-volume (MODULE_NOT_FOUND) depending on volume state — the
gate does not reliably probe the real app. **Note:** the ticket stays OPEN even
though the Phase-3 failure was resolved operationally (see Re-verify) because the
probe-freshness defect (root cause 2) is not yet fixed.

## Verification

1. `docker volume ls | grep pnpm_store` — confirm the named volume persists
   across container rebuilds (stale-tree carrier).
2. Inspect the guard: `sed -n '245,252p' scripts/test-docker-smoke.sh` — confirm
   the presence-only check (`-x /workspace/node_modules/.bin/turbo`) and the
   `exit 0` skip path.
3. Refresh the volume, then re-run the smoke probe:
   - `docker compose down` (stops the stack) → `docker volume rm pnpm_store`
   - `docker compose up -d --build` → `docker compose run --rm dev pnpm install`
   - `bash scripts/test-docker-smoke.sh` → expect author-studio `:9000` HTTP 200.
4. Record exit codes + probe summary lines in Re-verify.

## Fix

> Implemented 2026-08-04 (code-executor, dev-infra lane) — **Fix b (durable
> probe-freshness guard; the ticket driver):**
>
> 1. New `scripts/author-studio-probe-guard.sh` — replaces the presence-only
>    check. Exit codes: `0` = toolchain fresh (`turbo` present AND
>    `@quasar/app-vite` resolvable — `test -e` follows the pnpm symlink into
>    the `pnpm_store` volume, so a stale volume leaves it dangling and fails) →
>    run the probe; `1` = node_modules present but stale/incomplete →
>    **FAIL LOUDLY** (was `exit 0` silent skip / MODULE_NOT_FOUND crash) with
>    volume-refresh instructions; `2` = node_modules absent (fresh clone) →
>    skip with `make install` pointer (intentional, documented design choice).
> 2. `scripts/test-docker-smoke.sh` — probe now invokes the guard INSIDE the
>    container (the repo is bind-mounted at /workspace, so the guard script is
>    always current without an image rebuild) and dispatches on its exit
>    code.
> 3. New `scripts/__tests__/author-studio-probe-guard.bats` — 6 tests over
>    fixture trees (fresh/stale/absent/incomplete + `/workspace` default
>    contract + smoke-wiring regression guard).

> NOT implemented: **Fix a** (operational refresh — already done operationally,
> see Re-verify) and **Fix c** (volume-lifecycle pre-step in the `test-infra`
> recipe) — Fix b addresses root cause 2, the ticket driver. The optional
> `pnpm install --frozen-lockfile` pre-step was intentionally omitted: it would
> change the smoke contract from stack-health to installer, and the guard's
> loud failure already surfaces a stale volume with exact refresh commands.

## Re-verify

Verification result 2026-08-04 (cod-14): `docker compose run --rm dev pnpm install`
exit 0 (+13/−14, esbuild 0.28.1); `test-docker-smoke` re-run exit 0 PASS
(author-studio `:9000` HTTP 200) — Phase-3 failure resolved operationally;
ticket remains OPEN for the probe-freshness improvement (Fix b).

Re-verify 2026-08-04 (code-executor, after Fix b): guard unit tests 6/6 (bats,
`scripts/__tests__/author-studio-probe-guard.bats`); guard run against the REAL
repo tree (host node_modules, turbo + @quasar/app-vite resolvable) → exit 0
"ok: author-studio toolchain fresh"; absent path → exit 2 skip; default
`/workspace` path → exit 2 on host (no /workspace — correct). `make test-shell`
exit 0 (90/90, incl. the 6 new guard tests + bash -n on the guard via
bats-wrapper). Full `make test-infra` docker smoke run deferred to the next
test-infra pass (this lane's change touches `scripts/`, not
docker-compose.yml/Dockerfile.dev; the gate is >10 min and tears down running
stacks) — the guard's container path is exercised by that run. Verification
item 2 (guard inspection) now reads: `scripts/author-studio-probe-guard.sh`
freshness check (turbo + `@quasar/app-vite`), NOT the old `-x
/workspace/node_modules/.bin/turbo` presence-only guard.
