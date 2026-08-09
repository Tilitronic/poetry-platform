# DIA-069 §10 gate findings — opencode-telemetry command-doc pollution (2026-08-08)

- **Date:** 2026-08-08
- **Source:** §10 Phase-1 gate research by @ai-specialist for DIA-069 (opencode-telemetry@0.1.19 `registerCommands()` rewrites `.opencode/commands/telemetry-{report,inspect}.md` with literal `/home/qualt` paths on every plugin load). Registered per AGENTS.md §10 ("orchestrator registers the findings"); the executor lane persists them so they are recoverable beyond the git diffs. Follows the upstream-fix conspect (res005) and the DIA-069 ticket.
- **Status:** IMPLEMENTED + VALIDATED 2026-08-08 — interim guard committed (8e75259: portable baseline, restore script + Makefile target, watcher.ignore, verify guard); Phase 5 restart-twice validation PASS (after two developer OpenCode restarts the patched vendored plugin did NOT rewrite the two command docs — zero `/home/qualt` literals, `make test-telemetry-guard` 5/5 (A1-A5) both times WITHOUT restore, `make test-config` exit 0); Phase 6 @ai-auditor review SOUND-WITH-CAVEATS (no blockers, caveats accepted). Upstream PR (phase 4 part 2) PENDING — staging clone `/tmp/opencode-telemetry-upstream` LOST on host (regeneration required; patch regeneration is a separate pending step).

## Outcome

- **Part 1 — INTERIM GUARD IMPLEMENTED 2026-08-08.** (a) `.opencode/commands/telemetry-{report,inspect}.md` replaced with the SHIPPED portable octm-template form (verbatim copy from the package `command/*.md` — byte-identical; the new committed baseline). (b) `scripts/restore-telemetry-commands.sh` + `make restore-telemetry-commands` restores the baseline when the plugin re-pollutes (run BETWEEN restart and verification). (c) `watcher.ignore` for the two docs in `.opencode/opencode.jsonc` (removable when the upstream patch lands). (d) `scripts/verify-telemetry-guard.sh` + `make test-telemetry-guard` — 5 automated assertions (A1 no `/home/qualt`; A2 portable runtime-resolved form present; A3 git status clean for the two docs; A4 `make test-config` exit 0; A5 frontmatter valid YAML) + manual restart-twice note. `make test-config` exit 0.
- **Part 1.5 — VALIDATED 2026-08-08 (Phase 5 + Phase 6).** Phase 5 restart-twice: after two developer OpenCode restarts the patched vendored plugin (opencode-telemetry@0.1.19) did NOT rewrite the two command docs — zero `/home/qualt` literals, `make test-telemetry-guard` 5/5 (A1-A5) both times WITHOUT restore, `make test-config` exit 0. Phase 6 @ai-auditor independent review: verdict SOUND-WITH-CAVEATS, no blockers — portable baseline matches shipped templates; restore guard + verify guard A1-A5 implemented and passing; watcher.ignore applied; learnings registration present; vendored patch respect-existing guard verified (commands.ts:41 `fs.existsSync` skip, `copyFileSync` of shipped templates, package root passed from index.ts, no `writeFileSync` remains, `.bak-dia069` backups present). Caveats (informational, accepted): cache-path volatility of the vendored patch (durability depends on upstream merge); watcher-ignore temporary-by-design; one-time manual restore needed for previously-polluted files (covered by `make restore-telemetry-commands`).
- **Part 2 — UPSTREAM PATCH (permanent fix, NOT in this lane):** fork agostinilabsrl/opencode-telemetry → patch `src/commands.ts` to honor the shipped `command/*.md` templates / emit runtime-resolved forms → PR. Until it lands, every OpenCode load re-pollutes the two docs — the restore guard must run between restart and verification. **Status 2026-08-08:** PR NOT yet submitted; staging clone `/tmp/opencode-telemetry-upstream` LOST on host (possibly still inside the dev container; Docker unreachable from this WSL host to confirm) — patch regeneration is a separate pending step.

## Findings

- **A — No config-level mitigation exists.** Plugins bypass the OpenCode permission system entirely: the write is a raw `fs.writeFileSync` at module init with NO sandbox, NO path allowlist, and NO skip-registration option. Permission rules (`permission` blocks in `opencode.jsonc`) do not intercept plugin-side filesystem writes. Only removing the plugin from both configs or fixing the plugin source stops the write. (Evidence: `~/.cache/opencode/packages/opencode-telemetry@0.1.19/node_modules/opencode-telemetry/src/commands.ts` L33-34 unconditional `fs.writeFileSync`; `src/index.ts` L7 `registerCommands(import.meta.dir, ctx.directory)`.)
- **B — Union loading: the plugin loads from BOTH config layers.** Listed in the project `.opencode/opencode.jsonc` `plugin[]` L347 AND the global `~/.config/opencode/opencode.jsonc` `plugin[]` L135 — plugin arrays concatenate across config layers, so removing it from one layer alone will NOT prevent the write. The vendored package is byte-for-byte the upstream main (res005 Q1 evidence).
- **C — Root cause in the plugin's command registration:** `src/commands.ts` L6 `scriptsDir = path.resolve(pluginSrcDir, "..", "scripts")` embeds an absolute path; L17/L29 bake `bun run ${JSON.stringify(path.join(scriptsDir, "report.ts"))}` (absolute script path) into the command bodies; L33-34 then overwrite the project's command docs unconditionally. The package ALREADY ships portable templates (`command/telemetry-report.md`, `command/telemetry-inspect.md`) that use runtime-resolved forms (octm CLI → `bun pm ls -g` discovery → `~/.config/opencode/plugin/...` fallback) — `registerCommands()` ignores them. That shipped form is the correct committed baseline (A1b).
- **D — OpenCode config schema has NO lifecycle hooks.** No `postAttachCommand` / lifecycle / hooks keys exist in the OpenCode config schema — there is no declarative "run X after plugin load" or "on startup" mechanism to auto-restore after the plugin writes. Hence the interim guard is a manual/CLI restore + a file-watcher ignore (to avoid watcher re-triggers), not an automated post-boot hook. (Evidence: `https://opencode.ai/docs/config/` — no lifecycle keys; `https://opencode.ai/docs/plugins/`.)
- **E — Existing guard covers the commit gate, not the live tree.** `scripts/verify-pre-commit.sh` / `verify-pre-push.sh` `guard_no_home_qualt` (L44-66) blocks a literal `/home/qualt` from being committed/pushed, but the plugin's write happens in the LIVE working tree on every load — the pre-commit guard cannot prevent the pollution, only catch it at commit time. The layered interim guard adds: committed portable baseline + restore script + Makefile target + watcher.ignore + dedicated verify guard.

## Recommendations

- **R1 — interim guard (IMPLEMENTED, this lane):** commit the shipped portable octm-template form as the new baseline; `scripts/restore-telemetry-commands.sh` + `make restore-telemetry-commands`; `watcher.ignore` for the two docs; `scripts/verify-telemetry-guard.sh` + `make test-telemetry-guard` (5 automated assertions + manual restart-twice note). Layered on the existing `guard_no_home_qualt` pre-commit/pre-push guard (A4 — left UNCHANGED per design ADR: keep full-directory scan).
- **R2 — upstream patch (part 2, NOT this lane):** fork → patch `src/commands.ts` to honor the shipped `command/*.md` templates (or emit runtime-resolved `$HOME`/`~`/relative forms) and stop the unconditional `fs.writeFileSync` at module init → PR to agostinilabsrl/opencode-telemetry. Includes regression tests simulating plugin load. Traced to the res005 conspect "Recommended patch direction" and the DIA-069 ticket Fix section.
- **R3 — monitoring:** until R2 lands, treat the two command docs as transiently dirty after every OpenCode restart; run `make restore-telemetry-commands` between restart and verification, then `make test-telemetry-guard`. Re-check upstream for the merged patch on the next §10 review cycle.

## Alternatives rejected

- **Plugin removal from project config only:** insufficient — union loading (Finding B) means the global config still loads the plugin. Removing from BOTH configs would kill the telemetry tools entirely (they are used for session cost/token auditing). Rejected.
- **Permission-based deny of plugin writes:** not technically possible — the permission system does not intercept plugin-internal `fs.writeFileSync` (Finding A). Rejected.
- **Config lifecycle/postAttachCommand hook:** no such key exists in the OpenCode config schema (Finding D). Rejected.
- **Fork-only local patch vendored into the repo:** fragile, per DIA-069 ticket Fix section ("Fork — fragile; not recommended"). The upstream PR path is preferred. Rejected for part 1.

## Confidence

| Item | Confidence |
|------|------------|
| Plugin writes bypass the permission system (Finding A) | HIGH |
| Union loading across project + global config (Finding B) | HIGH |
| Root cause: absolute script path baked into command bodies (Finding C) | HIGH |
| No lifecycle/hooks keys in OpenCode config schema (Finding D) | HIGH |
| Shipped `command/*.md` templates are the intended portable baseline | HIGH |
| Interim guard restores but does NOT stop next-load re-pollution | HIGH |

## Sources

- DIA-069 ticket: `docs/dev-infra-audit/tickets/DIA-069.md`
- Upstream-fix conspect: `knowledge/res005-opencode-telemetry-upstream-fix/res005-opencode-telemetry-upstream-fix-conspect.md`
- Plugin source (vendored): `~/.cache/opencode/packages/opencode-telemetry@0.1.19/node_modules/opencode-telemetry/src/commands.ts` (L6, L17, L29, L33-34), `src/index.ts` (L7)
- Shipped portable templates: `~/.cache/opencode/packages/opencode-telemetry@0.1.19/node_modules/opencode-telemetry/command/telemetry-report.md`, `command/telemetry-inspect.md`
- Project config: `.opencode/opencode.jsonc` L344-349 (`plugin[]`, `opencode-telemetry@0.1.19` L347; watcher.ignore block added at L51-62)
- Global config: `~/.config/opencode/opencode.jsonc` L135
- Existing guard: `scripts/verify-pre-commit.sh` / `scripts/verify-pre-push.sh` L44-66 (`guard_no_home_qualt`)
- OpenCode docs (live-fetched at gate time): https://opencode.ai/docs/plugins/, https://opencode.ai/docs/permissions/, https://opencode.ai/docs/commands/, https://opencode.ai/docs/config/

## Tags

§10-gate, plugins, telemetry, DIA-069, command-docs, portability, watcher-ignore, restore-guard, upstream-patch, union-loading, opencode-config
