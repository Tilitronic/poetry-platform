## 1. Delete Project Simplify Skill

- [ ] 1.1 Delete the project `simplify` skill directory (`.opencode/skills/simplify/`) — removes the Tier-2 near-duplicate warning and eliminates latent Tier-1 risk

## 2. Update Documentation

- [ ] 2.1 Update `.opencode/skills/README.md` to remove `simplify` from the project-pinned skills list and add it to the global-only skills list; update counts (23 → 22 project-pinned, 8 → 9 global-only)
- [ ] 2.2 Update `docs/onboarding.md` to remove the `simplify` row from the Layer 2 skills table

## 3. Correct Ticket Premise

- [ ] 3.1 Update DIA-260823-v9di ticket description to clarify that files are NOT byte-identical (3 differing hunks) and `validate-skills` emits a SOFT warn-only (not a HARD failure); document the observed evidence

## 4. Verify Post-Change State

- [ ] 4.1 Run `make test-config` — verify exit 0 with no simplify-related warnings
- [ ] 4.2 Grep for orphan references to `.opencode/skills/simplify` — verify no matches (except this change's artifacts)
- [ ] 4.3 Verify the global OMO source resolves correctly — confirm `simplify` appears in `<available_skills>` when running `opencode` (resolved from global tree)
