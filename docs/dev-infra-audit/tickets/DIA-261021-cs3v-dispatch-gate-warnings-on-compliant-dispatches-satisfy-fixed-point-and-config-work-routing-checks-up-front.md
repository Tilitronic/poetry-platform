# DIA-261021-cs3v - Dispatch gate warnings on compliant dispatches: satisfy FIXED_POINT and config-work routing checks up front

---

id: DIA-261021-cs3v
title: "Dispatch gate warnings on compliant dispatches: satisfy FIXED_POINT and config-work routing checks up front"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "grilled" # grilled | waived | bypassed | partial | skipped
gate_triggers: [cross-cutting] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "Grill served by the architector + ai-specialist read-only analysis (2026-10-21) plus the developer disposition approving variant V2; no live grill session required." # free-text: developer signal + reason; empty = no override
discovered: 2026-10-21
source: inventory
date: 2026-10-21
created: 2026-10-21
updated: 2026-10-21

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

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## Analysis 2026-10-21 (architector + ai-specialist, read-only)

Read-only gate analysis. No implementation was made; both remedies wait for
developer approval under AGENTS.md section 2.5.

### 1. Current-state map

- Emitter 1: `.opencode/plugins/delegation-observer.ts:1895-2006`, inside
  `tool.execute.before` (:1837). Predicate `input.tool === "task" &&
subagentType === "reviewer"`, then `matchAll(/FIXED_POINT:\s*(\S+)/gi)` over
  description+prompt. Zero matches -> `failEnvelope("reviewer dispatch has no
FIXED_POINT marker")`; more than one -> `failEnvelope("... N FIXED_POINT
markers (exactly one required)")`. Applies to EVERY reviewer dispatch,
  including re-review cycle N/2. On success the hook injects an
  IMMUTABLE_GIT_ENVELOPE block into the CHILD prompt at `:1996`. Because the
  capture is `(\S+)`, backticks/quotes/trailing periods become part of the ref
  and then fail `git rev-parse --verify`
  (`.opencode/memory/lessons.md:3305-3313`). Both warnings are THROWN Errors,
  not advisory prompt injections: the blocked call never spawns a child lane,
  the cost is a parent turn plus a retry.
- Emitter 2: `.opencode/plugins/lib/routing-gate.ts:23-24` CONFIG_WORK_PATTERN
  (path literals: `.opencode/plugins/`, `.opencode/oh-my-opencode-slim`,
  `orchestrator_append.md`, `.opencode/agents/`, `.opencode/skills/`,
  `.opencode/commands/`, `.opencode/rules/`, `opencode.jsonc`, `AGENTS.md`,
  `practice-protected.md`) + `:103-133` `evaluateRoutingGate`, called at
  `delegation-observer.ts:2464`, thrown at `:2502` (also `tool.execute.before`).
  Conditions: `isCoderAgent && isConfigWorkDispatch &&
!hasPriorAiSpecialistDispatch` - no intent, no authoring-verb, no marker
  term. `hasPriorAiSpecialistDispatch` = a prior row with
  `row.agent === "ai-specialist" && event_type === "paracrine" &&
signal_type === "dispatch.started"` in the same orchestrator session.
- The DIA-260826-zvu4 verification-only convention CANNOT suppress emitter 2
  today: `verificationOnlySessions` is populated in `tool.execute.after`
  (`delegation-observer.ts:2802-2813`) keyed by the CHILD taskId and read only
  by the empty-result detector (`:3303-3309`); `evaluateRoutingGate` has no
  reference to it and `lib/routing-gate.ts` does not import the set. Different
  hook phase, different key.
- The FIXED_POINT rule exists only in `.opencode/memory/lessons.md:3387-3400`,
  which is not read at boot. grep for FIXED_POINT / REVIEWER ENVELOPE / ROUTING
  GATE across `.opencode/agents/`, `.opencode/skills/`, `.opencode/commands/`,
  `AGENTS.md`, `orchestrator_append.md` returns zero hits; the shared reviewer
  card (jsonc:344) actively contradicts the rule by saying "Capture git diff
  <fixed-point>...HEAD". Same miss class as DIA-261006-y72h (rule living in a
  carrier the orchestrator never reads).
- Surface note: there is no `.opencode/agents/orchestrator.md`. The live
  orchestrator base is the inline jsonc prompt
  (`.opencode/oh-my-opencode-slim.jsonc:31` and `:257`, byte-identical prompt
  strings) plus `.opencode/oh-my-opencode-slim/orchestrator_append.md`.

### 2. Failure modes

| Emitter                           | Failure mode                                                                                                                   |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| 1 (reviewer FIXED_POINT envelope) | missing-marker-in-payload + knowledge-in-the-wrong-place (not an over-broad predicate; the reviewer-only predicate is correct) |
| 2 (config-work routing gate)      | over-broad predicate (path substring, intent-blind)                                                                            |

### 3. Variants

| Variant | Description                                                                                                                                                                            | Disposition                                                                           |
| ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| V1      | Prompt-only contract: teach the orchestrator the dispatch-payload rules on the surfaces it actually loads (jsonc orchestrator cards, reviewer card, orchestrator_append.md, AGENTS.md) | viable, covers emitter 1 fully                                                        |
| V2      | V1 + narrow predicate tightening: routing-gate honours the zvu4 verification-only marker (six lines + one test)                                                                        | viable, needed for emitter 2                                                          |
| V3      | Pre-dispatch parent-side validator that checks payloads before the gate runs                                                                                                           | rejected: the throws already run pre-spawn, so a second checker still fails attempt 1 |
| V4      | Status quo (keep hitting both throws and retry)                                                                                                                                        | rejected, the ticket exists because of it                                             |

### 4. Recommendation

V1 + narrow V2. Emitter 1 is a first-attempt instruction gap on a surface the
orchestrator actually loads; emitter 2 is intent-blind code that no prompt can
satisfy.

### 5. Exact file set for the eventual implementation

- `.opencode/oh-my-opencode-slim.jsonc` `agents.reviewer.orchestratorPrompt`
  (:344) rewrite: parent emits exactly one FIXED_POINT line, does not paste the
  envelope, reviewer does not run git.
- `.opencode/oh-my-opencode-slim.jsonc` orchestrator prompt (:31 and :257,
  byte-identical): one mandatory-rule sentence pointing at the contract.
- `.opencode/oh-my-opencode-slim/orchestrator_append.md`, next to the zvu4
  block (:370): canonical dispatch-payload contract with the per-lane templates
  (review, verification/run-gates, config implementation, analysis, research)
  and the "exactly one marker, bare ref, prompt only, never in description too"
  rules.
- `AGENTS.md:50` and section 6 pre-work gates (:198): one sentence each.
- `.opencode/plugins/lib/routing-gate.ts` `evaluateRoutingGate`: if the zvu4
  regex matches, return `{ violation: false, reason: "verification-only lane" }`
  before the path check; export the regex and have
  `delegation-observer.ts:2808` reuse it. Add a `ponytail:` ceiling comment.
- `scripts/__tests__/routing-order-gate.test.mjs`: two cases (config path +
  verification-only -> no violation; config path without it -> violation) and
  fix the stale "advisory" header claim.
- Do NOT change the throws. Do NOT add a new `validate-*.sh` drift gate.

### 6. Open decisions deferred to the developer

(i) accept the self-declared verification-only marker as a routing-gate
exemption (fail-open, same trust boundary zvu4 already accepts);
(ii) keep the hard throw rather than reverting to the DIA-230 advisory ADR;
(iii) confirm the reviewer-card rewrite (reviewer does not run git; the
envelope is its only evidence, matching
`.opencode/oh-my-opencode-slim/reviewer.md:8`).

### 7. DIA-104 gate check

Pending developer disposition: this is a cross-cutting orchestrator-behaviour
change; ticket frontmatter currently reads `gate_state: "skipped"`.

## Decision 2026-10-21

Chosen variant: **V2** (= V1 prompt/contract surfaces + narrow routing-gate
predicate fix). Because emitter 1 (reviewer FIXED_POINT envelope) was a
first-attempt instruction gap on a surface the orchestrator actually loads,
and emitter 2 (config-work routing gate) was intent-blind code that no prompt
could satisfy.

Rejected alternatives:

- V1-only: leaves warning 2 (routing gate) firing on compliant
  verification-only dispatches that merely name a config path.
- V3 (pre-dispatch parent-side validator): redundant - the existing throws
  already run pre-spawn, so a second checker still fails attempt 1.
- V4 (status quo): rejected; the ticket exists because of it.

Developer approved both parts on 2026-10-21; the ai-specialist section-2.5
gate ran and its findings are registered in
`.opencode/learnings/external-patterns/2026-10-21-cs3v-dispatch-gate-contract.md`.
