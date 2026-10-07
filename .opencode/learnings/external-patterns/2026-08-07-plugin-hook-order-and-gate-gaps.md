# Plugin hook execution order + §10-gate fail-open triggers (apply_patch) + canonical handoff checksum serialization

- **Date:** 2026-08-07
- **Source:** DIA-059 + DIA-061 §10 cycle (ai-specialist research; code-executor Phase 4)
- **Status:** applied

## Pattern — plugin hook execution order
OpenCode plugins load in **`opencode.jsonc` `plugin` array order** and their
`tool.execute.before` hooks run in that order. In this repo
(`.opencode/opencode.jsonc` L318-324) `oh-my-opencode-slim@2.2.8` is declared
BEFORE `file://./.opencode/plugins/delegation-observer.ts`, so omo's
apply-patch rewrite hook runs BEFORE the delegation-observer §10 gate hook.
Any gate that assumes it sees the RAW tool args must account for earlier
plugins already mutating them.

## Pattern — omo rewritePatch output format
omo's `formatPatch` (`.opencode/oh-my-opencode-slim/src/hooks/apply-patch/codec.ts`
L326-352) rewrites apply_patch input into a custom marker format:

```
*** Begin Patch
*** Add File: <path>
*** Update File: <path>
*** Delete File: <path>
*** End Patch
```

These markers match NEITHER `^Index:` NOR `^diff --git` — a gate parsing only
git-style headers will resolve no file path and FAIL OPEN on every
omo-rewritten patch.

## Finding — the two §10-gate fail-open triggers (DIA-059)
1. **First-line-only parsing:** the old apply_patch branch in
   `.opencode/plugins/delegation-observer.ts` parsed only the first line of
   `patchText` for `Index:` / `diff --git`. Patches with leading blank lines,
   format-patch or MIME headers → `filePath` undefined → gate opened.
2. **omo format mismatch:** rewritten patches (`*** Add/Update/Delete File:`)
   matched neither regex → gate opened for ALL rewritten patches touching
   `.opencode/**`.

**Fix:** multi-marker, multi-file scan — iterate every line, try all markers
(`Index:`, `diff --git`, `+++ b/`, `*** Add File:`, `*** Update File:`,
`*** Delete File:`), and stop at the first candidate that
`isProtectedPath()` accepts. This closes both gaps and covers multi-file
patches (blocked if ANY protected file appears).

## Pattern — canonical handoff checksum serialization (DIA-061)
The handoff checksum is the SHA256 of the **sorted-key, compact JSON** of the
`prognosis` object:

```bash
jq -c '.prognosis | to_entries | sort_by(.key) | from_entries' .opencode/session/current-handoff.json | sha256sum
```

`validate-handoff.sh` recomputes with exactly this command and rejects
missing / empty / non-64-hex / placeholder (all-same-char) / mismatching
checksums. The orchestrator boot gate (orchestrator_append.md) refuses to
resume on any of those conditions (log_decision event_type 'handoff',
resolution_status 'escalated', content_ref 'checksum-mismatch').

## Update — Phase 6 audit fixes (2026-08-07, re-review cycle 1/2 on 8672917)
- **Writer-side canonical serialization aligned (DIA-061 Finding 1):**
  `delegation-observer.ts` `computeChecksum` now builds a top-level-key-sorted object
  (`Object.keys(prognosis).sort()` + `JSON.stringify`) before hashing — byte-identical
  contract with the validator: TS `Object.keys().sort() + JSON.stringify` == jq
  `-c '.prognosis | to_entries | sort_by(.key) | from_entries'` piped via `printf '%s'`
  (no trailing newline). Verified: the writer's serialization of the current handoff
  prognosis reproduces the stored checksum 0eee533e… exactly.
- **`*** Move to:` marker coverage (DIA-059 Finding 2):** the apply_patch marker chain
  now also scans omo's rename-destination marker (`*** Move to: <path>`, codec.ts
  `formatPatch` L343) so a patch that MOVES a file INTO `.opencode/**` is blocked by the
  §10 gate, not just Add/Update/Delete.

## Evidence / sources
- `.opencode/plugins/delegation-observer.ts` `tool.execute.before` apply_patch branch (L520-556)
- `.opencode/oh-my-opencode-slim/src/hooks/apply-patch/codec.ts` L326-352 (`formatPatch`)
- `.opencode/opencode.jsonc` L318-324 (`plugin` array order)
- `scripts/validate-handoff.sh` checksum block (DIA-061)

## Tags
plugin-development, hook-order, apply-patch, §10-gate, handoff-checksum
