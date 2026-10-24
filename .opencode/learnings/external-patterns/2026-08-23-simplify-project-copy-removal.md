# simplify skill: project-copy removal decision (DIA-260823-v9di)

- Date: 2026-08-23
- Source: ai-specialist findings (verified, read-only research). Registered per AGENTS.md section 2.5 Phase 1 (orchestrator registers findings before config implementation).
- Status: LEARNING-REGISTRATION ONLY. No config implementation performed. Do NOT delete skills, edit docs/config, alter tickets, or run implementation on the basis of this artifact.
- Ticket: DIA-260823-v9di 'simplify-project-copy-removal' (docs/dev-infra-audit/tickets/DIA-260823-v9di-simplify-project-copy-removal.md, OPEN).

## Context

The `simplify` skill exists in two places: the OMO-bundled GLOBAL copy (canonical) and a PROJECT copy pinned into this repo. The ai-specialist confirmed the global OMO source is the canonical upstream; the project copy is a downstream pin from DIA-084 carrying 3 local divergences. The only overlap is project-vs-global; there is no third source. Precedence resolves global-wins, so the project copy is shadowed in the current workspace (Tier-2 soft near-duplicate). However, the host runtime may hard-fail on a byte-exact duplicate, making the project copy a latent hazard rather than a benefit.

## Findings (evidence-only)

- F1: OMO bundled global `simplify` is canonical; the project copy is a DIA-084 downstream pin with 3 local divergences (divergence detail retained in the ticket, not re-derived here).
- F2: Only project/global overlap exists; no other source competes.
- F3: Precedence is global-wins; in the current workspace the project copy is a Tier-2 soft near-duplicate (shadowed, not loaded).
- F4: The host runtime may hard-fail on a byte-exact duplicate, so the project copy is a latent failure risk even though it is currently shadowed.

## Decision

Safe remedy: DELETE the project copy and UPDATE docs to reference the retained global OMO source. Retain the global OMO `simplify` as the single canonical source. No new abstraction, no re-pin.

## Risks

- R1: If any doc/config references the project copy path, deletion leaves a dangling reference -> must be swept in the same change (docs update is part of the remedy).
- R2: The 3 local DIA-084 divergences are lost on deletion; confirm none are load-bearing before applying (ticket holds the divergence inventory).
- R3: Host byte-exact duplicate hard-fail is the trigger; leaving the project copy in place preserves the hazard.

## Validation

- V1 (pre-implementation, read-only): confirm global-wins precedence and that the project copy is currently shadowed (Tier-2 soft near-duplicate) -> done by ai-specialist.
- V2 (post-implementation, when approved): `make test-config` exits 0; grep for the project-copy path across docs/config returns zero references; `git status` shows only the deletion + doc-update files, no ticket or unrelated changes.

## Outcome field

PENDING - LEARNING REGISTRATION ONLY. No implementation performed. [Update after developer disposition: applied / rejected / deferred, with V2 evidence if applied.]

## Tags

DIA-260823-v9di, simplify-skill, project-copy-removal, omo-global-canonical, dia-084-downstream-pin, global-wins-precedence, byte-exact-duplicate, learning-registration-only, no-implementation, ai-specialist
