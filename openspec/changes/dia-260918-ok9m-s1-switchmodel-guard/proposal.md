# Proposal: dia-260918-ok9m-s1-switchmodel-guard

## Why

`/new` creates sessions on a stale model: the footer shows one model while routing uses another, because session selection wins over config and selecting an agent does not move the session model. A v2-shape project plugin guard that fires once at session.created and calls ctx.session.switchModel to the preset intent closes this gap at creation time, before any turn runs.

## What Changes

- New project plugin file (e.g. `.opencode/plugins/preset-model-guard.ts`) in v2 shape `{id, server, setup}`, subscribing to `session.created`.
- On each newborn session: read preset intent from `OH_MY_OPENCODE_SLIM_PRESET` env; if env absent or empty, no-op.
- If the user invoked with an explicit `--model` / agent-model selection, no-op (explicit override wins).
- If the newborn session model already equals the preset intent, no-op.
- Otherwise call `ctx.session.switchModel({sessionID, model: {providerID, id}})` exactly once per sessionID (fired-set guard; never per-turn, never per-message).
- All failures fail soft: malformed env, switchModel throw/reject, or v2 shape drift degrade to no-op with one log line; session creation is never blocked.
- v2 migration cost accepted: new `{id, server, setup}` shape per OMO dist/v2/index.d.ts:4-6, version-sync triplet, full `make test-config` re-pass.

## Capabilities

### New Capabilities

- `session-created-model-guard`: the session.created guard contract - trigger, preset-intent resolution, explicit-override exemption, fire-once guarantee, env-absent no-op, fail-soft error behavior, and the acceptance cases in Q7.

### Modified Capabilities

None. No existing spec-level requirements change; the single existing spec (`container-engine-socket-selection`) is unrelated.

## Impact

- Files: one new plugin file under `.opencode/plugins/` + its test file(s) at the session.created seam; optional one-line registration in `.opencode/opencode.jsonc` plugin array if the v2 loader requires it.
- Systems: newborn-session model routing (TUI `/new` and headless session creation); no per-turn cost; no config-file writes; no preset-block or agents-block edits.
- Untouched: `.opencode/plugins/delegation-observer.ts` (seam family reused, file untouched), OMO dist, existing presets, `delegation-observer` registry behavior.
- Dependencies: OMO pinned npm dist 2.2.19 as the v2 shape authority (vendored checkout is REFERENCE-ONLY per F5); `@opencode-ai/plugin` v2 event + session surface.
- Rollback: delete the new plugin file (and its registration line if added); sessions revert to current stale-model behavior. One-key revert, no migration.

## Alternatives considered

- A. O2 chat.message model override: rejected - NO-GO at ai--1 gate; no hook or v1 client method sets a per-message model, fights the SDK session-channel contract. Evidence Tier-1: `.opencode/memory/adr.md:2337-2340` (O2 REJECTED), `.opencode/learnings/external-patterns/2026-09-21-preset-model-guard.md:10-11` (F1 NO-GO).
- B. S3 stripOrchestratorModel re-add: rejected - REVERTED per ai-auditor F4; inert under all presets because every preset sets orchestrator.model explicitly, so the strip guard never fires and gives false confidence. Evidence Tier-1: `.opencode/memory/adr.md:2341-2346` (S3 REVERTED), `2026-09-21-preset-model-guard.md:53-62` (revert closeout).
- C. Status-quo / do nothing: rejected - `/new` keeps landing sessions on a stale model with a footer-vs-routing mismatch and zero warning, worst in automation. Evidence Tier-1: `knowledge/res-260921-qivl-container-model-isolation/res-260921-qivl-container-model-isolation-conspect.md:24-54` (session/agent separation) and `:56-79` (issue 42561 silent-wrong-model precedent).
  Chosen option: S1 v2 session.created switchModel guard - because it is the only sanctioned action path (V2-ONLY verdict: v1 observes but cannot act) and it fires once at creation without touching config. Evidence Tier-1: `.opencode/memory/adr.md:2360-2379` (S1 V2-ONLY), `res-260921-qivl conspect:80-97` (switchModel as sanctioned switch).

## Testing Decisions

A good test for this change proves the guard acts exactly once on divergence and never otherwise, without blocking session creation: divergent newborn + env + no override yields one switchModel to intent; explicit override, env absent, already-correct, and duplicate-event cases yield zero additional calls; a throwing switchModel leaves the session alive on its newborn model with no retry. Modules under test: the new guard file at the session.created seam only. Prior art: `delegation-observer.ts` "event" hook tests (session.created RUNNING / idle COMPLETE / error FAILED lifecycle), DIA-189 platform-gate fixture pattern (env-marker-gated assertions), verify-pre-push.bats structural assertions for wiring.

## Gate

DIA-104 Phase 0a: gate_state=grill-required; triggers=new-module,cross-cutting; waivers=none; interview=Compressed Q1/Q2/Q4/Q5/Q7 all agreed no amendments. (Mirror to DIA-260918-ok9m ticket frontmatter by orchestrator; openspec-plan cannot edit outside openspec/ per lane permissions.)

ownership:
substance: developer
structure: AI
interview_depth: compressed
interview_reason: "narrow scope (one hook, one call, three exemptions); evidence archived (ADR, res-260921-qivl, preset-model-guard note); v2 cost known"
