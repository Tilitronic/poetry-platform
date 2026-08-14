# DIA-127 - OMO slim 2.2.13 update evaluation (research + safety decision)

<!-- UPDATE 2026-08-14 (REOPENED): developer reported the OMO slim right panel
     still shows v2.2.8 on 2026-08-14 despite the 2026-08-13 CLOSED + restart-verify
     PASS. Root cause found by the plan lane (read-only forensics): the GLOBAL
     ~/.config/opencode/tui.json still carries a BARE plugin entry
     "oh-my-opencode-slim" (no version) which resolves to the stale npm @latest
     cache install at 2.2.8 - the panel renders meta.version of that loaded
     instance. Secondary: the project .opencode/opencode.jsonc plugin array still
     declares a dead "file:///workspace/.opencode/oh-my-opencode-slim" entry
     (/workspace does not exist on the host; the directory is not a loadable
     plugin - no package.json/dist). The 2026-08-13 restart-verify was inference-
     based (pin + skill-sync staging) and missed both. The directory
     .opencode/oh-my-opencode-slim/ itself is NOT dead: it is the live OMO prompt
     override directory (npm 2.2.13 PROMPTS_DIR_NAME = "oh-my-opencode-slim",
     dist/index.js line 18885) - orchestrator_append.md, reviewer.md, coder.md,
     coder_append.md, analyzer_append.md, knowledge/* are loaded at runtime by the
     npm plugin. Ticket flipped CLOSED -> OPEN for the incomplete rollout. Fix
     plan: remove bare tui.json entry + dead file:// entry + stale cache dirs +
     docs sync; keep the prompt directory. -->

<!-- UPDATE 2026-08-13 (Step B done + CLOSED): res019-omo-slim-version-gate
     conspect persisted (10 archived sources, 2 documented NOT-ARCHIVED npmjs
     SPA pages per DIA-072), memory-shelf registration added, DIA-126 re-verify
     PASS achieved concurrently. Ticket flipped to CLOSED - the version-gate
     evaluation is complete (update decision: 2.2.13, implemented + verified). -->

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
updated: 2026-08-14

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

## Step B completion (2026-08-13) - res019 conspect persistence

Step B (research conspect persistence) DONE - closes the pending item that
kept this ticket OPEN after the phase-6 registration (the ai-auditor
approve-with-changes commit referenced "ticket stays OPEN until Step B res019
conspect persistence").

- **Conspect created:** knowledge/res019-omo-slim-version-gate/
  res019-omo-slim-version-gate-conspect.md (20,491 bytes, ~2700 words,
  10 MLA-cited archived sources).
- **Source provisioning:** 12 source URLs provisioned (10 external cited by
  the ai-specialist lane + 2 supplementary fetched); 10 archived
  (trafilatura/curl), 2 NOT ARCHIVED (npmjs SPA pages, 42B shell; DIA-072
  exclusions documented in conspect section 8).
- **Memory shelf registration:** .opencode/memory-shelf.yaml shelf.conspects
  entry res019 added (matches res018 format).
- **DIA-126 re-verify PASS achieved concurrently:** the res019 Phase A
  archival doubled as the DIA-126 full re-verify on the post-restart opencode
  process (see the DIA-126 ticket "Full re-verify (2026-08-13, post-restart
  process) - RESULT PASS" section).
- **Finding 5 reconciliation:** this Step B completes the pending item;
  ticket flipped to CLOSED 2026-08-13.

## Reopened 2026-08-14 - panel still shows v2.2.8 (incomplete rollout)

Developer-reported: the OMO slim right panel shows v2.2.8 despite the CLOSED
ticket. Read-only forensics by the plan lane established the root cause:

### Evidence

1. **Global `~/.config/opencode/tui.json`** contains a BARE plugin entry
   `"plugin": ["oh-my-opencode-slim"]` (no version). OpenCode 1.18.18 reads
   tui.json (binary embeds the legacy TUI plugin host; verified `tui.json`
   path resolution in the opencode binary strings). A bare name resolves to
   npm `latest` -> the STALE cache install
   `~/.cache/opencode/packages/oh-my-opencode-slim@latest/` whose package.json
   still says `"version": "2.2.8"` (installed 2026-07-26, never refreshed).
2. **Panel version source:** npm 2.2.13 dist/tui.js line 1906
   `const version = meta.version ?? await readPackageVersion() ?? "dev"` - the
   panel renders the version of the LOADED plugin instance. The tui.json bare
   entry loads a 2.2.8 instance whose package.json -> panel shows v2.2.8.
3. **Triple plugin load per opencode process confirmed:** process boot produced
   three distinct plugin logs (e.g. 20260814T071515/071520/071522.log): one
   v1-style init (071515, no `[v2]` prefix, tracks sessions incl.
   ses_000df36d0ffeg0yYnB8oimq3BY) + two v2-style (071520/071522, identical
   code, differ only in instanceId). 2.2.8 has NO dist/v2/ (verified), so the
   v1-style log is the tui.json 2.2.8 instance and the v2 logs are the
   opencode.jsonc @2.2.13 instance(s).
4. **Secondary dead entry:** project `.opencode/opencode.jsonc` line 570
   `"file:///workspace/.opencode/oh-my-opencode-slim"` - `/workspace` does not
   exist on the host (Docker-only path); the directory has no package.json/dist
   so it cannot load as a plugin. No plugin-load error is logged today (silently
   skipped/ignored), but the entry is dead config and must go.
5. **The fork directory is LIVE, not dead:** npm 2.2.13
   `PROMPTS_DIR_NAME = "oh-my-opencode-slim"` (dist/index.js line 18885);
   `loadAgentPrompt` (line 19154) reads `${agentName}.md` and
   `${agentName}_append.md` from `.opencode/oh-my-opencode-slim/` (project) and
   `~/.config/opencode/oh-my-opencode-slim/` (global). LIVE files in the
   project dir: `orchestrator_append.md` (18KB, mtime 2026-08-14 09:03),
   `reviewer.md`, `coder.md`, `coder_append.md`, `analyzer_append.md`,
   `knowledge/{ai-assist-sources.yaml,opencode-best-practices.md}`. Deleting
   the directory would break `make test-config` (validate-reviewer-sections.sh
   exit 2) and `make test-interview` (test-interview-enforcement.sh) and strip
   the live agent prompts. REFERENCE-ONLY.md claim "NOT loaded at runtime"
   applies only to the fork SOURCE (src/), not to the prompt files.
6. **DIA-127 restart-verify gap:** the 2026-08-13 PASS was inference-based
   (config pin + skill-sync staging into 2.2.13 paths) and never checked the
   runtime-loaded instance version nor the tui.json plugin key. The panel is
   direct runtime evidence that was missed. Lesson: future upgrade verification
   MUST check `tui.json` plugin keys and the actually-loaded instance, not only
   the opencode.jsonc pin.

### Fix plan (section-10 chain, approved)

1. Remove the bare `"oh-my-opencode-slim"` entry from global
   `~/.config/opencode/tui.json` (plugin array -> empty; the panel is provided
   by the opencode.jsonc `@2.2.13` entry, so the TUI panel survives).
2. Remove the dead `"file:///workspace/.opencode/oh-my-opencode-slim"` entry
   from project `.opencode/opencode.jsonc` plugin array (line 570).
3. Purge stale cache installs: `oh-my-opencode-slim@2.2.8`, `@latest`, and the
   bare `oh-my-opencode-slim` dir (prevents accidental re-resolution to 2.2.8).
4. Docs sync: `docs/dev-infra-audit/inventory.md` lines 60-61 (2.2.8 -> 2.2.13),
   `REFERENCE-ONLY.md` (correct the "NOT loaded at runtime" wording to note the
   dir doubles as the live prompt override dir), this UPDATE block,
   `.opencode/CHANGELOG.md`.
5. KEEP `.opencode/oh-my-opencode-slim/` (live prompt dir), `.opencode/
oh-my-opencode-slim.jsonc` (OMO config), global pin `@2.2.13`.

### Success criteria

- [ ] OMO panel shows v2.2.13 after restart
- [ ] `make test-config` exit 0, `make test-interview` PASS
- [ ] One OMO plugin log per process (currently 3)
- [ ] DIA-127 re-verified and flipped back to CLOSED
