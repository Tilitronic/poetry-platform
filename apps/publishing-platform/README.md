# @poetry/publishing-platform

Public poem pages and author profiles, server-rendered via Nuxt 3 (SSR for
poem pages, static generation for profile pages). Shares UI components with
`author-studio` via the monorepo workspace packages
(`@poetry/visualizer-2d`, `@poetry/visualizer-3d`, `@poetry/data-contracts`).
See `architecture.md` §7.

## Status — not implemented (stub, deferred)

This app is a **stub**: `package.json` exists with empty `"scripts": {}` — no
`dev`/`build` scripts, no `src/`, no `dist/`, no `nuxt.config.ts`, and nothing
binds host port 3000. Browser E2E against it fails with
`ERR_CONNECTION_REFUSED` (DIA-042).

Implementation is **deferred**, closed doc-only via DIA-049 (2026-08-04). The
full publishing feature is a future campaign that requires a `.sdd/` design and
resolves the `architecture.md` §7 open questions (shared component contract).

## Plumbing

- `docker-compose.yml` maps `${PUBLISHING_PORT:-3000}:3000` for this app (the
  `apps/*` services run inside the dev container via `pnpm dev`/turbo).
- Root Turborepo defines `dev` and `build` tasks, and the pnpm workspace
  includes `apps/*` — this package currently defines no scripts, so those
  tasks have nothing to run here yet.
