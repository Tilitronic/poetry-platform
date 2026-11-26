# §10 Phase 1 GATE — OpenCode Settings Critical Review (2026-08-04)

> §10 Phase 1 GATE — critical review of OpenCode settings (agents/workflows/rules/configs), working-tree as-is incl. 4 uncommitted §10 change sets.

## Source

- ai-specialist read-only critical review, 2026-08-04, of .opencode/opencode.jsonc + oh-my-opencode-slim.jsonc + ai-assist-sources.yaml + dcp.jsonc + NEXT-RUN.md + HANDOFF.md + practice-protected.md + boss_append.md + jsonl-stats.sh + learnings/index.md.

## Verdict

- **CONDITIONAL PASS** — internally coherent (permission enforcement, agent definitions, presets, skill arrays); 4 pending §10 change sets mutually consistent, no inter-set conflicts; cross-cutting drift (stale boss aliases, stale agent names, cross-project paths) indicates the C4/DIA-007 rename was not fully propagated.

## Findings

- **22 = 1 Blocker (F1) + 4 Critical (F2–F5) + 7 Major (F6–F12) + 6 Minor (F13–F18) + 4 Suggestion (F19–F22)** — 1 Blocker (F1 ai-specialist prompt stale global path), 4 Critical (F2 role_mapping stale OMO names oracle/fixer/code_reviewer/explorer/librarian; F3 tier3_local_references cross-project visualPoetryResearch paths; F4 opencode_best_practices stale global path; F5 @code-executor dangling in NEXT-RUN.md:103/112), 7 Major (F6 HANDOFF.md format lacks Prognosis 5-subsection schema → G1 gate-skip risk; F7 observer role_mapping GPT-5 mini not multimodal vs gemini-3.6-flash; F8–F11 stale "boss" aliases coder×3/architector/analyzer/practice-protected.md; F12 boss_append.md dead file), 6 Minor (F13–F18) — F13/F14 underscore agent names ai_specialist/resource_manager; F15 .mise.toml↔Dockerfile.dev sync gap untracked; F16 learnings/index.md stale "boss" refs; F17 jsonl-stats.sh jq any() per-line bug; F18 explorer agent defined in project opencode.jsonc without model assignment; 4 Suggestion (F19–F22) — F19 free-preset reviewer model (opencode/mimo-v2.5-free) verify; F20 council gemini-3.1-pro-preview GA monitor; F21 compaction.reserved 10000 for 1M-context models; F22 (RESTORE — was dropped by a prior fix) coder prompt ~1068ch approaching the ~2000ch soft limit — monitor; if adding more prompt content, consider extracting to a skill.

## Gaps

- no cross-reference validator for agent names/paths
- no HANDOFF.md schema validator
- agent-name sources fragmented across 5 files

## Decision points D1–D6

- D1 boss_append.md rename .DEAD
- D2 @code-executor→@coder
- D3 remove cross-project paths
- D4 HANDOFF.md rewrite to Prognosis schema
- D5 .mise.toml sync DIA ticket
- D6 single cleanup commit

## Outcome

- `F1–F5 RESOLVED — §10 cleanup lane (coder, cod-3) 2026-08-04; make test-config exit 0 (interview 5/5, skills 20 passed, JSONC 4/4); ai-specialist §10 Phase 5 independent review (ai--2) APPROVE — all 5 findings resolved, no collateral damage. Fixes uncommitted (commit decision at campaign end). F6–F21 deferred to DIA-045 backlog (incl. sources.yaml:207 stale rules names + explorer global agent).`
