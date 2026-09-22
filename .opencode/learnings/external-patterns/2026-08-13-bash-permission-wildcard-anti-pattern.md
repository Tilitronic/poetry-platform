# OpenCode bash allow-pattern anti-pattern: bare tool names without trailing wildcard block all arg-bearing invocations (2026-08-13)

- **Date:** 2026-08-13
- **Source:** DIA-126 restart-verify partial (conspecter test session ses_0059b11dbffegxB19B4ywdBVs5) - glob-matching proof; section-10 Phase 1 gate research for the follow-up fix ran in the ai-specialist lane (session ses_0058960eaffe9NLUJ8fPvcr6Bs, read-only web research via webfetch).
- **Status:** IMPLEMENTED - wildcard fix committed 2026-08-13 on branch omo-slim-changes; validated with make test-config exit 0; full re-verify pending next-session restart.
- **Ticket:** DIA-126 (OPEN) - "autonomous overnight mode: permission allow-list + no-stall guarantees".
- **Outcome:** implemented 2026-08-13 via section-10 workflow; validated with make test-config; full re-verify pending next-session restart.

## Finding (OpenCode permission glob semantics)

- **OpenCode glob-matches the FULL command string:** permission patterns are matched against the entire command as the agent would run it (e.g. `curl -s https://example.com`), not against a bare tool-name token.
- **Last matching rule wins:** when multiple patterns in the merged ruleset match, the last matching rule decides the action (same semantics as the DIA-081 visibleTools findLast gate and the DIA-096 specific-pattern / last-match merge rule).
- **A bare tool-name pattern matches ONLY the exact bare command:** `"curl": "allow"` matches the literal command `curl` (no arguments) and nothing else. This produces TWO DISTINCT failure modes, not one:
  - **(a) tool-invisibility:** a catch-all `"*": "deny"` placed LAST hides the entire bash tool from the agent's function schema (OpenCode findLast tool-visibility gate) - the DIA-126 ordering bug, fixed by the catch-all-first reorder in 2faae73.
  - **(b) command-level deny:** a bare pattern without trailing wildcard (e.g. `"curl"`) matches only the exact bare command, so every arg-bearing invocation (`curl -s URL`, `trafilatura -u URL`, `openspec propose ...`) is denied by the catch-all while the tool REMAINS VISIBLE - this produced the permission-ask storm in autonomous windows (exactly the DIA-126 stall class), fixed by the wildcard change in 942fcda.
- **The fix is a trailing wildcard:** `"curl *": "allow"` matches any invocation that starts with `curl` followed by at least one argument. The bare `curl` command itself is rare in practice; the `*` form is the correct allow granularity for arg-bearing CLI tools.
- **Accepted residual (finding 7, developer disposition 2026-08-13):** `curl *` / `wget *` are least-privilege by binary prefix but operationally broad - any command beginning with those binaries is allowed. Accepted as-is per developer disposition 2026-08-13; dangerous shell-composition forms (e.g. `curl | sh`) could be denied explicitly with more specific patterns if ever observed.

## Affected agents (fixed 2026-08-13)

- **conspecter** - bash map: `"curl"` -> `"curl *"`, `"wget"` -> `"wget *"`, `"trafilatura"` -> `"trafilatura *"`; `"crwl *": "allow"` already carried the wildcard and stays as-is. `"*": "deny"` stays FIRST (DIA-126 catch-all-first ordering preserved).
- **resource-manager** - bash map: same three wildcard changes (`curl *`, `wget *`, `trafilatura *`); `"*": "deny"` stays first.
- **openspec-plan** - bash map: `"openspec": "allow"` -> `"openspec *": "allow"`; `"*": "deny"` stays first.
- **ai-specialist** - the entire bash permission OBJECT replaced with a flat `"bash": "deny"` string (matching the existing flat-deny style of orchestrator/architector/reviewer/researcher/ai-auditor). Its lane is read-only web research via webfetch; bash is fully denied so the tool never prompts. The bash tool does NOT stay at default ask mode.

## Pattern (minimal-diff principle)

- **Change only what the evidence demands:** the DIA-126 partial result isolated exactly two residual issues - (1) bare allow patterns without trailing wildcards, (2) crawl4ai Playwright chromium revision skew (tracked separately as DIA-129). The fix touched ONLY the four bash maps above; coder/coder-escalated snip denies, council, the global config at ~/.config/opencode/opencode.jsonc, and all other agents were untouched.
- **Preserve the catch-all-first ordering:** moving `"*": "deny"` to the first position was the DIA-126 fix that made the bash tool visible in the function schema (findLast gate). The wildcard fix must NOT re-order the maps; the tool allows stay LAST, after the catch-all.
- **Flat deny beats an allow-list for read-only lanes:** ai-specialist has no legitimate bash need; an allow-list (even empty) keeps bash at default-ask and invites permission prompts. A flat `"bash": "deny"` removes the tool entirely - the same treatment other pure-analyst lanes already use.
- **Every config change needs a restart-verify:** OpenCode loads config at launch; the wildcard fix is validated by make test-config but only PROVEN by a post-restart conspecter archival re-run (DIA-126 FULL re-verify pending).

## Source references

- Section-10 Phase 1 gate research (ai-specialist lane, session ses_0058960eaffe9NLUJ8fPvcr6Bs): OpenCode permissions docs (opencode.ai/docs/permissions) - glob matching semantics.
- DIA-126 verification (conspecter test session ses_0059b11dbffegxB19B4ywdBVs5): bash tool present and executable, `crwl *` runs with arguments, webfetch never invoked and explicitly denied; runtime errors were Playwright-level, not permission-level.
- Local .opencode/opencode.jsonc before/after diff (branch omo-slim-changes).

## Outcome

- Commit (config): "fix(opencode-config): DIA-126 wildcard fix - trailing * for arg-bearing bash allows (conspecter, resource-manager, openspec-plan); ai-specialist bash flat-deny".
- Commit (docs): "docs(tickets): DIA-129 crawl4ai Playwright revision skew + DIA-126 verification evidence + bash wildcard learnings".
- make test-config exit 0; pre-commit hooks (prettier, eslint, tsc) passed; global config UNCHANGED; no push performed.
- Full re-verify pending next-session restart: post-restart conspecter archival re-run must confirm curl/wget/trafilatura/openspec arg-bearing invocations pass the permission gate with no asks.

## Reusable lesson

Bare tool-name allow patterns (`"curl": "allow"`) match ONLY the argument-less command. Any arg-bearing CLI tool that must be allow-listed needs the trailing wildcard form (`"curl *": "allow"`), or every real invocation falls to the catch-all deny and the lane gets a permission-ask storm. When adding a bash allow-list entry for a CLI tool, always ask: "does the lane ever call it with arguments?" - if yes, use the `*` form.

## Tags

DIA-126, opencode-config, permissions, glob-matching, wildcard, bash-allowlist, conspecter, resource-manager, openspec-plan, ai-specialist, permission-ask, S10
