# opencode-telemetry upstream fix (DIA-069): root cause, evidence, and recommended upstream patch

This conspect synthesizes the DIA-069 upstream-research findings about opencode-telemetry's command-template pollution (writing $HOME/absolute-path command bodies into a user's .opencode/commands/ directory) and documents an upstream fix strategy plus a local interim guard. Sources are archived under knowledge/res005-opencode-telemetry-upstream-fix/sources/ and are cited inline by filename.

MLA-style citations are provided with source keys matching the saved filenames.

## Summary

The opencode-telemetry plugin (agostinilabsrl/opencode-telemetry) programmatically registers command templates using absolute paths resolved from the plugin install location. The registration implementation bakes an absolute, host-specific path into command bodies and unconditionally writes telemetry-report.md and telemetry-inspect.md into the project's .opencode/commands/ on every plugin load. This produces persistent $HOME/absolute-path pollution and clobbers the project's command templates on each plugin activation (see telemetry-commands-source.md; opencode-telemetry-repo.md). A locally vendored copy at ~/.cache/opencode/packages/opencode-telemetry@0.1.19/node_modules/opencode-telemetry/src/ matches upstream main byte-for-byte and shows the same code.

## Key findings (synthesis)

- Root cause: src/commands.ts constructs scriptsDir with path.resolve(pluginSrcDir, "..", "scripts") and then writes command registration lines embedding path.join(scriptsDir, "report.ts") using JSON.stringify to create literal absolute path strings. It then calls fs.writeFileSync to write telemetry-report.md and telemetry-inspect.md on EVERY plugin load (telemetry-commands-source.md; opencode-telemetry-repo.md).
- Trigger site: src/index.ts calls registerCommands(import.meta.dir, ctx.directory) at module initialization, meaning the write occurs at plugin load time, not on an explicit opt-in action (opencode-telemetry-repo.md).
- Upstream state: the GitHub repository has no existing issue/PR addressing $HOME pollution; issue creation is restricted in that repository so filing an issue is not viable — remediation therefore requires a fork, patch, and PR (telemetry-issues.md; telemetry-pulls.md).
- The package already ships portable command templates (command/telemetry-report.md and command/telemetry-inspect.md) that use runtime-resolved bash expressions and tilde-style $HOME references; these template bodies are the intended portable pattern. The registerCommands() path diverges by producing absolute-entrypoint command bodies that reference scripts/report.ts (legacy entrypoint) rather than the provided templates (opencode-telemetry-repo.md; local vendored templates at ~/.cache/opencode/packages/opencode-telemetry@0.1.19/node_modules/opencode-telemetry/).

## Evidence and provenance (selected)

- opencode-telemetry-repo.md — GitHub repository snapshot (source files, README, merge history). Supports code-location claims and PR #7 appearance.
- telemetry-commands-source.md — saved capture attempt for the raw commands.ts URL; network capture produced a transparent diagnostic (see sources/telemetry-commands-source.md). However, a byte-exact vendored copy exists in ~/.cache/opencode/packages/opencode-telemetry@0.1.19/node_modules/opencode-telemetry/src/commands.ts and matches upstream main; that local copy supplied the concrete L6/L17/L29/L33-L34 line references used in this conspect (local vendored copy — primary evidence, not archived).
- telemetry-issues.md and telemetry-issues-command.md — repository issues listing and filtered search; show no open issue addressing $HOME pollution and confirm that issue creation is restricted (no matching issue found) so an upstream issue path is blocked.
- telemetry-pulls.md — pulls listing; low activity on PRs but maintainer has merged many PRs historically; PR path via fork is viable.
- opencode-plugins-docs.md and opencode-commands-docs.md — OpenCode docs describing how commands should be authored (static .md templates in .opencode/commands/ or ~/.config/opencode/commands/), and runtime template substitution expectations. These docs define the portable pattern the plugin should follow.

## Root-cause detail (line references)

- src/commands.ts L6: const scriptsDir = path.resolve(pluginSrcDir, "..", "scripts"); — resolves an absolute location based on the plugin installation path.
- src/commands.ts L17 & L29: bun run ${JSON.stringify(path.join(scriptsDir, "report.ts"))} — generates a literal command body containing an absolute path to the report script.
- src/commands.ts L33-34: unconditional fs.writeFileSync(telemetry-report.md + telemetry-inspect.md) — writes command files into the project's .opencode/commands directory on every plugin load.
- src/index.ts L7: registerCommands(import.meta.dir, ctx.directory); — invoked at plugin initialization so the write occurs implicitly when the plugin is loaded.

These exact lines appear in the vendored local copy at ~/.cache/opencode/packages/opencode-telemetry@0.1.19/node_modules/opencode-telemetry/src/{commands,index}.ts and match upstream main byte-for-byte (researcher evidence). The combination of absolute-path creation + unconditional write at load-time explains observed per-load clobbering.

## Impact & behavior

- On plugin load (including benign runtime events), two command files are created or overwritten in the project's .opencode/commands/ directory. The files contain absolute, host-specific paths which, when executed on another machine or after environment changes, will either fail or run unexpected binaries. The behavior is persistent across plugin activations and leads to user-visible corruption of project command templates.
- Because the write is unconditional and run at module init, the pollution recurs after any remove/restore unless the plugin code is patched or the plugin load suppressed.

## Upstream status and contribution path

- There is no open issue/PR addressing this bug in upstream (telemetry-issues.md; telemetry-issues-command.md). The repository restricts issue creation, so the only practical upstream remediation is:
  1. Fork agostinilabsrl/opencode-telemetry
  2. Patch src/commands.ts to avoid baking absolute paths and to prefer the shipped command/*.md templates or generate templates that use runtime-resolved shell expressions (tilde/$HOME or relative runtime lookups). Patch should also stop unconditional writes at plugin init — do not perform writes on module load; instead provide a runtime opt-in command to install templates or detect and respect existing templates.
  3. Open a PR against upstream main with explanation, test, and a reversible patch. Maintainer historically merges PRs; PR route is viable despite issue restrictions (telemetry-pulls.md).

## Recommended patch direction (DIA-069)

Primary upstream patch should implement all of the following:

1. Stop writing command files on plugin module initialization. Move any fs.writeFileSync calls behind an explicit user-invoked command (e.g., opencode plugin install/telemetry:install-commands) or a safe idempotent check that only writes when templates are missing and never overwrites existing files without a deliberate force flag.
2. When generating command registration entries, avoid path.resolve(import.meta.dir, ...) for runtime command bodies. Instead:
   - Respect and prefer the shipped command/*.md templates included in the package; if templates exist in package, register them as static templates (no absolute path embedding). OR
   - Emit command bodies that use runtime-resolved shell expressions (tilde ~, $HOME, or runtime location discovery via bun pm ls or $BUN_PM_GLOBAL_DIR) so that the command body is portable across hosts.
3. Reconcile entrypoints: either update templates to call the same entrypoint used by any generated registration code (prefer the package's CLI entrypoint, e.g., bin/cli.ts) or change registerCommands to reference the canonical entrypoint declared in package.json (not a hard-coded scripts/report.ts). This ensures that registered commands and shipped templates are coherent.
4. Add tests that simulate plugin load in a sandbox and assert that .opencode/commands/ files are not written unless explicitly requested. Add a regression test for the absolute-path generation.

Local interim guard (recommended for immediate mitigation):

- Restore the project's .opencode/commands//*.md to the $HOME-form templates shipped with the package and commit them to the repository. Because the plugin will re-pollute on load, keep the guard as a monitored short-term fix; the permanent fix requires the upstream patch described above.

## Confidence levels (per research question)

- Q1 (bug present in upstream main + local vendored copy matches): HIGH — repository snapshot and the vendored local copy match byte-for-byte; code lines enumerated above appear in the vendored files (opencode-telemetry-repo.md; local vendor copy).
- Q2 (no upstream issue/PR about pollution + issue creation restriction): HIGH — issue listing and PR listing were inspected; no matching issue found and repository settings restrict issue creation (telemetry-issues.md; telemetry-pulls.md).
- Q3 (OpenCode recommended pattern for commands): HIGH — official docs require static .md files and runtime substitution; the shipped templates follow that pattern (opencode-commands-docs.md; opencode-plugins-docs.md).
- Q4 (portable pattern already shipped in package): HIGH — command templates are present in the vendored package and are the intended portable baseline (local vendored templates; opencode-telemetry-repo.md).

## Actionable next steps (DIA-069 disposition)

1. Persist this conspect to the memory shelf (res005). (This document.)
2. Create an upstream PR: fork repository → patch src/commands.ts per Recommended patch direction → open PR. Include tests and an explanation referencing DIA-069.
3. Apply the local interim guard: restore committed .opencode/commands/*.md templates to $HOME-style bodies and monitor for re-pollution; escalate to package patch if recurring.

## Sources (archived captures)

- opencode-telemetry-repo.md
- telemetry-commands-source.md (capture diagnostic; see conspect body for note about using the local vendored copy)
- telemetry-issues.md
- telemetry-issues-command.md
- telemetry-pulls.md
- opencode-plugins-docs.md
- opencode-commands-docs.md

## Notes on local primary sources (not archived)

- Vendored copy: ~/.cache/opencode/packages/opencode-telemetry@0.1.19/node_modules/opencode-telemetry/src/{commands,index}.ts — byte-for-byte match to upstream main and the concrete evidence for line references.
- Shipped templates: ~/.cache/opencode/packages/opencode-telemetry@0.1.19/node_modules/opencode-telemetry/command/telemetry-report.md and telemetry-inspect.md — portable templates that use runtime-resolved shell expressions.

---
Conspect created: 2026-08-08
