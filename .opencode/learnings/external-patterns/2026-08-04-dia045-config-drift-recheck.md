# §10 Phase 1 GATE — DIA-045 Config Drift Recheck (2026-08-04)

> §10 Phase 1 GATE — recheck of DIA-045 backlog findings against post-ee91265 ground truth (TS2.0 commit), registration of disposition + new delta findings.

date: 2026-08-04

## Source

- ai-specialist read-only Phase 1 GATE findings (ai--1), 2026-08-04, disposition recheck of the 22 DIA-045 findings against the post-ee91265 working tree, plus new findings from the TS2.0 delta.

## Findings disposition (17 rechecked, post-ee91265 ground truth)

- **RESOLVED** — F12 boss_append.md dead historical ref (documented dead, CHANGELOG:140, no action) · F17 jsonl-stats.sh jq `-s -e` fix — CLOSED by TS2.0 commit ee91265.
- **OPEN** — F8–F11 stale "boss" aliases: coder prompts ×3 (oh-my-opencode-slim.jsonc:70,245,422 "escalate to boss"), architector orchestratorPrompt :521 ("Boss routes"), analyzer orchestratorPrompt :528 ("boss dispatches"), practice-protected.md:26 ("before the boss proceeds... The boss does not silently" ×2) → replace boss→orchestrator.
- **OPEN** — F13 ai_specialist underscore (ai-assist-sources.yaml:199, practice-protected.md:38, analyzer prompt:527 ×2, ai-specialist orchestratorPrompt:535) + F14 resource_manager (ai-assist-sources.yaml:200) → hyphenate to ai-specialist / resource-manager.
- **OPEN (low)** — F16 learnings/index.md:27,29,32-35 six historical "boss" entries → add header note "Historical entries pre-2026-08-02 use 'boss' — canonical name is now 'orchestrator'".
- **OPEN (low)** — F18 explorer agent no model (opencode.jsonc:161-163) + dual-presence in disabled_agents (oh-my-opencode-slim.jsonc:5) → remove block OR assign model.
- **OPEN** — F21 compaction.reserved 10000 (opencode.jsonc:21) → consider 16000.
- **PARTIAL** — F6 HANDOFF template heading mismatch — **NF-1 Major**: orchestrator_append.md:172 checks `## Prognosis for next cycle` but openspec/templates/HANDOFF.md uses `## Session summary`/`## Fixes applied`/`## Open tickets`/`## Verification request`/`## Resume instructions` — gate would never match; fix option (b): change the check to `## Session summary`, or (a) add wrapper heading to template.
- **PARTIAL** — F7 observer multimodal only in cebula (gemini-3.6-flash ✓); opencode-go (deepseek-v4-flash ✗) + free (big-pickle ✗) text-only; role_mapping:198 stale ("GPT-5 mini") → recommend opencode-go observer → opencode-go/kimi-k2.7-code (vision), update role_mapping to "Gemini 3.6 Flash (Copilot) — multimodal passive monitoring".
- **PARTIAL** — F22 coder prompt ~1300ch (up from ~1068ch, soft limit ~2000ch) — monitor.
- **DEFER** — F15 .mise.toml ↔ Dockerfile.dev pin sync → separate DIA ticket.
- **MONITOR** — F19 opencode/mimo-v2.5-free availability (oh-my-opencode-slim.jsonc:425), F20 github-copilot/gemini-3.1-pro-preview GA rename (:556).

## New findings from TS2.0 delta (ee91265)

- **NF-1 Major** — HANDOFF template vs gate heading mismatch (see F6): orchestrator_append.md:172 expects `## Prognosis for next cycle`; template uses `## Session summary` etc. — gate would never match.
- **NF-2 Minor** — boss_append.md dead file (24 "boss" occurrences) — not loaded, documented dead.
- **NF-3 Minor** — explorer dual-presence (opencode.jsonc:161-163 + disabled_agents) — confusing.
- **NF-4 Minor** — @ai_specialist underscore in routing prompts (orchestratorPrompt:535, analyzer:527, practice-protected:38) — dispatch may fail to match display name ai-specialist.

## Recommended fix scope (for owner Phase 2 decision)

- **Fix now** — ~15 word replacements (boss→orchestrator, underscore→hyphen) + NF-1 heading fix (option b: orchestrator_append.md:172) + F7 opencode-go observer → kimi-k2.7-code + role_mapping:198 update.
- **Convenient** — F18 explorer cleanup, F21 compaction.reserved → 16000.
- **Defer** — F15 (separate ticket), F19/F20/F22 monitor, audit gaps 1-2 (cross-ref validator, HANDOFF schema validator) future.
- **Risk** — all changes trivially revertible (git checkout); restart needed after opencode.jsonc/oh-my-opencode-slim.jsonc edits; 0 permission/plugin/agent-definition changes.

## Gaps

- 2 of the 3 original audit gaps partially addressed by TS2.0 (agent-name cross-referencing not automated).

## Outcome

- DIA-045 fix-now set **IMPLEMENTED + VERIFIED** 2026-08-04: stale "boss"→"orchestrator" aliases (F8–F11), underscore→hyphen agent names (F13/F14 + NF-4), opencode-go observer → kimi-k2.7-code multimodal + role_mapping update (F7), HANDOFF template option A restructure (NF-1). Applied via §10 lane: 12 fix-now edits + 2 anomaly fixes.
- **Verification:** ai--2 §10 Phase 5 APPROVE, cod-7 independent mechanical re-confirm, `make test-config` exit 0 (§10 audit trail rows 266–275). Uncommitted — owner commit decision pending.
- **Deferred items unchanged:** F18/F21/F15/F19/F20/F22 remain OPEN.
- **Pending:** 4 post-restart smoke items (observer dispatch kimi, HANDOFF gate on template-produced HANDOFF, @ai-specialist/@resource-manager name resolution, coder escalation "orchestrator").
