## 1. Meta-task carve-out (gate logic)

- [ ] 1.1 Add the meta-task detection block inside the DIA-217 gate at
      delegation-observer.ts, immediately after the capability-token check
      (line 2805) and BEFORE the `ticket_id` resolution (line 2811). Assemble
      `dispatchText` from `description + "\n" + prompt` (reuse the existing
      assembly). Test it against a whitelist array of literal substrings:
      `scripts/tickets new`, `create ticket`, `procedural authorization`,
      `meta-task`, `[META-TASK]`. On match: `appendRow({ event:
"meta_task_bypass", session_id, detail, writer: "plugin" })`,
      `tuiSafeWarn("[meta-task] bypassing ticket gate for ticket-creation /
procedural-authorization dispatch")`, then `return` (allow, no ticket ID
      required). **Acceptance:** a `task()` dispatch whose prompt contains
      `scripts/tickets new` is allowed (no throw) and a `meta_task_bypass` row is
      written; a dispatch containing the `[META-TASK]` marker is allowed; a
      dispatch containing `create ticket` / `procedural authorization` /
      `meta-task` is allowed. **Blocks:** 3.1.

- [ ] 1.2 Confirm the carve-out returns BEFORE ticket_id resolution so a
      meta-task never infers/attributes a stray ID. **Acceptance:** a meta-task
      dispatch that also contains a literal `DIA-...` id in its text does NOT
      resolve/attribute to that id; it returns at the carve-out with no
      `gate_blocked` / `gate_warn` row. **Blocks:** 3.1.

## 2. Capability-token scope tightening (line 2787)

- [ ] 2.1 Change the capability-token verification condition at line 2787 from
      `if (result.valid)` to
      `if (result.valid && result.payload && typeof result.payload.scope === "string")`.
      Keep the existing invalid-token throw path (line 2800) for tokens that are
      valid-signed but lack a scope. **Acceptance:** a validly-signed token WITH
      a `payload.scope` still bypasses the gate (existing behavior preserved); a
      validly-signed token whose `payload.scope` is missing or non-string is
      rejected (throws `§10 TICKET GATE: Capability token invalid ...`). **Blocks:**
      3.1.

## 3. Tests + validation gate

- [ ] 3.1 Write bats tests for the new behavior (extend the plugin's existing
      test harness, or add `scripts/__tests__/delegation-observer-gate.bats` if
      none exists): (a) `scripts/tickets new` in prompt -> bypass,
      `meta_task_bypass` row written; (b) `[META-TASK]` marker -> bypass; (c)
      `create ticket` / `procedural authorization` / `meta-task` substrings ->
      bypass; (d) no whitelist signal AND no ticket ID -> still hard-blocked
      (`gate_blocked` row, throw); (e) capability token with missing
      `payload.scope` -> rejected. **Acceptance:** all new bats tests pass;
      existing gate tests still pass. **Blocks:** 4.1.

- [ ] 3.2 Run the plugin test suite and `openspec validate` for this change.
      **Acceptance:** the bats suite exits 0; `openspec validate
dia-260820-jlu0-chicken-egg-ticket-gate` exits 0.

## 4. Documentation follow-up (gate contract)

- [ ] 4.1 Update the AGENTS.md DIA-217 gate description (section 2.3.1 and/or
      2.5) to document the meta-task carve-out whitelist (`scripts/tickets new`,
      `create ticket`, `procedural authorization`, `meta-task`, `[META-TASK]`) as
      an allowed no-ticket-ID path for ticket creation, alongside the existing
      `[CAPABILITY: ...]` token path. **Acceptance:** AGENTS.md states the
      meta-task carve-out is an allowed no-ticket-ID path for ticket creation;
      `make test-config` (agent-name / doc-drift checks) still passes. (Non-code
      doc edit; the decision was made in the interview, not invented here.)
