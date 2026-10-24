# Analysis Report: P5 jsonl-Cross-Check Readiness

**Report ID**: ana008
**Date**: 2026-08-06
**Campaign**: "Silent session logging" (m0001) — Phase 5 validation readiness
**Analyst**: @analyzer (self-reported read-only; persistence folded into the cod P5 smoke gate-fix lane)
**Inputs**: ground-truth disk inspection of `.opencode/session/registry.jsonl` + `.opencode/session/messages.jsonl`, direct orchestrator verification, prior gate tool review (rev-1 APPROVE)

## Executive Summary

**Verdict**: The P5 gate tool is **healthy but gated on a poisoned universe**. The plugin itself captures every smoke delegation (7/7 smoke rows = 100% match), but the cross-check completeness formula computed **3.35%** because the universe was **ALL registry task_success rows (209 total)** — of which **202 (96.7%) are pre-plugin legacy rows** (seq 1-682, timestamps 2026-08-04/05) written by the legacy orchestrator before the messages.jsonl plugin writer existed.

**Root cause**: Legacy registry rows are **structurally unmatchable** — their messages rows carry no `gen_ai.agent.id`, so the join key is absent. No amount of plugin health fixes this; the universe must be scoped to what the plugin observes.

**Fix (owner-approved)**: **timestamp filter** — universe = registry task_success rows with `timestamp >= 2026-08-06T19:30:00Z` (the plugin messages-writer activation boundary; first plugin-written messages row was `2026-08-06T19:30:20.746Z`). Plus a **report-split diagnostic** (legacy vs plugin row counts reported separately for transparency).

## 1. The Problem — Measured

| Metric | Value |
|---|---|
| Registry task_success rows (universe before fix) | 209 |
| Legacy pre-plugin rows (seq 1-682, 2026-08-04/05) | 202 (96.7%) |
| Smoke plugin rows (2026-08-06T19:39+) | 7 (3.3%) |
| Completeness with old formula (matched/universe) | 3.35% → FAIL |
| Plugin health (smoke-only cross-check) | 7/7 = 100% → healthy |

**Why legacy rows are unmatchable**: the messages.jsonl plugin writer (delegation-observer.ts `appendMessageRow`) writes the `gen_ai.agent.id` field. Legacy orchestrator messages rows have **no `gen_ai.agent.id`** — the join key does not exist for them. Timestamps also routinely fall outside the ±5s tolerance (round-minute legacy vs millisecond plugin rows). Both failure modes are structural, not transient.

## 2. Discriminator Correction (owner-verified)

The initial recommendation was a `writer=="plugin"` filter. **Owner-verified NO-OP**: **all 704 registry rows (including legacy) already carry `writer:"plugin"`** because the registry IS the plugin's original output — the plugin has been writing registry.jsonl since the start, but only began writing messages.jsonl at 19:30:20Z on 2026-08-06. The registry rows and the messages rows come from *different* writers over different eras:

| Era | registry.jsonl writer | messages.jsonl writer | messages row has gen_ai.agent.id? |
|---|---|---|---|
| Legacy (seq 1-682, 08-04/05) | plugin (registry) | legacy orchestrator | NO |
| Plugin era (seq 683+, 08-06T19:39+) | plugin (registry) | plugin (messages) | YES |

**The only reliable discriminator is TIMESTAMP**: the plugin messages-writer activation boundary at `2026-08-06T19:30:00Z` (clean minute boundary; actual first row `19:30:20.746Z`).

## 3. Recommendation (owner-approved)

1. **Timestamp filter** — universe = registry task_success rows with `timestamp >= 2026-08-06T19:30:00Z` (default `--since`; overridable for future eras).
2. **Report split** — the gate summary reports legacy vs in-universe row counts separately, so the exclusion is transparent and auditable.
3. **Fail-loud on empty in-universe** — zero in-universe rows must exit 2 (must not mask a dead plugin).
4. **Keep join/tolerance intact** — task_id ↔ `gen_ai.agent.id`, ±5s, threshold ≥99%.

**Forecast after fix**: universe = 7 smoke rows (2026-08-06T19:39+) → 7/7 = 100% → **PASS**. Verified in the implementing lane: real-data run reports **8/8 = 100% PASS** (registry had grown to 8 smoke rows by run time).

## 4. Implementation Status

- `.opencode/scripts/jsonl-cross-check.sh`: `--since` flag (default `2026-08-06T19:30:00Z`), timestamp-filtered universe, report split, exit 0/1/2 — implemented in cod P5 smoke gate-fix lane.
- `scripts/__tests__/jsonl-cross-check.bats`: 12 cases (7 original + 5 new hermetic) — green.
- Real-data gate (defaults): **PASS, 8/8 = 100%**.
