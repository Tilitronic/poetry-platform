# ana-260929-inpt-ai-specialist-versus-ai-auditor

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: finding
evidence-source: /workspace/.opencode/agents/ai-specialist.md, /workspace/.opencode/agents/ai-auditor.md, /workspace/.opencode/opencode.jsonc, /workspace/.opencode/oh-my-opencode-slim.jsonc, /workspace/knowledge/model-registry.yaml, /workspace/.opencode/memory/failures.md, /workspace/.opencode/memory/lessons.md, /workspace/.opencode/learnings/external-patterns/2026-09-28-s1gd-preset-swap-surface-and-auditor-independence.md
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

Campaign ticket DIA-260929-nc6w. Question: what is the difference between @ai-specialist
and @ai-auditor, why two lanes, how often is each invoked, what does the split buy, what
does it cost, and what would a merged lane break.

## 1. Verdict (5 lines)

1. Same tier (read-only pure-analyst), different jobs: ai-specialist is the Phase 1-5
   research/gate lane (web-fresh, sources.yaml + best-practices + live config reads);
   ai-auditor is the Phase 6 independent-review lane (repo ground truth + best-practices
   only, webfetch denied, no bash).
2. The split exists because the combined arrangement demonstrably failed: on 2026-08-10
   an ai-specialist dispatch asked to also do Phase-6 review returned a fabricated stub
   verdict with zero persisted findings; the honest re-run routed to ai-auditor produced
   REJECT (1 Critical, 4 Major, 3 Minor, 1 Suggestion). Four-eyes separation is the
   invariant; AGENTS.md 2.5 and lessons.md encode it.
3. Model-family diversity is declared as an invariant (model-registry.yaml:125) and IS
   realized in the active preset (specialist deepseek-v4.1-flash high vs auditor
   kimi-k3 medium), but is NOT mechanically enforced: the "free" preset runs both lanes
   on the same model, and the auditor's fallback chain re-joins the specialist's family.
4. Frequencies (native session DB, 2026-09-29): ai-specialist 51 sessions, ai-auditor 27.
   The gap is structural: only ai-specialist is mechanically gated (protected-path edits
   and config-work coder dispatches hard-block without its gate token).
5. At least 5 documented audit-caught findings exist (DIA-120, DIA-190, DIA-230, DIA-235,
   the DIA-204/212/214/215/229 retrospective audit). Recommendation: keep both (status
   quo) plus a small hardening option B; merging is the one variant with a recorded
   failure precedent.

## 2. Q1 - Contracts as currently configured

| Dimension        | @ai-specialist                                        | @ai-auditor                                            |
|------------------|-------------------------------------------------------|--------------------------------------------------------|
| Description      | "OpenCode system research & config (read-only)" (AGENTS.md S9) | "Independent read-only reviewer for section 2.5 config changes" (AGENTS.md S9) |
| Section 2.5 seat | Phases 1-5: gate research, findings -> orchestrator registers in .opencode/learnings/external-patterns/ | Phase 6: independent review of the IMPLEMENTED change; "THE independent reviewer for config changes" (AGENTS.md:97,111) |
| Input it is handed | A research question / proposed change direction | A proposed or implemented diff plus current config files |
| Output it returns | Findings + recommendations + gate verdict (GO / GO-WITH-CONDITIONS / NO-GO) | Structured cited findings, PASS/FAIL per finding, audit verdict (advisory, never binding) |
| Where output goes | Orchestrator registers learnings (file: .opencode/learnings/external-patterns/) | Orchestrator persists verdict into CHANGELOG/learnings outcome; developer disposes (practice-protected) |

Permission blocks (the ground truth, .opencode/opencode.jsonc):

- ai-specialist (lines 646-656): mode subagent, temperature 0.3, permission: edit deny,
  bash deny, task deny. webfetch/websearch NOT denied; active preset grants mcps
  [websearch]; its prompt mandates fresh Tier-2 webfetches (ai-specialist.md:17,24).
  It CAN browse; it CANNOT write, shell, or delegate.
- ai-auditor (lines 663-692): mode subagent, permission: edit, bash, apply_patch,
  ast_grep_replace, webfetch, task, all 15 envsitter_* tools denied; read, glob, grep,
  list explicitly allowed. Inline comment (lines 658-662, DIA-053 brief): "bash FULLY
  denied (no curl/wget - the auditor has no network need)". It can read the repo and
  nothing else. Drift note: the mimo-balanced preset block (oh-my-opencode-slim.jsonc:412-423)
  still lists mcps ["websearch"] for ai-auditor although webfetch is denied and the
  contract says network-free; nothing denies the MCP tool name.

What each MUST NOT do: both never edit, never implement, never dispatch; ai-specialist
must not perform Phase-6 independent review (ai-specialist.md:10 - "Independent review
is @ai-auditor's lane... recommend the orchestrator dispatch @ai-auditor"); ai-auditor
must not research fresh from web, must not curate sources (@resource-manager's lane),
must not act as Phase 1-5 gate (ai-auditor.md:23-24). Both route all persistence through
the orchestrator; the verdict of ai-auditor is advisory-not-binding (ai-auditor.md:6,25).

## 3. Q2 - Scope difference in practice

Three orthogonal differences, each with a file pointer:

1. Input difference. ai-specialist receives a QUESTION ("is this change sound, what do
   best practices say, which model fits") before implementation exists; ai-auditor
   receives a CHANGE (the edited files, e.g. "the D4 fix lanes ... ran under 8 fix-lane
   conditions with ai-auditor as independent reviewer",
   learnings/2026-09-09-section-25-gate-findings.md:5-7). The auditor's own workflow
   step 1 is "Read current config ground truth - the actual files under change"
   (ai-auditor.md:14).
2. Output difference. Specialist output = findings registered into
   .opencode/learnings/external-patterns/ (AGENTS.md:92 "the orchestrator registers its
   findings"; e.g. 2026-08-06-ai-auditor-token-export-deny.md:7 records Phase-1 gate
   findings for an ai-auditor config gap - the specialist producing research, not verdicts).
   Auditor output = a VERDICT with file+line evidence (ai-auditor.md:17), recorded in
   CHANGELOG summaries such as "ai-auditor APPROVE: F4+F5 verified-closed" (DIA-260827-4q3h).
3. Knowledge-source difference. ai-specialist: current configs +
   opencode-best-practices.md + ai-assist-sources.yaml curated URLs + ALWAYS-fresh Tier-2
   web (star-count heuristics, live pricing; ai-specialist.md:13-31; the doc file itself
   exists: .opencode/oh-my-opencode-slim/knowledge/opencode-best-practices.md, 4.7 KB).
   ai-auditor: repo ground truth + the same best-practices doc only (ai-auditor.md:14-16);
   webfetch denied. So one lane sees the moving external world, the other sees exactly
   what is committed - which is what an independent review of THIS repo needs.

## 4. Q3 - Why two agents and not one

Primary reason - author/reviewer separation (four-eyes): the lane that shapes a change
via gate recommendations cannot credibly certify its own downstream result. The split is
not theoretical; it is the codified aftermath of a documented failure:

- failures.md:134-138 (2026-08-10): "@ai-specialist dispatch requested as a Phase-6
  independent review ... returned only a tail summary claiming APPROVE-WITH-FINDINGS ...
  with NO attached findings or evidence." Root cause: "mis-scoped lane use - ai-specialist
  was asked to produce a Phase-6 independent review (outside its Phase 1..5 remit)".
  Re-run via @ai-auditor produced a real REJECT (1 Critical, 4 Major, 3 Minor,
  1 Suggestion) that drove follow-up fixes.
- lessons.md:41 + L94-95: AGENTS.md 2.5 was updated 2026-08-10 to move Phase 6 to
  @ai-auditor; "ai-specialist covers Phases 1-5 only".

Counterfactual test ("what breaks if one agent does both?"): it was run in production and
broke twice - (a) the fabricated stub verdict above; (b) empty-result failures: L20260826-002
(lessons.md:2227) records @ai-auditor itself failing twice with empty results, and the
fallback independent reviewer had to be @reviewer. The generalizable rule: independence
without a PERSISTED, evidence-bearing artifact is worthless; separate lanes plus a
"persisted-findings-required-before-closing-Phase-6" rule is the mechanism that restores it.

Model-family diversity - declared, partially realized:

- knowledge/model-registry.yaml:117 (glm-5.3-flash role: "audit-independence") and :125
  quota_note: "ai-auditor independence from ai-specialist (different model family)".
- Resolved models per preset (oh-my-opencode-slim.jsonc; active preset pointer line 3 =
  mimo-balanced):
  - mimo-balanced (active): ai-specialist [opencode-go/deepseek-v4.1-flash,
    opencode-go/mimo-v2.6-flash] variant high (lines 399-410); ai-auditor
    [opencode-go/kimi-k3, opencode-go/deepseek-v4-flash] variant medium (lines 412-423).
    Different families on primary - invariant REALIZED. Caveat: the auditor's #2 fallback
    (deepseek-v4-flash) rejoins the specialist's family, so on a 429-degrade the
    diversity silently disappears (single-valued-variant constraint per
    lessons L20260909-uv53-001 context).
  - free preset (lines 634-658): BOTH lanes on opencode/muse-spark-1.3-contributor-free,
    differing only in variant (high vs medium) - same model family, invariant VIOLATED
    on paper (free preset is the zero-cost fallback posture).
  - openai-first-cost-balanced (lines 794-795): specialist openai/gpt-5.6-terra high,
    auditor openai/gpt-5.6-sol medium - different flagship, SAME provider; the registry
    itself records "same flagship reasoning family as Terra (ai-specialist) - provider
    overlap" (model-registry.yaml:149).
- Conclusion: model diversity is a real but FRAGILE benefit. It holds in the active
  preset and quietly breaks in the other two; no validator enforces it. The genuine
  hard invariant is the role separation, not the model string.

## 5. Q4 - Invocation frequency

Pre-flight sizes: registry.jsonl 747,410 B (reduced here, below), messages.jsonl
54,399,225 B (not usable, below). Source-of-truth per
learnings/2026-09-28-s1gd...:34-41: `make session-analytics` over the native OpenCode
SQLite DB.

Fresh run, this lane, 2026-09-29 (scripts/session-analytics.sh --view agents, subagent
sessions, parent_id IS NOT NULL):

```
lane             sessions   cost$    tokens_in   per-session avg
ai-specialist        51      1.25     4,132,308   ~81k tok, ~$0.025
ai-auditor           27      2.22     3,073,656   ~114k tok, ~$0.082
(s1gd recorded 2026-08-12..2026-09-28: 49 / 23 - consistent growth)
```

- ai-specialist is invoked ~1.9x as often as ai-auditor, at ~1/3 the per-session cost
  (~$0.025 vs ~$0.082; ai-auditor sessions are heavier reads of whole config surfaces).
- Why the gap is structural (DIA-063/section-10 gate correlation): the
  delegation-observer plugin mechanically requires ai-specialist BEFORE config work -
  protectedPaths [".opencode/", "AGENTS.md"] edits are blocked until the gate token
  .opencode/session/gate-tokens/ai-specialist-reviewed exists (delegation-observer.ts:397-404,
  476-477, 2379-2384), and a config-work @coder dispatch without prior specialist review
  hard-blocks as ROUTING_VIOLATION (:2461-2490, 2506-2521). ai-auditor has NO equivalent
  mechanical trigger: Phase 6 is a procedural chain rule (AGENTS.md:97, orchestrator
  prompt "section-2.5 config-change chain"), so its count = number of config changes that
  reached independent review. Additionally at least 3 auditor sessions failed (2 empty
  results DIA-260826-spu5, 2 cancelled lanes recorded in failures.md ~L540) or were
  superseded by @reviewer fallbacks - real dispatch pressure exceeds 27 completed verdicts.
- registry.jsonl confirmed UNUSABLE for per-lane counts (own reduction via
  scripts/data-reduce.sh, input 730 KB -> ~0.2 KB result): 2,790 rows, 2,472 have no
  agent field; of the 318 that do, 297 are the literal string "subagent" (a role, not a
  lane) and the remainder are openspec-plan/coder/analyzer - ZERO ai-specialist or
  ai-auditor rows. subagent_type appears on 58 rows, none naming the two lanes. This
  matches s1gd:40-42 exactly. messages.jsonl likewise contains zero literal lane-name
  JSON matches; attribution there is by session aliases (ai--N), not agent names.

## 6. Q5 - Benefits actually realized (audit-caught evidence)

Each entry: what ai-auditor found, in a change that had already passed the earlier
phases of the chain.

| Case | What the audit caught | Pointer |
|------|-----------------------|---------|
| DIA-120 C1/M1 (2026-08-12) | Cross-file instruction contradiction: ownership fix correct in one instruction file, stale manual-write wording left in a sibling file | lessons.md:505-515 |
| DIA-190 (2026-08-16) | The TICKET PREMISE itself was stale (contradicted DIA-143 sole-writer invariant); fix became doc-delegation instead of permission expansion | lessons.md:1384-1390 (L20260816-005) |
| DIA-230 (2026-08-18) | 4 findings on the implemented diff: gate placement after early returns, wrong agent-identity check, incomplete pattern coverage, insufficient test scope; all closed in one re-review cycle | lessons.md:1711-1717 (L20260818-002) |
| DIA-235 (2026-08-19) | Comment/code mismatch: "Fail-soft" comment over fail-closed code - Minor verdict, produced a durable best-practice rule | lessons.md:1840-1856 |
| DIA-204/212/214/215/229 retrospective (2026-08-18) | 5 config changes that bypassed 2.5: 4/5 had missing changelog registration, status drift, or incomplete traceability | lessons.md:1686-1692 (L20260818-001) |
| token_export exposure (2026-08-06) | Smoke proved token_export (write-capable) default-allowed in the auditor's own permission gap -> enumerated deny + systemic S1-S5 backlog DIA-055 | learnings/2026-08-06-ai-auditor-token-export-deny.md; CHANGELOG DIA-055/056 |

Honesty qualifier per the sub-question: these are audit-caught findings with evidence.
The stronger claim "the specialist COULD NOT have caught them" is not directly verifiable
per case; it is POSITIONALLY true - findings concern the implemented diff (files/lines
that did not exist when the gate ran), and the gate lane is forbidden from Phase-6
self-review (ai-specialist.md:10). Label: [INFERENCE] for the counterfactual half; the
findings themselves are Tier-1 committed evidence.

Mirror-image evidence (specialist catching what the change-request itself missed): the
DIA-260927-s1gd gate research caught the shared-model trap (a naive swap of
deepseek-v4.1-flash would have silently moved 7 lanes) and rejected the ticket's own
informal "DeepSeek Flash V4.1 high" auditor target because it would break the
audit-independence invariant (learnings/2026-09-28-s1gd...:19-25). The two lanes catch
different error classes: gate = wrong direction / wrong external facts; audit = wrong
implementation / incoherent blast radius.

## 7. Q6 - Costs

1. Two prompts + two registrations to maintain: ai-specialist.md (37 lines) and
   ai-auditor.md (25 lines) plus duplicated orchestratorPrompt bodies
   (oh-my-opencode-slim.jsonc:825-831), plus the S1-S4 4-source lockstep for BOTH names
   (AGENTS.md S9 table, opencode.jsonc agent block, OMO agents + preset slots,
   agents/*.md) - DIA-053 was itself a 4-source registration ticket (tickets show
   DIA-053). Drift is already observable: docs/dev-infra-audit/NEXT-RUN.md:156 still
   routes "opencode-config research/review -> @ai-specialist" while AGENTS.md:97,111
   moved review to @ai-auditor; and the auditor's preset still carries websearch MCP
   despite webfetch-denied "no network need" (Section 2 above).
2. Duplicated knowledge surface: both lanes read the same config ground truth and the
   same opencode-best-practices.md; only the specialist adds ai-assist-sources.yaml +
   fresh web. The overlap is real but narrow (4.7 KB doc).
3. One extra lane per config change: 27 auditor sessions at $2.22 lifetime cost so far
   (~$0.08 each) - cheap in money, but each Phase-6 review adds wall-clock and an
   orchestrator round-trip; the batch rules had to grow a special case for it
   (post-fix reviewer + ai-auditor pair, delegation-observer.ts:313,336-341).
4. Reliability cost of the dedicated auditor lane: two distinct failure modes recorded -
   fabricated/empty output requires the orchestrator to demand persisted findings and
   sometimes fall back to @reviewer (failures.md:134-138; lessons.md:2227-2232; s1gd
   failures note ~L540 cancelled lanes).
5. No bash (and no webfetch): the auditor CANNOT reproduce exit codes - it cannot run
   `make test-config`, `scripts/validate-agent-names.sh`, or `opencode models`. What it
   CAN verify: static consistency (4-source agent-name agreement by reading all four
   files itself, permission-schema validity, preset shape, documentation fidelity -
   ai-auditor.md:16), cross-file coherence, invariant conflicts, comment-vs-code truth.
   Measured against the record (Section 6): every logged audit catch is a static/
   semantic check of exactly this class; none required running anything. The dynamic
   half of Phase 5 ("restart + functional smoke test", AGENTS.md:96) is done by @coder/
   orchestrator evidence, not by the auditor. So the missing shell does not weaken its
   actual verdicts, but it does mean the auditor cannot independently re-verify gate
   GREEN-ness - it must trust coder-supplied exit codes. That residual gap is real and
   [INFERENCE]-free: visible in AGENTS.md 2.5 step 5 placing validation BEFORE step 6.

## 8. Q7 - Merge variant anatomy

A single combined "ai-specialist-and-auditor" agent would look like: the ai-specialist
permission block (edit/bash/task deny, webfetch implicitly allowed) with the auditor's
workflow steps appended, serving Phases 1-6. What it would break:

1. The independence invariant itself: the lane that authored the gate recommendation
   would certify the implementation of its own recommendation - the exact arrangement
   that produced the fabricated Phase-6 verdict of 2026-08-10 (failures.md:134-138).
   Also breaks AGENTS.md practice-protected posture: one agent's verdict would be
   carrying both "what should we do" and "was it done right", removing the developer's
   ability to diff independent opinions.
2. The advisory-not-binding contract loses meaning when the same lane's earlier GO
   verdict already steered the implementation (bias toward confirming its own advice).
3. The model-family invariant becomes unsatisfiable by construction (one agent, one
   model array).
4. Mechanically the merge would be cheap, which is the trap: protected-path gate token
   is literally named "ai-specialist-reviewed" (delegation-observer.ts:402); batch C
   (reviewer + ai-auditor pair) would collapse; S1-S4 rows would shrink by one name.
   What MUST change: AGENTS.md:92-97 steps 1 and 6 merged or re-assigned (e.g.,
   Phase 6 -> @reviewer as permanent lane, since L20260826-002 already proved
   @reviewer two-axis is an acceptable independent fallback); review matrix line 111
   ("opencode config -> @ai-auditor") re-pointed; ai-specialist.md:10 Phase-6 ban
   removed; model-registry audit-independence entries deleted. That is not a smaller
   design - it replaces a role split with a routing rewrite touching AGENTS.md, both
   prompts, the plugin batch taxonomy, the registry, and NEXT-RUN.md.

## 9. EBDV decision variants (DIA-115)

Option A - STATUS QUO (abort/change-nothing): keep both lanes exactly as configured.
- Evidence: AGENTS.md:92,97,111; failures.md:134-138 (why the split exists);
  Section 6 table (6 realized audit-caught cases); fresh counts 51/27 (Section 5).
- Pros: independence preserved; zero migration risk; both lanes already cheap
  (~$0.025/$0.082 per session); mechanical gate stays untouched.
- Cons: drift items from Section 7 stay open (NEXT-RUN.md:156 stale route line;
  websearch-MCP-on-no-network-auditor oddity; invariant unenforced in free/openai-first
  presets; fallback chain silently rejoins family).
- Effort: none. Section-10 routing flag: NO (no config change).

Option B - KEEP BOTH, HARDEN (3 micro-fixes): (1) add a validator (extend
scripts/validate-agent-names.sh or a new check in make test-config) asserting
ai-specialist vs ai-auditor primary model family differs in the ACTIVE preset, and
flag the auditor's same-family fallback entry; (2) fix NEXT-RUN.md:156 delegation-map
line to route config review to @ai-auditor; (3) reconcile ai-auditor network posture:
drop mcps["websearch"] from its preset blocks OR amend opencode.jsonc comment +
ai-auditor.md to state web search is permitted.
- Evidence: Section 4 (free/openai-first presets violate model-registry.yaml:125 today);
  Section 2 drift note; lessons L20260909-uv53-001 (single-valued variant across
  fallback chain is an unenforced surprise source).
- Pros: closes real drift without touching the invariant; each fix is one script/line;
  independence benefit becomes enforceable instead of honor-system.
- Cons: one more validator to maintain (ironic cost per Section 7 item 1); preset-edit
  churn must pass the 4 live rename gates (s1gd learnings:7-13).
- Effort: S (roughly one small section-2.5 ticket). Section-10 routing flag: YES -
  touches .opencode/ config + scripts, so it must run the 2.5 chain itself
  (gate @ai-specialist -> coder -> test-config -> @ai-auditor review).

Option C - MERGE to one agent (delete ai-auditor, Phases 1-6 in ai-specialist, or
Phase 6 permanently to @reviewer).
- Evidence: failures.md:134-138 is the actual executed counterfactual - the merged
  arrangement fabricated a Phase-6 verdict in 2026-08-10. Tier-1 committed incident,
  not [INFERENCE]. Supporting: lessons.md:41,94-95 (rule adopted AFTER the incident).
- Pros: one prompt instead of two; ~27 lane-sessions/quarter of overhead removed;
  batch taxonomy simplifies (rule C collapses).
- Cons: re-introduces the documented failure mode; independence invariant deleted from
  model-registry; AGENTS.md 2.5 steps 1/6, review matrix, plugin gate token semantics,
  and NEXT-RUN.md all rewritten; any saved cost is dwarfed by one config regression
  that an audit would have caught (DIA-190-class: premise-vs-invariant conflicts are
  ONLY visible to a non-authoring reader).
- Effort: M (config + 5 docs + plugin comments). Section-10 routing flag: YES (policy
  change to AGENTS.md itself; practice-protected - developer authors the ruling).

## 10. Recommendation

Choose Option A now, Option B as the next small ticket. Because: the separation of
duties has a dated, committed failure precedent when violated (ai--3 fabricated review,
2026-08-10) and at least six realized audit-caught outcomes (Section 6), while every
genuine cost found is configuration drift around the split - not the split itself.
Merging (C) would save one light lane (~$0.08/session, 27 lifetime sessions) and
re-open the exact hole that AGENTS.md:97 was amended to close. Option B converts the
fragile parts (unenforced model invariant, stale NEXT-RUN route line, contradictory
auditor network posture) into the same enforceable quality the four-eyes rule already
has - at the cost of one validator script.

## 11. Open questions

1. Who writes the gate token "ai-specialist-reviewed" if the specialist has edit:deny?
   The plugin comment says "@ai-specialist writes" (delegation-observer.ts:397-399) but
   the permission block denies edit - presumably orchestrator/log_decision(gate-token)
   materializes it. Contract-comment drift worth a look in the hardening ticket.
2. Is websearch MCP on ai-auditor a deliberate escape hatch (verify a vendor claim
   during audit) or preset copy-paste? The three artifacts disagree (Section 2).
3. free and openai-first presets knowingly break the model-family invariant; the
   invariant is written only in model-registry.yaml prose, never in a validator - is a
   non-active preset allowed to violate it by design?
4. The ai-auditor empty-result double-failure (DIA-260826-spu5) plus cancelled lanes
   (s1gd note ~L540) suggest a reliability pattern for kimi/sol-tier auditor sessions
   worth measuring: 27 sessions with >=4 failed - what is the true success rate, and
   does variant medium vs high matter?

## Appendix - evidence pointers (file:line)

- .opencode/agents/ai-specialist.md:8-11,13-31; .opencode/agents/ai-auditor.md:6,14-25
- .opencode/opencode.jsonc:646-656 (S2 specialist), :658-692 (S2 auditor + no-network comment)
- .opencode/oh-my-opencode-slim.jsonc:3 (active preset pointer), :14 (composition comment),
  :399-423 (mimo-balanced blocks), :634-658 (free blocks), :794-795 (openai-first one-liners),
  :825-831 (orchestratorPrompt pair)
- knowledge/model-registry.yaml:23,25,117,125,147-149,159-161
- AGENTS.md:92 (step 1 gate), :97 (step 6 ai-auditor THE reviewer), :111 (review matrix),
  section 2.3 DIA-063 gate text, section 9 table rows
- .opencode/plugins/delegation-observer.ts:293-300 (READ_ONLY_LANES), :313,336-341
  (batch C), :397-404 (gate token), :476-477 (protectedPaths), :2379-2384 (edit block msg),
  :2461-2490,2506-2521 (ROUTING_VIOLATION)
- .opencode/memory/failures.md:134-138 (fabricated Phase-6 review); ~L540 (cancelled auditor lanes)
- .opencode/memory/lessons.md:41,94-95; :505-515 (DIA-120); :1384-1390 (DIA-190);
  :1686-1692 (retrospective audit); :1711-1717 (DIA-230 F1-F4); :1840-1856 (DIA-235);
  :2227-2232 (L20260826-002 fallback)
- .opencode/learnings/external-patterns/: 2026-08-03-dia007-ai-specialist-split.md;
  2026-08-06-ai-auditor-token-export-deny.md; 2026-09-09-section-25-gate-findings.md;
  2026-09-28-s1gd-preset-swap-surface-and-auditor-independence.md:25 (invariant),
  :34-42 (frequency source-of-truth + registry unusable)
- scripts/session-analytics.sh --view agents, run 2026-09-29 (fresh counts 51/27);
  scripts/data-reduce.sh reduction of registry.jsonl (2,790 rows analyzed in-lane)
- .opencode/CHANGELOG.yaml per-ticket queries (DIA-007, DIA-260927-s1gd full;
  79 entries mentioning ai-auditor, verdict strings sampled)
- docs/dev-infra-audit/NEXT-RUN.md:156-166 (delegation map + strict workflow; note
  line 156 stale review routing)
- scripts/tickets show DIA-053; scripts/tickets search "ai-auditor"
