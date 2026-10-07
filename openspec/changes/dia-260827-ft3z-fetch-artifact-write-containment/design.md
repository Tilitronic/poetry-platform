## Context

See proposal.md for motivation and the source attack cases. The relevant
configuration boundary is the existing `.opencode/` policy and plugin surface;
no `.sdd/` document currently governs this module. This design follows
architecture.md principles of validation at the edge, high cohesion, and
testable boundaries. It does not add an application module or a new system
architecture boundary.

The registered finding
`.opencode/learnings/external-patterns/2026-09-10-shell-redirection-write-scope-bypass.md`
establishes that edit-scoped researcher and resource-manager lanes have broad
fetch commands that bypass their edit scopes. The developer selected typed
fetch-to-artifact containment plus a protected-path bash gate.

## Goals / Non-Goals

**Goals:**

- Make the trusted allocation, not a shell argument, the authority for an
  artifact destination.
- Permit the two developer-approved artifact roots only.
- Fail closed for traversal, symlink escape, and failed atomic publication.
- Deny protected workflow-path write attempts before bash executes.
- Remove universal `curl` and `wget` permissions from the two affected lanes.

**Non-Goals:**

- Changing coder interpreter permissions for `node`, `bun`, or `python3`.
- Parsing all possible shell semantics as the primary security control.
- Expanding the fetch boundary to general application code or adding a new
  external dependency.
- Changing the artifact content format or existing source manifest semantics.

## Decisions

### D1: Trusted allocation selects the root and the boundary owns the filename

**Choice:** The fetch boundary receives a URL and a trusted, pre-allocated
artifact allocation. It selects one of two allow-listed roots from that
allocation: `knowledge/<id>/sources/` for researcher or the designated OMO
knowledge root for resource-manager. Callers cannot provide an output path.
The boundary derives a safe internal artifact filename from the canonical URL
and returns the published path.

**Rationale:** This implements the developer's confirmed least-privilege
decision. A caller-controlled output path is the vulnerability; constraining
only output flags leaves shell syntax variants outside the control.

**Alternatives considered:** accepting a directory or filename supplied by the
lane (rejected: reintroduces path authority); filtering selected downloader
arguments (rejected: glob-prefix permission matching cannot reliably parse
quoting, flag forms, redirection, or pipes).

### D2: Resolve and verify before atomic publication

**Choice:** The boundary canonicalizes the selected parent and target, verifies
that both remain within the selected root, rejects traversal and symlink escape,
writes to a temporary sibling, and atomically renames only after the fetch
succeeds.

**Rationale:** Containment must be evaluated using resolved paths, not string
prefixes. Atomic publication ensures consumers never treat a partial download
as a completed source artifact.

**Alternatives considered:** lexical prefix checks (rejected: traversal and
symlinks defeat them); direct final-path writing (rejected: can publish partial
artifacts after network failure).

### D3: Remove broad downloader commands after migration

**Choice:** The researcher and resource-manager permissions use the typed
boundary for artifact publication and remove universal `curl *` and `wget *`
rules. Existing non-output tooling remains subject to an implementation audit
against the new boundary rather than gaining new wildcard permissions.

**Rationale:** The typed boundary cannot be effective while the old arbitrary
output mechanisms remain universally callable.

**Alternatives considered:** retain universal commands and add deny patterns
for `-o`, `-O`, `>`, `>>`, and `tee` (rejected: known bypass class).

### D4: Protected-path gate is independent defense in depth

**Choice:** Extend delegation-observer's pre-execution processing to identify
resolved write targets for supported output forms and reject targets under
`.opencode/*`, `scripts/*`, `AGENTS.md`, Git metadata, and the explicitly
declared workflow-critical path set. The gate reports a clear denial without
executing the command.

**Rationale:** The primary control protects artifact publication; this control
protects critical paths against a separate command, redirection, or future
permission mistake. It must be path-based rather than downloader-name-based.

**Alternatives considered:** no bash gate (rejected: the registered finding
shows edit/write hooks do not currently cover bash); universal shell parser
(rejected: unnecessary expansion beyond supported write forms and not needed
once broad fetch permissions are removed).

## Seams

The developer confirmed these seams through the compressed interview.

- **Artifact-fetch boundary:** a focused test invokes the typed boundary with a
  trusted researcher or resource-manager allocation. It asserts successful
  containment and rejection of arbitrary path, traversal, symlink escape, and
  failed-publication cases.
- **Bash pre-execution gate:** the existing delegation-observer plugin harness
  presents downloader-output, redirect, and `tee` cases targeting protected
  paths. It asserts denial before execution and a non-protected trusted target
  does not match by protected-path rule alone.
- **Configuration validation:** the existing config validation surface inspects
  the two lane permission blocks and verifies that universal `curl *` and
  `wget *` permissions are absent and coder interpreter policy is unchanged.

## Risks / Trade-offs

- **A new trusted-allocation input could be forged by an untrusted caller** ->
  derive it from the existing caller identity/allocation mechanism and do not
  expose arbitrary root strings at the public boundary.
- **A path check could miss symlink resolution** -> canonicalize the existing
  parent and verify containment after resolution; test an escaping symlink.
- **A failed download could leave content visible** -> write a temporary
  sibling and publish only through atomic rename after success.
- **The protected-path recognizer may not understand an unsupported shell
  construct** -> treat it as defense in depth; remove the universal downloader
  permissions that create the current write capability, and add regression
  cases for each supported output form.
- **A false positive could block a valid maintenance workflow** -> keep the
  protected set explicit, log the denied target and rule, and use the typed
  boundary for the two legitimate artifact roots.

## Migration Plan

1. Add focused failing tests at the artifact-fetch, bash-gate, and configuration
   seams.
2. Implement and verify the typed boundary without granting new wildcard
   permissions.
3. Route the two affected lanes through it and remove universal `curl` and
   `wget` permissions.
4. Add the protected-path pre-execution gate and its regression cases.
5. Run `make test-config`, the focused plugin harness tests, restart OpenCode,
   and perform a permitted source-fetch smoke test plus protected-path denial
   smoke test.
6. Obtain independent `@ai-auditor` review, then register the approved change
   in the OpenCode changelog workflow.

**Rollback:** Revert the implementation as a single change and restart
OpenCode. Do not restore broad downloader permissions independently; restore
only a previously reviewed policy state or deploy a corrected containment
implementation first.
