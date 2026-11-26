# T11 — Manual functional UX verification (owner-run)

> **Change:** dev-infra-language-servers (host scope, T11)
> **Blocker:** T10 — run only after `check-host-lsp.sh` passes (or after
> `SKIP_RUST=1` for the Rust section).
> **No automation by design** (Q7c ruling) — this checklist is the test.

Owner: run the checks below in your editor of choice, tick items off, and
record the verification client, date, and initials at the bottom. Any failure
should be recorded as a comment next to the item — do not silently skip.

## Prerequisites

- [ ] `bash scripts/check-host-lsp.sh` exits 0 (or the failing tool is one you
      intentionally skipped with `SKIP_RUST=1`).

## TypeScript

- [ ] Open a file in `packages/editor-engine/src/`, hover over a symbol imported
      from `@poetry/data-contracts` — go-to-def works.
- [ ] Hover over a local symbol shows type information.
- [ ] Diagnostics panel shows no spurious "cannot find module" errors for
      `@poetry/*` imports.

## Python

- [ ] Open a file in `apps/api-server/`, hover over a symbol imported from
      `packages/analytics-pipeline` — go-to-def works.
- [ ] Diagnostics panel shows no spurious import errors.

## Rust (skippable via `SKIP_RUST=1`)

- [ ] Open a file in `packages/stress-lang-core/`, hover over a symbol — type
      information appears.
- [ ] Diagnostics panel shows no spurious errors (or only pre-existing ones
      unrelated to LSP).

## Record

- [ ] Verification client used: **VSCode / opencode-in-container /
      opencode-on-host** (circle one).
- [ ] Date + developer initials: **\*\*\*\***\_\_\_\_**\*\*\*\***
