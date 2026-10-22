# Dispatch gate contract findings - DIA-261021-cs3v

Date: 2026-10-21
Gate: ai-specialist section-2.5 read-only gate research (findings reproduced from the dispatch payload).
Ticket: DIA-261021-cs3v 'Dispatch gate warnings on compliant dispatches: satisfy FIXED_POINT and config-work routing checks up front'
Source: architector + ai-specialist (read-only)

## Findings

1. Both warnings are THROWN Errors from `tool.execute.before`, not advisory prompt injections. The blocked call never spawns a child lane; the cost is a parent turn plus a retry.
2. Emitter 1: `.opencode/plugins/delegation-observer.ts:1895-2006`. Predicate: `input.tool === "task" && subagentType === "reviewer"`, then `matchAll(/FIXED_POINT:\s*(\S+)/gi)` over description+prompt. Zero matches -> `failEnvelope("reviewer dispatch has no FIXED_POINT marker")`; more than one -> `failEnvelope("... N FIXED_POINT markers (exactly one required)")`. Applies to EVERY reviewer dispatch including re-review cycle N/2. On success the hook injects an IMMUTABLE_GIT_ENVELOPE block into the CHILD prompt at `:1996`. Because the capture is `(\S+)`, backticks/quotes/trailing periods become part of the ref and then fail `git rev-parse --verify` (lessons.md:3305-3313).
3. Emitter 2: `.opencode/plugins/lib/routing-gate.ts:23-24` CONFIG_WORK_PATTERN (path literals: `.opencode/plugins/`, `.opencode/oh-my-opencode-slim`, `orchestrator_append.md`, `.opencode/agents/`, `.opencode/skills/`, `.opencode/commands/`, `.opencode/rules/`, `opencode.jsonc`, `AGENTS.md`, `practice-protected.md`) + `:103-133` `evaluateRoutingGate`, called at `delegation-observer.ts:2464`, thrown at `:2502`. Three conditions: `isCoderAgent && isConfigWorkDispatch && !hasPriorAiSpecialistDispatch`. No intent, no authoring-verb, no marker term. `hasPriorAiSpecialistDispatch` = a prior row with `row.agent === "ai-specialist" && event_type === "paracrine" && signal_type === "dispatch.started"` in the same orchestrator session.
4. FACT: the DIA-260826-zvu4 verification-only convention CANNOT suppress emitter 2 today. `verificationOnlySessions` is populated in `tool.execute.after` (`delegation-observer.ts:2802-2813`) keyed by the CHILD taskId and is read only by the empty-result detector (`:3303-3309`); `evaluateRoutingGate` has no reference to it and `lib/routing-gate.ts` does not import the set. Different hook phase, different key.
5. FACT: the FIXED_POINT rule exists only in `.opencode/memory/lessons.md:3387-3400`, which is not read at boot; the orchestrator cards (jsonc:31, :257) carry no such rule and the shared reviewer card (jsonc:344) actively contradicts it by telling the orchestrator "Capture git diff <fixed-point>...HEAD". grep for FIXED_POINT / REVIEWER ENVELOPE / ROUTING GATE across `.opencode/agents/`, `.opencode/skills/`, `.opencode/commands/`, `AGENTS.md`, `orchestrator_append.md` returns zero hits. This is the same class of miss as DIA-261006-y72h (rule living in a carrier the orchestrator never reads).

## Failure modes

- Emitter 1 = missing-marker-in-payload + knowledge-in-the-wrong-place (not an over-broad predicate; the reviewer-only predicate is correct).
- Emitter 2 = over-broad predicate (path substring, intent-blind).

## Verdict

Both remedies are AGENTS.md section-2.5 config-change class; there is no docs-only escape because the controlling files are `.opencode/plugins/**` and `.opencode/oh-my-opencode-slim/orchestrator_append.md`.

## Index row

| 2026-10-21 | architector + ai-specialist gate (read-only) | Dispatch gate contract: both dispatch warnings are THROWN Errors from tool.execute.before, not advisories - emitter 1 (reviewer FIXED_POINT envelope, delegation-observer.ts:1895-2006, envelope injected into child prompt at :1996, `(\S+)` capture swallows trailing punctuation) and emitter 2 (config-work routing gate, lib/routing-gate.ts:23-24 + :103-133, thrown at delegation-observer.ts:2502, path-substring intent-blind); the DIA-260826-zvu4 verification-only set cannot reach evaluateRoutingGate (filled in tool.execute.after keyed by child taskId, read only by the empty-result detector); the FIXED_POINT rule lives only in memory/lessons.md:3387-3400 (not read at boot) and the jsonc reviewer card :344 contradicts it - same carrier-miss class as DIA-261006-y72h; verdict: both remedies are section-2.5 config-change class, no docs-only escape. See `external-patterns/2026-10-21-cs3v-dispatch-gate-contract.md`. | applied - implemented + ai-auditor ACCEPT 2026-10-21, DIA-261021-cs3v |

No implementation changes were made during this gate.
