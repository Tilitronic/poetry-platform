# DIA-127 - OMO slim 2.2.13 update evaluation (research + safety decision)

---

id: DIA-127
title: "OMO slim 2.2.13 update evaluation - research what is new, decide safety/worth for the project"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
discovered:
source: inventory
date: 2026-08-13
created: 2026-08-13
updated: 2026-08-13

---

## Description

A new oh-my-opencode-slim version, 2.2.13, is available (developer-reported 2026-08-13). The project runs a customized OMO slim config (.opencode/oh-my-opencode-slim.jsonc) with 3 presets (opencode-go, cebula, free) and heavily customized agents (orchestrator, coder, reviewer, conspecter, etc.). Notably the conspecter permission hardening from commit 753e374 (crwl bash allow, webfetch deny, websearch MCP removed from all 3 presets) must not regress.

Before any upgrade, research what 2.2.13 contains and decide whether updating is:
(a) worth it - net benefit vs the current pinned version;
(b) safe - no regression to the customized config (agent-name lockstep contract via scripts/validate-agent-names.sh, presets, permissions, model assignments), no breaking changes to the OMO presets/agents/skills the project depends on, no OpenCode-version incompatibility;
(c) good for the project long-term - maintenance burden, stability, alignment with newest best practices.

Route per section 10 (AI Devtools Modernization Workflow): gate research by @ai-specialist (web-fresh), findings reviewed by the developer (practice-protected), design via @architector if non-trivial, implementation by @coder, validation via make test-config + restart-verify, independent review by @ai-auditor.

## Evidence (2026-08-13)

Research by the ai-specialist lane: 12 cited sources reviewed for OMO slim
2.2.13 (changelog/diff, release notes, breaking-change scan). Current pin:
2.2.8. Target: 2.2.13.

Pre-flight PASS: opencode version 1.18.18 >= required 1.18.13 (compatibility
floor for 2.2.13), so the update is compatible with the installed OpenCode.

Developer decision 2026-08-13: UPDATE NOW.

Actions taken: global pin changed to 2.2.13 (outside repo,
`~/.config/opencode/opencode.jsonc` line 148, done by lane cod-7); project
comment synced (`.opencode/opencode.jsonc` line ~135 comment bump
2.2.8 -> 2.2.13).

restart-verify PENDING (post-restart): confirm OMO 2.2.13 loaded, websearch
works for ai-specialist, conspecter bash works (DIA-126 catch-all-first fix
also requires the restart to take effect).

Rollback plan: revert global pin to 2.2.8 in
`~/.config/opencode/opencode.jsonc` line 148, then restart opencode.

ai-auditor review pending (section-10 independent review step).

## Verification

- [x] Changelog/diff for 2.2.13 vs the current pinned version collected, with source URLs cited (DONE 2026-08-13 - 12 cited sources by ai-specialist lane)
- [x] Impact analysis: what changes in agents, skills, presets, models, permissions, MCPs, plugins (DONE 2026-08-13)
- [x] Compatibility check against current .opencode/oh-my-opencode-slim.jsonc customizations (3 presets, conspecter permission changes from 753e374, agent-name lockstep S1-S4 contract via validate-agent-names.sh, make test-config exit 0) (DONE 2026-08-13 - pre-flight PASS opencode 1.18.18 >= 1.18.13, make test-config exit 0, restart-verify PASS - see Restart-verify evidence section)
- [x] Recommendation documented with rationale: update now / defer / skip (DONE 2026-08-13 - developer decision: UPDATE NOW)
- [x] If update recommended: section 10 chain executed (ai-specialist gate -> developer decision -> design -> implement -> make test-config exit 0 -> restart-verify -> ai-auditor review) (DONE 2026-08-13 - gate/decision/implement done; restart-verify PASS (evidence section); ai-auditor review APPROVE-WITH-CHANGES ses_00561027affeWdPCmgU2VBjg7O; Phase-6 registration committed; ticket stays OPEN until Step B res019 conspect persistence)
- Note (ai-auditor finding 4, accepted NOTE): no explicit runtime version fingerprint is logged at plugin load - version attribution is inferred (see Honest limitation in Restart-verify evidence). Future upgrades: log an explicit loaded-version line. No action now.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## Restart-verify evidence (2026-08-13, post-pin session)

Performed by the verification lane (docs-only ticket evidence; NO config
or code changes). Current orchestrator session launched Thu Aug 13
11:05:03 local (opencode PID 3379527), AFTER the global pin commit:
~/.config/opencode/opencode.jsonc mtime 2026-08-13 10:55:39 +0200 <
session start 11:05:02 +0200.

### (a) OMO 2.2.13 LOADED - PASS (runtime behavioral evidence, version inferred)

1. Config pin (file state):
   ~/.config/opencode/opencode.jsonc line 148 = "oh-my-opencode-slim@2.2.13"
   Project comment synced: .opencode/opencode.jsonc line 135 =
   "// The orchestrator is the plugin's real delegating agent
   (oh-my-opencode-slim@2.2.13".
2. Installed package (file state):
   ~/.cache/opencode/packages/oh-my-opencode-slim@2.2.13/node_modules/
   oh-my-opencode-slim/package.json -> "name": "oh-my-opencode-slim",
   "version": "2.2.13". (Stale 2.2.8 install dir also present in cache.)
3. Runtime evidence (session plugin log
   ~/.local/share/opencode/log/oh-my-opencode-slim.20260813T090505.log,
   first entry [2026-08-13T09:05:05.484Z] = 11:05:05 local, matches
   session start):
   - line 22: [skill-sync] Safely cleaned up staged path for
     verification-planning: .../skill-updates/2.2.8/verification-planning
   - line 23: [skill-sync] Staged new update for customized skill
     verification-planning at .../skill-updates/2.2.13/verification-planning
   - lines 24-29: same clean-2.2.8/stage-2.2.13 pattern for reflect,
     oh-my-opencode-slim, worktrees
   - line 33: [auto-update-checker] Already on latest version for
     channel: "latest"
4. Filesystem corroboration:
   ~/.config/opencode/.oh-my-opencode-slim/skill-updates/2.2.13/
   {worktrees,oh-my-opencode-slim,reflect,verification-planning} created
   2026-08-13 11:05:21 +0200 (session start). The loaded plugin staged
   its skill updates into the 2.2.13 version directory; a 2.2.8 plugin
   would stage into 2.2.8 paths.

Honest limitation: the plugin log does not print an explicit
"loaded version = 2.2.13" line. Version attribution is inferred from
(i) the pinned install dir package.json (2.2.13), (ii) runtime skill-sync
staging into 2.2.13 paths at session start, (iii) auto-update-checker
"Already on latest version". The skill-sync 2.2.13 staging is runtime
behavior of the loaded plugin, not mere file state, so this is a PASS
with a stated inference chain, not a bare config-pin claim.

### (b) ai-specialist websearch - PASS (declared available; loaded-state caveat)

1. .opencode/opencode.jsonc lines 434-445 (current on-disk state,
   post-942fcda): "ai-specialist" permission = edit: deny, bash: deny
   (flat), task: deny. No webfetch deny in this block (webfetch available
   by default; contrast ai-auditor which explicitly denies webfetch). No
   websearch deny in this block.
   - Loaded-state caveat: this session launched 11:05:02, BEFORE commit
     942fcda (11:43:04). At launch the loaded ai-specialist bash was the
     b0cf53a state: bash { "\*": "deny", "curl": "allow", "wget": "allow" }.
     The flat bash deny in the current file takes effect on the NEXT
     launch (same timing as the conspecter wildcard note in (c)).
2. OMO presets grant websearch to ai-specialist in ALL 3 presets
   (.opencode/oh-my-opencode-slim.jsonc):
   - opencode-go preset lines 100-102: "mcps": ["websearch"]
   - cebula preset lines 359-361: "mcps": ["websearch"]
   - free preset lines 539-541: "mcps": ["websearch"]
     websearch is a permission action in OMO 2.2.13 schema
     (dist/server.js line 33575: websearch: PermissionActionSchema.optional())
     and a builtin tool in opencode 1.18.18 (binary contains 220 websearch
     string refs).
3. Agent definition confirms web-fresh research lane, no RAG:
   .opencode/oh-my-opencode-slim.jsonc line 616 orchestratorPrompt =
   "@ai-specialist - Lane: Agent/skill/config research (no RAG, always
   web-fresh); read-only - findings routed via orchestrator".

Note: websearch is DENIED for the orchestrator (.opencode/opencode.jsonc
line 212 "websearch": "deny" sits inside the orchestrator block), but
NOT denied for ai-specialist.

### (c) conspecter bash - PASS (prior same-session proof cited, NOT re-run)

Not re-run per instructions (archival test already proven this session).
Proof: conspecter lane ses_0059b11dbffegxB19B4ywdBVs5, registry
.opencode/session/registry.jsonl seq 3071 session_spawn
2026-08-13T09:12:26.406Z and seq 3072 session_complete 09:30:49.882Z
(role subagent, status COMPLETE): bash tool present and executable,
crwl \* runs with args, webfetch absent+denied. Evidence dir:
knowledge/test-dia126-archival/ (.source-urls.txt 1627 bytes,
sources/.keep).

Pending: the 942fcda wildcard hardening (curl _/wget _/trafilatura
_/openspec _) was committed 11:43:04 AFTER this session launched
11:05:02, so it loads only on the NEXT opencode launch. A FULL conspecter
archival re-verify is pending next-session restart (tracked with the
DIA-126 full re-verify).

### Gates

- make test-config (host): exit 0 BEFORE this append and exit 0 AFTER
  (summary: 20 agents audited, 0 gaps, 249 warnings; docker config
  audited 0 agents, 0 gaps, 1 warning).
- ASCII-only (DIA-079): this section is ASCII-only.
- Scope: only docs/dev-infra-audit/tickets/DIA-127-...md modified; README
  ticket index untouched (evidence append, counts unchanged).
