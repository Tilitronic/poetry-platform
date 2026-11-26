# Preset Workspace Bridge - Free Switching Gate Report

Date: 2026-09-18
Ticket: DIA-260918-yug6
Source: ai-specialist ai--2 gate report on preset free switching
Scope: AGENTS.md 2.5 step 1 learnings registration (write-only, no config edits)

## Resolution chain

Preset value resolves in this order (first hit wins):

1. PRESET env var (explicit CLI override)
2. OPENCODE_WORKSPACE_PRESET env var (workspace bridge)
3. Persisted store value (last used preset)
4. none (no preset, default behavior)

Key file: workspace-preset.ts lines 159-161 (silent none fallback).

## Findings summary

- S1 bridge bypassed CONFIRMED: Makefile lines 53-67 show only
  `make opencode` carries OPENCODE_WORKSPACE_PRESET. All other
  entry points (shell, dev, exec) skip the bridge.
- S2 silent none: workspace-preset.ts 159-161 falls back to none
  with no warning when env and store are both empty.
- S3 no parent traversal: loader.ts 169-187 does not walk up
  parent dirs, so nested worktrees miss project config.
- S4 host/container key divergence: realpathSync lines 32-34 plus
  store path lines 22-30 plus compose with no mount means host
  and container resolve different keys for the same project.
- S5 free models valid: per zen docs, free-model preset entries
  are legitimate config values, not typos.

## Host vs container split-brain (text diagram)

  HOST                              CONTAINER
  ----                              ---------
  realpathSync(PROJECT)             realpathSync(PROJECT)
    -> /workspace                     -> /workspace (different mnt)
  store key = hash(host path)       store key = hash(container path)
    -> key A                            -> key B
  preset read = A                   preset read = B
    -> PRESET or stored-A               -> none or stored-B

  No shared mount for the store, so A != B. Same repo, two
  truths. Writes on one side are invisible on the other.

## Recommendations

- R-1 read consistency: make every entry point resolve the preset
  the same way. Either all carry the bridge env or none do.
  Single helper, no per-target divergence.
- R-2 loud error: replace silent none with a warning when the
  chain falls through. Log expected-vs-found at startup.
- R-4 container-level bridge or mount: fix at container level,
  not per-command. Either inject the bridge env in compose/dev
  entrypoint or mount the store path so host and container
  share one key space.

## Deferred (noted, out of scope)

- R-6 docs drift: docs still describe old preset behavior.
- R-7 inert preset field: unused preset field should be removed
  or wired, not left as a decoy.
