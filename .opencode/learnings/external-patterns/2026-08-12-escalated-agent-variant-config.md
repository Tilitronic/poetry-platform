# Escalated agent variant config - coder-escalated / analyzer-escalated (2026-08-12)

- **Date:** 2026-08-12
- **Source:** DIA-111 (coder/analyzer model escalation) + DIA-108 (optimal model assignment audit), developer-approved revised design 2026-08-12; evidence from knowledge/res016-coder-escalated-model-evidence/res016-coder-escalated-model-evidence-conspect.md (25 sources); probe evidence on opencode 1.18.16 task() schema recorded in DIA-111 Fix/Probe.
- **Status:** IMPLEMENTED - two hidden orchestrator-only escalated agents added (coder-escalated -> opencode-go/kimi-k3, analyzer-escalated -> opencode-go/gpt-5.6-luna) across all 4 lockstep sources; make test-config exit 0 (224 known WARNs); pre-commit hook ran live (container up).

## Pattern

OpenCode's task() tool has NO per-dispatch model override (probe, opencode 1.18.16: task input schema = description, prompt, subagent_type, task_id, command, background — no model param; child model resolved from the agent definition's `model` key, or inherited from the invoking parent only when the agent defines no model). Model escalation therefore REQUIRES dedicated escalated agent definitions (Option C), not orchestrator-prompt routing (Option B). The child session self-report confirmed: parent model was NOT inherited when the agent defines a model.

## Rule

- **Agent schema keys** (opencode.jsonc agent block): description (required), mode (subagent), model (provider/model-id string), permission, hidden (bool), disable, temperature, prompt. `hidden: true` hides the agent from @autocomplete but task() dispatch still works.
- **4-source lockstep contract** (scripts/validate-agent-names.sh; `make test-config` HARD-fails on drift): S1 = AGENTS.md section 9 table internal-name column; S2 = .opencode/opencode.jsonc `agent` block keys + orchestrator permission.task allow-list; S3 = .opencode/oh-my-opencode-slim.jsonc `agents` node + preset routing values (per-preset agent keys) + disabled_agents; S4 = .opencode/agents/*.md filename stems (optional; every *.md there registers a real agent at startup, so only create files for agents you actually want registered). Containment, not set-equality: a config-defined agent need not have an S4 file.
- **Escalated-agent config pattern:** define the escalated variant in S2 with an exact permission clone of the base agent; add `task: "deny"` on the escalated CODER for quota protection (the escalated lane must never delegate further; the base analyzer already denies task). Add the escalated names to the S2 orchestrator permission.task allow-list ("<name>": "allow") or task() dispatch silently fails. In S3 add the agent to the agents node with an orchestratorPrompt documenting trigger conditions + one-shot no-retry + routing-back, AND add a per-preset entry with the target model, FULL skill array cloned from the base (not stripped), same temperature/variant as the base. Record the display->internal mapping in the S1 AGENTS.md table.
- **hidden semantics:** `hidden: true` on both escalated agents keeps them out of @autocomplete (no accidental user dispatch), while orchestrator task() dispatch (allow-listed) still works. Orchestrator-only dispatch is additionally documented in S1 lane text + S3 orchestratorPrompt.

## Evidence verdict (res016, 25 sources)

- coder-escalated -> opencode-go/kimi-k3: chosen on SWE-bench Verified evidence (93.4% per Go docs) as the strongest available coding model for complex problem-fix tasks; kimi-k3 has a hard 490 req/mo cap -> ONE-SHOT no-retry rule.
- analyzer-escalated -> opencode-go/gpt-5.6-luna: chosen for 'cannot comprehend domain' expert analysis (developer-provided reference flow).
- Cap fallback routing: on kimi-k3 cap exhaustion, orchestrator asks the developer via wait_for_user BEFORE falling back to deepseek-v4-pro/mimo-v2.5-pro (quota-critical decision is never made silently).

## Restart-verify checklist (next OpenCode boot)

1. Hidden check: escalated agents do NOT appear in @autocomplete agent list; both appear in `opencode agents` / agent listing.
2. task() dispatch: orchestrator can dispatch task(subagent_type: "coder-escalated") and "analyzer-escalated" without permission errors (S2 allow-list works).
3. Model self-report: dispatched child session self-reports "opencode-go/kimi-k3" / "opencode-go/gpt-5.6-luna" respectively (agent-definition model wins, per probe).
4. `make test-config` still exit 0 (224 known WARNs).

## Reusable lesson

Model escalation in OpenCode is done by defining dedicated escalated agent variants (agent-definition `model` key is the only override mechanism — task() has no per-dispatch model param). Keep escalated variants hidden + orchestrator-only, clone base permissions exactly, add task deny for quota protection, allow-list them in the orchestrator task permission, clone full skill arrays in the active preset, and register the name in all 4 lockstep sources atomically. Budget-capped escalation models (e.g. kimi-k3 490 req/mo) need a documented one-shot no-retry rule with wait_for_user fallback routing.

## Tags

DIA-111, DIA-108, escalation, kimi-k3, gpt-5.6-luna, hidden-agent, orchestrator-only, one-shot, quota-protection, task-deny, lockstep-contract, res016, 4-source, model-override, wait_for_user-fallback
