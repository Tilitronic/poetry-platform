---
# ID-Allocation Drift: orchestrator rule never wired to scripts/allocate-id
Date: 2026-08-31
Ticket: DIA-260831-9zq6 (follow-up to DIA-260819-8kwm, CLOSED)
Source: @ai-specialist gate review (session ai--1)

## Finding
The unified-ID ticket DIA-260819-8kwm (CLOSED) created `scripts/allocate-id` to emit collision-resistant datetime IDs (`<type>-YYMMDD-<rand4>-<slug>`) for res/ana/tch/DIA, eliminating sequential scanning. But the orchestrator prompt's ID ALLOCATION rule was never updated — it still instructs "scan knowledge/ for highest existing <type><nnn> and assign the next integer". The script exists, is hardened (DIA-260826-pjm: 4-char suffix + burst entropy), has bats tests, and is already wired into `scripts/tickets new` for DIA IDs, but the orchestrator never calls it for ana/tch/res.

## Fix surface (9 locations)
- 7 orchestrator presets in .opencode/oh-my-opencode-slim.jsonc (opencode-go:26, cebula:208, cebula-openai-hy3:434, cebula-hy3:657, cebula-ox-alpha:915, promo:1170, free:1441)
- .opencode/oh-my-opencode-slim/orchestrator_append.md:54
- .opencode/skills/research-pipeline/SKILL.md:14
- AGENTS.md: NO change needed (no ID-allocation text present)

## Evidence
- scripts/allocate-id supports res/ana/tch/DIA; emits <type>-YYMMDD-<rand4>-<slug>; RAND mixes /dev/urandom + date +%N + PID, truncated to 4 [a-z0-9]; bats tests pass (scripts/__tests__/allocate-id.bats).
- lessons.md:2159 documents a 4-way ana001 collision from non-recursive scan — the scan pattern is a known collision source.
- DIA-260819-8kwm intent: all artifact types use datetime IDs.

## Recommended delta
Replace the scan-based instruction with: run `scripts/allocate-id <type> <slug>` and pass the returned datetime ID in the dispatch payload. Never scan knowledge/ for highest existing IDs.

## Best-practice citation
ai-assist-sources.yaml Tier-1 (Anthropic "Building Effective Agents", "Writing Tools for Agents"): tools should encapsulate deterministic logic; agents call tools, not reimplement via convention. The scan rule asked the LLM to do a filesystem scan + arithmetic — exactly the brittle convention a tool call eliminates.

## Outcome
[to be filled after implementation + @ai-auditor review for DIA-260831-9zq6]
---
