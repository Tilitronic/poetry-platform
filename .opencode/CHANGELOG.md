# OpenCode Config Changelog

## 2026-08-03 — mattpocock/skills fork+adapt: 5 skills for OpenCode workflows

Change: Forked and adapted 5 skills from mattpocock/skills (MIT, 200k★) into
our workflows — domain-grilling (merged grill-with-docs+domain-modeling+grilling,
3-phase Socratic interview w/ CONTEXT.md glossary + .sdd ADR capture), to-tickets
(tracer-bullet vertical slices + blocking edges + expand-contract, published to
DIA ticket ledger), code-review-fowler (12-smell baseline for @reviewer),
resolving-merge-conflicts (never --abort discipline), diagnosing-bugs discipline
merged into debugging-workflow (global + project copies). Root CONTEXT.md created;
AGENTS.md §3/§2.3 + .sdd/README updated; DIA-037 filed for make test-skills gap.
Reason: gaps surfaced by §10 Phase 1 gate — persistent domain glossary (ana004
remediation), wide-refactor playbook, review smell descriptions, bug-diagnosis
discipline, merge-conflict process. Owner approved all 5 (row 99); design arc-1
(row 100-101); independent review approve-with-changes (row 103-104); fixes applied
(row 105).
Files: .opencode/skills/{domain-grilling,to-tickets,code-review-fowler,resolving-merge-conflicts}/SKILL.md,
CONTEXT.md, ~/.config/opencode/skills/debugging-workflow/SKILL.md,
.opencode/skills/debugging-workflow/SKILL.md, .opencode/oh-my-opencode-slim.jsonc
(12 skill-array edits across 3 presets + reviewer prompt ref), AGENTS.md, .sdd/README.md,
docs/dev-infra-audit/tickets/{_TEMPLATE.md,DIA-037.md,README.md}
Pending: owner restart OpenCode → smoke tests (skill activation ×5) → commit.

## 2026-08-03 — cebula preset rebalance: Copilot Pro utilization (observer → gemini-3.6-flash; conspecter/code-navigator/resource-manager → gpt-5-mini)
- **Change:** cebula preset rebalance — `observer` → `github-copilot/gemini-3.6-flash` (multimodal, replaces gpt-5-mini which is NOT multimodal — observer does visual/media analysis), `conspecter` → `github-copilot/gpt-5-mini`, `code-navigator` → `github-copilot/gpt-5-mini`, `resource-manager` → `github-copilot/gpt-5-mini`. All 4 moved agents keep their Go → free fallback chains (observer: kimi-k2.7-code → big-pickle; conspecter/code-navigator/resource-manager: deepseek-v4-flash ×2). dcp.jsonc: `github-copilot/gemini-3.6-flash` added to both `modelMaxLimits` ("50%") and `modelMinLimits` ("25%"), mirroring the `github-copilot/gemini-3.1-pro-preview` entry.
- **Reason:** shift subscription quota drain from OpenCode Go ($60/mo cap) toward Copilot Pro (1,500 credits/$15) targeting ~70% Copilot utilization; per §10 GATE research 2026-08-03.
- **Files:** `.opencode/oh-my-opencode-slim.jsonc` (cebula preset models), `.opencode/dcp.jsonc` (max/min limits), `.opencode/learnings/external-patterns/2026-08-03-cebula-copilot-rebalance.md`
- Pending user: restart OpenCode + monitor Copilot utilization via `token_stats` (2-week plan in learnings entry; flip conspecter back to Go if Copilot >80% by mid-month).

## 2026-08-03 — Split ai-specialist into resource-manager + ai-specialist (DIA-007)
- **Change:** split ai-specialist into `resource-manager` (NEW artifact-producer curation agent: model opencode-go/deepseek-v4-flash, edit scoped to `.opencode/oh-my-opencode-slim/knowledge/*` only, bash curl/wget/trafilatura, task: allow → @researcher/@conspecter, mcps [websearch]; owns ai-assist-sources.yaml curation, Tier-1 caching, Tier-2 re-fetch, awesome-opencode star-count eval) + `ai-specialist` (RETAINED name/roles: pure-analyst qwen3.7-plus, §10 gate + independent review + telemetry receiver; prompt + step-10 source-referral; orchestratorPrompt trimmed to ~2-line routing summary)
- **Reason:** owner approved full split (Alternative D) 2026-08-03 — all 6 design decision points approved; fixes pre-existing stale WINDOWS paths in ai-assist-sources.yaml (6 paths → Linux)
- **Files:** the 11-file change set (opencode.jsonc, oh-my-opencode-slim.jsonc, practice-protected.md, global AGENTS.md naming row, orchestrator_append.md, boss_append.md, onboarding.md, NEXT-RUN.md, ai-assist-sources.yaml, opencode-best-practices.md, DIA-007.md)
- Pending user: restart OpenCode + functional smoke test, then commit.

## 2026-08-02 — Orchestrator operating model: read-restriction + session continuity + NEXT-RUN manual
- **Permission change (DIA-036):** `.opencode/opencode.jsonc` orchestrator permission block rewritten — BEFORE: flat `read/glob/grep: allow` + `write: deny` + `edit/apply_patch/ast_grep_replace/bash/webfetch/envsitter*: deny`; AFTER: `read` path-scoped to `.opencode/session/*`, `docs/dev-infra-audit/NEXT-RUN.md`, `AGENTS.md`, `.opencode/practice-protected.md` (everything else denied), `edit` path-scoped to `.opencode/session/*` (covers write+apply_patch per OpenCode docs — flat `write` key removed), `glob` path-scoped to `.opencode/session/*`, `grep` denied. Orchestration tools unchanged: task/cancel_task/list/lsp/question/wait_for_user/todowrite/skill/websearch allow. No other agent block touched.
- **Session continuity protocol:** orchestrator appends one row to `.opencode/session/messages.md` after EVERY delegation result and user decision (`# | timestamp | from | to | lane/ticket | result | next-action`); writes `.opencode/session/HANDOFF.md` on self-rerun.
- **Self-rerun at >= 50% context:** orchestrator detects via `token_stats`, computes (input+output)/model_context_window (lookup table: qwen3.7-max 1M, qwen3.7-plus 131K, deepseek-v4-flash 64K, big-pickle 200K, else 131K), writes HANDOFF.md + final log row, then tells the user to start a fresh session.
- **`docs/dev-infra-audit/NEXT-RUN.md`:** new operating manual — boot sequence (HANDOFF → messages.md → NEXT-RUN → practice-protected), orchestrator operating rules (read/write restrictions, messages-log discipline, self-rerun, delegation map, strict workflow), audit rerun flow (7 gates in order), open tickets to close (DIA-003/006/007/030/034 with dispositions), clean-cycle definition, session continuity.
- **OMO prompt additions:** `oh-my-opencode-slim.jsonc` — all 3 presets (opencode-go, cebula, free) orchestrator blocks got a compact "Orchestrator Operating Rules" `prompt` (same text each): delegation-only + forbidden repo reads (path-scoped permission), messages.md after every delegation, self-rerun handoff at >=50%, strict workflow adherence (interview gate, §10, review gates).
- **Gitignore:** `.opencode/session/` added — transient orchestrator session state is never committed.
- Validation: `make test-config` PASS (4/4 JSONC). `git check-ignore .opencode/session/messages.md` → ignored. Diff confirms only the orchestrator permission block changed in opencode.jsonc.
- **Follow-up (same day):** reordered the three path-scoped orchestrator permission objects (`read`/`edit`/`glob`) so the catch-all `"*": "deny"` rule comes FIRST and specific `allow` paths follow — per OpenCode permission docs, "last matching rule wins" and the common pattern puts `"*"` first; valid under both order-based and specificity-based matcher semantics. No allow/deny values lost or added.
- Pending user: restart OpenCode + functional smoke tests (orchestrator must delegate, read-restriction enforced, messages.md logging works).

## 2026-08-02 — Dev-infra config audit fixes (DIA-001/003/016/017/019/020, F3 lane)
- DIA-001 (Minor): `opencode.jsonc` `references.shelf.path` `".opencode"` → `".opencode/memory-shelf.yaml"` — the shelf key pointed at a directory instead of the actual shelf index file (the description already named memory-shelf.yaml as the entry point).
- DIA-019 (Major): `skills/book-rag/SKILL.md` (8 refs) + `commands/rag.md` — replaced `~/.config/opencode/scripts/query_rag.py` with `.opencode/scripts/query_rag.py` (repo-relative). The repo's canonical script lives at `.opencode/scripts/query_rag.py`; `~/.config/opencode/scripts/` is a machine-local copy and must not be referenced from the repo. Verified `grep -rn "~/.config/opencode/scripts" .opencode/` → clean.
- DIA-017 (Minor): `oh-my-opencode-slim.jsonc` ai-specialist prompt — knowledge-source path `~/.config/opencode/oh-my-opencode-slim/knowledge/ai-assist-sources.yaml` → `.opencode/oh-my-opencode-slim/knowledge/ai-assist-sources.yaml` (the global path does not exist; the project file does — verified).
- DIA-020 (Minor, global OUTSIDE repo): `~/.config/opencode/oh-my-opencode-slim.jsonc` — added `"!openspec-propose"` to orchestrator `skills` in all 3 presets (`opencode-go`, `cebula`, `free`) so global matches project `["*", "!openspec-propose"]`. Backup: `~/.config/opencode/oh-my-opencode-slim.jsonc.bak-20260802`. No other global keys touched.
- DIA-003 (evaluate → DEFER): skills-lock.json pinning of the 15 project skills — NOT done. Evidence: (1) lock format is remote-github-skill only (`source`/`sourceType: "github"`/`skillPath`/`computedHash`) — local `.opencode/skills/*` don't fit; (2) zero consumers in the vendored fork (`rg skills-lock` in fork source/docs → nothing; fork is REFERENCE-ONLY per REFERENCE-ONLY.md, not the running npm 2.2.8 plugin); (3) local skills are already pinned by git. Ticket stays OPEN for the reconcile lane.
- DIA-016 (evaluate → intentional): global `~/.config/opencode/dcp.jsonc` left as the sparse `maxContextLimit: "50%"` fallback; project `.opencode/dcp.jsonc` (14 models, max/min limits) is project-scoped and takes precedence inside this repo. Evidence: global file is a generic default for all projects; the 14 model IDs are this repo's lineup; aligning global would leak repo-specific tuning into the user's machine-wide config. Divergence documented, no change.
- Validation: `make test-config` PASS (4/4 JSONC). `pytest .opencode/scripts/test_query_rag.py .opencode/scripts/test_query_web.py` in dev container (`uv run --with pytest`): 68 passed, 3 failed — the 3 failures (`test_unknown_hashtag`, `test_hashtag_with_digits`, `test_hashtag_with_underscore`) are pre-existing hashtag fuzzy-match bugs in untouched `query_rag.py`, reproduced identically at baseline 6ba7200; out of scope for this config lane.
- Pending user: restart OpenCode — config changes take effect on next start (DIA-001/017/019/020 are loaded at startup).

## 2026-08-02 — Fix context7 remote MCP registration
- Change: Fix context7 remote MCP registration (canonical Authorization Bearer header, oauth:false, timeout 15000) in .opencode/opencode.jsonc and tools/opencode-docker/config/opencode.json.
- Reason: Context7 MCP tools (resolve-library-id / query-docs) not exposed: non-canonical auth header + OAuth auto-detect interference + tight 5s timeout; per ai-specialist research of upstash/context7 server source.

## 2026-08-02 — Config audit fixes (P1–P9 + N1–N5)
- P1: `.opencode/tui.json` plugin key dropped (dead `file:///workspace/` Docker path + unpinned `dcp@latest`) → `{}`; plugin ownership is `opencode.jsonc`.
- P5: removed dead `github:raisbecka/opencode-subagent-output` from project plugin array (repo has no `package.json`; never loaded; global uses local `~/.config/opencode/plugins/subagent-reporter.ts`).
- P4/N6: removed `agent.orchestrator.model` from `opencode.jsonc` — a user-agent model string overrides the preset array and disables its fallback chain (verified dist:40228-40241); OMO cebula preset owns model routing.
- P7: council block indentation fixed (cosmetic).
- P3: project `disabled_agents` `[]` → `["oracle","fixer","explorer","librarian"]` — project `[]` was overriding the global disable list (deepMerge replaces arrays), re-enabling native agents contrary to AGENTS.md §9. Now aligned.
- P6: `dcp.jsonc` pruned 6 stale model entries (`github-models/*` ×3, `github-copilot/gemini-3-flash-preview`, `opencode-go/deepseek-v4-pro`, `opencode-go/kimi-k2.6`) from both max/min limits; 14 valid entries kept.
- N4: `validate-opencode-config.sh` now covers `opencode.jsonc` + `oh-my-opencode-slim.jsonc` + `dcp.jsonc` + `tui.json`.
- P8: `.opencode/oh-my-opencode-slim/REFERENCE-ONLY.md` — vendored fork checkout documented as reference-only (not the running plugin; npm 2.2.8 is live).
- P9: `.env.example` got `CONTEXT7_API_KEY=` placeholder (real key goes in `.env` — user step).
- N1–N3 (global `~/.config/opencode/`): `cebula.designer` model fixed (invalid `github-copilot/gemini-3-flash-preview` → `[claude-sonnet-4.5, kimi-k2.7-code, big-pickle]`); council `github-models` seats (`gemini-3-flash`, `gemini-2.5-pro`) consolidated into one `github-copilot/gemini-3.1-pro-preview` seat (5→4); `github-models` provider block removed from global `opencode.jsonc` (auth-broken).
- Review: independent @ai-specialist review PASS (14/14, no scope creep, no dangling references). Validation: `validate-opencode-config.sh` exit 0 on all 4 files; `opencode models` cross-check (residual: `opencode/deepseek-v4-flash` not in model list — pre-existing, kept).
- Pending user: add `CONTEXT7_API_KEY` to `.env`; restart OpenCode.

## 2026-08-02 — Boss delegation enforcement: orchestrator-first default (Phase 2)
- **Root cause:** `default_agent: "boss"` resolved to a bare config agent (model+color only, no prompt, no permission restrictions) while the plugin's real delegating agent is registered as `orchestrator`. The npm 2.2.8 config hook only overrides `default_agent` when unset/subagent, so `boss` (truthy primary) won — sessions ran a plain coder that did engineering work itself → context overflow + session restarts.
- Changed `default_agent` → `"orchestrator"` so sessions start in the plugin's delegating agent.
- Replaced bare `agent.boss` block with `agent.orchestrator` (model `opencode-go/deepseek-v4-flash`, color `#6366F1`) with mechanical enforcement: `edit/write/apply_patch/ast_grep_replace/bash` deny + `envsitter_set/add/delete/unset/annotate/format/reorder/copy` deny + `webfetch` deny (save_binary disk-write risk). Orchestration tools remain allow: `task/cancel_task/read/glob/grep/list/lsp/question/wait_for_user/todowrite/skill/websearch`.
- Created `.opencode/oh-my-opencode-slim/orchestrator_append.md` — the strict delegation workflow loaded by 2.2.8 (`loadAgentPrompt("orchestrator", ...)` → `orchestrator_append.md`): HARD RULE no-self-engineering, Interview-First Gate (@openspec-plan → spec → vertical slices → @coder), Fast-Path Opt-In, Context Budgets, Change Routing, **new Verification Discipline** (orchestrator never runs verification — it reviews results from specialists, communicates to user, or restarts cycle for rework/bugfix), Mandatory Final Step via @memory-manager.
- `boss_append.md` kept in place as dead historical reference (2.2.8 never loads it); `orchestrator_append.md` is the live prompt file.
- Independent review (ai-specialist): initial BLOCKER was a false positive (reviewer cited fork source `index.ts:495`; running 2.2.8 uses `loadAgentPrompt("orchestrator")` — verified in dist). Valid findings applied: envsitter + webfetch denies.
- Validation: `validate-opencode-config.sh` OK; jsonc parses; append file verified.
- Pending: restart OpenCode + functional smoke test (boss must delegate, never edit).

## 2026-08-02 — Copilot model cleanup in cebula preset (Phase 1)
- Fixed `designer`: replaced invalid `github-copilot/gemini-3-flash-preview` (not in OpenCode model list — silently fell through to Go kimi) with `github-copilot/claude-sonnet-4.5` (GA, 6x, vision). Chain now: claude-sonnet-4.5 → kimi-k2.7-code → big-pickle.
- Rebuilt `council` balanced lineup: gemini-3.1-pro-preview (6x) + gpt-5.3-codex (6x) + claude-sonnet-4.5 (6x) + deepseek + qwen (Go) = ~18 premium/run.
- Deleted dead `github-models` provider block from `opencode.jsonc` (auth-broken) + both `github-models/*` council seats (gemini-3-flash, gemini-2.5-pro).
- `memory-manager` kept on `github-copilot/gpt-5-mini` (already optimal: cheapest premium @ 0.33x).
- Verified via `opencode models`: all referenced models exist; `make test-config` passes.

## 2026-08-02 — Interview-first spec-authoring enforcement (Phase 1)
- Rewrote `skills/openspec-propose` + `/opsx-propose`, `/opsx-new`, `/opsx-continue`, `/tdd-cycle` to interview-first: mandatory Socratic interview via @openspec-plan, artifact synthesis from interview transcript only, `openspec validate` before apply. Removed one-shot "generate all artifacts / keep momentum" behavior.
- Boss skills denylist in all 3 OMO presets: `["*"]` → `["*", "!openspec-propose"]`.
- Added Fast-Path Opt-In gate (explicit "fast-path approved" + eligibility checklist + audit trail; NEVER auto-classify) and Interactive Review Gate row to `boss_append.md`.
- Extended `@openspec-plan` orchestratorPrompt with deep interview protocol (Full/Compressed/Skip depth modes, silent context scan, one-question-at-a-time with recommended answers, Q1–Q11 incl. numerical-invariants battery, transcript-only synthesis).
- Added Review Disposition zone + Artifact Ownership Tracking to `practice-protected.md`.
- Added `scripts/test-interview-enforcement.sh` (5 checks) + registered in Makefile test targets (script path: `scripts/test-interview-enforcement.sh`).
- Decision: Option C — no forks, plugins auto-update (npm oh-my-opencode-slim@2.2.8 unchanged). Phase 2 (compiled boss gate) deferred.
