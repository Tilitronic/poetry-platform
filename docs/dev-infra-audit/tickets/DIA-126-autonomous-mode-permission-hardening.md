# DIA-126 - autonomous overnight mode: permission allow-list + no-stall guarantees

<!-- Planning ticket filed 2026-08-13 from the developer failure report reviewing
     the autonomous night run (session ses_007cb6c40ffeCeCyQZYgkl3DRy). The
     autonomous overnight session failed from the autonomy side: several times
     agents asked for folder-read permissions and work stopped for hours until a
     human answered. This is an opencode-config feature request. Planning
     ticket - no implementation performed yet.

     UPDATE 2026-08-13 (DIA-126 IMPLEMENTATION, direction (c) tool-gap
     closure): developer approved Option B (keep documented model, fix the
     gaps). CRWL REACHABILITY: conspecter bash executes on the HOST per
     DIA-067 (no bridge from host-side OpenCode into container binaries).
     Host probe: `which crwl` -> /home/qualt/.local/bin/crwl (uv tool
     crawl4ai v0.9.2); binary responds to invocation (`crwl crawl --help`
     exit 0).      Conclusion: the `crwl *` allow-list entry added to the
     conspecter permission block is sufficient; NO container change needed
     (dev-entrypoint.sh / Dockerfile.dev skipped).

     SECTION-10 COMPLETION (2026-08-13): Phase 1 gate research DONE
     (.opencode/learnings/external-patterns/2026-08-13-dia126-research-workflow-tool-gaps.md),
     Phase 2 developer decision Option B (keep documented model, fix gaps),
     Phase 3 design per research, Phase 4 implement DONE (crwl * allow,
     webfetch deny, websearch MCP removed from all 3 presets, conspecter
     tool manifest, stale doc fix), Phase 5 validate make test-config +
     make test-shell exit 0 (restart-verify pending next opencode launch),
     Phase 6 ai-auditor APPROVE-WITH-NOTES (concern resolved: cross-preset
     harmonization), Phase 7 register + commit. Status stays OPEN:
     directions (a) permission profile, (b) stall detection + auto-resume,
     (d) audit hook remain for the full autonomous-mode feature. -->

---

id: DIA-126
title: "autonomous overnight mode: permission allow-list + no-stall guarantees (agents ask for folder-read permissions and stall for hours)"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # no blockers
discovered: 2026-08-13
source: session-observation (developer failure report, 2026-08-13, night run review)
date: 2026-08-13
created: 2026-08-13
updated: 2026-08-13

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: [docs/dev-infra-audit/tickets/DIA-126-autonomous-mode-permission-hardening.md, docs/dev-infra-audit/tickets/README.md]
artifacts: []
evidence: []

---

## Description

**(a) Developer failure report (verbatim, 2026-08-13 morning, night run
review):**

> "The autonomous overnight session was a failure from the autonomy side.
> Several times agents asked for some folders reading permissions and it
> stopped work for several hours."

Observed session: ses_007cb6c40ffeCeCyQZYgkl3DRy.

**(b) The default-deny read permission model + the exact allow-list:** the
orchestrator's read permission model is default-deny with a narrow allow-list.
`read` allows only:

- `.opencode/session/*`
- `docs/dev-infra-audit/NEXT-RUN.md`
- `docs/dev-infra-audit/tickets/*`
- `docs/dev-infra-audit/tickets/archive/*`
- `.opencode/practice-protected.md`
- `AGENTS.md`

Directory listing via `read <dir>` and `glob` on non-allow-listed paths are
DENIED.

**(c) Observed stalls (from the night run):**

1. Orchestrator `glob` deny and tickets-directory listing deny on
   non-allow-listed paths.
2. The conspecter lane had NO shell/exec primitive - it could not run the
   mandated trafilatura/curl/crawl4ai CLI chain and fell back to webfetch
   (DIA-067-class tool gap).
3. Coder lanes need access to folders like `knowledge/`,
   `.opencode/learnings/`, `scripts/`, `.opencode/` that may not be on their
   permission allow-lists, causing permission asks that block work until a
   human answers.

**(d) Why this breaks autonomy:** any non-allow-listed folder read becomes an
interactive permission ask that only a human can answer. In an autonomous
overnight window no human is present, so each ask turns into a multi-hour
stall - exactly what the developer observed.

**(e) Cross-references:**

- DIA-098 "spontaneous subagent/session stops" (stalled-agent detection,
  auto-resume) - OPEN but does NOT cover the permission-ask blocking class.
- DIA-113 "agentic autonomy configuration audit" - OPEN but does NOT cover the
  permission-ask blocking class.
- DIA-080 "orchestrator frequent stops" - CLOSED, historical stops class.
- DIA-067 "docker dev-tool access gap" - tool-gap class, conspecter no-shell.

**Proposed fix directions (to be designed at fix time, NOT implemented now):**

(a) Permission profile for autonomous runs: expand the read allow-list for a
dedicated autonomous/overnight agent profile to cover the folders agents
actually need (`knowledge/`, `.opencode/learnings/`,
`.opencode/plugins/`, `scripts/`, `docs/`, `.sdd/`, `openspec/`,
`.opencode/skills/`), OR an explicit `permission` override mode that
auto-approves `ask`-level reads during autonomous windows (fail-safe:
never auto-approve writes/exec of destructive commands).
(b) Stall detection + auto-resume: fold the DIA-098 stalled-agent detection
into autonomous mode so a permission-ask stall auto-cancels/reroutes
instead of hanging.
(c) Tool-gap closure: ensure conspecter/analysis lanes have the shell tools
their workflow mandates (DIA-067 review), or document a webfetch-equivalent
path.
(d) Audit hook: log every permission-ask during autonomous windows to
registry.jsonl so stalls are visible post-hoc.

**Workflow requirements:** the fix routes through the section-10 AI-Devtools
Modernization Workflow (gate research -> developer review -> design ->
implement -> validate -> independent review -> register). DIA-063 section-10
ticket gate satisfied by this ticket.

### Evidence (2026-08-13) - restart-verify step 3 FAILED, catch-all-first fix applied

restart-verify step 3 FAILED 2026-08-13: the conspecter session exposed NO
bash tool (tool manifest had no bash despite the config grant). Evidence:
`knowledge/test-dia126-archival/.source-urls.txt` shows all 3 sources marked
NOT ARCHIVED because the conspecter had no bash tool - this is the FAIL
evidence (source-capture test output, untracked throwaway dir).

Root cause: a trailing `"*": "deny"` catch-all at the END of the bash
permission map hides the entire bash tool via the OpenCode findLast
tool-visibility gate (same mechanism as DIA-081). Even allow-listed commands
(curl, wget, trafilatura, crwl) never appear in the agent's function schema
because the catch-all is matched last and denies the whole tool.

Fix applied (DIA-036 pattern, catch-all-first): `"*": "deny"` moved to FIRST
position in the bash permission map for FOUR agents - conspecter,
openspec-plan, resource-manager, ai-specialist - so allow-list entries are
matched first and the bash tool is visible in the function schema. Applied to
`.opencode/opencode.jsonc` on branch omo-slim-changes.

Validation: `make test-config` exit 0 after the fix (config validation gate).
restart-verify PENDING: a post-restart re-run of the conspecter test archival
is required to confirm bash is exposed and the crwl/trafilatura chain works.

## Verification

> To be filled at fix time.

## Fix

> To be filled at fix time. Planning ticket - no implementation performed yet.

## Re-verify

> To be filled at re-verify time.

## Restart-verify evidence (2026-08-13, wildcard cycle) - RESULT PARTIAL

Restart-verify re-run of the conspecter test archival (conspecter test session
ses_0059b11dbffegxB19B4ywdBVs5, evidence path knowledge/test-dia126-archival/):

**RESULT PARTIAL.**

1. **Original visibility bug FIXED and PROVEN:** the conspecter session exposed
   the bash tool present and executable, and `crwl *` ran WITH arguments. The
   DIA-126 catch-all-first ordering fix works end-to-end. webfetch was never
   invoked and is explicitly denied at `.opencode/opencode.jsonc`. The runtime
   errors observed during the test run were Playwright-level, NOT
   permission-level (see DIA-129).
2. **Residual bug found:** bare allow patterns WITHOUT trailing wildcards
   (`"curl": "allow"`, `"wget": "allow"`, `"trafilatura": "allow"`,
   `"openspec": "allow"`) match ONLY the exact bare command. Every
   arg-bearing invocation (`curl -s URL`, `trafilatura -u URL`,
   `openspec propose ...`) falls through to the `"*": "deny"` catch-all and
   trips the permission gate (permission-ask storm in autonomous windows).
   FIXED via the approved section-10 wildcard change (this commit): trailing
   `*` added to the arg-bearing allows for conspecter, resource-manager and
   openspec-plan; ai-specialist bash map replaced with a flat `"bash": "deny"`
   string (its lane is read-only web research via webfetch).
3. **Separate infra gap:** crawl4ai crwl fallback fails at runtime because
   Playwright pins chromium revision 1228 while the host cache has only 1234
   (runtime error `BrowserType.launch: Executable doesn't exist at ...chromium_headless_shell-1228...`;
   crwl browser start fails with "'NoneType' object has no attribute 'browser_type'"). Tracked as DIA-129.
4. **FULL re-verify PENDING:** Phase A archival actually succeeding end-to-end
   (source capture via curl/trafilatura with arguments, crwl fallback for
   JS-heavy pages) is still PENDING next-session restart - config changes load
   only on a new opencode launch.
