# Plugin loader + native base64url (DIA-260825-n5x4 findings)

Date: 2026-08-25
Source: ai-specialist research summary, registered per AGENTS.md 2.5 before code edits.

## Findings

1. **Plugin loading model**: OpenCode loads project plugins as individual
   files via `node --experimental-strip-types`. Each plugin file is a
   standalone module; there is no module registry or export surface consumed
   by other files.

2. **Native base64url**: `Buffer.prototype.toString("base64url")` and
   `Buffer.from(x, "base64url")` are native since Node 15.7.0. The project
   runtime is Node 24.18.0 (verified on host), so the hand-rolled
   encode (`base64` + regex replace of `+`, `/`, `=`) and the decode shim
   (reverse replace back to standard base64) are redundant re-implementations
   of a stdlib feature. Native output is unpadded and URL-safe by contract.

3. **Test replication rationale**: `capability-tokens.test.mjs` replicates
   the mint/verify/base64url algorithm inline because plugin functions are
   not exported (see finding 1). The tests therefore verify the CONTRACT
   (no `+`, `/`, `=` characters; roundtrip fidelity) rather than importing
   the implementation; the replicated helpers must be kept in sync with the
   plugin source manually.

## Consequence for DIA-260825-n5x4

Replace hand-rolled base64url in delegation-observer.ts with the native
codec; update the replicated helper in capability-tokens.test.mjs to match,
keeping all contract assertions unchanged.
