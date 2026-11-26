# §10 Phase 1 GATE — Handoff Protocol Audit (2026-08-03)

> §10 AI Devtools Modernization Workflow — Phase 1 GATE research.
> Lane: @ai-specialist (read-only). Registered by orchestrator via docs lane.
> Status: findings pending owner Phase 2 decision.

## Request
Owner: "check how orchestrator uses handoff skill? Is it correct and modern way? Audit it"

## Source (audit evidence)
- docs/dev-infra-audit/NEXT-RUN.md §2 (SELF-RERUN / CRISIS-DETECTION / PROGNOSIS-DISCIPLINE) + §7 (Redispatch Protocol)
- openspec/changes/dia-redispatch-cycle/ (design.md 536L, tasks.md 269L) + .sdd/dia-redispatch-cycle/architecture.md (ADR-001..005)
- openspec/templates/HANDOFF.md (152L) + .opencode/session/{HANDOFF.md, messages.md, README.md}
- .opencode/oh-my-opencode-slim.jsonc (orchestrator prompt refs L26/196/377) + .opencode/opencode.jsonc
- models.dev (live fetch 2026-08-03) — context-window verification
- Anthropic Claude Code Best Practices + Sub-agents docs, Boris Cherny Loop Engineering (Jun 2026), mattpocock/skills handoff SKILL.md, OpenCode compaction docs

## Key findings
1. NO literal `handoff` SKILL.md exists (project 20 skills + global 17 — zero handoff); handoff is PROTOCOL-based: one-line prompt ref ×3 presets + NEXT-RUN.md rules + HANDOFF.md template + messages.md discipline.
2. Context-window lookup CORRECT (post row-69 fix): deepseek-v4-flash / qwen3.7-max / qwen3.7-plus = 1,000,000 verified live against models.dev; big-pickle 200,000 honestly tagged unverified.
3. Correctness: design↔spec faithful ✅ (design.md §1–§14 ↔ NEXT-RUN §2/§7); premature-handoff root cause resolved ✅ (rows 10/19/49/57 fired on wrong 64k assumption; fixed row 69, lessons.md + failures.md); ❌ HANDOFF.md STALE (Major — written at row 143, log now at 175; 30+ rows of work missing); ❌ messages.md row numbering inconsistent (Major — duplicate row 159 lines 185/208, restarts at 39/46/49); ❌ **batch-approval boot protocol NEVER executed (Critical — design.md §8 "no work before approval" is a dead rule; zero evidence across 5 SELF-RERUN events + fresh boots)**; ⚠️ §9 clean-termination independent verification partially aligned; Minor: memory/adr.md:175 stale 64k ref.
4. Modernity split: DESIGN CONCEPTS ahead of community practice (C1–C5 crisis triggers, ADR-003 fresh-session independence, cycles budget, 5-subsection prognosis = exactly Cherny's worker≠judge + hard stops + Anthropic "agent doing the work isn't the one grading it"); EXECUTION MECHANICS pre-modern (manual file writes + human restart + token_stats threshold counting vs OpenCode native compaction/resume/checkpoint; JSONL sidecar dual-written but zero consumers).
5. Row-97 skip decision for mattpocock `handoff` skill VALIDATED — that skill is a ~50-word summary tool (writes to OS temp dir, no schema/crisis/budget/independence); our dia-redispatch-cycle protocol is dramatically richer.

## Verdict
Correct: mostly, with 3 operational defects (stale HANDOFF.md, dead batch-approval rule, unreliable row numbering).
Modern: design yes, mechanics no → EVOLVE, don't replace (keep design concepts; replace mechanics with native session tooling).

## Gaps (G1–G9)
- **G1 Critical**: batch-approval §8 — either enforce (orchestrator prompt hard rule) or formally deprecate (design amendment + ADR superseding §8)
- **G2 Major**: HANDOFF.md refresh automation on campaign completion, OR adopt native compaction as primary continuity (HANDOFF supplementary)
- **G3 Major**: messages.md numbering freeze (monotonic, no restarts); consider JSONL-as-canonical log, messages.md as human-readable export
- **G4 Major**: evaluate replacing 50% SELF-RERUN with OpenCode auto-compaction (compaction.auto: true already enabled; manual handoff duplicates it at higher cost)
- **G5 Major**: /goal or Stop-hook deterministic verification gating — the deferred Phase 2/3 of the verification-loop campaign
- **G6 Minor**: HANDOFF.md verification_result section per §9 (currently skipped after fresh-session smoke)
- **G7 Minor**: memory/adr.md:175 correct 64k → 1,000,000 (match repo.md/lessons.md/failures.md)
- **G8 Suggestion**: reviewer teaching/reflect/playwright-browser skill bloat — options A+C already applied (row 174-175); remaining = fresh-context instruction (done) + future /goal
- **G9 Suggestion**: messages.jsonl consumer (dashboard / session replay / audit reader) or document as write-only audit trail

## Outcome

- **ADOPTED** 2026-08-03 — owner approved all G1–G9 ("Adopt everything"); §10 Phase 4 implemented (9 files, all validations exit 0); ai-specialist ai--14 APPROVE-WITH-CHANGES (C1 resolved by coder evidence, M1 cosmetic not applied, M2 no-action); owner approved as-is; Phase 6 registration 2026-08-03. Batch-approval boot enforced (NEXT-RUN §1 Step 1.5/§7.3), HANDOFF-REFRESH milestone rule, monotonic numbering + JSONL canonical, compaction/SELF-RERUN 30%/50% split, pre-handoff verification gate, Verification Result section, adr 64k→1M, jsonl-stats consumer.
