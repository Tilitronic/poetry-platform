## Context

`.opencode/plugins/delegation-observer.ts` implements the DIA-217 ticket gate as
a `tool.execute.before` hook. The gate is scoped to `input.tool === "task"`
(line 2776). Resolution order (lines 2764-2771, 2811-2844):

1. `ticket_id` field on the task args -> validate format + file.
2. field missing -> one marked `campaign|governing ticket` / `ticket_id` marker
   -> materialize.
3. field missing -> one unique literal `DIA-...` id in text -> materialize.
4. field missing + no unambiguous id -> hard block (throw at 2847-2861).

The ONLY working bypass before this change is a pre-minted `[CAPABILITY:
CAP-...]` token: a regex at 2782 captures the token, `verifyCapabilityToken`
(line 118) validates HMAC + TTL and returns `{ valid, payload?, error? }` where
`payload.scope` is one of `ticket-creation` / `ai-infra-application` /
`bootstrap` (minted by `mint_capability` at 4837). On `result.valid` the gate
early-returns (line 2798).

Chicken-and-egg: `scripts/tickets new` generates the ticket ID with a random
suffix, so the creating `task()` cannot know its own future ID. The
weak-correlation path (2905-2917) requires citing a known (but absent) ID, which
is impossible for a fresh ticket. Hence the only path to create a ticket is an
orchestrator pre-minted capability token; forgetting it deadlocks.

No `.sdd/` module document governs this plugin-internal gate (the plugin is
dev-infra within existing boundaries; per AGENTS.md this does not require an
`@architector` dispatch). Relevant prior art: the capability-authorization
research conspect `knowledge/res035-capability-authorization/
res035-capability-authorization-conspect.md` and the sibling change
`dia-260821-cku1-tickets-update-capability` (which added the `mint_capability`
tooling). This change extends that machinery.

Constraints:

- ASCII-only dispatch text handling (DIA-079) - the whitelist is ASCII literals;
  no non-ASCII concern.
- Fail-soft gate discipline: a broken gate is worse than no gate; the carve-out
  must not throw on its own detection logic.
- Audit visibility: every bypass (capability or meta-task) must emit a registry
  row + TUI warn.
- No secret minting inside the hook.

## Goals / Non-Goals

**Goals:**

- Remove the ticket-creation deadlock by adding a meta-task carve-out inside the
  DIA-217 gate that allows ticket-creation / procedural-authorization dispatches
  without a ticket ID.
- Tighten the capability-token scope check (line 2787) to require
  `payload.scope` (defense-in-depth against a no-scope token).
- Preserve audit visibility for the new bypass path.

**Non-Goals:**

- Auto-minting capability tokens inside the gate (orchestrator privilege,
  secret-bearing).
- A separate carve-out for `bootstrap` / `ai-infra-application` (stay on the
  token path).
- Full scope-to-operation binding across all gates (larger change; out of scope
  for this fix).
- Changing the `mint_capability` tool, the `[CAPABILITY: ...]` marker contract,
  or the weak-correlation path.
- Any change to the ticket_id resolution order (steps 1-3) or the hard-block
  throw text.

## Decisions

### Decision 1: Meta-task carve-out placement and detection

**Choice:** Insert the meta-task detection block immediately after the
capability-token check (line 2805) and BEFORE the `ticket_id` resolution
(line 2811). Build `dispatchText` from `description + "\n" + prompt` (same
assembly the capability check and resolution already use), test it against a
whitelist of literal substrings: `scripts/tickets new`, `create ticket`,
`procedural authorization`, `meta-task`, `[META-TASK]`. On match:
`appendRow({ event: "meta_task_bypass", ... })`, `tuiSafeWarn(...)`, and `return`
(allow, no ticket ID required).

**Rationale:** Placing the carve-out before resolution means a meta-task never
even attempts ID inference, so it cannot accidentally resolve a stale/weak ID and
then proceed as if attributed. The whitelist is the explicit intent signal the
audit recommended; the `[META-TASK]` marker is the strictest opt-in, the others
cover natural orchestrator phrasing. Returning early mirrors the
capability-token bypass shape (line 2798), keeping the two escape hatches
symmetric and easy to audit.

**Alternatives considered:**

- Place the carve-out only right before the hard block (line 2847): rejected -
  that would run full ID resolution first; a meta-task containing a stray literal
  `DIA-...` could resolve a wrong ID and proceed attributed. Earlier return is
  safer.
- Marker-only whitelist (`[META-TASK]` + `scripts/tickets new`): rejected per
  interview Q1 - developer approved the broader audit-literal set for ergonomics.

### Decision 2: Scope-check tightening (line 2787)

**Choice:** Change `if (result.valid)` to
`if (result.valid && result.payload && typeof result.payload.scope === "string")`.
Keep the existing invalid-token throw path (line 2800) for tokens that are
valid-signed but lack a scope.

**Rationale:** `verifyCapabilityToken` returns `payload` only when the HMAC and
TTL check out, and `mintCapabilityToken` always sets `scope`, so every legitimate
token already satisfies the new condition - zero behavior change for real tokens.
The new condition closes the concrete leak the audit flagged: a validly-signed
token whose payload is missing/non-string scope can no longer bypass the gate.
This is the minimal B1 fix; full scope-to-operation binding (B2) is deferred.

**Alternatives considered:**

- B2 stricter allowlist binding: rejected per interview Q2 - larger re-plumb of
  the multi-gate token contract; B1 closes the concrete leak now.
- B3 leave as-is: rejected - leaves the scope-leak the audit identified.

### Decision 3: No carve-out for bootstrap / ai-infra-application

**Choice:** Keep `bootstrap` and `ai-infra-application` on the existing
`[CAPABILITY: ...]` token path. They are NOT chicken-and-egg: the orchestrator
pre-mints a token with the matching scope, then dispatches. No keyword carve-out
is added for them.

**Rationale:** Those meta-operations already work (pre-minted token -> bypass).
Adding a keyword carve-out would widen the bypass surface for no deadlock benefit
and dilute the gate's attribution guarantee. The meta-task carve-out is scoped
exclusively to ticket creation / procedural authorization, which is the only
true deadlock.

**Alternatives considered:**

- C2 keyword carve-out for bootstrap/ai-infra-application: rejected per interview
  Q3 - no deadlock to solve, wider bypass surface.

## Seams

**Test seam:** the delegation-observer plugin's test harness (bats, under
`scripts/__tests__/` or the plugin's own test dir - confirm at implementation
time). The new tests exercise the `tool.execute.before` hook with a synthetic
`task()` input carrying (a) `scripts/tickets new` in the prompt, (b)
`[META-TASK]` marker, (c) `create ticket` / `procedural authorization` /
`meta-task` substrings, (d) no whitelist signal and no ticket ID (expect hard
block), (e) a capability token whose `payload.scope` is absent (expect
rejection). The hook gate logic is pure-function-friendly for the branch, so a
unit-style invocation of the gate branch is the right seam.

**Public boundary:** the DIA-217 gate behavior (what dispatches are blocked vs
allowed) is the observable contract. The meta-task whitelist literals and the
`[META-TASK]` marker are part of that contract and must be documented in
AGENTS.md (the gate description at AGENTS.md section 2.3.1 / 2.5 already
references the capability token; the meta-task carve-out must be added there as a
follow-up doc edit - tracked in tasks). The `mint_capability` tool and
`[CAPABILITY: ...]` marker remain unchanged public boundaries.

**Code seam:** the new block lives inside the existing
`if (input.tool === "task") { ... }` gate at delegation-observer.ts:2776, reusing
`buildDispatchText()` (extracted helper, S-02), `appendRow`, and `tuiSafeWarn`.

**Exported test seam (constrained, post-review correction of the original
"No new exported symbols" claim):** to drive the REAL hook path in the plugin
test harness (F3 / Obs-4), three symbols are exported from the plugin and
marked `@internal test-only seam`: `mintCapabilityToken`, `verifyCapabilityToken`,
and `CAPABILITY_SECRET`. These are NOT a security control and do NOT change the
gate's runtime behavior — the gate logic is unchanged. Trust-boundary rationale:
the capability secret is `randomBytes(32)` generated PER PROCESS at plugin load,
tokens are short-lived (5-min TTL), and plugins are TRUSTED code running inside
the same process as the hook. Exporting these symbols therefore only widens
token forgeability within the already-trusted plugin boundary (a test can mint a
validly-signed no-scope token to assert the scope-leak rejection); it does not
expose the secret outside the process or to untrusted callers. The
`[CAPABILITY: ...]` marker contract and the `mint_capability` tool remain the
public, orchestrator-only minting path.

## Risks / Trade-offs

**Risk:** The broader whitelist (esp. `create ticket`, `procedural authorization`,
`meta-task` as bare substrings) could let a non-meta dispatch that happens to
contain those words bypass the gate without a ticket ID.
-> **Mitigation:** These phrases are unlikely in normal ticketed-work dispatches
(which cite `campaign ticket DIA-...`). The `[META-TASK]` marker remains the
strict opt-in for callers that want zero ambiguity. Every carve-out emits a
`meta_task_bypass` row + TUI warn, so abuse is observable after the fact. If
false positives prove material, the whitelist can be narrowed to marker-only
without code-structure change (ponytail: whitelist is a single array, narrow if
needed).

**Risk:** Placing the carve-out before ID resolution means a meta-task that ALSO
carries a real `campaign ticket DIA-...` marker will bypass without attributing
to that ticket.
-> **Mitigation:** Acceptable - a ticket-creation dispatch should not also claim
to be governed by an existing ticket; if it does, the explicit marker wins (intent
is "create new", not "work on existing"). The capability-token path remains for
cases that need both a token and a ticket.

**Risk:** The scope-check tightening could break a currently-working token if any
minted token lacks `scope`.
-> **Mitigation:** `mintCapabilityToken` always sets `scope` (enum-validated at
the tool boundary, line 4841). No production token omits it. The change is
behavior-preserving for all real tokens.

**Trade-off:** We do not fully bind token scope to the specific gate/operation
(B2 deferred). A `bootstrap` token still bypasses the ticket gate.
-> **Acceptable:** the token is process-scoped (5-min TTL, ephemeral secret) and
orchestrator-minted; the residual risk is low and the full binding is a separate,
larger change. Documented as a known limitation.

## Migration Plan

**Deployment:** additive change inside the existing gate. No new files, no new
CLI surface, no config keys. The gate simply gains one more allow condition.

**Rollback:** revert the plugin edit (git revert). The gate returns to token-only
bypass; the deadlock returns but no data/state is lost.

**Open Questions:** none. (Doc follow-up: add the meta-task carve-out to the
AGENTS.md gate description - tracked in tasks.md as a non-code doc task, since the
gate contract is user-facing.)
