# Knowledge Lane Trio: Researcher / Conspecter / Analyzer - Do We Need Three? (Argument Set C)

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: recommendation
evidence-source: .opencode/oh-my-opencode-slim.jsonc
confidence: Medium
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

Campaign ticket DIA-260929-nc6w, second question set, argument set C (independent lane).
This lane is itself a subject of the question (analyzer). Bias handling: section BIAS CONTROL.
Method used: MECE decomposition of the three-lane contract + OODA on merge feasibility +
inversion ("what breaks if a lane is removed") + quantified blast radius and invocation counts.

## 0. CONTRACT OF THE THREE LANES TODAY (sub-question 1)

| Attribute | researcher | conspecter | analyzer |
|---|---|---|---|
| Purpose | External web/docs/library retrieval; owns Phase A source capture | Pure synthesis of already-archived sources into an MLA-cited conspect | Multi-method analysis + terminal visualization, writes report |
| edit scope | `knowledge/*` only | `knowledge/*` only | `knowledge/*` only |
| bash | deny-first, allow-list `curl/wget/trafilatura/crwl` (network capture) | FLAT deny (`bash: "deny"`) | `allow` (unrestricted; can reach network via curl) |
| webfetch | not denied (default-allow); tools list websearch/context7/gh_grep MCPs | explicitly `deny` | not denied; websearch MCP assigned |
| task | deny | deny | deny |
| model tier | variant medium, temp 0.3 | variant medium, temp 0.1, mcps `[]` | variant HIGH, mcps websearch, 7 skills |
| permission tier (practice-protected SS7) | hybrid - not in the tier table (retrieval + writes sources/) | artifact-producer | artifact-producer |
| artifacts | `sources/*.md\|.json` + `sources/.source-urls.txt` (relevance/reliability ratings) | `<resid>-<topic>-conspect.md` | `<anaid>-<topic>-report.md` |
| trigger | orchestrator dispatch (research-pipeline Phase 2), pre-allocated `res` ID | Phase 4, only after researcher returns `PERSISTENCE_RECOMMENDED: true` | direct dispatch (standalone) or Phase 5 after conspect verified; pre-allocated `ana` ID |
| shelf path | n/a (reports findings) | reports path; @memory-manager registers `shelf.conspects` | reports path; @memory-manager registers `shelf.analyses` |

Source pointers: `.opencode/opencode.jsonc` agent blocks (researcher/conspecter/analyzer
permission), `.opencode/agents/{researcher,conspecter,analyzer,memory-manager}.md`,
`.opencode/practice-protected.md:58-77`.

## 1. WHAT EACH LANE UNICELY PROVIDES (sub-question 2)

Capabilities existing in EXACTLY ONE lane:

- Researcher ONLY: (a) network fetch via bash allow-list (`curl/wget/trafilatura/crwl`) -
  `.opencode/opencode.jsonc` researcher block; conspecter is flat-denied, analyzer is not
  gated to a capture allow-list. (b) The 3-tier Phase A capture chain with D6 per-source
  relevance/reliability ratings written to `sources/.source-urls.txt` - `researcher.md:49-66`,
  `research-pipeline/SKILL.md:19-24`. (c) Discovery MCPs `context7` + `gh_grep` (official docs
  + GitHub code search) - assigned only to researcher in every preset.
- Conspecter ONLY: the air-gapped synthesis invariant - `bash: "deny"` AND `webfetch: "deny"`
  AND `mcps: []`, so a conspect is provably grounded only in archived sources (DIA-135 D7,
  `conspecter.md:74-90`). No other lane has network revoked at the config level.
- Analyzer ONLY: multi-method analysis + terminal visualization via the 7-skill set
  (teaching, book-rag, mermaid-diagramming, console-charting, data-reducer,
  debugging-workflow) at variant HIGH - analyzer preset entries in all 4 presets. Neither
  researcher nor conspecter carries any of these skills.

Shared across lanes: edit `knowledge/*` (all three); artifact-producer tier (conspecter,
analyzer - researcher is unclassified). No capability is duplicated exactly, but researcher
and conspecter share the "external knowledge" domain and conspecter and analyzer share the
"produce one knowledge/ artifact" output shape.

## 2. DEPENDENCY STRUCTURE (sub-question 3)

Linear pipeline with two plugin-enforced gates:

```
@researcher  --(PERSISTENCE_RECOMMENDED:true)--> [conspect-pending.json]  -> @conspecter
@conspecter  --(conspect artifact)------------> [analysis-pending.json]   -> @analyzer
@analyzer / @conspecter / @researcher  -------> reports path -> @memory-manager (sole shelf writer, DIA-143)
```

- researcher -> conspecter serialization: A6 point 2, `orchestrator_append.md:304`
  ("conspecter synthesizes researcher output; PERSISTENCE_RECOMMENDED triggers conspecter
  dispatch only after researcher returns"). Also enforced by the persistence-pending detector
  `delegation-observer.ts:2934-2999` (writes `conspect-pending.json` on researcher completion).
- research-pipeline phases: `research-pipeline/SKILL.md` Phase 1 (ID pre-allocation),
  Phase 2 (researcher + Phase A), Phase 3 (quality gate, auto-proceed), Phase 4 (conspecter
  synthesis), Phase 5 (analysis gate).
- Gate/flag-file dependencies: `conspect-pending.json` keyed on RESEARCHER completion
  (`delegation-observer.ts:2934`); `analysis-pending.json` keyed on CONPECTER completion with
  `status: "pending_verification"` (`delegation-observer.ts:3017-3054`); ANALYSIS GATE rule in
  all 3-4 orchestrator prompts (`oh-my-opencode-slim.jsonc` prompt bodies) blocks @analyzer
  while analysis-pending.json is unverified. Live files present:
  `.opencode/session/{analysis-pending,conspect-pending}.json` (both from ses_f25... 2026-09-25).
- analyzer is NOT in A6 serialization list; its ordering vs conspecter is enforced by the
  ANALYSIS GATE (Phase 5), not A6.
- Autocrine gate (DIA-212): `delegation-observer.ts:2441-2453` warns on `@researcher` dispatch
  lacking a `res` ID - name-keyed to researcher only.

## 3. MERGE FEASIBILITY (sub-question 4)

Name-keyed machinery a merge MUST re-edit (LIVE enforcing surfaces, not doc mentions):

1. `scripts/validate-agent-names.sh` 4-source lockstep: S1 AGENTS.md SS9 table, S2
   opencode.jsonc agent keys, S3 OMO jsonc agents/preset/disabled_agents keys, S4
   agents/*.md stems. Any lane rename/removal must move all four atomically or `make test-config` fails.
2. `.opencode/plugins/delegation-observer.ts`: `READ_ONLY_LANES` set (contains `researcher`,
   line 293), `WRITER_LANES` set (contains `analyzer`,`conspecter`,`memory-manager`, line 301),
   `isResearcherLane` persistence detector (2934), `isConspecterLane` analysis-gate detector
   (3017), autocrine gate (2441), `ACTION_MAP` next_agent entries (3718-3722), batch classifier.
3. `.opencode/skills/research-pipeline/SKILL.md` Phase routing (2/4/5).
4. `orchestrator_append.md` A1 batch sets + A6 point 2 + ID-allocation rule + ANALYSIS GATE;
   mirrored in all preset orchestratorPrompt bodies in OMO jsonc.
5. `scripts/validate-output-contracts.sh` per-lane header schema
   (ANALYZER-OUTPUT-CONTRACT / CONSPECTER-OUTPUT-CONTRACT).
6. `.opencode/practice-protected.md` SS7 tier table.

Prose mentions (non-enforcing) are far larger - grep of the literal names finds researcher in
~187 files, conspecter ~115, analyzer ~191 across docs/tickets/learnings/CHANGELOG; a merge
leaves that trail as historical record (no edit needed) but inflates the apparent blast radius.
Honest enforced-surface count: ~6 live surfaces + 1 config file per lane.

Pairing verdicts:

- researcher + conspecter: MEDIUM blast radius, real invariant conflict. A merged lane needs
  bash capture (Phase A) AND conspect synthesis - the D7 air-gap (`conspecter.md:74-90`) is
  exactly the property lost when one lane both fetches and writes the conspect. Counter-argument
  (honest, see A4): the double-fetch defect the split fixed (DIA-135 D2/D5) does NOT reappear if
  the single lane fetches once then synthesizes from its own local `sources/`, so the air-gap is
  partly a verification artifact, not a hard functional need.
- researcher + analyzer: HIGH blast radius, LOW cohesion. Collapses a `READ_ONLY_LANES`
  member (researcher) into `WRITER_LANES`, breaking batch class A (parallel read-only fan-out)
  in `delegation-observer.ts:309/326`. Capability sets are near-disjoint (retrieval chain vs
  7 analysis/visualization skills). Least feasible pairing.

## 4. INVOCATION-FREQUENCY EVIDENCE (sub-question 5)

Two independent working sources; both give the SAME ordering analyzer > researcher > conspecter.

Source 1 - `scripts/session-analytics.sh --view agents` (OpenCode sqlite DB, cost-DESC,
all recorded subagent sessions, parent_id IS NOT NULL; DB window is full retained history):

| agent | sessions | cost(USD) | tokens_input |
|---|---|---|---|
| analyzer | 27 | 0.55 | 702,635 |
| researcher | 18 | 0.33 | 2,039,430 |
| conspecter | 14 | 0.09 | 511,775 |

Source 2 - `delegation` rows in `.opencode/session/messages.jsonl` (130,197 lines total,
4,538 delegation rows; window 2026-08-07T19:37Z .. 2026-09-29T01:31Z), counted in-worker
(streaming json parse; file never read raw):

| lane | delegation rows |
|---|---|
| analyzer | 53 |
| researcher | 37 |
| conspecter | 23 |

Caveat (per dispatch note): 1,982 delegation rows carry the generic `gen_ai.agent.name:
"subagent"` (lane unresolved), so the lane-specific counts are a LOWER BOUND, not exact.
`.opencode/session/registry.jsonl` per-lane counting is known-unreliable and was used only as
a directional tie-break (not reported numerically).

Pipeline continuation rate: conspecter delegations (23) / researcher delegations (37) = 0.62,
consistent across both sources (14/18 = 0.78 by sessions) - i.e. the conspecter fires on the
majority, but not all, of research runs; the researcher frequently returns without
PERSISTENCE_RECOMMENDED or is used standalone.

## 5. COST / BENEFIT: THREE VS TWO (sub-question 6)

Concrete savings if conspecter folds into a merged retrieval lane:
- -1 hop per persisted-research run (Phase 2->Phase 4 collapses); conspecter dispatch is
  the lowest-traffic lane (23 delegations, $0.09 - the cheapest lane to eliminate on cost).
- -1 serialization edge (A6 point 2) and -1 gate-file writer (`conspect-pending.json`
  re-keyed or removed) in `delegation-observer.ts`.
- -1 lane across the 6 enforced surfaces + the SS9 lockstep table + per-preset model entries.

Concrete losses:
- D7 air-gap verification: a conspect can no longer be proven to cite only archived+rated
  sources; the `sources/`-on-disk resumable checkpoint is replaced by in-session state.
- Independent synthesis retry: lesson (L20260816 class) - researcher can be resumed/retried
  independently of conspecter; a merged lane re-couples the two failure domains.
- Model tiering: conspecter runs temp 0.1 / cheap; research retrieval runs temp 0.3 / medium.
  A merged lane pays the retrieval tier for synthesis.
- Artifact-type split: `shelf.conspects` (59 entries) vs `shelf.analyses` (63 entries) are
  distinct, comparable-throughput registers; a merge blurs a clean provenance boundary.
- ~6 enforced-surface edits (re-tune gates, prompts, validators) = non-trivial config-work
  requiring the SS2.5 chain (@ai-specialist gate -> @coder -> make test-config -> @ai-auditor).

## ARGUMENTS (numbered, machine-comparable across the three sibling reports)

A1. CLAIM: A separate researcher is required; its capability set is unique and it is the
    established merge RECEPTOR.
    EVIDENCE: only lane with a network capture allow-list (`opencode.jsonc` researcher
    `bash: curl/wget/trafilatura/crwl`) + Phase A 3-tier chain with D6 ratings
    (`researcher.md:49-66`) + context7/gh_grep discovery MCPs (all presets) + it is the
    designated fold-into target in sibling ticket `DIA-260929-3ydp`
    ("resource-manager retirement: merge ai-assist-sources curation into the researcher lane",
    created 2026-09-29).
    STRENGTH: high - capability uniqueness is config-verifiable and the precedent ticket is
    same-day, owner-authored (not this lane).
    FALSIFIER: a demonstration that analyzer (bash allow + websearch MCP) already performs
    equivalent 3-tier source capture with a `.source-urls.txt` manifest and D6 ratings.

A2. CLAIM: conspecter + researcher CANNOT cleanly merge without breaking a declared invariant
    (the D7 air-gap).
    EVIDENCE: conspecter `bash:"deny"` + `webfetch:"deny"` + `mcps:[]`
    (`opencode.jsonc` conspecter block, `conspecter.md:74-90`, practice-protected SS7); a merged
    lane that also does Phase A capture must grant network, so the synthesized conspect is no
    longer provably grounded only in archived sources.
    STRENGTH: medium - the invariant loss is real but is a verification property, not a
    functional one (see A4 counter).
    FALSIFIER: an air-gap that is achievable inside one lane (e.g. a synthesis-only phase with
    a runtime network lock after fetch completes) - no such mechanism exists today.

A3. CLAIM: analyzer + researcher is the LEAST feasible merge (high blast radius, low cohesion).
    EVIDENCE: merging moves a `READ_ONLY_LANES` member into `WRITER_LANES`
    (`delegation-observer.ts:293` vs `:301`), breaking batch class A parallel read-only fan-out
    (`:309,:326`); capability sets near-disjoint (retrieval chain vs the 7-skill analysis/
    visualization set at variant high).
    STRENGTH: high - both the batch-set conflict and the skill disjointness are direct config
    reads.
    FALSIFIER: a workload profile showing research and analysis always co-occur on the same
    artifact, making one combined lane cheaper. Counts show analyzer usage (53) exceeds
    researcher (37), i.e. analyzer frequently runs WITHOUT a preceding researcher.

A4. CLAIM: If exactly two lanes remain, retire CONSCRIPTER (fold synthesis into researcher);
    keep researcher + analyzer.
    EVIDENCE: conspecter is the lowest-traffic and lowest-cost lane (23 delegations,
    $0.09 - Source 1/2), its function (condense rated archived sources) is a natural extension
    of the lane that already archived and rated them, and the same-campaign precedent (3ydp)
    folds a low-traffic curation lane INTO researcher. Analyzer carries the unique,
    most-used distinct-mode capability (multi-method + visualization, 53/27) and must survive.
    STRENGTH: medium - usage/cost data is solid; the "fold into researcher" choice partly
    reflects precedent, and the loss of A2's air-gap is non-trivial (see A5 caveat).
    FALSIFIER: evidence that conspect throughput depends on the independent synthesis retry /
    air-gap verification (a spike of conspect failures traceable to merged single-lane fetch
    poisoning the synthesis) - no such evidence exists yet.

A5. CLAIM: three-lane separation is worth keeping IF the air-gap verification and independent
    pipeline-gate properties are valued; two lanes are worth it IF hop/token cost dominates and
    the air-gap can be re-established by a runtime lock inside a merged lane.
    EVIDENCE: gate machinery (`conspect-pending.json` / `analysis-pending.json`,
    `delegation-observer.ts:2934,3017`) exists precisely because the lanes are separate;
    `shelf.conspects` 59 vs `shelf.analyses` 63 shows both downstream artifact types carry
    comparable sustained value.
    STRENGTH: medium - this is the honest cost/benefit pivot, dependent on developer priority
    [INFERENCE framing, but each cited fact is verifiable].
    FALSIFIER: an A/B of merged vs split pipeline over 5+ persisted-research runs showing no
    regression in conspect grounding or gate correctness.

A6. CLAIM: any merge is a SS2.5 config-work change with a non-trivial validation burden, so its
    cost is dominated by re-editing the ~6 enforced surfaces and re-running the SS2.5 chain,
    not by runtime token savings.
    EVIDENCE: `validate-agent-names.sh` 4-source lockstep (S1 SS9 table, S2 opencode.jsonc, S3
    OMO jsonc, S4 agents/*.md) fails `make test-config` on drift; the pipeline is wired in
    delegation-observer.ts (4 name-keyed detectors/sets) + research-pipeline skill + 4 preset
    orchestratorPrompt bodies.
    STRENGTH: high - the enforcement surfaces are enumerated from source.
    FALSIFIER: a validator/gate design where a lane merge needs changes in <2 surfaces.

## EBDV (DIA-115) - at least two genuine options + status-quo, each with evidence, pros/cons, effort, section-10 routing flag

Option A - STATUS QUO (keep all three lanes). Abort the consolidation.
    Evidence: gates + lockstep machinery documented in A6; conspecter lane is functional and
    low-cost ($0.09 total).
    Pros: zero blast radius; D7 air-gap and independent retry preserved; SS9 lockstep untouched.
    Cons: keeps the lowest-traffic lane; -0 hop savings; maintenance of 3 contracts.
    Effort: nil.
    Section-10 routing: NONE (no config/AGENTS change).

Option B - Merge researcher + conspecter into a single "research" lane (recommended by this report's A4 lean, but see bias flag).
    Evidence: conspecter is lowest-traffic (A4); 3ydp precedent folds curation into researcher;
    double-fetch defect avoidable if the merged lane fetches once then synthesizes locally (A2 counter).
    Pros: -1 hop, -1 serialization edge, -1 gate writer; cheaper maintenance; retrieval and
    condensation are the same knowledge-domain.
    Cons: loses D7 air-gap verification unless a runtime network-lock is added (A2, falsifier);
    must re-key `conspect-pending.json`/`analysis-pending.json` detectors
    (`delegation-observer.ts:2934,3017`) and the 4-source name lockstep.
    Effort: HIGH (~6 enforced surfaces + SS2.5 chain + restart-verify).
    Section-10 routing: YES - touches opencode.jsonc, OMO jsonc, delegation-observer.ts,
    research-pipeline skill, AGENTS.md SS9, practice-protected SS7. Requires @ai-specialist gate
    -> @coder -> make test-config -> @ai-auditor.

Option C - Retire analyzer, fold analysis into conspecter (kept as a genuine alternative to
    avoid self-favoring; see BIAS CONTROL).
    Evidence: none supports this - analyzer is the HIGHEST-traffic (53 delegations / 27
    sessions / $0.55), distinct-mode, 7-skill lane; conspecter has no analysis skills and is
    air-gapped.
    Pros: would eliminate a higher-cost lane than Option B.
    Cons: destroys multi-method analysis + terminal visualization (unique capability, A1-analog);
    breaks A4/Phase-5 consumer of the conspect; strongly contraindicated by usage data.
    Effort: HIGH.
    Section-10 routing: YES (same surfaces as B).
    [This option is listed precisely because choosing B/C/A is where self-interest could bias a
    naive answer; the data rules C out, which strengthens B over the status quo.]

Recommendation with because-justification: Prefer Option A (status quo) unless the developer
explicitly prioritizes hop/token reduction over grounding verification. Recommendation is A
because the maintenance blast radius of a merge (A6: ~6 enforced surfaces + SS2.5 chain) exceeds
the measured runtime savings (conspecter totals $0.09 and 14 sessions over the whole DB window -
too small to justify a high-risk config change), and the air-gap that a merge sacrifices is a
declared invariant (practice-protected SS7 / DIA-135 D7), not incidental. If the project is
already going to consolidate lanes for other reasons (the 3ydp resource-manager retirement shows
appetite for exactly this), THEN take Option B as the single coordinated merge - do not do B in
isolation.

## BIAS CONTROL (sub-question 7)

This report is authored by the analyzer lane, which is one of the three subjects. Explicit
self-favor audit:
- The verdict (A4) keeps analyzer and proposes retiring conspecter. That outcome is favorable to
  my own lane. I flag it as a potential self-serving direction and mitigate three ways:
  (1) I listed Option C (retire analyzer) as a genuine variant and let the usage data disprove
  it, rather than omitting the option that would harm my lane.
  (2) The load-bearing facts are config/DB reads (permission blocks, delegation counts, shelf
  entry counts), not value judgments about analyzer quality.
  (3) The "merge into researcher" direction (A4/Option B) rests on the same-campaign precedent
  ticket DIA-260929-3ydp, which is owner-authored and NOT an analyzer artifact - I did not
  originate that pattern.
- Reasoning that could read as self-favoring, named: calling analyzer "distinct-mode /
  highest-value" (A4) while conspecter's low count could reflect that analysis frequently runs
  STANDALONE (analyzer 53 > researcher 37 > conspecter 23), i.e. conspecter is invoked less
  often because fewer research runs reach synthesis, NOT because condensation is less valuable.
  Low usage is NOT low value; I did not treat conspecter's $0.09 as a verdict on its worth, only
  as its marginal elimination cost.
- Neutral tie-break note: if the developer wants a merge and is wary of an analyzer-authored
  report keeping analyzer, the defensible independent call is simply "execute the already-open
  3ydp resource-manager->researcher merge first" (no analyzer involvement), then re-evaluate the
  trio on post-merge data.

## OPEN QUESTIONS

1. Can a runtime network-lock (deny bash/webfetch after Phase A completes, within one session)
   reproduce the D7 air-gap inside a merged researcher+conspecter lane? Not evidenced today.
2. Is the 0.62 researcher->conspecter continuation rate dropping (i.e. is conspecter being
   skipped more often lately), or steady? Needs a time-bucketed re-count (this report used one
   window aggregate).
3. Does any skill or doc assume `shelf.conspects` and `shelf.analyses` remain distinct registers
   (promo-review references res041 conspect)? A merge must preserve those references or repoint them.
