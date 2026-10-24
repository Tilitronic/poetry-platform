# DIA-045 — OpenCode config drift backlog (ai-specialist review 2026-08-04, findings F6–F22)

---

id: DIA-045
title: "OpenCode config drift backlog (ai-specialist review 2026-08-04, findings F6–F22)"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: []
discovered:
source: inventory
date: 2026-08-04
created: 2026-08-04
updated: 2026-08-07

---

## Description

Deferred findings from the 2026-08-04 ai-specialist opencode-settings critical
review (`.opencode/learnings/external-patterns/2026-08-04-opencode-settings-review.md`).
**F1–F5 (Blocker/Critical) were fixed via the §10 cleanup lane; these F6–F22
remain as backlog.** Owner disposition 2026-08-04: file as this ticket;
D1/D3/D4/D5 deferred here; D2 folded into F5.

**Major:**

- **F6** — HANDOFF.md format lacks the `## Prognosis for next cycle`
  5-subsection schema → **G1 batch-approval gate-skip risk** at next boot.
  Verify whether `openspec/templates/HANDOFF.md` (the schema source) or a stale
  file is the problem (D4 deferred here).
- **F7** — `ai-assist-sources.yaml` observer `role_mapping` lists "GPT-5 mini"
  as not multimodal; config uses `gemini-3.6-flash` — mismatch.
- **F8–F11** — stale "boss" aliases: coder prompt ×3 presets, architector
  prompt, analyzer prompt, `practice-protected.md` §4.
- **F12** — `boss_append.md` dead file; D1 recommends rename to `.DEAD`.

**Minor:**

- **F13/F14** — underscore agent names `ai_specialist` / `resource_manager` in
  `ai-assist-sources.yaml`.
- **F15** — `.mise.toml` ↔ `Dockerfile.dev` pin sync gap untracked; D5 — file a
  tracking note.
- **F16** — `learnings/index.md` stale "boss" refs.
- **F17** — `jsonl-stats.sh` `jq -e 'any(...)'` per-line vs file-level bug
  (needs `-s` slurp).
- **F18** — `explorer` agent defined in `opencode.jsonc` with no model
  assignment.
- **F19** — free-preset reviewer model: verify.
- **F20** — monitor `gemini-3.1-pro-preview` for GA.
- **F21** — `compaction.reserved` 10000 may be low for 1M-context models.
- **F22** — coder prompt ~1068ch approaches ~2000ch soft limit — monitor; consider extracting prompt content to a skill if it grows.

**Audit gaps (3):**

1. No cross-reference validator for agent names/paths.
2. No HANDOFF.md schema validator.
3. Agent-name sources fragmented across 5 files.

## Verification

1. F6: check `.opencode/session/current-handoff.json` and `openspec/templates/HANDOFF.md` for the Prognosis 5-subsection schema; record which file is authoritative vs stale.
2. F7: read the `observer` role_mapping entry in `ai-assist-sources.yaml`; compare with the configured model.
3. F8–F11: grep the referenced prompts/`practice-protected.md` §4 for "boss"; record file + line refs.
4. F12: confirm `boss_append.md` exists / is unreferenced.
5. F13/F14: grep `ai-assist-sources.yaml` for underscore agent names.
6. F15: diff the node/pnpm pins in `.mise.toml` vs `Dockerfile.dev` ARGs; record drift.
7. F16: grep `learnings/index.md` for "boss".
8. F17: run `bash .opencode/scripts/jsonl-stats.sh` on a multi-line jsonl; confirm the per-line vs file-level `jq` behavior.
9. F18/F19: read the agent model assignments in `opencode.jsonc` / presets in `oh-my-opencode-slim.jsonc`.
10. F20/F21: record current `gemini-3.1-pro-preview` status and `compaction.reserved` value.
11. Record per-finding evidence + dispositions in Re-verify.

## Fix

> Applied 2026-08-04 via §10 lane (owner-approved fix-now set + 2 anomaly dispositions; 12 fix-now edits + 2 anomaly fixes). Uncommitted — pending owner commit decision.

> **Remaining items (2026-08-07):** Actionable items exhausted as of 2026-08-07;
> remaining F19/F20/F22 are monitor-only. Final status (CLOSE vs
> keep-OPEN-for-monitor) pending owner decision.
> **Owner decision 2026-08-07: CLOSE.** F19/F20/F22 remain monitor-only items
> documented above; reopen if any becomes actionable.

- **RESOLVED** — F8–F11: stale "boss"→"orchestrator" aliases replaced (coder ×3 prompts, architector/analyzer orchestratorPrompts, practice-protected.md).
- **RESOLVED** — F13/F14 + NF-4: underscore→hyphen agent names (ai-specialist, resource-manager) across ai-assist-sources.yaml + routing prompts.
- **RESOLVED** — F7: opencode-go observer → kimi-k2.7-code (multimodal) + role_mapping updated.
- **RESOLVED** — NF-1: HANDOFF template option A restructured (## Prognosis for next cycle wrapper + 5 ### subsections matching the batch-approval gate); gate check stays `## Prognosis for next cycle`.
- **RESOLVED** — F18: vestigial `explorer` agent block removed from `opencode.jsonc` (was :161-163, no model assigned in any preset); lane covered by `code-navigator` in all 3 presets; `disabled_agents` retains `explorer` to suppress the native OMO alias.
- **RESOLVED** — F21: `compaction.reserved` 10000 → 16000 (headroom for 1M-context models).
- **STILL OPEN** — F15 (mise↔Dockerfile sync — deferred to separate ticket), F19/F20/F22 (monitor).
- **FUTURE** — audit gaps 1–2 (agent-name cross-ref validator, HANDOFF schema validator).
- **Verification:** `make test-config` exit 0; ai--2 §10 Phase 5 APPROVE; cod-7 independent mechanical re-confirm; uncommitted pending owner commit decision.
- **Resolution note (2026-08-04, lane A commit):** F18 + F21 above committed as `fix(opencode): DIA-045 F18/F21 — remove vestigial explorer agent, compaction.reserved 16000`. Ticket remains OPEN for F15/F19/F20/F22 + audit gaps 1–3.

### Resolved 2026-08-07 via §10 cycle (remaining actionable items)

- **F18 (explorer agent) — CONFIRMED RESOLVED.** Ground truth re-check: project
  `.opencode/opencode.jsonc` (386 lines) has **no** `explorer` agent block; the
  agent block contains explore/general (disabled), orchestrator, architector,
  analyzer, reviewer, coder, code-navigator, researcher, designer, observer,
  memory-manager, council, resource-manager, ai-specialist, ai-auditor. No
  preset in `oh-my-opencode-slim.jsonc` assigns a model to `explorer`. No
  `.opencode/agents/explorer.md` exists (dir has ai-auditor.md,
  memory-manager.md, researcher.md only). `disabled_agents` retains `explorer`
  (correct per AGENTS.md §9 — suppresses the OMO native alias). The ticket's
  addendum (b) predated the 2026-08-04 fix. **The addendum's "F18 stays OPEN"
  correction is SUPERSEDED — F18 is resolved.**
- **F21 (compaction.reserved) — CONFIRMED RESOLVED** (`opencode.jsonc:21`
  `"reserved": 16000`).
- **Addendum (a) (stale OMO names in ai-assist-sources.yaml rules) — RESOLVED.**
  Commit 74d6bd1: `ai-assist-sources.yaml:207` renamed `"For review diversity:
code-reviewer must be different model family than fixer"` → `"For review
diversity: reviewer must be different model family than coder"`. Full-file
  grep: 0 stale agent names remain. YAML valid. §10 Phase 6 independent review
  (ai-specialist ses_023e5fb13ffeU37NECuqTxhoUt): **PASS** — S1–S4 contract
  consistent, zero stale collateral.
- **F6 (HANDOFF schema / validate-handoff.sh) — RESOLVED.** The handoff is now
  a JSON document (`.opencode/session/current-handoff.json`) with a validated
  `prognosis` schema + SHA256 checksum (DIA-061). `validate-handoff.sh` gained
  a JSON-mode branch (commits a87fdf5 + a3ed5dc): JSON handoffs skip the
  markdown `## Prognosis for next cycle` heading check and go straight to
  checksum validation; the markdown template path (no-arg, `make test-config`)
  is byte-identical. Direct smoke: `bash scripts/validate-handoff.sh
.opencode/session/current-handoff.json` → exit 0 ('info: JSON handoff
  detected' + 'ok: checksum verified'). Dev-infra two-axis review (rev-3):
  **APPROVE**, Spec axis 0 findings, Standards 2 Minor + 1 Suggestion all fixed
  (a3ed5dc). **Audit-gap 2 (no HANDOFF schema validator) is effectively
  resolved** — validate-handoff.sh is now the schema + checksum validator.
- **F15 — RESOLVED via separate ticket DIA-050 (CLOSED 2026-08-07).** The
  pin-sync validator `scripts/check-pin-sync.sh` (commits 49739f2 + 37a6986)
  now enforces `.mise.toml` ↔ `Dockerfile.dev` +
  `tools/opencode-docker/Dockerfile` parity (4 comparisons).
- **F19/F20/F22 — REMAIN MONITOR-ONLY (no action).** Snapshot 2026-08-07: F19
  free-preset reviewer model = `opencode/mimo-v2.5-free`; F20
  `gemini-3.1-pro-preview` still referenced (opencode-go preset, cebula
  ai-auditor fallback, dcp.jsonc) with no GA signal; F22 coder prompt
  ~1200–1300ch, well under the ~2000ch soft limit.
- **NEW observation (config, backlog for DIA-055/056):** @resource-manager's
  runtime toolset LACKS a bash/shell tool (routing-table contract 'bash
  curl/wget/trafilatura' not satisfied at runtime) — it could not run YAML
  validation / git / commit; shell steps had to be completed by a
  code-executor lane. Flag for the DIA-055/056 config-hardening backlog.

## Re-verify

> To be filled at re-verify time.

## Validation-loop addendum (2026-08-04) — §10 Phase 5 reviewer flags

Two items flagged by the §10 Phase 5 reviewer during the validation loop; folded
into this config-drift backlog (F18-adjacent):

- **(a) `ai-assist-sources.yaml` line ~207 — stale OMO names in `rules` entry.**
  The `rules` entry reads: `"For review diversity: code-reviewer must be
different model family than fixer"`. Post-C4-pass canonical names are
  `reviewer` / `coder` (project AGENTS.md §9); `code-reviewer` / `fixer` are
  stale OMO aliases. Proposed: rename to `reviewer` / `coder`. **Verified
  2026-08-04:** entry present verbatim at
  `.opencode/oh-my-opencode-slim/knowledge/ai-assist-sources.yaml:207`.
- **(b) `explorer` agent definition — PROJECT `opencode.jsonc` lines 161–163:
  F18 CONFIRMED, stays OPEN.** The F18 finding refers to the **project** file
  `.opencode/opencode.jsonc` (339 lines), which DOES define the `explorer`
  agent at lines 161–163: `"mode": "subagent"`, `"color": "#10B981"` — **no
  model assigned in any preset**. F18 stays OPEN (fix at fix time: assign a
  model to the project `explorer` agent, or disable it).
  **Correction 2026-08-04:** the earlier "stale claim" verdict ran its
  verification against the **global** config `~/.config/opencode/opencode.jsonc`
  (149 lines) — the wrong file. The global config has **no** `explorer`
  definition; its agent block (lines 28–88) defines `build` / `plan` /
  `explore` (disabled) / `general` (disabled) / `council` / `councillor` /
  `analyzer` only, with `"explore": {"disable": true}` at line 59. The
  `explorer` OMO alias additionally appears in the disabled-agent list
  `.opencode/oh-my-opencode-slim.jsonc:5` — `"disabled_agents": ["oracle",
"fixer", "explorer", "librarian"]` — and no `explorer` / `code_explorer`
  agent file exists in `.opencode/agent/` (checked 2026-08-04). Proposed:
  at fix time, re-grep for `explorer` across `.opencode/` and
  `~/.config/opencode/` config files, assign a model to the project `explorer`
  agent or disable it, then close F18.

> **Superseded 2026-08-07:** addendum (b)'s "F18 stays OPEN" claim is superseded
> by the 2026-08-07 ground-truth re-check — F18 is resolved (see Fix →
> "Resolved 2026-08-07 via §10 cycle (remaining actionable items)").
