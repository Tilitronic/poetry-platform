## Purpose

Ensure that explicit skill capability declarations are compatible with the configured runtime before a skill is accepted as valid.

## ADDED Requirements

### Requirement: Resolve explicit capability declarations

The validator SHALL resolve every explicit machine-readable preset, command, agent-permission, and required-binary declaration against the runtime manifest for the validation run. The validator SHALL NOT infer requirements from prose or shell examples.

#### Scenario: Valid declared capabilities

- **WHEN** the `SKILLS_ROOT` seam supplies a skill whose explicit declarations resolve against the fixture runtime manifest
- **THEN** the validator accepts those declarations without a compatibility failure

#### Scenario: Empty optional declaration list

- **WHEN** the `SKILLS_ROOT` seam supplies a skill with an empty optional capability list
- **THEN** the validator accepts the empty list without a compatibility failure

#### Scenario: Empty declaration entry

- **WHEN** the `SKILLS_ROOT` seam supplies an explicit capability list containing an empty entry
- **THEN** the validator reports that entry as a validation failure

### Requirement: Reject unresolved or impossible capabilities

The validator SHALL report each dangling preset, unknown command, unknown agent or permission, missing required binary, and impossible combined requirement as a distinct compatibility failure. Each failure SHALL identify the skill, capability class, declaration, and unresolved target.

#### Scenario: Dangling preset declaration

- **WHEN** the `SKILLS_ROOT` seam supplies a skill declaring a preset absent from the fixture preset manifest
- **THEN** the validator emits a deterministic `FAIL:` line for that preset and exits with status 1

#### Scenario: Impossible bash requirement

- **WHEN** the `SKILLS_ROOT` seam supplies a skill whose explicit bash requirement cannot be satisfied by the fixture runtime capabilities
- **THEN** the validator emits a deterministic `FAIL:` line for that requirement and exits with status 1

#### Scenario: Multiple unresolved declarations

- **WHEN** the `SKILLS_ROOT` seam supplies a skill with more than one unresolved explicit declaration
- **THEN** the validator reports every unresolved declaration before exiting with status 1

### Requirement: Preserve validator outcomes and diagnostics

The validator SHALL retain its existing final passed, failed, and warnings summary. Compatibility failures SHALL contribute to the failed result, while existing form advisories SHALL remain warnings.

#### Scenario: Valid compatibility and form checks

- **WHEN** all form and explicit capability declarations resolve at the validator boundary
- **THEN** the validator exits with status 0 and preserves the existing summary format

#### Scenario: Required manifest unavailable or malformed

- **WHEN** a required runtime manifest at the validator boundary is missing or malformed
- **THEN** the validator reports a validation failure and exits with status 1

#### Scenario: Validator infrastructure unavailable

- **WHEN** required validator infrastructure is unavailable
- **THEN** the validator exits with status 2
