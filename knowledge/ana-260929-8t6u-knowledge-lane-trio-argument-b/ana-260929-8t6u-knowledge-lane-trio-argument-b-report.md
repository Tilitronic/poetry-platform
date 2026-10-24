# Knowledge Lane Trio: Are Three Lanes (researcher / conspecter / analyzer) Needed, or Can Two Suffice?

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: recommendation
evidence-source: .opencode/opencode.jsonc
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

- Campaign ticket: DIA-260929-nc6w (agent-role consolidation study, question set 2)
- Lane: analyzer (argument-b). Sibling lanes a/c deliberately unread (independence protocol).
- Date: 2026-09-29. Methods: MECE decomposition of the three pairing questions,
  inversion ("what mechanically dies if a lane is deleted"), evidence-counting.
- Bias note: the authoring lane (analyzer) is itself one of the three subjects.
  See section BIAS CONTROL.

---

## 1. ARGUMENTS

A1. CLAIM: The three lanes form one strict serialization chain, and its transitions
    are enforced by three name-keyed mechanical artifacts; deleting a lane deletes
    a gate, not just a role.
    EVIDENCE: .opencode/plugins/delegation-observer.ts:2435-2441 (DIA-212 autocrine
    gate: warns when @researcher is dispatched without a pre-allocated res ID);
    delegation-observer.ts:2917-2996 (conspect-pending.json dropped on completed
    researcher task); delegation-observer.ts:3002-3051 (analysis-pending.json
    dropped on completed conspecter task); orchestrator_append.md:301-305 (A6
    serialization point 2: researcher -> conspecter, "PERSISTENCE_RECOMMENDED
    triggers conspecter dispatch only after researcher returns");
    research-pipeline/SKILL.md:34-41 (Phase 2 hard gate on .source-urls.txt) and
    :71-78 (Phase 5 analysis gate).
    STRENGTH: high - the enforcement is plugin code plus a cleared-by-script
    (scripts/pending-gate-clear:20,83) gate pair, not prose.
    FALSIFIER: evidence that the pending-gate files and A6 point are routinely
    bypassed in practice (e.g., analyzers dispatched while analysis-pending.json
    is present and unverified). Not observed in the sampled files.

A2. CLAIM: The conspecter's network air-gap (D7) is the only mechanically enforced
    Archive-Before-Claim guarantee in the knowledge pipeline, and every merge
    involving the conspecter must dissolve it or dissolve Phase A.
    EVIDENCE: .opencode/opencode.jsonc:581-593 (conspecter: edit knowledge/* only,
    bash FLAT deny, webfetch deny, task deny - the unique permission combo
    "writes knowledge/ but cannot reach the network"); conspecter.md:14-20,76-84
    (DIA-135 D7, native block since commit f85bdd7 2026-08-11, D7-modified
    2026-08-14); CHANGELOG.yaml entry DIA-135 2026-08-14 ("research-pipeline
    optimization: ... double source fetch ... closed"); research-pipeline/SKILL.md:64
    ("NO network fetch - curl/trafilatura/crwl/playwright are revoked").
    STRENGTH: high - a permission-set fact, dated commit, and changelog entry.
    FALSIFIER: measurement showing conspects written by a network-capable lane
    still pass the sources-manifest check at the same rate; if contract-level
    discipline suffices, the permission-level guarantee is ceremony. No such
    measurement exists yet (open question O2).

A3. CLAIM: Permission-wise, researcher+analyzer is the only compatible merge
    pairing; researcher+conspecter is a direct permission conflict and
    conspecter+analyzer breaks D7 by the analyzer's unrestricted bash.
    EVIDENCE: opencode.jsonc:270-277 (analyzer bash "allow" - a superset of the
    researcher's allow-list curl/wget/trafilatura/crwl at :535-541; both write
    knowledge/*); vs :589-590 (conspecter bash+webfetch deny vs researcher's
    network allow-list - a merged lane can hold at most one of these).
    STRENGTH: high for feasibility as a permission fact; note feasibility is not
    desirability (A1, A4, A6 give the countervailing costs).
    FALSIFIER: a discovered hard dependency of the researcher MCP surface
    (context7, gh_grep - researcher.md:42-44) on the researcher name itself;
    MCPs are preset-level assignments (oh-my-opencode-slim.jsonc preset rows),
    so none was found.

A4. CLAIM: The trio is a low-traffic tail; merging saves roughly one dispatch hop
    and cents per run, while the name-keyed machinery a merge must re-edit spans
    ~194 references across nine project-owned files plus two plugin lane-sets.
    EVIDENCE: counts per name (grep, 9 core files: AGENTS.md, opencode.jsonc,
    oh-my-opencode-slim.jsonc, delegation-observer.ts, validate-output-contracts.sh,
    validate-agent-names.sh, research-pipeline/SKILL.md, orchestrator_append.md,
    .opencode/agents/): researcher 77, conspecter 58, analyzer 59 lines;
    delegation-observer.ts:294-301 (READ_ONLY_LANES includes researcher;
    WRITER_LANES = analyzer, conspecter, memory-manager); frequencies in section 3
    (analyzer 44, researcher 30, conspecter 20 delegation rows over ~5.5 weeks);
    validate-agent-names.sh:1-27 (S1-S4 lockstep; drift fails make test-config).
    STRENGTH: high on the frequency and set-membership numbers; medium on the
    grep count as blast radius (line count overstates semantic sites, understates
    learnings/CHANGELOG/shelf/test references).
    FALSIFIER: lane volume rising ~10x (hop savings become material), or a
    demonstration that a merge touches only the lane's own agent file.

A5. CLAIM: The researcher+conspecter pair is the pipeline's load-bearing core,
    because DIA-135 deliberately kept them split while fixing the double-fetch
    defect - the merge was considered, and ownership transfer (D5), not lane
    fusion, was the chosen remedy.
    EVIDENCE: researcher.md:9 ("This single-fetch ownership structurally
    eliminates the double-fetch defect"); CHANGELOG.yaml DIA-135 entry 2026-08-14
    (D1 reorder, D5/D6/D7 developer-approved via section-10);
    memory-shelf.yaml:229-247 (conspect res024 = DIA-135 lane-optimization
    research: "both researcher (volume retrieval) and conspecter (long-context
    MLA synthesis)" have divergent model profiles; EBDV recommendation R2
    retained the split with retuned temp/routing).
    STRENGTH: high - dated Tier-1 ledger entries recording the alternative and
    the decision against it.
    FALSIFIER: the res024 profile finding being obsolete (one current model now
    fits both roles at both price points), making the split purely ceremonial.

A6. CLAIM: Merging the researcher into the analyzer degrades two batch-dispatch
    mechanics: the researcher's read-only fan-out class and the separation
    between fetch volume and analysis routing profiles.
    EVIDENCE: delegation-observer.ts:294 (researcher in READ_ONLY_LANES enables
    approved batch A = parallel read-only fan-out); :301 (analyzer in
    WRITER_LANES - "at most ONE writer may appear in a batch", rule B, mirrored
    in oh-my-opencode-slim.jsonc BATCH-DISPATCH rule and AGENTS.md 2.5/9 routing);
    preset profiles: analyzer variant high + 7 skills vs researcher variant
    medium temp 0.3 (oh-my-opencode-slim.jsonc per-preset agent blocks; DIA-135
    C3 temp band for synthesis 0.1 on conspecter). [INFERENCE] the loss of
    parallel fan-out follows from set membership, not from a measured incident.
    STRENGTH: medium - the set-membership facts are high-confidence; the
    practical cost of losing fan-out is unmeasured (researcher batch usage not
    counted).
    FALSIFIER: registry/history showing @researcher is almost never dispatched
    in parallel batches - then batch A membership buys nothing and this argument
    collapses to routing-only.

A7. CLAIM: If exactly two of the three lanes must survive, the pair that keeps
    both structural invariants (A6 serialization chain + D7 air-gap) is
    conspecter + analyzer, absorbing Phase A capture into the analyzer's already
    unrestricted bash; what is lost is cheap volume-retrieval routing, the
    read-only fan-out class, the DIA-212 autocrine gate, and cross-lane
    independence between the lane that fetches and the lane that analyzes.
    EVIDENCE: A3 (analyzer permission superset absorbs the 3-tier chain - it is
    literally bash-allow); A2 (conspecter must survive for the air-gap);
    delegation-observer.ts:2435 (autocrine gate is keyed on subagentType
    "researcher" and dies with the name); :3720-3722 (ACTION_MAP routes
    workflow state "research" to next_agent "researcher" - re-keying required);
    stats-db window: researcher $0.33/18 sessions vs analyzer $0.51/27 sessions
    (section 3) - folding retrieval into the higher-variant lane raises unit cost.
    [INFERENCE] label applies only to the claim that conspecter re-verification
    still functions as an independent grounding hop when the fetcher is also the
    eventual analyst - it does, because the conspecter cannot see the web and
    must cite only the archived manifest.
    STRENGTH: medium - the mechanics are evidenced; the ranking against keeping
    researcher+analyzer (losing A2 instead) is a judgment call on which
    invariant is worth more, resolved here toward correctness-grounding over
    efficiency.
    FALSIFIER: observing that grounding failures (cited-but-unarchived sources)
    never occur without the air-gap, or that retrieval cost/independence loss
    exceeds it. Neither observed nor excluded - see O2, O3.

A8. CLAIM: Any merge is a section-10 class config-chain change, not a file
    deletion, because four validator/gate systems key on the lane names.
    EVIDENCE: scripts/validate-agent-names.sh:1-27 (S1 AGENTS.md section 9 table,
    S2 opencode.jsonc agent block, S3 OMO presets, S4 agents/*.md; drift fails
    make test-config); scripts/validate-output-contracts.sh:27-28,98,147 (M1
    agent must be 'analyzer', M2 agent must be 'conspecter' - hard-coded asserts);
    AGENTS.md 2.5 (config-change chain: ai-specialist gate -> learnings ->
    coder -> test-config -> ai-auditor -> CHANGELOG); DIA-260831-h3i4 precedent
    for disabling built-ins in that same lockstep (AGENTS.md section 9 notes).
    STRENGTH: high - direct file evidence.
    FALSIFIER: none plausible unless the validators are made name-agnostic first.

---

## 2. SUB-QUESTION EVIDENCE

### 2.1 Contract of each lane today (sub-question 1)

| Dimension | researcher | conspecter | analyzer |
|---|---|---|---|
| Purpose | external retrieval + Phase A source capture | pure synthesis of archived sources | multi-method analysis + visualization |
| edit scope | knowledge/* only (jsonc:531-534) | knowledge/* only (jsonc:585-588) | knowledge/* only (jsonc:271-274) |
| bash | allow-list: curl/wget/trafilatura/crwl, else deny (jsonc:535-541) | FLAT deny (jsonc:589) | ALLOW (unrestricted, jsonc:275) |
| network (MCP/webfetch) | websearch + context7 + gh_grep (researcher.md:42-44; preset mcps) | webfetch DENIED (jsonc:590; conspecter.md:16) | websearch MCP via presets; webfetch not denied |
| task | denied (jsonc:542) | denied (jsonc:591) | denied (jsonc:276) |
| Artifacts | sources/*.md + sources/.source-urls.txt manifest (+ findings in conversation) | res<id>-topic-conspect.md with M2 header | ana<id>-topic-report.md with M1 header |
| Invocation trigger | research-pipeline Phase 2; quick web research handoff (analyzer.md:68; openspec-plan preset prompt); autocrine gate requires pre-allocated res ID (DIA-212) | pipeline Phase 4, auto-proceed after Phase 2 hard gate + Phase 3 quality gate - no developer decision (SKILL.md:42-56) | pipeline Phase 5 after analysis-pending cleared; trade-off analysis recommendation; direct orchestrator dispatch (most common) |
| Shelf registration | none (findings in conversation; persistence decision via PERSISTENCE_RECOMMENDED) | delegated to @memory-manager (DIA-143 sole writer; shelf.conspects, memory-shelf.yaml:2) | delegated to @memory-manager (analyzer.md:26-28; shelf.analyses, memory-shelf.yaml:544) |
| Model routing | variant medium, temp 0.3 (presets; DIA-135 R2) | variant medium, temp 0.1, no skills/mcps (DIA-135 C3) | variant high, 7 skills (teaching, mermaid-diagramming, console-charting, data-reducer, ...), websearch mcp |

### 2.2 What exists in exactly one lane (sub-question 2)

- Phase A ownership: 3-tier chain + per-source relevance/reliability manifest +
  PERSISTENCE_RECOMMENDED producer + the "MUST NOT return PERSISTENCE_RECOMMENDED
  before writing .source-urls.txt" checkpoint (researcher.md:49-68): researcher only.
- Air-gapped writing: the permission combination "can create knowledge artifacts,
  cannot reach the network": conspecter only (unique in the whole agent table -
  analyzer and researcher both reach knowledge/ AND the network).
- Unrestricted bash among knowledge lanes (python/plotext/mermaid-cli analytics):
  analyzer only.
- READ_ONLY_LANES batch-A membership among the trio: researcher only (A6).

### 2.3 Dependency structure (sub-question 3)

```
orchestrator (Phase 1: scripts/allocate-id res)
   |
   v
@researcher  --completes--> plugin drops .opencode/session/conspect-pending.json
   |            (delegation-observer.ts:2935-2966; A6 point 2 serializes)
   v
@conspecter  --completes--> plugin drops .opencode/session/analysis-pending.json
   |            (delegation-observer.ts:3018-3030)
   v
orchestrator verifies artifacts, clears gate via scripts/pending-gate-clear
   v
@analyzer  (consumes the conspect, NOT raw findings - SKILL.md:76)
   v
@memory-manager (sole shelf writer, DIA-143; memory-manager.md + jsonc:560-570)
```

- Researcher feeds conspecter (only through on-disk sources/, never conversation).
- Conspecter feeds analyzer (only through the verified conspect).
- Analyzer feeds nothing in the chain; it is a terminal artifact producer.
- The researcher also serves non-pipeline callers (quick web research,
  openspec-plan interviews) - it is NOT conspecter-only infrastructure.
- The analyzer serves non-pipeline callers too (trade-off analysis, audits -
  43 ana artifact dirs on disk vs 16 datetime-form res dirs + 61 conspect files
  across all naming eras).

### 2.4 Invocation frequency (sub-question 5) - two independent sources

Source 1: .opencode/session/messages.jsonl delegation rows (reduced in-worker;
file 54,417,326 bytes, 130,194 lines; window 2026-08-21T05:17Z to
2026-09-29T01:29Z, ~5.5 weeks):

| lane | delegations |
|---|---|
| coder | 1101 |
| memory-manager | 106 |
| reviewer | 105 |
| analyzer | 44 |
| researcher | 30 |
| conspecter | 20 |

Source 2: `bash scripts/session-analytics.sh --view agents` (opencode stats db,
subagent sessions, longer lifetime window): analyzer 27 sessions / $0.51 /
702,503 in-tokens; researcher 18 / $0.33 / 2,039,430; conspecter 14 / $0.09 /
511,775. (Full window of the db not stamped by the script - [INFERENCE] it is
at least as long as source 1's.)

Corroboration ratio: conspecter runs are ~66% of researcher runs - about a third
of research dispatches end conversationally without persistence, so the
conspecter is not a fixed companion of every researcher run. registry.jsonl was
NOT used (known unreliable per dispatch brief; neither source was consulted).

### 2.5 Cost/benefit of three vs two (sub-question 6)

Concrete recurring savings of a 2-lane merge:
- ~1 orchestrator hop per pipeline completion (Phase 4 dispatch + its pending
  gate), 20 runs in the 5.5-week window -> ~4 hops/week saved, only on the
  persistence path.
- ~$0.09-0.33 per merged run in marginal model cost (source 2); combined trio
  cost across the db window is $0.93 total - an order of magnitude below even
  the memory-manager line ($0.31) and trivial next to coder (24M in-tokens).
- Maintenance: -1 agent file, -4 preset blocks (one per preset), -1 AGENTS.md
  section 9 row, -1 pending-gate writer, -~60-77 name references.

Concrete losses (pairing-specific):
- Drop conspecter: the D7 air-gap, the only mechanical Archive-Before-Claim
  enforcement (A2), plus the M2 contract validator target.
- Drop researcher: read-only fan-out class for retrieval, volume-vs-analysis
  routing split, autocrine gate, fetch/analyze independence (A6, A7).
- Drop analyzer: the most-used lane (44 vs 30 vs 20), the only unrestricted-bash
  knowledge lane, the M1 report contract, 43 artifact dirs, the escalated
  sub-lane's base (analyzer-escalated.md clones analyzer permissions;
  jsonc:289-305) - largest functional loss of the three.

One-time merge cost dominates recurring savings at current volume: a merge is
an AGENTS.md 2.5 chain (ai-specialist gate, learnings registration, coder
implementation, make test-config, ai-auditor review, CHANGELOG entry) touching
9+ name-keyed files (A4, A8).

---

## 3. EBDV (DIA-115) - decision variants

V1. STATUS QUO (abort the consolidation for this trio). Keep three lanes;
    optionally document the invariant rationale as an ADR.
    Evidence: A1, A2, A5, A8; DIA-135 precedent (CHANGELOG 2026-08-14; res024
    shelf entry). Pros: zero regression risk; keeps both mechanical invariants;
    preserves routing granularity and batch-A fan-out. Cons: ~$0.93 lifetime
    extra cost and 3 agent files / 12 preset blocks / 3 table rows to keep in
    lockstep. Effort: near zero (documentation only, ~1h).
    Section-10 routing: NO (doc-only) / YES if any config touched.
    RECOMMENDED.

V2. MERGE researcher + conspecter into one network-capable synthesis lane.
    Evidence-for: adjacent contracts; conspecter is the rarest/cheapest lane
    (section 2.4); researcher already owns source evaluation (D5/D6).
    Evidence-against: A2/A3 (permission conflict - the merged lane must hold
    curl/wget/trafilatura/crwl, dissolving the D7 air-gap), A5 (DIA-135
    deliberately rejected this shape), res024 divergent model profiles.
    Pros: removes 1 hop + 1 gate on the persistence path; single fetch owner
    already merged. Cons: Archive-Before-Claim demotes from permission-level to
    prompt-level; ~135 name references re-edited across 9 files; validator
    churn (M2 agent field, plugin sets, autocrine gate re-key). Effort:
    M (1 section-10 chain, est. 6-10h). Section-10 routing: YES.

V3. MERGE researcher into analyzer (keep conspecter + analyzer = the forced-two
    answer, A7). Evidence-for: A3 permission superset fit - no new permission
    surface needed; conspecter air-gap and the grounding hop survive; M2
    validator untouched. Evidence-against: A6 (loses batch-A read-only fan-out
    for retrieval, coarser routing, higher per-run cost), A7 (fetcher == final
    analyst within one lane family), ACTION_MAP + autocrine gate +
    conspect-pending trigger re-keying. Pros: -1 lane with no invariant loss on
    grounding; retrieval rides existing bash. Cons: efficiency and independence
    losses above; ~77 researcher references + plugin re-keys. Effort: M-L
    (est. 8-14h incl. re-tests of plugin gate paths). Section-10 routing: YES.

V4. MERGE analyzer + researcher the other direction (drop analyzer, keep
    researcher + conspecter). Evidence-against: A4 frequencies (loses the most
    dispatched lane, 44 rows), no unrestricted bash anywhere in the surviving
    pair for data analytics/visualization (jsonc:535-541 allow-list and :589
    flat deny), analyzer-escalated becomes orphaned (analyzer-escalated.md;
    jsonc:289-305), M1 validator target dies. Effort: M. Section-10: YES.
    NOT RECOMMENDED except under a two-lane hard constraint that also forbids
    V3.

Abort/status-quo variant is V1 per the DIA-115 rule.

---

## 4. VERDICT

Keep three lanes (V1 status quo). Because: both cost-side and benefit-side
evidence point the same way - the recurring saving is cents and one hop on a
low-traffic tail (three-lane total: 94 delegations in 5.5 weeks vs coder's
1101; $0.93 lifetime db cost), while each candidate merge deletes a named
mechanical invariant: V2 deletes the only air-gapped artifact writer (D7,
opencode.jsonc:581-593, dated commit f85bdd7 + CHANGELOG DIA-135), and V3
deletes the read-only fan-out class plus retrieval/analysis routing split that
DIA-135's own lane-optimization research (res024) priced and chose to keep.
The one-time merge cost (a full section-10 chain over ~194 name references and
two plugin lane-sets) exceeds years of savings at observed volume.
If the developer imposes a hard two-lane constraint anyway, V3 (conspecter +
analyzer survive) is the least-damaging: it preserves the grounding invariant
(A2) at the price of efficiency and cross-lane independence (A6, A7) - losing
the analyzer (V4) is the worst option by frequency and capability-surface
evidence.

---

## 5. BIAS CONTROL (sub-question 7)

- This report is authored by the analyzer lane, one of three subjects. The
  verdict "keep all three" is bias-neutral (it retains the author either way,
  but also retains both rivals).
- The V3 forced-two recommendation (analyzer survives, researcher dissolves)
  IS self-favoring on its face and must be read as such. Strongest counter-
  case, not straw: the researcher is the most operationally distinct lane
  (uniquely owns Phase A + PERSISTENCE_RECOMMENDED + batch-A fan-out), and
  A5's DIA-135 research treated researcher/conspecter as the priced core - so
  an unbiased forced-two might instead keep researcher + conspecter and route
  analysis through... nothing, since no surviving lane has bash for analytics
  (jsonc:258-261, 535-541, 589). The counter-case dies on capability, not on
  preference; that is why V3 is argued from A2/A6 mechanics. Flagged anyway:
  the tie-break between "grounding invariant worth more" (A2 > A6) is a value
  judgment where self-favoring could hide. [INFERENCE] marker applied in A7.
- A6's practical cost is unmeasured (no count of researcher batch-A usage);
  that number happens to cut against dissolving the researcher - it should be
  measured before any V3 action.

## 6. OPEN QUESTIONS

- O1: How often is @researcher dispatched in parallel batch-A fan-outs vs
  solo? A direct count over delegation rows would settle A6's unmeasured half.
- O2: Do any recorded conspect failures show cited-but-unarchived sources? If
  the air-gap has never caught anything, A2's invariant is empirically cheap to
  lose - check failures.md / lessons.md for conspecter-era incidents.
- O3: The stats-db window in source 2 is unstamped by session-analytics.sh;
  exact lifetime totals per lane would tighten A4/A7 cost claims.

## 7. VISUAL SUMMARY

Merge-feasibility matrix (Y = mechanically compatible, X = deletes a named invariant):

```
pairing                     permissions   invariants kept        verdict
------------------------------------------------------------------------
researcher+conspecter (V2)  X conflict    air-gap D7 LOST        not recommended
researcher+analyzer  (V3)   Y superset    grounding kept,        fallback only
                                           fan-out/routing lost
conspecter+analyzer         X conflict    air-gap D7 LOST        infeasible
none (V1 status quo)        -             both kept              RECOMMENDED
```

Pipeline gate topology (mechanical, name-keyed):

```
allocate-id -> @researcher ==complete==> conspect-pending.json  [plugin:2966]
     | autocrine warn [plugin:2435, DIA-212]
     v
@conspecter   ==complete==> analysis-pending.json      [plugin:3030]
     v
orchestrator clears gate (pending-gate-clear) -> @analyzer -> @memory-manager
```
