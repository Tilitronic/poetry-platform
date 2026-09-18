## Why

The `simplify` skill exists in both the project tree (`.opencode/skills/simplify/`) and the global OMO tree (`~/.config/opencode/skills/simplify/`), creating a Tier-2 near-duplicate warning from `validate-skills.sh`. While this currently passes `make test-config` (warn-only, exit 0), it represents latent risk: if the copies ever become byte-identical, Tier-1 HARD fires and breaks the build. The ownership question is unresolved, and the ticket premise (DIA-260823-v9di) incorrectly claimed byte-identical files and a hard failure. The correct remedy is to establish clear ownership: the global OMO source is canonical for non-load-bearing skills, and the project copy should be removed.

## What Changes

- **Delete** the project `simplify` skill directory (`.opencode/skills/simplify/`) — the global OMO copy is canonical
- **Update** `.opencode/skills/README.md` to remove `simplify` from the project-pinned skills list (23 → 22 skills) and document that `simplify` is now global-only
- **Update** `docs/onboarding.md` to remove `simplify` from the Layer 2 skills table
- **Correct** the DIA-260823-v9di ticket premise: the files are NOT byte-identical (3 differing hunks), and `validate-skills` emits a SOFT warn-only (not a HARD failure)
- **Verify** post-change: `make test-config` passes, no orphan references to the project simplify skill remain, and the global OMO source resolves correctly

## Capabilities

### New Capabilities

None — this is a tooling/docs change with no spec-level behavior changes.

### Modified Capabilities

None — no existing capabilities have requirement changes.

**Note:** This change sets `skip_specs: true` in `.openspec.yaml` because it is purely a skill-ownership remediation and documentation update. No spec-level behavior changes.

## Impact

- **Skills resolution:** `simplify` will resolve only from the global OMO tree (`~/.config/opencode/skills/simplify/`). This is acceptable because `simplify` is non-load-bearing for this repo's builds, tests, and agent contracts (per DIA-084 disposition).
- **Documentation:** `.opencode/skills/README.md` and `docs/onboarding.md` will reflect the corrected skill count and ownership.
- **Validators:** `make test-config` will pass without the near-duplicate warning. No validator logic changes.
- **Risk outside this user home:** The global-only `simplify` skill will NOT resolve in CI/containers/other machines without this user's home directory. This is accepted per DIA-084: if a future workflow makes `simplify` load-bearing, pin it at project level in the same change that adds the dependency.

## Alternatives considered

- **Keep project copy as canonical, delete global copy:** Rejected — the global OMO tree is the source of truth for non-load-bearing skills (DIA-084 convention). The project copy was a stale drift, not an intentional override. Evidence: DIA-084 two-tier skill architecture documentation.
- **Symlink project to global:** Rejected — symlinks break portability (CI/containers without the global tree) and add complexity for no benefit. The skill is non-load-bearing; deletion is simpler. Evidence: DIA-084 risk-mitigation strategy (pin at project level only when load-bearing).
- **Align content (make byte-identical):** Rejected — this would trigger Tier-1 HARD failure (byte-exact duplicate). The files already differ in 3 hunks (verification checklist wording), indicating intentional drift. Forcing alignment would lose the project-specific refinements. Evidence: `diff` output in DIA-260823-v9di.
- **Status-quo / do nothing:** Rejected — latent Tier-1 risk remains. If the copies ever align, `make test-config` breaks. The ownership question is unresolved, and the ticket premise is incorrect. Evidence: DIA-260823-v9di investigation findings.

**Chosen option:** Delete project copy, retain global OMO source — because the global tree is canonical for non-load-bearing skills (DIA-084), the project copy is stale drift, and deletion removes the latent Tier-1 risk with minimal impact (skill is non-load-bearing).
