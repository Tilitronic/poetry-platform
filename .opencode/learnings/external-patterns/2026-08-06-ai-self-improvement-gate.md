# AI Self-Improvement Gate: ai--1 findings (2026-08-06)

date: 2026-08-06

## Source

- §10 Phase-1 gate research by @ai-specialist (findings id `ai--1`, 2026-08-05/06) for the 4-phase self-improvement campaign; OpenSpec change `ai-self-improvement-auditor-and-cleanup` (validated, `openspec validate` exit 0, 2026-08-06 — pending implementation). This file registers the Phase 1 findings per AGENTS.md §10 ("orchestrator registers the findings"); the executor lane persists them so they are recoverable beyond the git diffs. Owner rulings (row 462 pre-approvals) are folded into the findings as durable external-pattern decisions.

Summary
-------
The gate verdict on the 4-phase self-improvement plan: **3 false plan claims corrected (D8), 2 DO-NOT-PROCEED / monitor decisions (D1 CLASH dropped, D2 partial), 1 confirmed no-op (D5), and the model-economy assumption already satisfied (D6 skip-mode already implemented — no model swap).** Real work concentrates in Phase 2 (duplicate-skill cleanup + validate-skills.sh two-tier detection) and Phase 3 (@ai-auditor registration), with an added council budget guard in NEXT-RUN.md §2. No change is blocked on external tools; native OpenCode permissions and existing config cover the requirements.

Findings
--------
- **D1 — CLASH (empathic/clash): DO-NOT-PROCEED.** OpenCode support is "Protocol ready" only (issue #197 OPEN), 33 stars (experimental tier <100), license discrepancy (API "Other" vs README Apache-2.0), last push 2026-05-14. `clash init --agent opencode` will NOT work. Native OpenCode permissions already cover the need: .env deny (default), orchestrator bash/edit deny (opencode.jsonc:70-111), practice-protected.md edit deny (addable). Owner ruling (row 462): **Drop, monitor issue #197** — OS-sandboxing gap remains a monitored backlog item. Best-practice rule: "Use the simplest tool that covers the requirement — native permissions suffice."

- **D2 — Skill shadowing (actually duplicates).** OpenCode loads BOTH project + global skill locations → duplicate `<available_skills>` entries (confusion, NOT true shadowing). 5 BYTE-EXACT dupes to delete from `.opencode/skills/` — `book-rag`, `mermaid-diagramming`, `console-charting`, `debugging-workflow`, `teaching` — owner pre-approved (row 462). `playwright-browser` = NEAR-dupe (4-line intentional diff: project omits 2 Console Ninja MCP paragraphs) → KEEP project version, validator flags SOFT warn. `git-diff` = DIFFERENT, project version BETTER (inline git cmds vs global external Python) → KEEP. `validate-skills.sh` lives at `.opencode/scripts/validate-skills.sh` (NOT `scripts/`), 296L, exit 0/1/2, no dup detection yet; wired via `make test-skills` (Makefile). Best-practice: "Ensure skill names are unique across all locations" (opencode.ai/docs/skills troubleshooting).

- **D3 — @ai-auditor (Phase 3) 4-source containment contract.** S1 AGENTS.md §9 row + S2 opencode.jsonc read-only block + S3 OMO agents + 3 presets + S4 `.opencode/agents/ai-auditor.md`. ⚠ `.opencode/agents/*.md` AUTO-LOADS at next OpenCode startup (dispatchable immediately). Frontmatter mirrors `memory-manager.md` (description+mode ONLY; permissions live in opencode.jsonc). Models: primary `github-copilot/gpt-5.3-codex`, fallback `github-copilot/gemini-3.1-pro-preview` (both in dcp.jsonc + council presets + Copilot Pro 1500 credits).

- **D4 — check-tools: no CLASH probe.** Makefile:66-67 → `scripts/check-tools.sh` (98L, mise/node/pnpm probes, exit 0/1, NOT a CI gate). Do NOT add a CLASH probe — it would break dev workflows.

- **D5 — dcp.jsonc scope correction.** 37L DCP compaction limits only (50% max / 20-30% min) — NO skill/context alignment effect. Phase-2 plan title "dcp.jsonc skill/context alignment" was a misconception.

- **D6 — Model economy: skip-mode ALREADY IMPLEMENTED.** `openspec-plan` = qwen3.7-plus High-Reasoning + big-pickle fallback (OMO cebula preset); skip-mode already implemented at OMO line 531 — no model swap needed. Council = 5 parallel seats (`deepseek-v4-flash` + `qwen3.7-plus` [Go] + `gemini-3.1-pro-preview` + `gpt-5.3-codex` + `claude-sonnet-4.5` [Copilot credits]) — council only at C1–C5 crisis per owner-approved plan Phase 4 (see NEXT-RUN.md §2 COUNCIL-BUDGET-GUARD: 75% warn 1125 / 90% hard-stop 1350 of 1500 Copilot credits).

- **D8 — 3 false plan claims corrected.** (1) CLASH readiness — false, protocol-only per D1; (2) orchestrator skill scoping lives in `oh-my-opencode-slim.jsonc` (`presets.cebula.orchestrator.skills`), NOT opencode.jsonc; (3) 'shadowing' semantics = duplicate `<available_skills>` entries, not true shadow.

Outcome
-------
Owner rulings (row 462 pre-approvals) accepted: D1 dropped + monitored (issue #197), D2 5 byte-exact dup deletions pre-approved, D3/@ai-auditor + D4 (no probe) + D5 scope correction + D6 no-op confirmed. Registered as durable external-pattern findings (this file). Implementation pending via OpenSpec change `ai-self-improvement-auditor-and-cleanup` (status: validated, `openspec validate` exit 0, 2026-08-06). Best-practice-driven entries (D1 "simplest tool", D2 "unique skill names") are marked with their governing rule so the Phase-6 outcome field stays traceable after implementation.
