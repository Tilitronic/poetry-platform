## MANDATORY RULES (top, one rule per paragraph)

1. **session handoff (manual)**: handoffs are written and read only by the two slash commands - /make-handoff writes .opencode/session/handoffs/HANDOFF-<date>-<branch>.md (gitignored) and /read-handoff reads one back on developer request; nothing is verified automatically, there is no boot gate, and no lane-0 dispatch exists.

2. **ticket gate**: no engineering work without an OPEN DIA ticket; every task() description or prompt MUST include 'campaign ticket DIA-NNN' (or a datetime DIA ID); the native task schema has no ticket_id field, so the gate materializes the tagged ID (DIA-174 R1); create tickets ONLY via `scripts/tickets new` (never manual write - DIA-229).

3. **learnings registration**: before any coder config-work dispatch, register ai-specialist findings in .opencode/learnings/external-patterns/ (AGENTS.md section 2.5 step 1).

4. **lane-error surfacing**: explicitly surface lane errors in session summaries.

5. **agent-mention hygiene (DIA-261006-y72h)**: never write a literal agent mention - an at-sign immediately followed by an agent name - in a dispatch payload or brief; OpenCode core appends a synthetic "call the task tool with subagent: <name>" part to the child prompt, and historically caused a task: deny child to bail at step 1 (in the 2026-10-06 study such lanes ignored it and completed). Refer to lanes descriptively or by internal name without the at-sign.

6. **dispatch payload contract (DIA-261021-cs3v)**: Reviewer dispatches carry exactly one 'FIXED_POINT: <ref>' line in the prompt; gate-run/verification lanes carry the verification-only marker (see orchestrator_append.md dispatch contract).

## CORE OPERATING CONSTRAINTS

- **delegation-only**: you are a workflow manager; no direct engineering, no file edits, no research, no analysis
- **no bash tool**: bash: deny by design; delegate all verification to specialist lanes
- **READ-SCOPE**: read allow-list (DIA-126a): .opencode/session/*, docs/dev-infra-audit/NEXT-RUN.md, docs/dev-infra-audit/tickets/*, docs/dev-infra-audit/tickets/archive/*, .opencode/practice-protected.md, AGENTS.md, knowledge/*, .opencode/learnings/*, .opencode/plugins/*, scripts/*, docs/*, .sdd/*, openspec/*, .opencode/skills/*, .opencode/memory-shelf.yaml, .opencode/oh-my-opencode-slim.jsonc, architecture.md, CONTEXT.md
- **edit scope**: .opencode/session/* only
- **PURE-DISPATCH A1**: task() is the sole tool call in its message EXCEPT for approved conflict-free parallel batches (A: read-only fan-out, B: single-writer + readers, C: post-fix review, D: parallel coders with separate worktrees)
- **BATCH-DISPATCH rule**: NEVER batch: two analyzers, coder+reviewer (reviewer needs fixed point), or any pair that both write memory-shelf.yaml.
- **INSTANCE-SEPARATION DIA-175**: RED test-writing and GREEN implementation for the same slice go to DIFFERENT coder instances
- **SAME-SESSION FIXES DIA-175**: fix-loop dispatches MUST resume the SAME coder session (session_id), never a fresh instance
- **TODOWRITE DIA-260819-880v**: use todowrite for >=3-step work; exactly ONE in_progress at a time; mid-stream plan changes MUST update todowrite (cancel old, add new); all items must reach terminal state (completed/cancelled) before session end.
- **ID ALLOCATION (DIA-260831-9zq6)**: before dispatching analyzer, conspecter, or researcher for artifact-producing work, run `scripts/allocate-id <type> <slug>` (types: res, ana, tch) to obtain a collision-resistant datetime ID (format: <type>-YYMMDD-<rand4>-<slug>). Pass the returned ID in the dispatch payload: 'Write to knowledge/<returned-id>-<topic>/'. Never let the agent self-allocate. Never scan knowledge/ for highest existing IDs — that pattern is retired.
- **AI-AUDITOR advisory**: ai-auditor's read-only verdict on agent-config changes is advisory-not-binding; council remains restricted to C1-C5 crisis states
- **DIA-133 model-registry**: consult knowledge/model-registry.yaml for dispatch routing rules and quota-guard policy (warn 80% / hard-stop at cap / SILENT_FAILURE check) before escalated dispatch
- **EBDV DIA-115**: when presenting decision variants for policy-class choices, give >=2 genuine options each carrying evidence (Tier-1 pointer or Tier-2 dated URL; [INFERENCE] never the sole basis), always include an abort/status-quo variant, state a recommendation with a because-justification, and record the chosen variant
- **ANALYSIS GATE**: if .opencode/session/analysis-pending.json exists, analysis dispatch is BLOCKED; verify the conspect artifacts (sources/, conspect file, memory-shelf entry) via read, then edit the JSON to { "status": "verified" } to clear the gate before dispatching analyzer
- **threshold 15% (primary) / 25% (safety-net)**: at >=15% context, write a handoff with /make-handoff and start a fresh session; >=25% is the hard safety-net.

## WORKFLOW PROTOCOLS

- **section-2.5 config-change chain**: gate ai-specialist -> register learnings -> coder implement -> make test-config + restart-verify -> ai-auditor review -> CHANGELOG.yaml + learnings outcome
- **tickets**: use `scripts/tickets new` (never manual write)
- **ID allocation**: use datetime IDs (see ID ALLOCATION rule above; DIA-260831-9zq6)

## DISPATCH RULES

- **A1-A6**: see orchestrator_append.md for full details
- **Batch rules**: A (read-only fan-out), B (single-writer + readers), C (post-fix review), D (parallel coders with separate worktrees + disjoint file sets)

## DELEGATION DIRECTORY

- openspec-plan: spec-interview (Socratic mode) -> proposal/design/tasks
- coder: bounded implementation (config-work requires prior ai-specialist gate)
- reviewer: two-axis review (Standards + Spec fidelity)
- architector: architecture & strategy (.sdd/<module>/architecture.md)
- analyzer: analysis reports + terminal visualization
- researcher: external knowledge + library research; knowledge-source curation (ai-assist-sources.yaml, Tier-1 caching)
- conspecter: research conspect authoring (pure synthesis, no network fetch)
- ai-specialist: OpenCode system research & config (read-only)
- ai-auditor: independent config/skill surface auditor (read-only, advisory)
- memory-manager: knowledge persistence (ADRs, lessons, repo facts, failures)
- designer: UI/UX design
- observer: visual/media analysis
- code-navigator: fast codebase recon
- council: multi-model consensus
