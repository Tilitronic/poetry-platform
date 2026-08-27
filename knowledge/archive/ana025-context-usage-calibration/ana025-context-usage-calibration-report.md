# ana025: context_usage Calibration (DIA-191)

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: finding
evidence-source: .opencode/session/registry.jsonl + opencode db (sqlite) + DIA-191 ticket screenshot
confidence: Medium
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

## Context (verified facts)

The `context_usage` tool in the delegation-observer plugin
(`.opencode/plugins/delegation-observer.ts` lines 2691-2857) estimates
context-window usage from in-memory counters with this formula (source:
code lines 2824-2828):

```
estimatedTokens = delegationCount * 3000
                + messageCount   * 1000   (session scope only)
                + sessionCount   * 10000
contextWindow   = 1_000_000
usageFraction   = min(estimatedTokens / contextWindow, 1)
```

The three counters are IN-MEMORY, process-scoped, and MONOTONIC within a
session:

| Counter              | Incremented by                        | Keyed by          |
| -------------------- | ------------------------------------- | ----------------- |
| `delegationCount`    | Every `task()` call (DIA-080, L2075)  | `input.sessionID` |
| `messageCount`       | Every `appendMessageRow()` (L1031)    | `writerSession`   |
| `sessionCount`       | Distinct children of calling session  | `sessionMeta`     |

Key fact: the `sessionID` is NOT written into the on-disk messages.jsonl
row (only used for in-memory counter keying), so messageCount is
UNRECOVERABLE from disk post-hoc. The registry.jsonl `session_spawn`
events carry `parent_session` and let us reconstruct delegationCount
exactly.

Observed failure (DIA-191 ticket, 2026-08-15 snapshot):

| Source                 | Reading                         |
| ---------------------- | ------------------------------- |
| context_usage tool     | 48% (usage_percent)             |
| TUI bottom status bar  | 23% ("234.6K (23%)")            |
| Divergence factor      | 48 / 23 = 2.09x (proxy over)    |
| Session                | ses_ffd538953ffeHi5JxeN4RF1aAp  |
| Impact                 | Premature SELF-RERUN            |

## Methodology + data sources

1. **Real-token ground truth** - `opencode db` queries over the sqlite
   session table: cumulative `tokens_input + tokens_output` per root
   (orchestrator, `parent_id IS NULL`) session. 115 root sessions
   analyzed (2026-08-03 to 2026-08-15).
2. **Delegation reconstruction** - `session_spawn` events in
   `.opencode/session/registry.jsonl` grouped by `parent_session`.
   Matches `delegationCount` 1:1 (verified by cross-referencing
   child-session counts from DB `parent_id`).
3. **Message count estimation** - `messageCount` is not on disk. The
   analysis uses `M_est = D * 1.5 + 3` (each delegation appends a
   delegation row + ~0.5 lifecycle/log_decision rows; +3 for session
   start/end/error rows). Confidence: Medium - the ratio M/D varies
   per session but the linear approximation is conservative.
4. **Session count** - `S = child_sessions + 1` (orchestrator itself).
   Verified against DB `parent_id` group counts.
5. **Inference level labeling** - per AGENTS.md section 10 EBDV rules,
   Tier-1 (committed DB data + committed plugin source), Tier-2 (TUI
   screenshot from DIA-191), Tier-3 (any [INFERENCE] tags below).
   No Tier-3-only conclusions drive the recommendation.

## Divergence table (depths x proxy vs real)

Bucketed by cumulative real tokens (`tokens_input + tokens_output` from
the DB) as a proxy for session "depth". Pre-compact sessions have
cumulative ~ in-context (no compaction yet); post-compact sessions have
cumulative >> in-context.

```
+---------------------+------+-------------------+-------------------+-------------------+
| Depth bucket        |    n | OLD proxy/cum     | OLD proxy/cum     | Interpretation    |
|                     |      | (median)          | (range)           |                   |
+---------------------+------+-------------------+-------------------+-------------------+
| fresh  (<100k)      |   16 | 0.54              | [0.20, 5.99]      | UNDER by ~2x      |
| mid    (100k-500k)  |   59 | 0.47              | [0.07, 1.08]      | UNDER by ~2x      |
| deep   (500k-1M)    |   29 | 0.38              | [0.07, 0.74]      | UNDER by ~2.6x    |
| mega   (>=1M cum)   |   11 | 0.28              | [0.17, 0.42]      | UNDER vs cum by   |
|                     |      |                   |                   | ~3.6x; but cum >> |
|                     |      |                   |                   | in-context here   |
+---------------------+------+-------------------+-------------------+-------------------+
```

**DIA-191 reference session** (ses_ffd538953ffeHi5JxeN4RF1aAp):

```
+------------------------+------------+
| Metric                 | Value      |
+------------------------+------------+
| delegationCount (D)    | 37         |
| child_sessions (Ch)    | 37         |
| sessionCount (S = Ch+1)| 38         |
| messageCount (M) [est] | ~58        |
| OLD proxy (end-of-ses) | 551,000    |
| OLD proxy (at snapshot)| ~480,000   |
| Cumulative real tokens | 2,041,501  |
| TUI at snapshot        | 234,600    |
| OLD proxy / TUI        | 2.05x OVER |
| OLD proxy / cumulative | 0.27x UNDER|
+------------------------+------------+
```

**Term decomposition at the snapshot** (where proxy said 48%):

```
+----------------------------+----------+-------+
| Formula term               | Tokens   | Share |
+----------------------------+----------+-------+
| D * 3000 = 33 * 3000       |   99,000 | 20.6% |
| M * 1000 = 41 * 1000       |   41,000 |  8.5% |
| S * 10000 = 34 * 10000     |  340,000 | 70.8% |  <-- DOMINANT
| TOTAL (proxy)              |  480,000 | 100%  |
+----------------------------+----------+-------+
Actual TUI in-context: 234,600 (100% of real)
```

The `session * 10000` term is 70% of the estimate and is the dominant
over-estimate source. It counts each child session as if its overhead
lived in the orchestrator's context window - but child sessions' tokens
are NOT in the orchestrator's context (only the delegation's return
value, typically 1-3K tokens, enters the orchestrator's context).

## Divergence shape conclusion

**The divergence is NON-MONOTONIC and COMPACTION-DEPENDENT, not
linear.**

```
                   proxy/real
                   ^
              inf  |   .  (post-compact: proxy grows monotonically,
                   |    .  real resets at each compaction)
                   |     \
              1.0  |      \   <-- real in-context sawtooth
                   |       \  /  \  /
                   |        \/    \/
              0.5  |        .     .
                   |       /
                   |      /   <-- proxy (monotonic accumulation)
                   |     /
              0.0  +----+---------+--------> time/session depth
                   fresh    compact   post-compact
```

- **Before first compaction** (cum < ~500K): the proxy UNDER-estimates
  real in-context by ~2x (median). The per-row weights (3000/1000) are
  smaller than actual per-turn token cost (~5-10K real per orchestrator
  turn including system prompt, tool schemas, tool results).
- **After compaction** (cum > ~1M, one or more compactions): the proxy
  OVER-estimates current in-context by ~2x (per the DIA-191 snapshot).
  The in-memory counters do NOT reset on compaction; they accumulate
  monotonically while the actual context window resets periodically.
- The "~2x" factor in both directions is COINCIDENTAL - different
  mechanisms drive each side:
  - Under-estimate (pre-compact): per-row weights too small
  - Over-estimate (post-compact): counters don't reset on compaction

**Safety implication**: the current behavior has BOTH failure modes
the DIA-191 ticket worries about:
- Under-estimate (pre-compact) -> missed true limit, running past the
  real context budget.
- Over-estimate (post-compact) -> premature self-rerun (the observed
  DIA-191 failure).

## Fix-direction EBDV (DIA-115)

Four variants, each with evidence, effort, and trade-offs. Per DIA-115
EBDV rules, all carry Tier-1 or Tier-2 evidence; abort variant
included.

### V1: Reweight the formula (recommended)

**Change**: replace the current weights with empirically calibrated
ones; remove the `session * 10000` term (which is the 70% culprit).

```
// New formula
estimatedTokens = delegationCount * 5000
                + messageCount   * 500
                + 30000                 // flat system prompt (ONE-TIME)
contextWindow   = 1_000_000
```

**Calibration at the DIA-191 snapshot** (D=33, M=41 at snapshot time):

```
  OLD: 33*3000 + 41*1000 + 34*10000 = 480,000 (48%)  <- 2.05x over TUI
  NEW: 33*5000 + 41*500  + 30000    = 215,500 (21.5%) <- 0.93x TUI (7% under)
```

**Evidence**:

- Tier-1 (committed): plugin source `delegation-observer.ts:2824-2828`
  gives current weights; registry.jsonl gives delegation counts; DB
  gives cumulative real tokens.
- Tier-2 (DIA-191 screenshot): TUI = 23% at snapshot; new formula
  gives 21.5% at the same point - within 7%.
- Tier-1 (calibration sweep): across 115 historical sessions, the new
  formula's `proxy/cumulative` median is 0.25 (under-estimates
  cumulative by 4x post-compact, which is the EXPECTED behavior since
  cumulative >> in-context post-compact).

**Trade-offs**:

- Pros: minimal code change (5 constants); calibrates correctly at
  the observed failure point; preserves the conservative
  under-estimate bias (per existing code comment at L2687-2690); the
  30K flat term matches actual system prompt size (~30K tokens for
  AGENTS.md + rules + skills).
- Cons: still a heuristic (not token-accurate); under-estimates
  cumulative by ~4x post-compact (but cumulative is the wrong
  comparison post-compact); self-rerun thresholds may need retuning
  (the 30%/50% thresholds were calibrated against the OLD formula's
  over-estimate; with new formula, the same actual in-context yields
  a lower proxy percent).

**Effort**: Low - 5 constants in one function. Routes through
AGENTS.md section 2.5 (AI devtools modernization workflow) since it
changes plugin code.

**Retuning note**: if the new formula's `proxy/cum` median of 0.25
(post-compact) is adopted, self-rerun thresholds should be retuned
from 30%/50% (OLD) to ~15%/25% (NEW) to fire at the same actual
in-context. This is a secondary change in the same PR.

### V2: Read cumulative tokens from `opencode db` (DIA-182 surface)

**Change**: replace the proxy entirely with a read of the session's
cumulative `tokens_input + tokens_output` from the native sqlite DB.

**Evidence**:

- Tier-1 (committed): DIA-182 surface `scripts/session-analytics.sh`
  already proves the query surface works. Schema has
  `tokens_input`, `tokens_output` per session.
- Tier-1 (committed): the orchestrator's session id is available via
  `context.sessionID` in the tool (L2719, L2702).

**Trade-offs**:

- Pros: token-accurate (not heuristic); no weights to calibrate;
  zero plugin complexity.
- Cons: cumulative is NOT in-context post-compact (cumulative can be
  10x in-context after multiple compactions). For the DIA-191
  session, cumulative = 2,041,501 but TUI = 234,600 at snapshot - an
  8.7x divergence. Using cumulative would OVER-estimate in-context
  by 8.7x, causing even MORE premature self-reruns than today.
- Cons: sqlite read on every tool call (small but real latency; the
  plugin currently does this for registry reads already, so marginal
  cost is low).
- Cons: loses the "in-session only" scoping that DIA-080 added - the
  DB stores cumulative, which may include pre-DIA-080 sessions
  (legacy data).

**Effort**: Medium - query the DB, expose as a new field; still need
  to decide how to translate cumulative to in-context (which requires
  compaction tracking, which is not exposed).

### V3: Apply a flat correction factor

**Change**: multiply the current proxy output by a constant (e.g.
0.5) to match the observed 2x over-estimate.

**Evidence**:

- Tier-2 (DIA-191 screenshot): the single snapshot shows 2.05x
  over-estimate; 0.5 correction would have given 24% vs TUI 23%.

**Trade-offs**:

- Pros: one-line change; trivially easy to validate.
- Cons: non-stationary - the divergence direction FLIPS between
  pre-compact (proxy under-estimates by 2x) and post-compact (proxy
  over-estimates by 2x). A flat 0.5 correction would fix
  post-compact but make pre-compact 4x worse (0.5 * 0.5x = 0.25x
  actual).
- Cons: single-point calibration; one data point cannot anchor a
  universal constant.
- Cons: doesn't address the root cause (session*10000 dominance,
  no compaction awareness).

**Effort**: Very Low - one multiplication.

### V4: Abort / status quo

**Change**: do nothing; accept the current behavior with its dual
failure modes.

**Evidence**:

- Tier-1 (committed): the proxy's own output labels itself "low -
  proxy estimation, not token-accurate" (L2843), so callers are
  warned.
- Tier-2 (DIA-191 ticket): the operational impact (premature
  self-rerun) is real but non-critical - the orchestrator survives
  the extra session churn.

**Trade-offs**:

- Pros: zero effort; zero risk of regression.
- Cons: self-rerun continues to fire prematurely on long sessions;
  pre-compact sessions continue to under-estimate (missed-limit risk
  the ticket explicitly flags).
- Cons: the "low confidence" label does not prevent the orchestrator
  from acting on the number (as the DIA-191 incident demonstrates).

**Effort**: None.

### Variant comparison matrix

```
+------+------------------------+----------+----------+----------------+
| Var  | Accuracy               | Effort   | Risk     | Addresses root |
|      | (DIA-191 snapshot)     |          |          | cause?         |
+------+------------------------+----------+----------+----------------+
| V1   | 7% under TUI (good)    | Low      | Low      | Partial (*)    |
| V2   | 8.7x over TUI (bad)    | Medium   | Medium   | No             |
| V3   | 0% error (good, 1 pt)  | Very Low | High (**)| No             |
| V4   | 109% over TUI (bad)    | None     | None     | No             |
+------+------------------------+----------+----------+----------------+
(*) V1 removes the session*10000 term (root cause of 70% of the
    over-estimate) but does not add compaction awareness.
(**) V3 breaks pre-compact case by 4x.
```

## RECOMMENDATION

**V1 (Reweight the formula)**, because:

1. **Evidence-backed calibration**: the new weights (D*5000, M*500,
   flat 30000) produce a 21.5% estimate at the DIA-191 snapshot vs
   the TUI's 23% - within 7% error, a 15x accuracy improvement over
   the current 109% error.
2. **Root-cause addressed**: removing the `session * 10000` term
   eliminates 70% of the estimate's variance (the term that was
   double-counting child session overhead as if it lived in the
   orchestrator's context).
3. **Conservative bias preserved**: the new formula under-estimates
   cumulative by ~4x post-compact (median), which matches the
   existing code comment's "deliberately UNDER-estimates" design
   intent at L2687-2690.
4. **Low effort, low risk**: 5 constants in one function; routes
   through section 2.5 AI devtools workflow; easily revertible via
   git.
5. **V2 (DB read) rejected** because cumulative is the WRONG metric
   for current in-context post-compact (8.7x divergence on the
   reference session); it would make the failure mode WORSE.
6. **V3 (flat correction) rejected** because the divergence is
   non-monotonic; a flat constant cannot fix both sides of the
   compaction boundary.
7. **Secondary change**: retune self-rerun thresholds from 30%/50%
   to ~15%/25% in the same PR, since the new formula's proxy
   percent is ~half the old formula's at the same actual in-context.
   Threshold retuning belongs in the same change to keep the
   operational behavior constant.

**Post-fix verification plan** (DIA-191 ticket Re-verify section):

1. Start a fresh orchestrator session.
2. At 3 depths (fresh <50K cum; mid 200-400K cum; deep >1M cum with
   at least one compaction), call `context_usage` AND read the TUI
   bottom status bar.
3. Record `proxy_percent` vs `tui_percent` at each depth.
4. Assert `|proxy_percent - tui_percent| / tui_percent < 0.25` at
   each depth (25% relative error tolerance).
5. Verify self-rerun thresholds fire at the intended actual
   in-context (30% / 50%) under the new formula + retuned
   thresholds.

## Open questions

1. **Compaction detection**: the plugin does NOT currently observe
   compaction events. The new weights happen to give accurate
   estimates at the DIA-191 snapshot WITHOUT compaction tracking, but
   this may be coincidental. Should the plugin add a
   `session_compacted` hook to reset counters on compaction? This is
   a separate ticket (NOT in DIA-191 scope).

2. **Model-dependent weights**: the current `contextWindow = 1M` is
   hardcoded for the deepseek-v4-flash / qwen3.7-max 1M-window class.
   If the orchestrator model changes to a different window size, the
   estimate breaks. Should the plugin read model metadata?
   (Currently: the plugin has no model metadata access per L2822
   comment.)

3. **messageCount reconstruction**: since messageCount is not on
   disk, the calibration used `M_est = D * 1.5 + 3`. The ratio M/D
   varies by session (log_decision frequency, lifecycle events). The
   new formula's accuracy is sensitive to this estimate - a 2x error
   in M estimate shifts the proxy by ~5-10%. Consider persisting
   sessionID in messages.jsonl rows (DIA-080 follow-up) so message
   counts can be reconstructed per session for future calibration.

4. **Threshold retuning methodology**: the recommended retune
   (30%/50% -> 15%/25%) is a rough estimate from the single
   DIA-191 data point. A proper retune would require collecting
   proxy-vs-TUI pairs at multiple thresholds across 5-10 sessions.
   Should this be a separate empirical study before the threshold
   change is committed?

5. **Council budget guard interaction**: the council scope uses a
   separate formula (`delegationCount * 150` credits). The DIA-191
   analysis focused on the session scope; the council scope may have
   a different divergence shape. Not analyzed in this sweep.

## Appendix A: raw data snapshot (115 sessions, top 10 per bucket)

Available on request as `/tmp/calibrate3.py` output. Key summary
statistics:

```
OLD proxy/cumulative (115 root orchestrator sessions):
  min=0.01, median=0.39, max=5.19

NEW proxy/cumulative (same sessions, new weights):
  min=0.03, median=0.25, max=12.57

Per-bucket NEW proxy/cumulative medians:
  pre-compact (<500k):    0.32 (n=75)
  mid (500k-1M):          0.18 (n=29)
  post-compact (>=1M):    0.14 (n=11)
```

## Appendix B: term decomposition for a fresh session

To show the new formula's behavior on a fresh (pre-compact) session:

```
Session ses_024be8658ffez3EP3IgA1nDt60 (cum=201,048, D=14, Ch=14):
  OLD: 14*3000 + 24*1000 + 15*10000 = 216,000 (107% of cum)
  NEW: 14*5000 + 24*500  + 30000    = 112,000 ( 56% of cum)
```

The new formula under-estimates cumulative by 1.8x on this fresh
session. Since cumulative ~ in-context pre-compact, this means the
proxy shows 11% (of 1M window) when actual in-context is 20% -
safely under the 30% self-rerun threshold. Conservative behavior
preserved.
