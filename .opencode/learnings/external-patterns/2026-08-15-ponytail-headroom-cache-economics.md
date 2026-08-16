---
date: 2026-08-15
topic: prompt-cache economics for context compression - DCP degrades cache, ponytail is safe, headroom cache-mode preserves prefix
source: ai-specialist phase-1 gate (DIA-183), web-fresh fetches 2026-08-15
ticket: DIA-183-ponytail-headroom-context-compression
status: active
---

# Prompt-cache economics for context compression (DIA-183 Phase 1 gate findings)

## 1. FACT: the current DCP configuration ALREADY degrades the prompt cache

DCP (opencode-dynamic-context-pruning, @tarquinen/opencode-dcp@3.1.14 in the project
plugin array) documents its own cache impact: "cache hit rates approximately 85% with
DCP vs 90% without". The author has moved development to Sleev. So the ticket's central
concern ("compression busts the cache prefix and could cost more than it saves") is
ALREADY partially true under the current config - a documented ~5% cache-hit degradation
is being eaten today with no upside.

## 2. FACT: cache miss is catastrophically expensive on DeepSeek V4 Flash

- DeepSeek V4 Flash pricing (api-docs.deepseek.com/quick_start/pricing, 2026-08-15):
  cache hit $0.0028/1M input vs cache miss $0.14/1M input - a **50x ratio**. Peak/off-peak
  split effective 16:00 UTC 2026-08-16.
- Go subscription typical request: DeepSeek V4 Flash - 790 input, 68,000 cached, 280
  output tokens per request = **86% cached tokens** (opencode.ai/docs/go, 2026-08-15).
- DeepSeek KV-cache prefix rule (api-docs.deepseek.com/guides/kv_cache): a request only
  hits the cache if it fully matches a cache prefix unit; cache is "best-effort", no
  100% guarantee.
- Implication: ANY mid-conversation mutation of earlier context (compression, compaction,
  system-prompt change) busts the prefix for all subsequent turns in that conversation.

## 3. FACT: ponytail is a zero-cache-interaction parallel win

`@dietrichgebert/ponytail` (103.3k stars, MIT) is a pure ruleset injection - one-line
plugin-array append, no proxy, no message mutation, zero cache interaction. Benchmarks
(agentic Haiku 4.5, n=4): -54% LOC, -22% tokens, -20% cost, -27% time, 100% safety.
Resolves 7 dangling `ponytail:` comment sites already present in the repo.

## 4. FACT: headroom cache-mode is the ONLY tool whose default preserves the prefix

`chopratejas/headroom` (66.4k stars, Apache-2.0): `cache` mode (default) "compresses
only the newest delta in each turn and forwards prior turns byte-faithfully, so the
provider's prefix cache is never invalidated mid-conversation". CacheAligner is a
read-only drift detector (off by default, never mutates). BUT: preservation through the
opencode-go proxy endpoint (opencode.ai/zen/go/v1/*) is UNVERIFIED - that is the
feasibility spike's job.

## 5. EBDV recommendation (DIA-183, 2026-08-15)

Variant D (ponytail + spike parallel) recommended: add ponytail immediately (safe,
benchmarked -20% cost, zero cache interaction, resolves dangling comment refs) AND run
the 1-day headroom feasibility spike in parallel (measure actual cache-hit rate with and
without compression on a controlled overnight AFK campaign). If the spike proves
headroom cache-mode preserves prefix byte-identity on the opencode-go endpoint AND net
cost delta is positive, enable headroom --mode cache with CacheAligner as read-only
monitor. Variant B (ponytail-only) is the conservative fallback; Variant A (status quo)
is NOT recommended - it accepts a documented 5% cache degradation with no upside.

## 6. Sources (all Tier-2 dated URLs, fetched 2026-08-15)

- https://opencode.ai/docs/go/ (Go pricing + typical request 86% cached)
- https://api-docs.deepseek.com/quick_start/pricing (50x cache miss vs hit)
- https://api-docs.deepseek.com/guides/kv_cache (best-effort prefix matching)
- https://github.com/Opencode-DCP/opencode-dynamic-context-pruning (85% vs 90%, moved to Sleev)
- https://github.com/chopratejas/headroom (cache-mode preserves prefix)
- https://headroom-docs.vercel.app/docs/architecture (CacheAligner never mutates)
- https://github.com/DietrichGebert/ponytail (benchmarks, 103.3k stars)
- knowledge/ana023-ticket-backlog-priority-plan/ana023-ticket-backlog-priority-plan-report.md (Tier-1, L54 scope)
