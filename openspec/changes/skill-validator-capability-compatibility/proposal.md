## Why

The skill validator currently checks frontmatter form but does not prove that explicit capability declarations resolve in the configured runtime. A dangling preset or impossible bash requirement can therefore pass validation and fail only when a skill is used.

## What Changes

- Add compatibility validation for explicit machine-readable declarations of presets, commands, agent permissions, and required binaries.
- Build one read-only manifest per validation run from preset JSONCs, command definitions, agent permissions, and `PATH`.
- Report every unresolved claim with a deterministic `FAIL:` line and preserve collect-all validation.
- Extend hermetic Bats fixtures for valid and invalid capability declarations.
- Preserve existing form warnings and the `0` valid, `1` validation failure, and `2` infrastructure failure exit contract.

## Capabilities

### New Capabilities

- `skill-capability-compatibility`: Validates explicit skill capability declarations against the runtime manifest and rejects unresolved or impossible declarations.

### Modified Capabilities

None.

## Impact

- Affected validator: `.opencode/scripts/validate-skills.sh`.
- Affected tests: `scripts/__tests__/validate-skills.bats` and its fixture seam.
- Affected read-only configuration inputs: `.opencode/oh-my-opencode-slim.jsonc` and `.opencode/opencode.jsonc`.
- Governing references: `.sdd/opencode-config/architecture.md` and `.sdd/dev-infra/architecture.md`.
- No new module, dependency, service, persistent state, public API, or data migration. Rollback restores the prior form-only behavior by reverting the compatibility tier and its fixtures together.

## Testing Decisions

Good tests assert observable validator behavior: exit status, deterministic `FAIL:` diagnostics, and the final summary. Bats exercises the existing `SKILLS_ROOT` seam with small hermetic fixtures rather than mutating project configuration or asserting implementation details. The prior art is the existing form-validation and duplicate-detection cases in `scripts/__tests__/validate-skills.bats`.

## Alternatives considered

- Explicit declaration compatibility validation: Resolve only structured preset, command, agent-permission, and binary declarations against a read-only manifest. Chosen. Tier-1: `knowledge/res-260911-emj8-skill-validator-compat/res-260911-emj8-skill-validator-compat-conspect.md` sections 5-7.
- Infer capability requirements from prose and shell examples: Rejected because prose is not a stable machine contract and the developer selected explicit declarations only. Tier-1: interview Q1 and the same conspect section 1.
- Status-quo / do nothing: Rejected because dangling references remain form-valid and runtime-incompatible. Tier-1: conspect sections 2 and 6.

Chosen option: Explicit declaration compatibility validation, because it makes declared runtime requirements verifiable without treating prose as configuration.
