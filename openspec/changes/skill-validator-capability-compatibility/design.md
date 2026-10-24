## Context

See `proposal.md` for motivation and `specs/skill-capability-compatibility/spec.md` for required behavior. The current validator is a standalone shell validation boundary with Bats coverage through `SKILLS_ROOT`. This design extends that boundary without introducing a module, dependency, service, persistent state, or public API.

This design is governed by `.sdd/opencode-config/architecture.md`, which owns OpenCode configuration and agent permissions. `.sdd/dev-infra/architecture.md` confirms that global OpenCode permissions remain outside the dev-infra worktree lifecycle boundary. No new architectural decision or module boundary is required.

## Goals / Non-Goals

**Goals:**

- Resolve agreed explicit capability declarations against a single read-only runtime manifest per run.
- Preserve deterministic collect-all diagnostics and the existing exit-code contract.
- Cover valid and invalid compatibility behavior through the existing hermetic Bats seam.

**Non-Goals:**

- Interpret prose, shell examples, or undeclared implicit capabilities.
- Add telemetry, tracing, a new Make target, a new dependency, or a service.
- Persist capability state, modify runtime configuration, or add UI or numerical work.

## Decisions

### One in-process manifest snapshot

`validate-skills.sh` will read preset arrays, command names, agent permissions, and available binaries once at startup and build read-only in-memory membership sets. It will then validate every explicit declaration against that snapshot.

This avoids repeated parsing and subprocess-per-reference work while keeping the compatibility check co-located with the existing form validation. A separate validator or runtime service was rejected because the existing validator and Bats seam already provide the required boundary.

### Explicit declarations are the only input contract

Only machine-readable preset, command, agent-permission, and binary declarations participate in compatibility validation. Empty optional lists are valid; empty entries are hard failures. The validator does not derive requirements from narrative text or command examples.

This makes the contract deterministic and avoids treating documentation as configuration.

### Collect-all hard-failure policy

Each unresolved or impossible declaration produces one deterministic `FAIL:` line containing the skill, capability class, declaration, and target. Dangling presets, unknown commands, unknown agents or permissions, missing binaries, and impossible combined requirements are hard failures. Existing form advisories remain warnings.

The validator continues after every expected validation failure and exits 1 if any hard finding exists. Missing or malformed required manifests are validation failures with exit 1; unavailable validator infrastructure uses exit 2.

### Existing Bats fixture seam

`scripts/__tests__/validate-skills.bats` remains the test entry point. Its `SKILLS_ROOT` override supplies isolated skill trees, and fixtures provide clean manifests and runtime binary availability. Tests assert exit status, `FAIL:` output, and summary behavior rather than parser internals.

### Data flow

```text
explicit SKILL.md declarations
  -> validate-skills.sh
  -> one manifest snapshot from config and PATH
  -> membership and satisfiability checks
  -> deterministic FAIL lines plus existing summary and exit status
```

## Seams

The developer confirmed these seams before test work:

| Seam                                                | Boundary exercised                                            | Test evidence                                 |
| --------------------------------------------------- | ------------------------------------------------------------- | --------------------------------------------- |
| `SKILLS_ROOT`                                       | Explicit skill declaration inputs                             | Bats temporary skill fixtures                 |
| Preset JSONC                                        | Declared preset membership                                    | Valid and dangling-preset fixtures            |
| OpenCode command and agent-permission configuration | Command and permission membership                             | Unknown command and agent-permission fixtures |
| Clean runtime `PATH`                                | Required binary availability and impossible bash requirements | Valid-binary and impossible-bash fixtures     |
| Validator stdout, stderr, and status                | Observable result contract                                    | Exit and deterministic `FAIL:` assertions     |

## Test Strategy

- Keep the real-tree baseline at 26 passed and 40 warnings.
- Add hermetic valid-declaration coverage that exits 0.
- Add separate invalid coverage for dangling presets, unknown commands, unknown agents or permissions, missing binaries, and impossible bash requirements; each asserts its `FAIL:` line and exit 1.
- Add a multi-failure fixture to prove collect-all reporting.
- Retain exit-2 infrastructure coverage and existing form-warning coverage.
- Verify the validator parses each manifest once, uses in-memory sets, and probes each distinct binary once through focused implementation review and the hermetic fixture design; no benchmark is required.

## Risks / Trade-offs

- [Runtime configuration drift] -> The validator reads the configured manifests for each run and fails missing or malformed required inputs rather than silently accepting stale declarations.
- [Environment-dependent binary availability] -> Fixtures control the runtime environment; production reports the exact unresolved binary.
- [Large declaration lists] -> One manifest snapshot, membership sets, and one probe per distinct binary avoid per-reference process cost while preserving no-cap collect-all behavior.
- [Overreach into documentation] -> The explicit-declaration-only contract excludes prose inference.

## Migration Plan

1. Extend the existing validator and its Bats fixtures in one bounded change.
2. Run the existing skill and config validation gates to establish valid behavior and preserve the real-tree baseline.
3. Roll back by reverting the compatibility tier and its fixtures together. The prior form validator remains intact; no migration, state cleanup, or runtime restart is required.
