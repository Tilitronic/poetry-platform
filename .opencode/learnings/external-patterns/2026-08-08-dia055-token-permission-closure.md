# DIA-055 §10 gate findings — token_export default-allow closure (2026-08-08)

- **Date:** 2026-08-08
- **Source:** §10 Phase-1 gate research by @ai-specialist for DIA-055 (write-capable `token_export` default-allow gap — closure of the 6-agent residual). Registered per AGENTS.md §10 ("orchestrator registers the findings"); the executor lane persists them so they are recoverable beyond the git diffs. Follows the prior gate findings on the same topic (`2026-08-07-token-tool-permission-model.md` F1–F5, `2026-08-06-ai-auditor-token-export-deny.md` D1–D5).
- **Status:** IMPLEMENTED 2026-08-08 (R1 applied; independent @ai-specialist review APPROVE, zero findings; Phase-5 post-restart smoke pending next boot). R2 spun off → DIA-066 (OPEN, Low); R3 on quarterly cadence.

## Outcome

- **R1 — IMPLEMENTED 2026-08-08.** `"token_*": "deny"` added to coder, code-navigator, researcher, designer, observer, and memory-manager in `.opencode/opencode.jsonc` — 13 total `token_*: deny` entries in config (7 pre-existing + 6 new). `make test-config` exit 0. Independent review (@ai-specialist, Phase 6): APPROVE, zero findings.
- **R2 — spun off → ticket DIA-066** (OPEN, Low priority, tool-coverage audit script). Stands alone; not bundled into DIA-055.
- **R3 — upstream monitoring:** recurring quarterly check of `opencode_releases` for permission-model changes; no permission-model changes across v1.18.12 → v1.18.15.
- **Resource-manager bash-gap — CLOSED** (not a real gap): `bash: curl/wget/trafilatura: allow` + `"*": deny` already present at `.opencode/opencode.jsonc` L195-214; no fix required.
- **Pending — post-restart smoke (next boot)** to prove permission enforcement is live in the loaded binary; DIA-055 status remains IMPLEMENTED until then.

## Findings

- **A — 6 agents still default-allow `token_*`.** The 2026-08-07 4-delta fix closed 8 agents (orchestrator keeps explicit `token_export: allow`; architector/analyzer/reviewer, council, resource-manager, ai-specialist, ai-auditor gained `token_*: deny`). These 6 remain OPEN in `.opencode/opencode.jsonc`:
  - `coder` (L151-154) — no permission block at all ("deliberately no restrictions" comment, M2 decision 2026-08-01)
  - `code-navigator` (L155-158) — no permission block
  - `researcher` (L159-167) — permission block has `edit/bash/task: deny` (L162-166) but NO `token_*` entry
  - `designer` (L168-171) — no permission block
  - `observer` (L172-175) — no permission block
  - `memory-manager` (L176-179) — no permission block
  All six fall through to default-allow for the write-capable `token_export`. Best-practice rule: "Permission rules must enumerate every tool an agent may use; unlisted tools are not implicitly denied."

- **B — Confirmed write risk.** `token_export` (opencode-token-monitor@0.5.0) is write-capable: arbitrary `file_path` via `mkdirSync` + `writeFileSync` with NO path allowlist, plus an auto CWD-write when content > 10k chars (from learnings F3, 2026-08-07). `token_stats` / `token_history` are read-only. Only `token_export` needs the deny for write-capability closure; the wildcard `token_*: deny` covers all three uniformly.

- **C — Plugin concatenation.** Token tools load from GLOBAL config even when the project `plugin[]` omits them — plugin arrays concatenate across config layers (learnings F1, 2026-08-07). Per-agent deny is the correct mechanism; removing opencode-token-monitor from the project `plugin[]` will NOT prevent the tools from loading.

## Recommendations

- **R1 — per-agent `"token_*": "deny"` for the 6 agents** (`coder`, `code-navigator`, `researcher`, `designer`, `observer`, `memory-manager`), append-only. For `coder`, PRESERVE the existing "deliberately no restrictions" comment (M2 decision) but note `token_*` is denied — the write-capable export tool is an explicit carve-out, not a general restriction. Traced to OpenCode docs: "Most permissions default to allow" + wildcard matching (`tool_*` documented, `token_*` new application) + "Permission rules must enumerate every tool an agent may use." Highest-confidence, lowest-risk delta (zero behavior change for read-only token tools).

- **R2 — spin-off ticket (DIA-066 candidate): tool-coverage audit script.** `scripts/audit-agent-tool-coverage.sh` — enumerate registered tools × per-agent permission coverage and surface unlisted default-allow tools. Directly addresses the systemic root cause (S3, 2026-08-06 learnings): unlisted-tools-default-allow. **Confidence MEDIUM** — the tool-enumeration mechanism needs investigation before committing to an approach. Do NOT bundle into DIA-055; the ticket stands alone.

- **R3 — upstream monitoring.** Quarterly check of `opencode_releases` for permission-model changes: deny-by-default option, plugin-permission scoping, `token_export` path-allowlist. No permission-model changes across v1.18.12 → v1.18.15. Note: `opencode_releases` is ALREADY present in `ai-assist-sources.yaml` tier2_volatile_web (L68-70, `https://github.com/anomalyco/opencode/releases`) — no curation action required, just use it on the quarterly cadence.

## Resource-manager bash-gap — CLOSED (not a real gap)

- resource-manager config (`.opencode/opencode.jsonc` L195-214) already grants `bash: curl/wget/trafilatura: allow` + `"*": deny`, with `edit` scoped to `.opencode/oh-my-opencode-slim/knowledge/*` only and `token_*: deny` present. This matches its lane requirements (Tier-1 Markdown caching + Tier-2 re-fetch). No fix needed — documented as already addressed in the prior config cycle (DIA-007 split + 2026-08-07 4-delta change).

## Alternatives rejected

- **Global deny + per-agent allow:** inverts the established per-agent-deny model (2026-08-07 outcome), harder to reason about (every agent would need an explicit allow list for every tool they use, including coder's unrestricted implementer role). Rejected.
- **OMO-config permission overrides:** not technically possible — permissions live only in `opencode.jsonc`; oh-my-opencode-slim.jsonc has no permission surface. Rejected.

## Confidence

| Item | Confidence |
|------|------------|
| 6-agent residual default-allow gap (Finding A) | HIGH |
| token_export write-capability (Finding B) | HIGH |
| Plugin-array concatenation (Finding C) | HIGH |
| Wildcard `token_*: deny` syntax | HIGH |
| No upstream permission changes v1.18.12→v1.18.15 (R3) | HIGH |
| Resource-manager bash-gap closed (no fix needed) | HIGH |
| R2 audit-script approach (DIA-066) | MEDIUM |

## Sources

- `.opencode/opencode.jsonc` (agent permission blocks L151-179, L195-214)
- `.opencode/oh-my-opencode-slim/knowledge/opencode-best-practices.md`
- `.opencode/oh-my-opencode-slim/knowledge/ai-assist-sources.yaml` (tier2_volatile_web, L68-70)
- Learnings: `2026-08-07-token-tool-permission-model.md` (F1–F5), `2026-08-06-ai-auditor-token-export-deny.md` (D1–D5)
- OpenCode docs: permissions, agents, releases (live-fetched, v1.18.12 → v1.18.15)

## Tags

§10-gate, permissions, token-monitor, default-allow, write-capability, DIA-055, DIA-066-candidate, per-agent-deny, upstream-monitoring
