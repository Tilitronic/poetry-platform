# ana-260929-lmhb-conspecter-memory-manager-merge - Should conspecter and memory-manager merge into one agent?

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: recommendation
evidence-source: .opencode/opencode.jsonc, .opencode/plugins/delegation-observer.ts, .opencode/oh-my-opencode-slim.jsonc, .opencode/session/messages.jsonl
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

Campaign ticket DIA-260929-nc6w (agent-role consolidation study), lane 1 of 4.
Question: should the conspecter lane and the memory-manager lane be merged into
a single agent, and if so should the merged agent be named conspecter?

VERDICT: NO - keep two lanes. The merge's saving is ~1 dispatch hop on a
lane invoked 23 times in 7.5 weeks; its cost is dissolving the D7 no-bash air
gap around untrusted-source synthesis, a write scope the orchestrator reads
back (.opencode/memory/), and ~12 config/code/validator touchpoints keyed on
the two lane names. Methods: contract comparison, inversion (what breaks if
merged), MECE invariant inventory, invocation-frequency measurement, EBDV.

---

## 1. Current contract of each lane (evidence: config is ground truth, prompts are intent)

### 1.1 conspecter - pure-synthesis conspect authoring

Source: `.opencode/opencode.jsonc` agent.conspecter block;
`.opencode/agents/conspecter.md` (92 lines); `oh-my-opencode-slim.jsonc`
agents.conspecter.orchestratorPrompt; `skills/research-pipeline/SKILL.md` Phase 4.

| Aspect | Contract |
|---|---|
| Purpose | Read archived sources under `knowledge/<id>/sources/` (written by @researcher Phase A), synthesize the MLA-cited conspect. Single phase since DIA-135 D7. |
| edit | `*: deny`, `knowledge/*: allow` ONLY |
| bash | FLAT DENY (curl/wget/trafilatura/crwl allow-list was explicitly removed, D7) |
| webfetch | DENIED |
| task | DENIED |
| Writes | `knowledge/<type><id>-<topic>/<...>-conspect.md` + M2 output-contract header (`agent: conspecter`) |
| Must NOT | fetch network; modify sources or config; register shelf entries (explicitly delegated to @memory-manager, `conspecter.md` L17-19, L42-44); proceed on empty sources/ (guard gate) |
| Model routing | preset-assigned; temp 0.1; mcps []; NO skills (all 4 presets: mimo-balanced/promo-union-alpha/free/openai-first-cost-balanced) |

### 1.2 memory-manager - knowledge persistence + sole shelf writer

Source: `.opencode/opencode.jsonc` agent.memory-manager block;
`.opencode/agents/memory-manager.md` (48 lines); OMO
agents.memory-manager.orchestratorPrompt; `orchestrator_append.md` L162.

| Aspect | Contract |
|---|---|
| Purpose | Persist irrecoverable knowledge (ADRs, lessons, repo facts, failures) after task completion or >=2 failed loops; register artifacts in `memory-shelf.yaml` (sole writer); write `.opencode/learnings/external-patterns/*` |
| edit | `*: deny`, `.opencode/memory/*: allow`, `.opencode/memory-shelf.yaml*: allow`, `.opencode/learnings/external-patterns/*: allow` |
| bash | NOT SET -> inherits global `"*": "allow"` (with the destructive-git denylist). Needed for: `git log --oneline -10` (memory-manager.md L43), PyYAML post-write verification (L33), CHANGELOG partial reads (orchestrator_append.md L390-399 lists @memory-manager as an eligible bash lane) |
| task | NOT SET -> inherits global (effectively allowed) |
| Writes | `.opencode/memory/{adr,lessons,repo,failures}.md` (all four exist on disk), memory-shelf.yaml, learnings |
| Must NOT | write knowledge artifacts (conspecter/analyzer own those); store anything recoverable from git/diff/tests (Core Rule L8) |
| Model routing | same model/variant/temp as conspecter in all 4 presets; extra skill `git-diff` |
| Position | TERMINAL lane: "memory-manager is the LAST lane before user response (Mandatory Final Step)" - `orchestrator_append.md` L159-165, A6 rule 3 (L305) |

## 2. Real overlap vs genuine difference

| Dimension | conspecter | memory-manager | overlap? |
|---|---|---|---|
| WRITER_LANES membership | yes | yes | SHARED (`delegation-observer.ts:301`; batch rule B: at most one writer/batch) |
| Temp / model lane | 0.1, preset model | 0.1, identical model in all 4 presets | SHARED - per-lane model choice is currently UNS USED (both presets route both lanes to the same model) |
| Write zone | `knowledge/*` (project-visible artifacts) | `.opencode/*` (config-adjacent: shelf, memory, learnings) | GENUINELY DIFFERENT |
| bash | flat deny | global allow | GENUINELY DIFFERENT - blast radius differs a tier |
| Input trust | UNTRUSTED archived web sources (synthesis subject) | own repo git history / agent outputs | GENUINELY DIFFERENT |
| Trigger | mid-pipeline, after @researcher returns (A6 rule 2) | end-of-session, after ALL lanes (A6 rule 3) | GENUINELY DIFFERENT ordering position |
| Output type | conspect .md with M2 contract header | YAML shelf entries + memory .md files | DIFFERENT |
| Invocation | 23 / 7.5wk | 120 / 7.5wk | 5.2:1 asymmetry |

The superficial overlap ("both write knowledge-ish things") hides the real
split: conspecter is an AIR-GAPPED synthesis lane (no bash, no network, one
write zone); memory-manager is a CONFIG-ZONE writer with shell. The D7 design
(research-pipeline double-fetch + order-corruption defects, DIA-135 CLOSED
2026-08-14) deliberately REMOVED capability from conspecter rather than adding
it - the project's own precedent is de-merging, not merging.

## 3. Merge variant - what breaks

A single lane would need the union permission block:

```
edit:  { "*": "deny", "knowledge/*": "allow", ".opencode/memory/*": "allow",
         ".opencode/memory-shelf.yaml*": "allow",
         ".opencode/learnings/external-patterns/*": "allow" }
bash:  (must stay allow - shelf YAML verification + git log + CHANGELOG reads)
webfetch: deny (keep)
```

### 3.1 Invariants that depend on the two lanes being distinct

1. **DIA-143 sole-writer invariant** (CHANGELOG DIA-143, 2026-08-12:
   "memory-shelf.yaml allow removed from analyzer + conspecter edit
   permissions ... memory-manager sole shelf writer"). A merge technically
   preserves sole-writer (one agent), BUT the invariant's SECOND effect is
   cross-lane verification: today the conspecter reports an artifact path and
   the orchestrator verifies it (research-pipeline Phase 5 gate) before
   dispatching memory-manager to register. Merged, synthesis and registration
   happen inside one instance - the orchestrator loses the independent
   confirmation that the file the shelf points to exists. The shelf-write
   contract was ALSO the fix for a proven defect: DIA-199 (CLOSED 2026-08-16)
   showed memory-shelf exact-file allow did not resolve at runtime; the fix is
   the glob `.opencode/memory-shelf.yaml*` now in the block. Any merged block
   must carry that glob or re-break DIA-143.
2. **D7 air gap (security).** Conspecter synthesizes text scraped from the
   public web (researcher archives it; conspecter reads it). bash flat-deny +
   knowledge-only edit is the containment: a poisoned source can at worst make
   conspecter write one more artifact under `knowledge/`. Merged into the
   bash-holding, `.opencode/memory/`-writing lane, injected instructions from
   an untrusted source gain a direct path to `lessons.md`/`adr.md` - files the
   orchestrator reads back every session (AGENTS.md design-authority chain).
   That is prompt-injection blast-radius escalation from artifact zone to
   control-plane zone. [evidence: conspecter.md L74-84; opencode.jsonc block;
   the repo already tracks this threat class, knowledge/ana001-prompt-injection-plugin-trust - [INFERENCE] on the merged-lane exploit path itself, never sole basis: the capability union is ground truth in the config.]
3. **A1 batch-dispatch rule + NEXT-RUN.md:167** ("NEVER batch two
   memory-shelf.yaml writers"; WRITER_LANES set at
   `delegation-observer.ts:301`). Merging two writers into one does NOT relax
   this - it shrinks WRITER_LANES to {analyzer, merged}. Safe because advisory,
   but the plugin constant must be edited; the set membership is name-keyed.
4. **Mandatory-final-step ordering (A6.3 + L159-165) vs A6.2 (researcher ->
   conspecter mid-stream).** One agent cannot be both "the mid-pipeline lane
   after researcher" and "the LAST lane before user response" in the same
   campaign without TWO dispatches of the same lane - so the merge saves zero
   dispatches in exactly the sessions that use conspecter at all. The only
   genuinely saved hop is the conspect->registration handoff, which IS the
   Phase 5 verification gate (invariant 1).
5. **Per-lane gate machinery keyed on lane names** (all must be reworked):
   - `delegation-observer.ts:3017-3034`: analysis-pending.json gate fires on
     `agentName === "conspecter"` (DIA-135 D4 analysis-block gate).
   - `delegation-observer.ts:2929-2996`: conspect-pending.json keyed on the
     researcher lane (untouched by merge, but the downstream lane it points to
     is renamed).
   - `.opencode/session/adaptive-routing-state.json`: per-agent circuit-breaker
     EMA keyed by agent name; merging folds two distinct failure profiles into
     one circuit (failure isolation lost).
6. **Validator/lockstep touchpoints**: `scripts/validate-output-contracts.sh`
   L129-171 enforces `agent: conspecter` in every conspect header and in
   agents/conspecter.md (make test-config gates this);
   `scripts/validate-agent-names.sh` 4-source lockstep (AGENTS.md sec.9 table,
   opencode.jsonc keys, OMO agents+presets keys, .opencode/agents/*.md stems) -
   one merge = coordinated edits in ~12 places: 2 agent .md, opencode.jsonc,
   OMO agents block + 4 preset routing pairs x2 lanes, delegation-observer.ts
   (3 sites), orchestrator_append.md (A1, A6.2, A6.3, input-budget table L19),
   AGENTS.md sec.9 + sec.2.3/sec.2.4 persist steps, NEXT-RUN.md batch rule,
   validate-output-contracts.sh, research-pipeline SKILL.md Phases 4-5.

### 3.2 If merge were forced anyway: name it conspecter or memory-manager?

Least validator churn is the **conspecter** name: agents/conspecter.md file
stem, M2 contract `agent: conspecter`, and the analysis-pending gate regex all
keep working; only memory-manager disappears. But the name is then actively
misleading - a lane named for artifact synthesis would hold bash + config-zone
writes, inverting least-privilege readability (the name no longer predicts the
danger). The merge is not recommended, so the name question is moot; if the
developer overrides, keep "conspecter" for churn and accept the naming lie in
exchange for a 3-line description fixup.

## 4. Keep-separate benefits (what is actually gained today)

| Benefit | Mechanism | Real? |
|---|---|---|
| Permission tiering / least privilege | bash flat-deny vs inherited-allow; disjoint edit zones | YES - core design (D7, D5, D6 in DIA-135) |
| Injection air gap | untrusted-web synthesis cannot touch orchestrator-read files | YES (see 3.1 #2) |
| Independent registration handoff | conspecter reports path -> orchestrator verifies -> memory-manager registers | YES - Phase 5 gate |
| Ordering clarity | mid-stream vs terminal role encoded in A6.2/A6.3 | YES |
| Failure isolation | separate per-agent circuit EMA + separate dispatch-failure blast radius | YES (adaptive-routing-state.json) |
| Per-lane model choice | same model on both lanes in all 4 presets today | NO - currently unused; honest con of keep-separate |
| Instance separation (DIA-175 analog) | author of artifact != registrar of artifact | YES by construction |

## 5. Invocation-frequency evidence

Method note (data-reducer discipline): pre-flight `wc -c`: messages.jsonl =
54,399,225 B; registry.jsonl = 747,410 B; memory-shelf.yaml = 156,398 B - all
over threshold, reduced mechanically with jq/rg aggregation; zero raw log lines
entered context. registry.jsonl carries NO per-lane agent name on normal
dispatch rows (session_spawn/task_success rows only have session_id +
role:"subagent"; the `agent` field appears only on empty_result_detected rows)
=> messages.jsonl delegation rows are the only usable frequency source.

Delegation rows in `.opencode/session/messages.jsonl` (window 2026-08-07 ..
2026-09-29, ~7.5 weeks), outbound-dispatch subset (resolution_status
"in-flight") in parentheses:

```
memory-manager | ######################################################## 120 (118)
conspecter     | ########### 23 (23)
researcher     | ################### 37 (37)     <- conspecter's upstream, pipeline context
analyzer       | ###################### 46 (46)
coder          | ################################################################ ... 1122 (1122)
```

- 100% of conspecter dispatches (23) vs 23/7.5 = ~3/week. The merge removes at
  most one dispatch hop per pipeline run: ~3 hops/week.
- memory-manager runs ~16/week - it is the session-terminal lane; merging it
  with the synthesis lane puts the synthesis prompt surface in front of 16
  weekly dispatches that will never use it (prompt dilution), and the
  persistence prompt in front of 3/week of conspect work.

## 6. Cost/benefit ledger

| Merge saves | Cost |
|---|---|
| 1 agent .md file (92+48 lines -> ~110 merged prompt, diluting both) | ~12 coordinated edit sites (3.1 #6) incl. TS plugin + validators; make test-config churn |
| 1 orchestratorPrompt in OMO + 1 sec.9 row + 1 opencode.jsonc block | bash+config-writes co-located with untrusted-source synthesis (air gap loss, 3.1 #2) |
| up to ~3 dispatch hops/week (23 per 7.5wk) | loss of independent path-verification before shelf registration (3.1 #1) |
| (per-lane model diversity would be free to give up - it is unused) | A6 role conflict: one lane cannot be both mid-stream and terminal without 2 dispatches anyway (3.1 #4) |
| | failure isolation: merged circuit-breaker EMA; conspect-failure now also blocks session-terminal persist |
| | M2 output-contract re-key or naming-lie workaround (3.1 #6, 3.2) |

Quantified: saving ~3 dispatches/week at 120-row baseline noise; cost is a
control-plane security posture change + the exact invariant (sole-writer with
verification handoff) that DIA-143 was created to install.

## 7. EBDV - decision variants (DIA-115)

### Variant A - STATUS QUO: keep two lanes (recommended)

- Evidence: CHANGELOG DIA-143 (2026-08-12, sole-writer centralization),
  DIA-135 CLOSED entry (2026-08-14, D7 capability-removal precedent),
  orchestrator_append.md A6.2/A6.3, delegation-observer.ts:301 + :3017.
- Pros: air gap intact; ordering rules stable; zero validator churn;
  independent registration verification kept.
- Cons: two prompt surfaces; one extra pipeline hop (~3/week); two near-identical
  model lanes.
- Effort: 0 (no change).
- Section-10 routing: NO (no config touched).

### Variant B - MERGE INTO "conspecter" (the question's proposal)

- Evidence: name-preservation points: validate-output-contracts.sh:129-171 (M2
  `agent: conspecter`), delegation-observer.ts:3017 (gate keyed "conspecter"),
  agents/conspecter.md stem (lockstep S4). Permission union is ground truth
  from opencode.jsonc blocks.
- Pros: least validator churn of the merge shapes; one fewer lane name; ~1
  hop/pipeline saved.
- Cons: conspects.md's name no longer matches a bash+shelf+memory writer
  (misleading privilege label); union permission block every dispatch,
  including all 120/7.5wk persistence dispatches that gain `knowledge/*`
  write they never need; all Variant-C costs (below).
- Effort: M (~12 edit sites, plugin change, make test-config + restart-verify).
- Section-10 routing: YES (opencode.jsonc, OMO jsonc, agents/*.md,
  AGENTS.md sec.9, plugin TS, validators).

### Variant C - MERGE INTO "memory-manager" (symmetric alternative)

- Evidence: same union analysis; M2 validator (validate-output-contracts.sh:147)
  hard-fails `agent != conspecter` in conspect headers => every existing
  conspect and the conspecter.md contract would need re-issue.
- Pros: name honestly signals persistence/config authority.
- Cons: strictly more churn than B (M2 contract re-key, gate regex, file stem,
  all downstream docs); identical security costs; the Phase-5 analysis gate
  must be re-derived from artifact shape instead of lane name.
- Effort: M-L.
- Section-10 routing: YES.

### Variant D - HALF-MERGE: give conspecter self-registration (revert sole-writer)

- Evidence: this is exactly the pre-DIA-143 state that DIA-140's
  parallelization analysis identified as the shelf-write conflict source
  (CHANGELOG DIA-143 "memory-shelf centralization").
- Pros: removes the handoff hop while keeping two model lanes and the D7 bash
  air gap.
- Cons: re-breaks a fixed defect; two shelf writers = the forbidden batch pair
  (NEXT-RUN.md:167); shelf YAML write races re-open. Regression, not option.
- Effort: S - but it spends effort to go backwards.
- Section-10 routing: YES.

## 8. Recommendation

**Keep the two lanes separate (Variant A). Do not merge; therefore the naming
sub-question is declined (if overridden anyway, "conspecter" is the lower-churn
name but misrepresents the privilege tier).**

Because: the merge's measured benefit is ~1 dispatch hop on ~3 pipeline runs
per week (23 conspecter dispatches in 7.5 weeks, messages.jsonl), while the
separation carries three load-bearing, evidence-backed invariants: (1) the D7
air gap - bash flat-deny on the only lane that ingests untrusted web-sourced
text, which a merge would co-locate with shell access and writes to
`.opencode/memory/lessons.md`/`adr.md` (control-plane files the orchestrator
reads back); (2) the DIA-143 sole-writer design whose verification value is
the cross-lane path-check before shelf registration, not just the single-writer
count; (3) the A6 ordering split (mid-stream vs Mandatory Final Step) that
means a merged lane must still be dispatched twice in any campaign using
conspects. Cost asymmetry is roughly 3 dispatches/week saved versus ~12
coordinated edit sites, a plugin constant change, a security-posture reversal,
and the regression of a defect the project already paid to fix twice
(DIA-143 -> DIA-190 -> DIA-199).

## 9. Caveats / open questions

- Frequency counts are delegation-row based; rows for lanes dispatched by non
  orchestrator parents or pre-A1 plugin era (before registry rotation) may be
  undercounted; ratio (5.2:1) is robust, absolutes are lower bounds.
- Preset model routing for the two lanes is identical in all 4 presets today;
  if a future promo-review re-routes one lane to a cheaper/fallback model, the
  keep-separate case strengthens further (no merge revisit needed).
- The sibling consolidation questions (resource-manager; reviewer+analyzer;
  ai-specialist+ai-auditor) are handled by the three sibling lanes of campaign
  DIA-260929-nc6w; this lane deliberately does not opine on them, though any
  merge touching WRITER_LANES interacts with lane 3's reviewer/analyzer result.
- DIA-057/DIA-058 show the gate machinery evolved via 4 defect tickets; any
  future re-litigation of this merge should re-run the frequency count over a
  >=1 quarter window rather than a 7.5-week slice.
