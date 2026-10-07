# ai-specialist Phase 1 Gate Review: Orchestrator Prompt Fixes (DIA-235)

- Source: ai-specialist Phase 1 gate review (ai--1, ses_fe56ce71fffeMcXCLzMuZJiyif)
- Date: 2026-08-19
- Ticket: DIA-235

## Findings

### Fix 1: Read-scope reference pattern (approved with modifications)
- The orchestrator prompt references read-scope incorrectly, causing it to attempt file reads outside its allowed scope.
- Best-practice alignment: Anthropic context engineering -- avoid conflicting instructions; the read-scope must match the agent's actual tool permissions.
- Modification: Scope the reference to the exact files the orchestrator needs, not a blanket read-all.

### Fix 3: MANDATORY RULES section (approved with modifications)
- The orchestrator prompt lacks a clear MANDATORY RULES section, leading to ambiguous behavior on critical workflow gates.
- Best-practice alignment: Clear role boundaries and explicit mandatory rules reduce agent confusion and improve reliability.
- Modification: Add a concise MANDATORY RULES section at the top of the orchestrator prompt, covering batch-approval, ticket-gate, and learnings-registration.

## Risks
- 3 presets affected (orchestrator, coder, reviewer); restructuring may affect other logic that depends on current prompt layout.
- Changes to MANDATORY RULES section may shift agent behavior in unexpected ways -- requires smoke testing.

## Next Steps
1. @coder implementation of approved fixes
2. make test-config validation
3. Restart OpenCode and verify behavior
4. @ai-auditor review of implemented changes

## Verification pass deltas (2026-08-19, ai-specialist ses_fe5498dc2ffeRhbcSd9f0QM6vJ)

### Preset naming correction
- 3rd preset key is `free` (line 414), NOT opencode-copilot
- Drift checker PRESETS default: `opencode-go cebula free`

### Stale references confirmed
- Prompt lines 26/209/433 reference `.opencode/session/current-handoff.json` twice (batch-approval boot + handoff-checksum)
- orchestrator_append.md line 144 stale (current-handoff.json)
- orchestrator_append.md line 243 intentional fallback (keep -- documents DIA-085 legacy fallback path)

### Drift markers survival table
All 8 markers survive restructure if phrases kept:
- no-bash-tool: 'no bash tool' (case-sensitive)
- batch-approval: 'batch-approval' (case-sensitive)
- DIA-133: 'DIA-133' (case-sensitive)
- pure-dispatch: 'pure-dispatch' (case-INSENSITIVE)
- read-scope-note: 'READ-SCOPE' (case-sensitive)
- ebdv-clause: 'EBDV' (case-sensitive)
- threshold-15-25: '15% (primary)' (case-sensitive)
- delegation-only: 'delegation-only' (case-sensitive)

### Read-scope enumeration (DIA-126a expansion)
18 paths: .opencode/session/*, docs/dev-infra-audit/NEXT-RUN.md, docs/dev-infra-audit/tickets/*, docs/dev-infra-audit/tickets/archive/*, .opencode/practice-protected.md, AGENTS.md, knowledge/*, .opencode/learnings/*, .opencode/plugins/*, scripts/*, docs/*, .sdd/*, openspec/*, .opencode/skills/*, .opencode/memory-shelf.yaml, .opencode/oh-my-opencode-slim.jsonc, architecture.md, CONTEXT.md

### Routing gate structural bug (Bug 7) -- DEADLOCK CONFIRMED AND FIXED
- Routing gate scanned for delegation rows with session_id, but delegation rows don't include session_id in payload
- Paracrine dispatch.started rows DO include session_id + agent fields
- FIX committed 10b02d1: changed scan to match paracrine dispatch.started rows
