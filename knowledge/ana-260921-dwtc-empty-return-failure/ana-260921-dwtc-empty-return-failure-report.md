# DIA-206 Analysis: ai-specialist Lane Empty-Return Failure (Systemic, Cross-Lane)

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: finding
evidence-source: docs/dev-infra-audit/tickets/DIA-206-ai-specialist-lane-empty-return-diagnosis.md
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

- **Ticket:** DIA-206 'ai-specialist lane systemic empty-return failure' (OPEN, Major, opencode-config)
- **Date:** 2026-09-21 (analysis lane, campaign ticket DIA-206)
- **Verdict:** DOMAIN COMPREHENDED. The failure is systemic (provider/endpoint/runtime layer), NOT ai-specialist-specific. Evidence for the cross-lane conclusion is strong; evidence for the exact sub-cause (transient provider fault vs harness session-return plumbing) is partial because the original ai-specialist partial-result files are no longer on disk.
- **Claim type:** finding (root-cause diagnosis) + recommendation (recovery + hardening)

---

## 1. Scope and sources

Ticket DIA-206 records 5 empty-return incidents in the 2026-08-17 window:

1. ai-specialist x3 in session ses_ff1484b67ffemi5N1IjJ7t3bj8 (DIA-194 CHANGELOG context), models deepseek-v4-flash and qwen3.7-plus.
2. coder cod-2 ses_ff0d1c373 (DIA-206 evidence-gather lane): read files, returned EMPTY (D1 signal).
3. researcher res-1 ses_ff0c44443 (res030): archived 4 of 5 sources, returned EMPTY (D1 signal); later resumed successfully by cod-3 (DIA-099 Variant A2).

Sources consulted for this analysis:

| # | Source | What it contributed |
|---|--------|---------------------|
| 1 | DIA-206 ticket body | Incident list, verification steps, section-2.5 gate impact statement |
| 2 | DIA-099 (CLOSED) | Detect-preserve-resume-validate Variant A2 mechanism; D1/D2/D5 signals; P1 schema; 3-failure cap rule |
| 3 | DIA-132 (CLOSED) | Prior one-shot silent failure precedent (coder-escalated/kimi-k3, 2026-08-13); transient hypothesis confirmed by passing smoke test |
| 4 | L20260817-006, L20260817-008 (lessons.md) | Session-return signature; cross-lane verdict; A2 resume confirmed working for res030 |
| 5 | res020 (agent-config watchdog) | No native per-agent timeout; no native empty-result handling; `steps` is an iteration cap, not a wall-clock timeout |
| 6 | res029 (model-fallback semantics) | Model-array fallback is an OMO extension; `retry_on_empty` is council-only; silent-empty without error may not trigger fallback |
| 7 | Live config (.opencode/opencode.jsonc, oh-my-opencode-slim.jsonc) | ai-specialist is read-only (edit/bash/task deny); current model array [union-alpha, deepseek-v4.1-flash] |
| 8 | partial-results dir (live) | ai--2.json + cod-2.json show the empty-result pattern persists as a known shape; the 3 original ai-specialist partials from 2026-08-17 are NOT present (evidence gap) |

---

## 2. Method 1: 5-Whys

```
W1: Why did the section-2.5 config gate stall?
  -> ai-specialist, the MANDATORY Phase-1 gate (AGENTS.md 2.5), returned
     EMPTY 3x in a row; no usable research reached the orchestrator.

W2: Why did the lane return EMPTY instead of erroring?
  -> Signature per L20260817-006: the session STARTS and reads files, then
     returns an EMPTY final result. No endpoint error surfaced to the
     orchestrator. This is a session-return failure, not a content failure.

W3: Why did nothing catch the empty return automatically?
  -> Three stacked absences (all Tier-1 evidenced):
     (a) res020: OpenCode v1.18.x has NO native per-agent wall-clock timeout
         and NO native empty-result handling (no AgentConfig field, no plugin
         event for it).
     (b) res029: OMO `retry_on_empty` is implemented ONLY in the council
         path, not globally -- silent-empty without an error signal does not
         trigger model-array fallback for non-council agents.
     (c) DIA-099 gap G2: the plugin cannot see the subagent's final result
         text, so detection is orchestrator-side only (manual observation).

W4: Why did it repeat 3x on the same lane?
  -> At incident time there was no automatic fallback on silent-empty (W3),
     so the orchestrator re-dispatched the designated lane. The DIA-099
     3-failure cap rule (do NOT loop past 3) plus the L20260817-006 lesson
     (route to a substitute lane) were the procedural stops -- created
     AFTER/BECAUSE of this incident class.

W5: Why call it systemic rather than an ai-specialist config bug?
  -> The same window produced the IDENTICAL signature on coder (different
     lane) and researcher (different lane), across BOTH deepseek-v4-flash
     AND qwen3.7-plus (different models/providers paths). A lane-config
     defect cannot explain cross-lane + cross-model coincidence. Common
     cause must sit BELOW the lane layer: provider/endpoint transient or
     shared harness session-return plumbing.
```

5-Whys result: root cause is at the provider/endpoint-or-harness layer; the lane layer is where the symptom surfaced and where detection was missing, not where the fault originated.

---

## 3. Method 2: Fault tree

Top event: EMPTY result delivered at the section-2.5 gate (no usable research).

```
                    TOP: empty result at gate
                    /        |         \          \
          PROVIDER/      HARNESS    LANE-CONFIG   TASK-SHAPE
          ENDPOINT       RETURN      DEFECT        (steps-cap/
          TRANSIENT      PLUMBING                          quota)
          (D1/D2)        (artifact?)
              |              |            |               |
   +----------+------+  +----+-----+  +---+----+  +-------+------+
   | rate-limit| empty |  | result |  | prompt |  | steps:MAX  | quota  |
   | /quota    | body  |  | text   |  | /perm  |  | STEPS      | exhaust|
   | spike     | 200OK |  | dropped|  | mis-   |  | (D2)       | (cap)  |
   +----------+------+  +----+-----+  +---+----+  +-------+------+
     SUPPORTED?          POSSIBLE     REFUTED      REFUTED for 4/5
```

Branch evaluation:

| Branch | Evidence | Status |
|--------|----------|--------|
| Provider/endpoint transient (rate-limit, quota spike, empty body) | Cross-lane + cross-model coincidence in one window; DIA-132 precedent (kimi-k3 one-shot silent failure did NOT reproduce on smoke test = transient); L20260816-006 endpoint-outage variant exists | SUPPORTED as leading hypothesis |
| Harness session-return plumbing / reporting artifact | Ticket itself warns registry signatures cannot discriminate silent failure from reporting artifact; ground-truth re-dispatch never recorded for the 3 ai-specialist sessions | POSSIBLE, unexcluded; needs probe |
| Lane-config defect (ai-specialist prompt/permission/model) | Coder + researcher failed identically; ai-specialist is read-only with no writes to corrupt; substitute @coder completed the same research OK | REFUTED as sole cause |
| Steps-cap (D2 MAXIMUM STEPS) | Read-only research tasks are short; no MAXIMUM STEPS signal claimed for the 3 ai-specialist incidents; res030 researcher had completed 4/5 archives (progress, not spinning) | REFUTED for 4 of 5; possible contributor, not driver |
| Quota exhaustion (monthly caps) | Era budgets were large (flash ~158K req/mo per res013); 5 failures in one window across two model families does not match budget exhaustion shape | REFUTED |

Two hypotheses survive: (H1) transient provider/endpoint fault, (H2) harness session-return plumbing defect. Both live below the lane layer, which is why the ticket's "systemic, not lane-specific" update is correct.

---

## 4. Method 3: Systems thinking (feedback and structure)

- **Single point of failure by design.** AGENTS.md 2.5 makes ai-specialist the MANDATORY Phase-1 gate for ALL config work. Any lane-level silence blocks the whole modernization queue (DIA-183, DIA-194 deferred). A mandatory gate with no automatic empty-result fallback is a structural SPOF -- the incident converted a latent structural risk into a realized stall.
- **Missing feedback loop.** Detection (orchestrator observes empty) existed informally, but no sensor-actuator loop closed it: no timeout sensor (res020 absence), no empty-result actuator (retry_on_empty council-only per res029), no plugin visibility into result text (DIA-099 G2). The system could observe failure but not react without human/orchestrator improvisation.
- **Reinforcing loop that made it worse.** No-fallback -> re-dispatch same lane -> same silent failure -> 3x repetition burned session time and context before the substitute-lane workaround fired. The DIA-099 3-failure cap is the circuit breaker that now bounds this loop.
- **Balancing loops added since.** (1) DIA-099 Variant A2 detect-preserve-resume-validate (proven: cod-3 resumed res-1 successfully). (2) L20260817-006 substitute-lane routing (@coder for read-only research). (3) res029/DIA-189 model-array fallback for error-signal failures. Residual gap: NONE of the three fires on silent-empty-without-error for non-council lanes -- the exact W3 hole.
- **Leverage point.** The cheapest structural fix is an orchestrator-side empty-result reaction (already partially procedural via A2 + 3-failure cap), not a lane-config change. Extending an empty-triggered fallback/actuator is section-10 config work and must go through the very gate that failed -- sequence it behind a live probe, not ahead of it.

---

## 5. Terminal-friendly summary table

```
+-------------+--------------------------------+----------------+------------+
| Incident    | Lane / model                   | Signal         | Recovery   |
+-------------+--------------------------------+----------------+------------+
| ai-spec x3  | ai-specialist / flash + qwen   | session-return | substitute |
| (DIA-194)   | ses_ff1484b67ffemi5N1IjJ7t3bj8 | EMPTY, no err  | @coder OK  |
+-------------+--------------------------------+----------------+------------+
| cod-2       | coder / (evidence-gather)      | D1: complete,  | (preserved |
| ses_ff0d1c3 | ses_ff0d1c373                  | no success     | P1 only)   |
+-------------+--------------------------------+----------------+------------+
| res-1       | researcher / res030            | D1: 4/5 arch,  | A2 resume  |
| ses_ff0c444 | ses_ff0c44443                  | then EMPTY     | via cod-3  |
+-------------+--------------------------------+----------------+------------+
| PRECEDENT   | coder-escalated / kimi-k3      | one-shot EMPTY | smoke PASS |
| DIA-132     | ses_004a15d0 (2026-08-13)      | 9.5min, no wr  | transient  |
+-------------+--------------------------------+----------------+------------+
```

---

## 6. Evidence gaps and caveats

1. The 3 original ai-specialist partial-result files named in the ticket are NOT in `.opencode/session/partial-results/` (80 files present, different naming era). The ticket's evidence links have rotted. Severity: Medium -- the ticket body + lessons preserve the observation, but byte-level re-verification of those 3 sessions is no longer possible.
2. Registry rows for ses_ff1484b67ffemi5N1IjJ7t3bj8 were not re-scanned in this analysis (registry has 1452+ rows and has rolled since August); classification relies on the ticket's D1/D2/D5 account plus L20260817-008. A fresh probe renders this moot.
3. Model assignments drifted since the incident (ai-specialist now [union-alpha, deepseek-v4.1-flash]; era models were flash + qwen3.7-plus). Conclusions about "which model failed" are era-bound; the cross-model argument only strengthens with drift.
4. H1 vs H2 (provider transient vs harness plumbing) is UNRESOLVED on current evidence -- both predict the observed signature. The ticket correctly mandates ground-truth re-dispatch before claiming discrimination.

## 7. Recommendations (ordered, cheapest first)

- **R1 (probe, no config change).** Dispatch ai-specialist on the ticket's own minimal test task (read `.opencode/opencode.jsonc`, report agent block keys). PASS = non-empty correct report; FAIL = empty again. This closes gap G4/H1-vs-H2 at zero section-10 cost. If it fails, capture the partial per P1 schema immediately so evidence does not rot again.
- **R2 (no change).** Keep DIA-099 Variant A2 + 3-failure cap + substitute-lane routing as the standing operating procedure for ANY empty lane result. It is the only recovery path with a live success case (cod-3/res030).
- **R3 (section-10, needs gate + decision).** Evaluate extending an empty-result trigger to the OMO fallback path (the W3 hole: retry_on_empty is council-only). Route: ai-specialist research -> developer decision -> coder -> test-config + restart-verify -> ai-auditor. Do NOT bundle with unrelated config work; reference DIA-206.
- **R4 (hygiene).** On the fix ticket, re-link or re-capture evidence paths (partials dir listing, registry seq rows) so the next reader does not hit the rotted links found here.
- **R5 (explicit non-goal).** Do NOT rewrite the ai-specialist prompt/permissions as the "fix" -- fault tree refutes lane-config as the cause; that change would add section-10 risk while leaving H1/H2 untouched.

## 8. Cannot-comprehend check

Not invoked. The domain (subagent empty-return handling, DIA-099/DIA-132/DIA-189 context, OMO fallback semantics) is fully comprehensible from committed artifacts plus live config. No guessing was required beyond the explicitly labeled H1/H2 fork, which the evidence genuinely leaves open.
