## Context

See proposal.md — the `simplify` skill exists in both project and global trees, creating a Tier-2 near-duplicate warning. The global OMO tree is canonical for non-load-bearing skills (DIA-084 convention). The project copy is stale drift that should be removed to eliminate latent Tier-1 risk.

## Goals / Non-Goals

**Goals:**

- Remove the project `simplify` skill directory (`.opencode/skills/simplify/`)
- Update documentation to reflect the corrected skill count and ownership
- Correct the DIA-260823-v9di ticket premise (files are NOT byte-identical, validator emits SOFT warn-only)
- Verify post-change: `make test-config` passes, no orphan references remain, global OMO source resolves correctly

**Non-Goals:**

- Do NOT modify the global `simplify` skill content
- Do NOT change `validate-skills.sh` or any validator logic
- Do NOT modify any other project skills
- Do NOT implement any code changes (this is purely a skill-ownership remediation and documentation update)

## Decisions

**Decision 1: Delete the project simplify directory entirely**

Rationale: The global OMO tree is the source of truth for non-load-bearing skills (DIA-084). The project copy was pinned on 2026-08-11 for CI/container portability, but `simplify` is non-load-bearing for this repo's builds, tests, and agent contracts. Deletion is simpler than symlinks or content alignment, and removes the latent Tier-1 risk.

Alternatives considered:

- Symlink project to global: breaks portability, adds complexity for no benefit
- Align content (make byte-identical): triggers Tier-1 HARD failure, loses project-specific refinements
- Keep project copy as canonical: contradicts DIA-084 convention (global is canonical for non-load-bearing)

**Decision 2: Update `.opencode/skills/README.md` to remove `simplify` from project-pinned list**

Rationale: The README documents the two-tier skill architecture. After deletion, `simplify` moves from the project-pinned list (23 skills) to the global-only list (8 → 9 skills). The README must reflect the corrected counts and ownership.

Changes:

- Remove `simplify` from the project-pinned skills list (line 39-46)
- Add `simplify` to the global-only skills list (line 54-57)
- Update the project-pinned count from 23 to 22 (line 26)
- Update the global-only count from 8 to 9 (line 48)

**Decision 3: Update `docs/onboarding.md` to remove `simplify` from Layer 2 skills table**

Rationale: The onboarding doc lists project skills in the Layer 2 table. After deletion, `simplify` should be removed from this table since it no longer resolves at project level.

Changes:

- Remove the `simplify` row from the Layer 2 skills table (line 156)

**Decision 4: Correct the DIA-260823-v9di ticket premise**

Rationale: The ticket incorrectly claimed byte-identical files and a HARD failure. The actual state: files differ in 3 hunks, validator emits SOFT warn-only (exit 0). The ticket description must be corrected to reflect the observed evidence.

Changes:

- Update the ticket description to clarify that files are NOT byte-identical
- Clarify that `validate-skills` emits a SOFT warn-only (not a HARD failure)
- Document the observed evidence (diff output, validator exit codes)

**Decision 5: Verify post-change state**

Rationale: After deletion and documentation updates, verify that:

- `make test-config` passes (no near-duplicate warning, no HARD failure)
- No orphan references to the project simplify skill remain (grep for `.opencode/skills/simplify`)
- The global OMO source resolves correctly (`opencode` runtime loads `simplify` from global tree)

Verification steps:

1. Run `make test-config` — expect exit 0, no simplify-related warnings
2. Run `grep -r ".opencode/skills/simplify" .` — expect no matches (except this change's artifacts)
3. Run `opencode` and verify `simplify` appears in `<available_skills>` (resolved from global tree)

## Risks / Trade-offs

**Risk 1: Risk outside this user home**

The global-only `simplify` skill will NOT resolve in CI/containers/other machines without this user's home directory.

Mitigation: Accepted per DIA-084 disposition. `simplify` is non-load-bearing for this repo's builds, tests, and agent contracts. If a future workflow makes `simplify` load-bearing, pin it at project level in the same change that adds the dependency.

**Risk 2: Orphan references in documentation or scripts**

Other docs or scripts may reference the project simplify skill path.

Mitigation: Post-change verification includes a grep for orphan references. Any matches are updated or removed as part of this change.

**Risk 3: Developer confusion about skill location**

Developers may expect `simplify` to be project-pinned (per the current README).

Mitigation: Update the README and onboarding doc to clearly document that `simplify` is now global-only. The README's "Risk outside this user home" section already explains the mitigation strategy.
