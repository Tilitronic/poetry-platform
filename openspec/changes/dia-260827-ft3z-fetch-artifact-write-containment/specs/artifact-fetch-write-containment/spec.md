## Purpose

Confines source-fetch artifacts to trusted allocated roots and prevents
untrusted shell commands from writing to workflow-critical repository paths.

## ADDED Requirements

### Requirement: Trusted artifact allocation confines fetched source output

The system MUST accept a fetch URL only with a trusted, pre-allocated artifact
identity. It MUST select the output directory from the allow-listed researcher
root `knowledge/<id>/sources/` or the allow-listed resource-manager OMO
knowledge root. It MUST NOT accept an arbitrary caller-selected output path.

#### Scenario: Researcher artifact is written to its allocation

- **WHEN** a researcher fetches a URL using its trusted allocated identifier
- **THEN** the artifact-fetch boundary publishes the resulting source only
  beneath `knowledge/<id>/sources/` at the artifact-fetch boundary seam

#### Scenario: Resource-manager artifact is written to its allocation

- **WHEN** a resource-manager fetches a URL using its trusted OMO allocation
- **THEN** the artifact-fetch boundary publishes the resulting source only
  beneath the allow-listed OMO knowledge root at the artifact-fetch boundary
  seam

#### Scenario: Caller supplies an arbitrary destination

- **WHEN** a caller attempts to select an output path outside its trusted
  allocation
- **THEN** the artifact-fetch boundary rejects the request and publishes no
  artifact at the artifact-fetch boundary seam

### Requirement: Artifact publication resists path escape and partial output

Before publishing an artifact, the system MUST canonicalize the destination
parent, verify containment in the selected trusted root, and reject traversal
or symlink escape. It MUST use atomic publication so a failed fetch or failed
validation leaves no partial final artifact.

#### Scenario: Traversal target is rejected

- **WHEN** a derived destination would resolve outside the trusted allocation
  through traversal
- **THEN** the artifact-fetch boundary rejects it and leaves no final artifact
  at the artifact-fetch boundary seam

#### Scenario: Symlink escape is rejected

- **WHEN** an in-allocation path resolves through a symlink outside the trusted
  root
- **THEN** the artifact-fetch boundary rejects it and leaves no final artifact
  at the artifact-fetch boundary seam

#### Scenario: Fetch fails before publication

- **WHEN** the fetch operation fails after temporary output begins
- **THEN** no partial file is published at the final artifact path at the
  artifact-fetch boundary seam

### Requirement: Fetch lanes do not retain universal download permissions

After the trusted artifact-fetch boundary is available, the researcher and
resource-manager lanes MUST NOT retain universal `curl *` or `wget *` bash
permissions. Their permitted fetch workflow MUST route artifact publication
through the trusted boundary.

#### Scenario: Legacy universal downloader permission is absent

- **WHEN** the OpenCode configuration is validated after the migration
- **THEN** neither affected lane has a universal `curl *` or `wget *` allow
  rule at the configuration validation seam

### Requirement: Protected workflow paths are denied before bash execution

The delegation-observer MUST reject a bash request before execution when a
resolved write target is a protected workflow path: `.opencode/*`, `scripts/*`,
`AGENTS.md`, Git metadata, or another declared workflow-critical path. The
denial MUST apply independently of the attempted fetch utility, output flag,
shell redirection, or `tee` form.

#### Scenario: Downloader output targets a protected path

- **WHEN** a permitted lane requests a downloader command whose resolved output
  target is under `.opencode/` or `scripts/`
- **THEN** delegation-observer denies the command before execution at the bash
  pre-execution gate seam

#### Scenario: Shell redirection targets Git metadata

- **WHEN** a permitted lane requests shell redirection whose resolved output
  target is Git metadata
- **THEN** delegation-observer denies the command before execution at the bash
  pre-execution gate seam

#### Scenario: Non-protected artifact target is presented to the guard

- **WHEN** a fetch workflow targets a path under its trusted artifact root
- **THEN** the protected-path gate does not deny it solely for matching a
  protected workflow path at the bash pre-execution gate seam

### Requirement: General coder interpreter policy remains unchanged

This capability MUST NOT change general coder interpreter permissions for
`node`, `bun`, or `python3`.

#### Scenario: Scope boundary is verified

- **WHEN** the implemented permission changes are reviewed
- **THEN** they contain no modification to the general coder interpreter policy
  at the configuration review seam
