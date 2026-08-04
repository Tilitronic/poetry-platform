# DIA-047 — pnpm audit: esbuild <0.28.1 advisory (GHSA-g7r4-m6w7-qqqr)

---

id: DIA-047
title: "pnpm audit: esbuild <0.28.1 advisory (GHSA-g7r4-m6w7-qqqr)"
area: deps
severity: Minor
status: VERIFIED
blocked_by: []
discovered:
source: test-lane
date: 2026-08-04
created: 2026-08-04
updated: 2026-08-04

---

## Description

Validation-loop gate failure (2026-08-04): `pnpm audit` exits 1 — 1
low-severity advisory:

- **GHSA-g7r4-m6w7-qqqr** — esbuild `>=0.27.3 <0.28.1`: arbitrary file read
  when running the development server on Windows. Patched `>=0.28.1`.
- Path: `.>@quasar/app-vite>esbuild` (`@quasar/app-vite` ^2.5.1 in root
  `package.json`).
- Root `package.json` `pnpm.overrides` does **not** pin esbuild (current
  overrides: `@eslint/eslintrc`, `body-parser`, `brace-expansion` ×3,
  `immutable`, `postcss`).

Impact: low (Windows-only dev-server vector; esbuild arrives transitively via
the Quasar build toolchain), but the failing `pnpm audit` keeps the
dependency-audit lane of the verify pipeline red.

## Verification

1. `pnpm audit` → exit 1; record the advisory summary (package / vulnerable
   versions / patched / path).
2. `grep -n "esbuild" package.json` → confirm no esbuild pin in
   `pnpm.overrides`.
3. Re-run `pnpm audit` after the fix → exit 0; record the clean summary.

## Fix

> Owner disposition pending (options: fix override / document-accept).
> Proposed: add root `pnpm.overrides` `"esbuild": ">=0.28.1"` (or bump the dep
> chain), then re-run `pnpm audit` → exit 0.

> To be filled at fix time.

## Re-verify

Re-verify 2026-08-04 (cod-10): `pnpm.overrides` esbuild `>=0.28.1` added;
`pnpm install` exit 0 (esbuild 0.28.1 deduped across @quasar/app-vite + vite);
`pnpm audit` exit 0 (No known vulnerabilities found).
