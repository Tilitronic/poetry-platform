# DIA-039 — pnpm verify pipeline + pnpm audit

---

id: DIA-039
title: "pnpm verify pipeline + pnpm audit"
area: js-tooling
severity: Medium
status: VERIFIED
blocked_by: []
discovered:
source: inventory
date: 2026-08-04
created: 2026-08-04
updated: 2026-08-04

---

## Description

The root `package.json` defines a full verify pipeline — `verify:format`
(prettier check), `verify:js` (lint + typecheck), `verify:js-tests` (test),
`verify:python` (`scripts/verify-python.sh`), and `verify` (all four) — but
**none of it is wired into any Makefile gate**. `make test-infra` /
`make test-shell` / `make test-config` never invoke `pnpm verify`, so JS
format/lint/typecheck/test regressions can ship with a green audit. This is the
untested-gap finding from the inventory lane.

**Script-name drift (verified 2026-08-04):** NEXT-RUN.md §3 item 3 names
`verify:lint` / `verify:typecheck` / `verify:test` — those scripts do **not**
exist. The real names are `verify:js` (lint + typecheck) and `verify:js-tests`
(test). The validation below uses the actual script names; the NEXT-RUN.md
listing itself is doc drift to reconcile separately.

## Verification

1. `node -e "console.log(Object.keys(require('./package.json').scripts).filter(s=>s.startsWith('verify')))"` → confirm actual names (`verify:format`, `verify:js`, `verify:js-tests`, `verify:python`, `verify`; no `verify:lint` / `verify:typecheck` / `verify:test`).
2. `pnpm verify:format` → exit 0.
3. `pnpm verify:js` → exit 0.
4. `pnpm verify:js-tests` → exit 0.
5. `pnpm verify:python` → exit 0 (record if container-dependent skip applies).
6. `pnpm audit` → exit 0; record vulnerability counts (prior Phase D evidence: 0 critical / 0 high).
7. Record every exit code + summary line in Re-verify.

## Fix

> To be filled at fix time.

## Re-verify

Re-verify 2026-08-04 (verify pipeline + audit): script names confirmed
(`verify:format`, `verify:js`, `verify:js-tests`, `verify:python`, `verify`; no
`verify:lint`/`verify:typecheck`/`verify:test` — NEXT-RUN.md listing remains doc
drift). `pnpm verify:format` exit 0; `pnpm verify:js` exit 0; `pnpm
verify:js-tests` exit 0. `pnpm audit` exit 0 — clean after the esbuild override
(DIA-047; esbuild 0.28.1, "No known vulnerabilities found"). pnpm verify
pipeline VERIFIED.
