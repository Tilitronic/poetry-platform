## Why

The researcher and resource-manager lanes can currently use broad `curl *` and
`wget *` permissions to write outside their edit scopes through output flags,
shell redirection, or `tee`. This change moves output-path authority to a typed
artifact fetch boundary and blocks writes to workflow-critical paths as a
defense in depth control.

## What Changes

- Add a typed fetch-to-artifact boundary that accepts a URL and a trusted,
  pre-allocated artifact identity rather than a caller-selected output path.
- Permit only the two explicitly allow-listed roots: `knowledge/<id>/sources/`
  for researcher artifacts and the OMO knowledge root for resource-manager
  artifacts.
- Require parent canonicalization, containment validation, symlink-escape
  rejection, and atomic artifact writes before a fetched artifact is published.
- Remove universal `curl *` and `wget *` permissions from the researcher and
  resource-manager lanes after migration to the typed boundary.
- Add a delegation-observer pre-execution bash gate that denies attempted
  writes to protected workflow paths, including `.opencode/*`, `scripts/*`,
  `AGENTS.md`, and Git metadata.
- Preserve existing general coder interpreter permissions (`node`, `bun`, and
  `python3`); they are explicitly out of scope for DIA-260827-ft3z.

## Capabilities

### New Capabilities

- `artifact-fetch-write-containment`: confine source-fetch artifacts to a
  trusted allocated directory and reject protected-path writes before command
  execution.

### Modified Capabilities

None.

## Impact

- `.opencode/opencode.jsonc`: researcher and resource-manager permissions will
  migrate from universal download commands to the typed fetch boundary.
- `.opencode/plugins/delegation-observer.ts`: gains the protected-path bash
  pre-execution control.
- A minimal local typed wrapper and its focused tests will be added in the
  existing OpenCode configuration/plugin boundary; no application package,
  runtime dependency, or system architecture boundary changes.
- Validation will extend the existing config and plugin-harness test surfaces.

## Testing Decisions

A good test proves the security property at the public boundaries, not merely
that a command succeeds: a valid trusted allocation can publish an artifact,
while traversal, symlink escape, arbitrary destination selection, and protected
path writes are rejected without a published partial file. Test the typed fetch
boundary, the delegation-observer pre-execution decision, and the permission
configuration that removes universal `curl` and `wget` access.

Prior art: the existing researcher and resource-manager deny-first permission
blocks in `.opencode/opencode.jsonc`, and the delegation-observer plugin test
harness. The source of the attack cases and the selected controls is
`.opencode/learnings/external-patterns/2026-09-10-shell-redirection-write-scope-bypass.md`.

## Rollback Plan

Revert the implementation commit as one unit to restore the last known
configuration and observer behavior. Rollback must not reintroduce broad fetch
permissions without a separately approved containment control.

## Alternatives considered

- Option 1: deny selected `curl`/`wget` flags and shell tokens - rejected.
  Tier-1: the registered finding documents bypasses through quoting, flag
  variants, redirection, and `tee`, which command-prefix matching cannot parse.
- Option 2: typed fetch-to-artifact boundary - selected primary control.
  Tier-1: the researcher contract already defines allocated artifact sinks;
  owning path resolution prevents caller-controlled destinations.
- Option 3: protected-path bash gate - selected as defense in depth. Tier-1:
  the finding documents that delegation-observer currently gates edit/write
  tools but not bash, leaving workflow paths exposed.
- Status-quo / do nothing: rejected. Tier-1: universal `curl *` and `wget *`
  permissions permit writes outside the lanes' edit scopes.

Chosen option: Option 2 plus Option 3, because path-resolution containment
prevents arbitrary artifact destinations and the protected-path gate blocks
independent write techniques at workflow-critical paths.
