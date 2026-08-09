# AI-Auditor token_export Deny: ai--3 findings (2026-08-06)

date: 2026-08-06

## Source

- §10 Phase-1 gate research by @ai-specialist (findings id `ai--3`, session `ses_029fd1725ffeVvjoDM6Rzja4zv`, 2026-08-06) for the @ai-auditor token_export config-gap fix. This file registers the Phase 1 findings per AGENTS.md §10 ("orchestrator registers the findings"); the executor lane persists them so they are recoverable beyond the git diffs. Owner rulings (row 496 session log) are folded into the findings as durable external-pattern decisions.

Summary
-------
The gate verdict on the @ai-auditor token_export gap: **§10 Phase-5 smoke FAILED — token_export (global plugin opencode-token-monitor@0.5.0) wrote /tmp/opencode/ai-auditor-smoke.txt (594B) with NO deny.** Coder-lane forensics confirmed a CONFIG-GAP (D1): the @ai-auditor permission block in `opencode.jsonc` (lines 220-251) has no token_export/token_history/token_stats entries, so the write-capable token_export tool falls through the per-tool permission override map to the global permission block → default allow (D2). Delta is minimal: add `"token_export": "deny"` after `"task": "deny"` in the ai-auditor block, then restart + re-smoke (D3). Zero-risk and scoped (D4). Forensics substantively correct; systemic exposure S1-S5 backlogged (D5, ticket DIA-055).

Findings
--------
- **D1 — CONFIG-GAP confirmed.** The @ai-auditor permission block (opencode.jsonc:220-251) lacks `token_export` / `token_history` / `token_stats`; the global `plugin[]` (opencode.jsonc:136) registers `opencode-token-monitor@0.5.0`; the global permission block has no token_* entries. `token_export` is write-capable (`format` required, `file_path` optional) — hence the smoke write. Best-practice rule: "Permission rules must enumerate every tool an agent may use; unlisted tools are not implicitly denied."

- **D2 — OpenCode permission model.** Arbitrary tool-name keys are valid in permission blocks (proven by 15 envsitter denies). Resolution order: agent → global → default-allow; agent rules take precedence. The `tools` field is deprecated → per-agent permission deny IS the correct mechanism. Deny-by-default is NOT implemented upstream. Best-practice rule: "Deny tools by name at the agent scope when the agent must not use them."

- **D3 — Delta.** Add `"token_export": "deny"` after `"task": "deny"` in the @ai-auditor permission block; restart OpenCode + re-run the Phase-5 smoke (attempt token_export → must be DENIED).

- **D4 — Risk.** Zero — the change is scoped to a single permission entry in one agent block; no behavior change for any other agent or tool.

- **D5 — Forensics + systemic exposure.** Coder-lane forensics were substantively correct. Systemic exposure S1-S5: (S1) token_export available to ALL subagents — pure-analyst tiers (analyzer/reviewer/architector) need audit; (S2) orchestrator also default-allow token_export — evaluate; (S3) unlisted-tools-default-allow is the root cause (HIGH, architectural — monitor upstream + consider a project tool-coverage audit script); (S4) token_export write behavior — no path allowlist, auto CWD-write on output >10k chars — file upstream issue; (S5) opencode-best-practices.md + ai-assist-sources.yaml MISSING from disk though referenced in ai-auditor.md + 2026-08-01 learnings → @resource-manager curation.

Outcome
-------
Owner rulings (row 496 session log): proceed through the §10 chain (gate → design → @coder → @ai-specialist independent review → restart + smoke); keep the fix scope minimal — token_export-only deny for @ai-auditor now; systemic exposure S1-S5 moved to backlog (DIA-055, opencode-config, Medium). Registered as durable external-pattern findings (this file). Best-practice-driven entries (D1 "enumerate tools", D2 "deny by name at agent scope") are marked with their governing rule so the Phase-6 outcome field stays traceable after implementation.
