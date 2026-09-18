# Orchestrator project-ops knowledge routing (2026-08-11)

- **Date:** 2026-08-11
- **Source:** Campaign c-20260809-residual-closure - developer directive (2026-08-11) filed as DIA-095 by the coder lane; S10-P6 registration by code-executor lane.
- **Status:** IMPLEMENTED - AGENTS.md section 6 (Option A), commit 56cc42b; ai-specialist gate complete; ai-auditor independent review APPROVED; S10-P6 registration complete.
- **Outcome note:** implemented (AGENTS.md section 6, commit 56cc42b).

## Ticket

- **DIA-095** (Major, CLOSED) - "Orchestrator needs an optimized project-ops reference - how to run the project, bring up docker, required gates".
- **Related:** DIA-094 (docker gate - work must not start without docker up), DIA-063 (ticket gate - no work without a DIA ticket), DIA-080 (orchestrator stops - setup knowledge reduces guesswork).

## Topic

- Orchestrator project-ops knowledge routing.

## Finding

- The orchestrator read scope excludes README and docker-dev setup docs. The opencode.jsonc orchestrator `read` block allows only `.opencode/session/*`, `docs/dev-infra-audit/NEXT-RUN.md`, `docs/dev-infra-audit/tickets/*` (+ archive), `.opencode/practice-protected.md`, and `AGENTS.md` - everything else is deny. There is no root README.md; the setup knowledge lives in `docs/docker-dev.md`, `docs/onboarding.md`, `Makefile`, `docker-compose.yml` - none orchestrator-readable. Project-ops commands (bring-up + required gates) must therefore live in AGENTS.md (or another orchestrator-readable location).

## Pattern

- When an agent's read scope excludes setup docs, distill bring-up + gates into AGENTS.md with a lean command reference verified against the Makefile. AGENTS.md is both read-allowed and prompt-injected, so the knowledge reaches the orchestrator with zero extra boot steps and also helps every other agent and the developer.

## Outcome

- Implemented: AGENTS.md section 6 "Project Ops Quick Reference" - bring-up commands (`cp .env.example .env`, `make up` = `docker compose up -d`, `make shell`, `make install`, `make dev`, `make opencode`, `make down`, `make clean`), container-dependent vs host-runnable gates, and the DIA-094 docker-required rule (commits must not land without a running docker dev container). Commit 56cc42b.
- S10-P6 registration complete 2026-08-11: CHANGELOG entry added + this learnings registration; DIA-095 OPEN to CLOSED.

## Reusable lesson

- Project-ops knowledge for an agent must be surfaced in a location that agent can actually read. Before assuming a doc is visible, check the agent read permission block. A compact AGENTS.md reference verified against the Makefile beats a full setup doc the agent cannot open.

## Tags

DIA-095, DIA-094, DIA-063, DIA-080, project-ops, orchestrator, read-scope, AGENTS.md, docker-gate, bring-up
