## Context

See `proposal.md` for motivation. No `.sdd/` document governs these
instruction-only files. The relevant existing constraint is the allocated
datetime-ID rule in
`.opencode/oh-my-opencode-slim/orchestrator_append.md`; the change must not
alter that rule or the DIA ticket's stable ID and canonical filename.

## Goals / Non-Goals

**Goals:**

- Make every confirmed concrete analyzer and researcher example use an allocated
  datetime ID.
- Remove only the confirmed obsolete quoted orchestrator path.
- Preserve generic `<type><id>` templates that state the naming rule.
- Establish focused textual verification plus the existing configuration gate.

**Non-Goals:**

- Changing artifact-allocation behavior, identifier formats, ticket identity, or
  any file outside the four confirmed instruction files.
- Adding validation code or tests solely for this one documentation correction.

## Decisions

### Edit the four confirmed instruction surfaces only

Use the contract-conformant analyzer example
`ana-260911-ab12-capability-gap-matrix`. Correct both doubled-slug destinations
to `knowledge/<returned-id>/sources/`, and state that allocator-returned IDs are
used verbatim in the researcher and research-pipeline guidance. Leave generic
`<type><id>` templates intact.

This is the smallest change that eliminates conflicting guidance. Removing all
examples would reduce readability; expanding the change to other files is out
of scope without evidence of another obsolete example.

### Verify text and configuration separately

Run a focused search limited to the four changed files for obsolete sequential
and doubled-slug forms, then run `make test-config`. The search proves the requested
textual invariant; the project gate checks the wider OpenCode configuration
surface.

## Seams

- **Instruction-text seam:** the four scoped Markdown instruction files are
  the public guidance consumed by OpenCode lanes.
- **Configuration-validation seam:** `make test-config` is the existing project
  gate for changes on this surface.

## Risks / Trade-offs

- [A generic rule template is accidentally replaced] -> Review the diff and
  confirm `<type><id>` templates remain where they describe the rule.
- [A sequential example remains in a scoped file] -> Use the focused scoped-file
  search before `make test-config`.
- [A broader stale example exists elsewhere] -> Do not expand this narrow slice;
  record it as separate follow-up work if independently discovered.

## Migration Plan

1. Apply the four scoped documentation edits in sequence.
2. Run the focused search and `make test-config`.
3. If validation fails or an edit changes a generic rule, revert only the
   affected documentation edit and restore the previous text; no data or runtime
   migration is involved.

## Test Strategy

No automated test is added. The focused search is the direct regression check
for obsolete examples, and `make test-config` is the established integration
gate for this configuration surface.
