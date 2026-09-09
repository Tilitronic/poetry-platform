# DIA-260909-tp5e - Add Muse Qwen balanced agent routing preset

---

id: DIA-260909-tp5e
title: "Add Muse Qwen balanced agent routing preset"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-09
source: inventory
date: 2026-09-09
created: 2026-09-09
updated: 2026-09-09

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence: []

---

## Description

Variant A (developer-approved, shipped INACTIVE): balanced Muse-volume + Qwen-reasoning split. Adds hand-authored preset `muse-qwen-balanced` in `.opencode/oh-my-opencode-slim.jsonc` cloning the promo skeleton (all 17 agents; researcher `orchestratorPrompt` verbatim; orchestrator prompt BYTE-IDENTICAL to current promo 15/25-marker text — NOT the held oj59 60/75 text). Header comment cites DIA-260909-tp5e + Muse 1.3 admission basis DIA-260828-qtsi. Preset pointer stays `promo` (promotion = pointer-swap).

Composition (primary -> fallbacks | variant):

- orchestrator `qwen3.8-flash -> deepseek-v4-flash, mimo-v2.5-free | medium`
- architector UNCHANGED from promo (`gemini-3.1-pro-preview, big-pickle | high`)
- coder `muse-spark-1.3-contributor -> deepseek-v4-flash | medium`
- reviewer `qwen3.8-flash -> deepseek-v4-pro | high` (fixes same-family collapse vs prior `qwen->muse`)
- analyzer `qwen3.8-flash -> muse-spark-1.3-contributor | high`
- openspec-plan `qwen3.8-flash -> muse-spark-1.3-contributor | high`
- researcher `muse-spark-1.3-contributor -> deepseek-v4-flash | medium`
- conspecter `muse-spark-1.3-contributor -> mimo-v2.5-free | medium`
- designer/observer/ai-specialist/ai-auditor/resource-manager/memory-manager/code-navigator/coder-escalated/analyzer-escalated UNCHANGED from promo.

Because: balances 226600/mo Muse volume economics ($0.10/$0.20) on coder/researcher/conspecter where cheapest input dominates with Qwen reasoning ($0.15/$0.47) on orchestrator/reviewer/analyzer/openspec-plan where reasoning is retained; fixes reviewer same-family fallback collapse (qwen->muse -> qwen->deepseek-pro cross-family); reuses promo skeleton and preserves orchestrator byte-identity (15/25 text) avoiding held oj59 drift; isolates Muse (trains-on-data NOT-ZDR region-limited) to non-sensitive lanes with containment grep; ships INACTIVE so promotion remains deliberate pointer-swap.

Diff vs prior `git show 9c1d365:.opencode/oh-my-opencode-slim.jsonc` muse-qwen-balanced block (~678-729) — where they differ, variant A wins:

- orchestrator: prior `[muse-1.3, qwen3.8|medium]` -> variant A `[qwen3.8, deepseek-v4-flash, mimo-free|medium]` (correct primary/fallbacks)
- architector: prior `[gpt-5.6-terra, qwen3.8|high]` -> variant A UNCHANGED promo `[gemini-3.1-pro-preview, big-pickle|high]`
- reviewer: prior `[qwen3.8, muse-1.3|high]` -> variant A `[qwen3.8, deepseek-v4-pro|high]` (cross-family fix)
- coder-escalated: prior `[gpt-5.6-sol, gpt-5.6-terra|max]` -> variant A UNCHANGED promo `[{kimi-k3 max},{deepseek-v4-pro max}|max]`
- analyzer-escalated: prior `[gpt-5.6-terra, gpt-5.6-sol|high]` -> variant A UNCHANGED promo `[{deepseek-v4-pro max}, qwen3.8| max]`
- ai-specialist: prior `[qwen3.8, gpt-5.6-terra|high]` -> variant A UNCHANGED promo `[qwen3.8, gpt-5.3-codex, big-pickle|high]`
- ai-auditor: prior `[gpt-5.6-terra, qwen3.8|high]` -> variant A UNCHANGED promo `[gpt-5.3-codex, gemini-3.1-pro-preview, big-pickle|high]`
- researcher: prior `[longcat-2.0, muse-1.3|medium]` -> variant A `[muse-1.3, deepseek-v4-flash|medium]`
- conspecter: prior `[mimo-free, mimo|medium]` -> variant A `[muse-1.3, mimo-free|medium]`
- memory-manager: prior `[mimo-free, mimo|medium]` -> variant A UNCHANGED promo `[mimo-free, deepseek-v4-flash|medium]`
- code-navigator: prior `[mimo-free, muse-free|medium]` -> variant A UNCHANGED promo `[mimo-free, deepseek-v4-flash|medium]`
- resource-manager: prior `[mimo-free, longcat|medium]` -> variant A UNCHANGED promo `[mimo-free, deepseek-v4-flash|medium]`
- observer: prior `[qwen3.8, kimi|medium]` -> variant A UNCHANGED promo `[kimi, big-pickle]` (no variant)
- designer: prior `[kimi, gpt-5.6-terra|medium]` -> variant A UNCHANGED promo `[claude-sonnet-4.5, kimi, big-pickle|medium]`
- coder/openspec-plan/analyzer: prior matches variant A (no change).

CRITICAL invariants: do NOT flip `preset` pointer (stays `promo`); do NOT touch drift checker scripts/thresholds/held oj59; do NOT edit AGENTS.md.

Files:

- `.opencode/oh-my-opencode-slim.jsonc` (new `muse-qwen-balanced` block)
- `.opencode/learnings/external-patterns/2026-09-09-dia-260909-tp5e-muse-qwen-balanced-gate-findings.md` (gate)
- `knowledge/model-registry.yaml` (add 1.3 entry)
- `.opencode/promo-registry.json` (fetched_at 2026-09-09 + stale 2026-09-16)

## Verification

- [ ] `make test-config` exit 0
- [ ] `scripts/validate-agent-names.sh` exit 0
- [ ] JSONC parse check exit 0 (`python3 -c "json.loads(strip_jsonc(open(...).read()))"`)
- [ ] `scripts/check-orchestrator-prompt-drift.sh` exit 0 (new preset must not break checker — checker ignores promo + new block; byte-identity stays 3/3)
- [ ] Privacy / lane-containment (7 acceptance criteria):
  1. Region smoke: provider pages 2026-09-09 confirm `muse-spark-1.3` region-limited availability; traffic limited to coder/researcher/conspecter + analyzer/openspec-plan fallback only.
  2. Lane-containment grep: `muse-spark-1.3-contributor` appears ONLY in `muse-qwen-balanced` on coder/researcher/conspecter primaries + analyzer/openspec-plan fallbacks; zero hits on orchestrator / ai-specialist / ai-auditor / coder-escalated / analyzer-escalated / council. Proof: `grep -n muse-spark-1.3 .opencode/oh-my-opencode-slim.jsonc` and `python3` JSONC lane check.
  3. No-secrets rule for Muse lanes: coder/researcher/conspecter lanes flagged `privacy_notes: trains-on-data NOT-ZDR region-limited`; orchestrator/escalated/auditor lanes never route Muse.
  4. Registry honesty: `knowledge/model-registry.yaml` has `muse-spark-1.3-contributor` entry mirroring 1.2 fields + `swe_bench_verified: null` (benchmark-pending UNVERIFIED inherits 1.2 terms) + `privacy_notes: trains-on-data NOT-ZDR region-limited` + `source_ref: DIA-260909-tp5e 2026-09-09`; `.opencode/promo-registry.json` has `fetched_at: 2026-09-09` + `stale_at: 2026-09-16` (7-day volatile stamp).
  5. Inactive shipping: `git diff` shows new `muse-qwen-balanced` block added but `"preset": "promo"` unchanged; `jq .preset .opencode/oh-my-opencode-slim.jsonc` == `promo`.
  6. DSF ZDR caveat: DeepSeek V4 Flash/Pro lanes carry ZDR via DSF terms through 2026-09-30; after that date re-verify ZDR before sensitive traffic (noted in model-registry `quota_notes` and promo-registry notes).
  7. Client-contract note: Muse Contributor tier trains on prompts/completions (region-limited); deployment restricts Muse to non-sensitive volume lanes per developer clearance DIA-260828-qtsi; no sensitive traffic on Muse lanes.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## UPDATE 2026-09-09 — DIA-260909-tp5e variant A chosen (developer-approved)

Chosen variant: A (balanced Muse-volume + Qwen-reasoning split, shipped INACTIVE).

Because: Muse $0.10/$0.20 dominates volume lanes (coder/researcher/conspecter 226600/mo) while Qwen $0.15/$0.47 reasoning retained on orchestrator/reviewer/analyzer/openspec-plan; reviewer fallback cross-family fix (qwen->deepseek-pro); promo skeleton reuse + orchestrator prompt BYTE-IDENTICAL to promo 15/25 text (no held oj59 60/75); lane-containment isolates trains-on-data Muse from orchestrator/escalated/auditor; INACTIVE preserves promotion as pointer-swap.

Alternatives considered:

- B: Muse-everywhere primary — cheaper but violates containment (Muse on orchestrator/escalated) and privacy boundary.
- C: Qwen-everywhere reasoning — strongest reasoning but loses Muse volume economics.
- D (abort/status-quo): no balanced preset — leaves volume/reasoning split unexploited.

Gate findings file: `.opencode/learnings/external-patterns/2026-09-09-dia-260909-tp5e-muse-qwen-balanced-gate-findings.md` (preset schema conventions, drift-gate gap note held oj59, lineup/pricing/privacy table dated 2026-09-09, promotion=pointer-swap boundary, 4-surface mechanical-change lesson).

Diff summary vs `git show 9c1d365:.opencode/oh-my-opencode-slim.jsonc` recorded in Description above; where they differ, variant A wins per ticket instruction.

Files touched (this lane):

- `.opencode/oh-my-opencode-slim.jsonc` (muse-qwen-balanced block)
- `.opencode/learnings/external-patterns/2026-09-09-dia-260909-tp5e-muse-qwen-balanced-gate-findings.md`
- `knowledge/model-registry.yaml` (muse-spark-1.3-contributor entry; decision: 1.3 does NOT supersede 1.2 globally — promo retains 1.2 primary; muse-qwen-balanced uses 1.3 on volume lanes)
- `.opencode/promo-registry.json` (fetched_at 2026-09-09, stale_at 2026-09-16, added 1.3 promo entry)

Verification evidence: see session result (make test-config, validate-agent-names, JSONC parse, check-orchestrator-prompt-drift, containment grep all exit 0).
