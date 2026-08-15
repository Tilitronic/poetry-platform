# DIA-183 - Properly introduce ponytail skill and headroom context-compression

<!-- Filed 2026-08-15 from plan-mode research session (agent: plan). Evidence-backed
     comparison of DCP / headroom / ponytail completed (benchmarks: ponytail agentic
     n=4; headroom evals tier-1; DCP vendor+cache test). DCP stays as-is (active).
     This ticket covers the two tools NOT present. Routed via AGENTS.md 2.5 (AI
     Devtools Modernization): gate @ai-specialist -> EBDV (DIA-115) -> @coder ->
     @ai-auditor. ASCII-only per DIA-079. -->

---

id: DIA-183
title: "Properly introduce ponytail skill and headroom context-compression"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-15
source: baseline
date: 2026-08-15
created: 2026-08-15
updated: 2026-08-15

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_ffdb9f859ffeyV8hpQzIoaJKRZ"
lane_id: ""
agent: "plan"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence: []

---

## Description

Research (2026-08-15) compared the three context/token-management tools. DCP is
active (`.opencode/dcp.jsonc` modelMaxLimits 50% / modelMinLimits 12-30%; plugin
@tarquinen/opencode-dcp@3.1.14; native compaction reserved 16000). Two tools are
NOT present:

(A) **ponytail** (DietrichGebert/ponytail, MIT, 102.7k stars): YAGNI 7-rung ladder
steering agents to write only necessary code. Removed 2026-08-01 as dangling skill
refs from all 3 OMO presets (no source existed then); the `ponytail:` comment
convention still lives in 7 sites (lessons.md:880, opencode-docker bin/scripts/
Dockerfile, example-store.test.ts:1) and the docker wrapper already has a
`$HOME/ponytail` mount hook. OpenCode support now exists (@dietrichgebert/ponytail
plugin + AGENTS.md auto-load; commands /ponytail lite|full|ultra|off,
/ponytail-review, /ponytail-audit, /ponytail-debt which harvests `ponytail:`
comments). Agentic benchmark (Haiku 4.5, n=4, 12+6 tasks): -54% LOC / -22% tokens
/ -20% cost / -27% time, safety 100% (only "one-liner" prompt dropped a guard).

(B) **headroom** (chopratejas/headroom, Apache-2.0, 66.4k stars): local proxy /
library compressing tool outputs, logs, files before the LLM; SmartCrusher (JSON)

- CodeCompressor (AST) + Kompress-v2-base (text); reversible CCR; `headroom wrap
opencode` supported. Measured: 60-95% on JSON, 15-20% coding agents; real
  workloads 47-92%; accuracy preserved (GSM8K +/-0.000); reproducible
  `python -m headroom.evals suite --tier 1`. Never installed here.

Why it matters: token/cost efficiency on the Go subscription (68-86K cached-read
tokens per request on deepseek-v4-flash/kimi-k3); consistency of the living
ponytail convention; both tools have real benchmarks vs DCP's vendor-only claims.

Key risk to resolve BEFORE enabling headroom: provider interception. All Go
models hit OpenAI-compatible endpoints (opencode.ai/zen/go/v1/\*) and Copilot has
its own auth flow - a local proxy must override baseURL without breaking auth.
Go bills cached reads separately ($0.0028-$0.50 per 1M): compression that busts
prompt-cache prefixes could cost MORE than it saves. CacheAligner exists
precisely for this, but ROI must be measured, not assumed.

## Verification

- [ ] Section-10 gate complete: @ai-specialist findings registered in learnings; EBDV (DIA-115) with >=2 genuine variants + chosen variant documented in this ticket
- [ ] Feasibility spike recorded: headroom proxy CAN intercept opencode-go / github-copilot traffic via baseURL override; auth intact; per-request cached-read cost delta measured before/after
- [ ] ponytail active: ruleset injected every turn; /ponytail commands registered; zero dangling skill refs; `make test-config` green (18/18 skills, agent-name lockstep)
- [ ] `ponytail:` convention documented (AGENTS.md/commands); /ponytail-debt run produces the deferred-ledger from the 7 existing comment sites
- [ ] headroom (if spike passed): `headroom doctor` healthy; measured savings via headroom perf/dashboard with holdout control; one real task run with and without shows no quality regression
- [ ] @ai-auditor review passed; CHANGELOG + learnings outcome updated; @memory-manager registered

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
