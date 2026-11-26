# scratch-lifecycle architecture

Module: scratch-lifecycle
Date: 2026-09-27
Status: proposed

# ADR-001: Scratch cleanup is a convention; the reliability invariant lives on the stall path

**Status:** superseded (partial) by .sdd/permission-stall-hardening/architecture.md
**Note:** its multi-argument-rm containment invariant was falsified by runtime probes (open ticket DIA-260928-rzty); the stall-side invariant moved to the new module doc.
**Module:** scratch-lifecycle

**Context.** The four anchored .scratch rm/rmdir allows (commit f6c84a5, mirrored
coder/coder-escalated) removed one trigger of chronic coder-lane early
termination (CAUSE B). Ground truth: permission matching is on the command
string and `*` crosses `/`; the global `"*": "allow"` plus python3/node/bun
allows already admit any deletion, so the anchored allows add no attack surface.
The only confirmed fatal arm is an UNANSWERED permission ask: our plugin
auto-rejects after 300 s and the child ends with an empty envelope. A
check-only helper cannot bind the pre-approved allow path; a performing wrapper
that realpath-validates would close the naive traversal edge but reintroduce
that same 300 s death for any lane that emits a raw rm.

**Decision.**

1. Retain the four anchored allows unchanged (O1). They are ask-suppression,
   not a security boundary, and are documented as such.
2. Decline O2 and O3. No check-only helper; no performing wrapper. A
   convention-tier check that its subject may skip is not a control, and a
   performer trades a below-floor accident class for the proven lane-killer.
3. Direct the next authorized spend at O4: make an unanswered ask non-fatal -
   tune/shorten the stall bound, surface the ask, or synthesize a non-fatal
   decision - so no ask class can end a lane with an empty envelope.
4. Treat worktree absolute paths (DIA-260927-vw0o) as an O1 ask-suppression
   extension after evidence capture, not as a new boundary.

**Consequences.** Scratch deletion stays auditable at the permission layer.
Unattended lanes are protected against the failure mode actually observed.
Residual risks accepted: a confused non-adversarial agent could still emit a
traversal-shaped or var-expanded .scratch rm and delete outside it silently
(low likelihood, below the existing interpreter floor); cross-lane scratch
deletion remains unenforceable. Revisit if the floor rises, a real
traversal row appears, or scratch becomes lane-private.

**Alternatives Considered.** O2 check-only (zero mechanical value; only a
future hook if rules are ever tightened). O3 performing wrapper (only
mechanical close, but re-arms the 300 s lane-killer and shifts audit). O5 do
nothing (leaves residuals iii/iv killing unattended lanes). O4-only
(insufficient while the mandated cleanup still trips the global ask today).

# Minimum invariant (testable)

For every coder-lane permission ask, the ask resolves within the configured
stall bound to either an explicit decision or a synthesized non-fatal decision,
and the child turn always ends with a non-empty result envelope.

Test: inject an outstanding ask, advance the clock past the stall bound, then
assert no permission_auto_rejected row is followed by a zero-length envelope and
the lane returns non-empty text.

## Evidence and prior art

- Analysis: knowledge/ana-260927-6bpp-scratch-permission-model-safety/ana-260927-6bpp-scratch-permission-model-safety-report.md
- Matcher mechanism: OpenCode 1.18.32 packages/opencode/src/tool/shell.ts parses
  each command node and matches its raw text;
  packages/opencode/src/util/wildcard.ts converts `*` to `.*` with the `s` flag.
- Stall evidence: .opencode/plugins/needs-input-observer.ts:316-323 env
  PERMISSION_STALL_TIMEOUT_MINUTES, default 300 s; autoRejectPermission :411-479.
