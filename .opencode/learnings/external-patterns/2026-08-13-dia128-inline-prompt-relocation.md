# DIA-128: OMO inline-prompt relocation - dual-runtime precedence split (2026-08-13)

- **Date:** 2026-08-13
- **Source:** DIA-128 bug fix - developer screenshot -> observer analysis -> section-10 gate -> coder fix (commit 15f68a4) -> ai-auditor APPROVE with 1 Suggestion (dual-runtime precedence ambiguity, ACCEPTED -> regression note). Registered per AGENTS.md section 10 Phase 6.
- **Status:** APPLIED - fix IMPLEMENTED (commit 15f68a4) + validated (make test-config exit 0); ai-auditor APPROVE with 1 Suggestion (accepted); restart-verify PENDING next opencode launch.
- **Ticket:** DIA-128 (OPEN) - "OMO plugin repeatedly warns 'inline prompt overrides prompt file' for coder and analyzer agents" (docs/dev-infra-audit/tickets/DIA-128-omo-inline-prompt-overrides-warning.md).

## Finding: OMO 2.2.13 inline-wins vs local-source file-wins semantic split

- OMO 2.2.13 npm dist (dist/index.js:19282): `const effectiveBase = inlinePrompt ?? filePrompt ?? fallback;` - INLINE prompt wins over the prompt file when both are present.
- Warning condition (dist/index.js:19280): emitted when `inlinePrompt !== undefined && filePrompt !== undefined` - "inline prompt overrides prompt file (<agent>.md). Remove the inline prompt to use the file."
- The project's LOCAL vendored plugin (wired at `.opencode/opencode.jsonc` line 541 as `file:///workspace/.opencode/oh-my-opencode-slim`) has FILE-wins semantics (docs/project-local-customization.md: `effectiveBase = filePrompt ?? base`) - a fork divergence from the published npm build.
- Practical consequence: a config change verified under ONE runtime is NOT behavior-equivalent under the OTHER. This dual-runtime split is a project-specific invariant that must be re-verified on every OMO upgrade (regression note added to coder.md + analyzer_append.md, 2026-08-13).

## Loader search order (prompt files)

1. Project preset directory: `<project>/.opencode/oh-my-opencode-slim/<preset>/<agent>.md`
2. Project root directory: `<project>/.opencode/oh-my-opencode-slim/<agent>.md`
3. User preset directory (global): `<user-config-dir>/oh-my-opencode-slim/<preset>/<agent>.md`
4. User root directory (global): `<user-config-dir>/oh-my-opencode-slim/<agent>.md`

Project-level files resolve at step 2 for BOTH runtimes, which is what makes the relocation fix runtime-agnostic.

## Fix pattern: relocate inline content to project-level prompt files BEFORE deleting inline keys

1. Identify agents with the inline-override warning (inline prompt AND resolvable prompt file both present).
2. Move the inline prompt content into a project-level prompt file: `<agent>.md` for a full replacement, `<agent>_append.md` for append-only sections.
3. Only THEN delete the inline `prompt` keys (preset blocks + root agents blocks) from oh-my-opencode-slim.jsonc. Deleting first would leave the agent with no prompt until the next reload; keeping both would keep the warning.
4. Verify with make test-config (exit 0) and confirm the warning no longer fires at next launch (restart-verify step).
5. Document the dual-runtime precedence split as a regression note on the prompt files so future upgrades re-verify inline-vs-file semantics before re-adding inline prompts.

Applied to coder (3 preset blocks) and analyzer (1 root block) in commit 15f68a4.

## Outcome field

- Verified 2026-08-13: fix IMPLEMENTED (commit 15f68a4), make test-config exit 0, ai-auditor APPROVE with 1 Suggestion (accepted, applied as the regression note). Restart-verify PENDING next opencode launch - confirm zero inline-override warnings + relocated prompts active; if regression found, update this entry to 'regressed'.

## Tags

DIA-128, omo-slim, inline-prompt, prompt-file, precedence, dual-runtime, section-10, ai-auditor, restart-verify
