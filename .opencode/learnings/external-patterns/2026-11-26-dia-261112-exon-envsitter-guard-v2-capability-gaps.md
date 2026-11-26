# envsitter-guard 0.0.4 capability gaps on the V2 tree (2026-11-26)

Date: 2026-11-26
Ticket: DIA-261112-exon 'opencode-version-migration-breaking-change-inventory-blockers-and-remove-or-adapt-rating'
Source: ai-specialist gate lane findings (evidence 2026-11-26), registered before the
config edit per AGENTS.md section 2.5 step 1.

## The pin and the contract split

- `envsitter-guard@0.0.4` is the pinned entry at `.opencode/opencode.jsonc:694`.
- 0.0.4 implements the V1 plugin contract only: published 2026-01-15, a
  function export, built against `@opencode-ai/plugin ^1.1.14`.
- V2 support arrived upstream in 0.1.0 (2026-10-21) with a breaking
  `{ id, setup, server }` export.
- Conclusion: on OpenCode 2.x the 0.0.4 pin very likely contributes nothing.
  The V2 tree is effectively already unprotected by it. This is why
  `tasks.md` 1.5 says "provisionally remove" and defers the re-add to
  probe 2.3 / task 2.6.

## What 0.0.4 actually guarantees

- Hard block on the `read` tool for `.env*` paths, except `.env.example`.
- Hard block on `edit` / `write` / `patch` for `.env*` paths.
- 15 value-free inspection and mutation tools (the `envsitter_*` names).
- `.envsitter/` and `pepper` always blocked.

## What it never guaranteed

Common false assumptions, each of them false for 0.0.4:

- `git add` / `git commit` publishing: not blocked.
- `git push`: not blocked.
- Un-gitignoring a dotenv file: not blocked.
- Output redaction: absent.

The plugin hooks no `bash` and no `git` at all, and 0.0.4 has no output
scrubbing. `bash cat .env`, `grep` and `glob` leaked raw values into context
even on V1.

## Where the "bump to 0.1.1" instruction came from

An unapproved research recommendation (Q7 Option A) that was never folded
into `tasks.md`. The handoff then restated it as a task. The spec governs:
`tasks.md` says provisionally remove, not bump.

## V2 built-in coverage

- Default agent policy asks on `read` for `*.env` and `*.env.*`, and allows
  `*.env.example`.
- But "ask" is a human prompt, not a block, and "Allow always" persists a
  project-scoped allow, so one approval can open future reads permanently.
- No built-in edit/write block (base policy is allow-all).
- No shell guarding.
- No grep content guarding.
- No output redaction.

## Capability table

| Guarantee | envsitter 0.0.4 | V2 built-in | repo-native | gap |
| --- | --- | --- | --- | --- |
| `read` blocked for `.env*` (except `.env.example`) | yes (hard block) | asks, persistable allow (not a block) | no `.env` rule in `.opencode/opencode.jsonc` | yes |
| `edit` / `write` / `patch` blocked for `.env*` | yes (hard block) | none (base policy allow-all) | `bash-write-gate.ts` does not cover `.env` | yes |
| `bash` read/write of `.env*` blocked | no (no bash hooks) | no (no shell guarding) | no (bash-write-gate scope is `.git/`, `.opencode/session/`, `docs/dev-infra-audit/tickets/`) | yes |
| `grep` / `glob` content not exposed unredacted | no | no (no grep content guarding) | no | yes |
| Tool output redaction | no (no output scrubbing) | no (no output redaction) | no | yes |
| Value-free inspection / mutation tools (15) | yes | n/a (tools come from the plugin) | n/a | no |
| `.envsitter/` and `pepper` always blocked | yes | n/a (tools absent without the plugin) | n/a | no |
| `git add` / `git commit` publishing blocked | no | no | no (pre-commit has no secret scan) | yes |
| `git push` blocked | no | no | no | yes |
| Un-gitignoring blocked | no | no | no | yes |
| Every dotenv file name gitignored | n/a | n/a | partial: `.env`, `.env.local`, `.env.*.local` only | yes |

## Gap list measured against repo-native guards

- `bash-write-gate.ts` protects only `.git/`, `.opencode/session/` and
  `docs/dev-infra-audit/tickets/` for the coder lane
  (`PROTECTED_LITERALS` at `.opencode/plugins/lib/bash-write-gate.ts:29`)
  and excludes `.env` entirely.
- `.opencode/opencode.jsonc` has no `.env` permission rule.
- `.gitignore` (lines 26-28) covers `.env`, `.env.local` and `.env.*.local`
  but misses `.env.production`, `.env.staging`, `api.env`, `config.env` and
  any other `*.env`-named file.
- The pre-commit path (`scripts/verify-pre-commit.sh`) contains NO secret
  scanning at all: it runs lint-staged autofix plus the `/home/qualt`
  path-pollution guard, nothing else. This corrects a widely-held
  assumption that a scanner was already present.

## Decision recorded

- `tasks.md` 1.5 deferred; no plugin change now.
- Close the cheap gaps with native deny rules.
- Final disposition is closed by probe 2.3 / task 2.6.

## Sources

- `.opencode/opencode.jsonc:694` (pin) and `:595-616` (envsitter tool names
  enumerated in the ai-auditor permission block).
- `.opencode/plugins/lib/bash-write-gate.ts:29` (`PROTECTED_LITERALS`).
- `.gitignore:26-28` (dotenv patterns).
- `scripts/verify-pre-commit.sh` (no `gitleaks` / `trufflehog` / entropy /
  secret-scan step).
- envsitter-guard release history: 0.0.4 (2026-01-15, V1 function export),
  0.1.0 (2026-10-21, V2 `{ id, setup, server }` export).
