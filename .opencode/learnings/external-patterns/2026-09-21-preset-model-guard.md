# Preset model guard: stripOrchestratorModel (S3) over chat.message override (O2)

Date: 2026-09-21
Ticket: DIA-260918-ok9m (investigate slash-new preset inheritance without fork)
Gate: ai--1 completed this session. Verdict: NO-GO O2, GO S3 conditional.
Decision (developer): S3-first, S1-spike queued.

## Gate summary (ai--1 F1-F6)

- F1: O2 (chat.message override for orchestrator model) is NO-GO. It fights
  the SDK session-channel contract; brittle across OpenCode versions and
  risks silent drops or session-state corruption.
- F2: S3 (stripOrchestratorModel true) is GO conditional. Single root-level
  boolean in .opencode/oh-my-opencode-slim.jsonc. Opt-in, schema-validated,
  defaults false, one-key revert.
- F3: S3 semantics (dist 2.2.19): when true, omit orchestrator.model and
  orchestrator.variant from the SDK config so OpenCode uses the session
  model selected with /model after subagent dispatch.
- F4: Guard clause: an explicitly selected preset that sets
  orchestrator.model is preserved (strip skipped). So S3 only bites when
  the active preset leaves orchestrator.model undefined.
- F5: Vendored checkout (.opencode/oh-my-opencode-slim/) is REFERENCE-ONLY
  and stale: src/config/schema.ts has no stripOrchestratorModel key. The
  runtime authority is the pinned npm dist
  oh-my-opencode-slim@2.2.19 (plugin array in .opencode/opencode.jsonc),
  which carries the key at dist index.js 19510 (schema), 22405-22406
  (getter), 22517-22529 (strip fn), 49793-49799 (apply call).
- F6: Placement: root level beside preset/compactSidebar. No preset-block
  edit, no agents-block edit, no Makefile change (single-path contract),
  no modelStore / tui-state.json touches.

## Corroborating evidence

- cod-1 PID 32: bare EMPTY evidence (no confirming read of the O2 path;
  treated as no-signal, not as support for O2).
- res-260921-qivl conspect pointer (shelf #47):
  knowledge/res-260921-qivl-container-model-isolation/res-260921-qivl-container-model-isolation-conspect.md
  section 4 documents stripOrchestratorModel as the opt-in flag that
  preserves a runtime /model selection for the orchestrator after subagent
  dispatch by omitting its configured model from the SDK config.
- DIA-187 evaluation (line 137) already lists stripOrchestratorModel among
  the known root keys (preset, setDefaultAgent, compactSidebar,
  stripOrchestratorModel).

## Outcome

- S3 applied: stripOrchestratorModel true at config root. Root preset key
  stays muse-balanced. Verified via make test-config.
- Rollback: delete the one key (or set false); defaults false.
- Queued: S1 spike (preset inheritance without fork) stays open under the
  same ticket; this S3 guard does not close the investigation.

## Outcome update (2026-09-21, S3 revert closeout)

- S3 REVERTED per ai-auditor F4 (developer disposition: revert):
  stripOrchestratorModel key removed from config root (one-key revert,
  nothing else). Root preset key stays muse-balanced. File parses;
  make test-config exit 0.
- S3 judged inert under all presets: every active preset sets
  orchestrator.model explicitly, so the F4 guard (strip skipped when the
  preset sets orchestrator.model) means the flag never bites.
- Investigation-only close: O2 NO-GO stands, S3 applied then reverted,
  S1 spike queued. Conspect pointer res-260921-qivl (shelf 47) retained.
