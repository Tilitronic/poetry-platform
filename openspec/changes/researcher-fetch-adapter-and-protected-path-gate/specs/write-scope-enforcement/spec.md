## Purpose

Confine agent source-fetch writes to the two knowledge roots through a typed
fetch boundary, remove the researcher shell, and keep the remaining
shell-bearing implementation lanes inside a narrow, explicitly non-provable
protected-path tripwire.

## ADDED Requirements

### Requirement: Researcher lane has no shell

The `researcher` agent MUST resolve every bash command to deny, and source
capture MUST happen only through the typed fetch tool. The four downloader
CLIs (`curl`, `wget`, `trafilatura`, `crwl`) MUST NOT remain grantable to the
lane.

#### Scenario: Researcher attempts any bash command

- **WHEN** the `researcher` lane invokes the bash tool with any command string
- **THEN** the permission layer denies it and no process is started

#### Scenario: Researcher archives a source

- **WHEN** the `researcher` lane archives a source URL during Phase A
- **THEN** it calls the typed fetch tool and never a downloader CLI

### Requirement: Typed fetch tool confines the destination

The typed fetch tool MUST accept a URL and an output path, resolve the
destination, and reject any destination that is not under `knowledge/` or
`.opencode/oh-my-opencode-slim/knowledge/`. It MUST reject `..` traversal,
absolute paths outside those roots, and symlink escapes. It MUST accept only
`http` and `https` URLs. It MUST reject callers other than `researcher`.

#### Scenario: Destination under a knowledge root

- **WHEN** `researcher` calls the tool with a path under `knowledge/<id>/sources/`
- **THEN** the artifact is written there and the resolved path is returned

#### Scenario: Traversal destination

- **WHEN** the output path contains `../` that resolves outside the roots
- **THEN** the tool rejects the call and writes nothing

#### Scenario: Absolute destination outside the roots

- **WHEN** the output path is an absolute path such as `/workspace/anything`
- **THEN** the tool rejects the call and writes nothing

#### Scenario: Symlink escape

- **WHEN** the resolved parent directory is a symlink that points outside the
  allowed roots
- **THEN** the tool rejects the call and writes nothing

#### Scenario: Non-researcher caller

- **WHEN** an agent other than `researcher` calls the tool
- **THEN** the tool rejects the call and writes nothing

#### Scenario: Tool hidden from other lanes

- **WHEN** an agent other than `researcher` starts
- **THEN** `fetch-source` is absent from that agent's tool surface

### Requirement: Typed fetch reports the tier and degrades

The tool MUST own the fetch fallback order: npm registry JSON API, then
trafilatura, then crwl as last resort. It MUST report which tier succeeded and
the number of bytes archived. Tier 3 MUST be optional: an unavailable `crwl`
binary MUST NOT be an error, and the tool MUST report the tier as unavailable
and continue with the remaining tiers.

#### Scenario: Registry JSON source

- **WHEN** the URL is an npm registry package endpoint
- **THEN** the tool archives the JSON response through tier 1 and reports
  `tier: json`

#### Scenario: HTML source

- **WHEN** the URL is a normal HTML page and trafilatura is available
- **THEN** the tool archives the extracted markdown and reports the trafilatura
  tier

#### Scenario: Tier 3 binary absent

- **WHEN** every earlier tier fails and `crwl` is not installed
- **THEN** the tool reports tier 3 unavailable and returns a failed status
  without treating the missing binary as a hard error

### Requirement: Per-source failure does not abort research

A failed fetch or a rejected destination MUST be recorded for that source and
MUST NOT abort the remaining research. The lane MUST mark the source as not
archived with a reason and continue.

#### Scenario: Unfetchable source

- **WHEN** a source URL cannot be fetched by any available tier
- **THEN** the lane records `# NOT ARCHIVED (all methods exhausted)` with the
  reason and continues with the next source

#### Scenario: Rejected destination is not retried elsewhere

- **WHEN** the tool rejects an output path
- **THEN** the lane does not retry the same source against a different path
  and counts that source as failed

### Requirement: Protected-path shell tripwire for implementation lanes

The `coder` and `coder-escalated` lanes MUST have a pre-execution tripwire that
rejects a bash command whose literal write destination is under `.git/`,
`.opencode/session/`, or `docs/dev-infra-audit/tickets/`. The tripwire MUST
apply only to those two lanes. Coverage is best-effort: a session whose lane
cannot be resolved is out of scope. It is accident protection, not a write
boundary, and MUST NOT be documented or relied on as provable containment.

#### Scenario: Redirection into git metadata

- **WHEN** `coder` runs a command containing a redirection to `.git/config`
- **THEN** the hook throws before execution and records the denial

#### Scenario: Tee into the ticket ledger

- **WHEN** `coder` runs a command that writes to a path under
  `docs/dev-infra-audit/tickets/`
- **THEN** the hook throws before execution and records the denial

#### Scenario: Ordinary build command

- **WHEN** `coder` runs an ordinary build or test command with no protected
  literal destination
- **THEN** the hook allows it unchanged

#### Scenario: Lane out of scope

- **WHEN** a lane other than `coder` or `coder-escalated` runs a command
  containing a protected literal
- **THEN** the tripwire does not apply to that lane

#### Scenario: Lane cannot be resolved

- **WHEN** the tripwire cannot resolve the session's lane (root, pre-restart,
  revived, or unparseable task id)
- **THEN** the tripwire does not apply and the command proceeds to the
  permission layer

### Requirement: Inherited-shell lanes have explicit deny-scoped maps

`designer` and `memory-manager` MUST declare explicit deny-scoped bash maps so
their shell no longer inherits the global allow baseline. `memory-manager`
MUST retain only the commands its workflow needs: read-only git inspection and
the existing memory-shelf validator. Because permission patterns match the
whole raw command string, the validator grant MUST be the
`bash scripts/validate-memory-shelf.sh *` pattern, and the memory-manager
agent document MUST prescribe exactly `bash scripts/validate-memory-shelf.sh`.

#### Scenario: Designer arbitrary command

- **WHEN** `designer` attempts an arbitrary command such as `curl -o /tmp/x URL`
- **THEN** the permission layer denies it

#### Scenario: Memory-manager inspection and validation

- **WHEN** `memory-manager` runs `git log --oneline -10` or
  `bash scripts/validate-memory-shelf.sh`
- **THEN** the command is allowed

#### Scenario: Memory-manager arbitrary interpreter command

- **WHEN** `memory-manager` attempts an arbitrary `python3 -c` command
- **THEN** the permission layer denies it
