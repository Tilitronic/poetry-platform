# DIA-261125-mu6w - model-registry backfill for kimi-k3.1-pro and qwen4-max (pricing, context window, quota notes) and routing_table Rung4 still names gpt-5.3-codex for the reviewer lane

---

id: DIA-261125-mu6w
title: "model-registry backfill for kimi-k3.1-pro and qwen4-max (pricing, context window, quota notes) and routing_table Rung4 still names gpt-5.3-codex for the reviewer lane"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-11-25
source: inventory
date: 2026-11-25
created: 2026-11-25
updated: 2026-11-25

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

Follow-up to DIA-261112-exon commit fc1a15f8 (dead-fallback repair + registry
rows). Two documentation defects were deliberately left unfixed there.

1. `knowledge/model-registry.yaml`: the two new rows for
   `opencode-go/kimi-k3.1-pro` and `opencode-go/qwen4-max` were added with
   `swe_bench_verified: null` and NO pricing or context-window fields, because
   no in-repo evidence existed and the dispatch forbade inventing figures. The
   local catalog at `~/.cache/opencode/models.json` carries cost fields and is a
   candidate source (it is also the live source `opencode models` reads); a
   fresh models.dev fetch is an alternative. Backfill `price_in_1m`,
   `price_out_1m`, `req_per_month`/quota notes, and context window only from a
   citable source, recording the source in `source_ref`.

2. `knowledge/model-registry.yaml` `routing_table` Rung4 (around line 325)
   still names `gpt-5.3-codex` for the reviewer lane, while the preset reviewer
   is now `opencode-go/kimi-k3.1-pro` with `opencode-go/qwen4-max` fallback
   (DIA-261112-exon). Align Rung4 with the preset, or record why the rung is
   intentionally pinned.

## Verification

- [ ] kimi-k3.1-pro row carries substantiated pricing/quota/context with a
      citable `source_ref`, or an explicit note why each remains null.
- [ ] qwen4-max row ditto.
- [ ] Rung4 reviewer model matches the preset reviewer primary/fallback, or
      the divergence is documented in the rung comment.
- [ ] `bash scripts/validate-changelog.sh` and
      `bash scripts/validate-model-ids.sh` still exit 0.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
