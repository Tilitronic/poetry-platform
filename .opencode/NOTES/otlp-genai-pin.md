# OTel GenAI Semantic Conventions — Pin Record

- **Status**: ACTIVE (2026-08-03)
- **Standard**: open-telemetry/semantic-conventions-genai v1.42.0 (June 2026)
- **URL**: https://github.com/open-telemetry/semantic-conventions-genai
- **Stability**: ALL `gen_ai.*` attributes are Development status — schema may change. Treat renames as non-breaking appends (add new field alongside old; no in-place deletion).

## Where the pin is enforced
- Canonical runtime doc (GITIGNORED): .opencode/session/README.md — schema table + example line for the JSONL sidecar.
- Orchestrator behavior: .opencode/oh-my-opencode-slim/orchestrator_append.md "JSONL Sidecar (messages.jsonl)" section + 3 preset prompts in oh-my-opencode-slim.jsonc ("messages.md + messages.jsonl").
- This tracked copy: preserves the pin across fresh clones. If the convention is bumped, update BOTH this file and the session README.

## JSONL sidecar (messages.jsonl)
- Location: .opencode/session/messages.jsonl (gitignored, forward-only, no backfill of rows 1–114).
- One JSON object per orchestrator log event (delegation result / user decision / handoff / crisis), dual-written alongside messages.md rows.
- Fields: timestamp (ISO-8601), gen_ai.operation.name (invoke_agent|plan|execute_tool|invoke_workflow), gen_ai.agent.name, gen_ai.provider.name, gen_ai.request.model, gen_ai.workflow.name, lane_id, cycle_id (c-YYYYMMDD-HHMMss), from (orchestrator|owner), event_type (delegation|decision|handoff|crisis), task_ref, result_ref, resolution_status; gen_ai.usage.input_tokens / output_tokens populated ONLY at cycle boundaries/handoff via token_stats.
- Project-specific extensions (lane_id, cycle_id, from, event_type, task_ref, result_ref, resolution_status) intentionally outside the gen_ai.* namespace — no collision with semconv.

## Consumers
- None today (opencode-telemetry SQLite + token-monitor do not read JSONL). Future-facing convention; the additive sidecar is safe to extend.
