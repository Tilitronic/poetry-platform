# DIA-076 — Implement DIA-063 ticket-gate fix + DIA-075 snip guardrails

<!-- Tracking ticket for the approved fix work on the §10 ticket-gate (DIA-063) and
     the snip jq-truncation guardrails (DIA-075), per §10 Phase-1 research by
     @ai-specialist (2026-08-10). This is the fix-implementation tracking ticket —
     the ticket-creation gate itself was followed (this ticket exists BEFORE fix
     work begins). -->

---

id: DIA-076
title: "Implement DIA-063 ticket-gate fix + DIA-075 snip guardrails"
area: opencode-config
severity: Major
status: VERIFIED
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-10
source: fix-lane
date: 2026-08-10
created: 2026-08-10
updated: 2026-08-10

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_015dabb9affeBu0yAK5OOfcAgE"
lane_id: "docs"
agent: "coder"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-076-dia063-fix-implementation.md"]
artifacts: []
evidence: ["ses_0157ee16cffegdBsSp9uGdasiy", "ses_0157db48effeHL0aMgFwslzjbn", "ses_014e750a0ffeIJBCOEvqi5DcLU", "ses_0146a6425ffeHH6Yg3G5xpCwJM", "ses_014693e89ffeftnU0Ue7JtP1ao", "ses_0144a2262ffeAP7MDK0y5GeQri", "ses_014475a8dffe72utMHBqLHa7Y3", "ses_014422613fferxqtxtxcRPoLYY"]

---

## Description

Tracking ticket for the approved fix work on the §10 ticket-gate (DIA-063) and the
snip jq-truncation guardrails (DIA-075), per §10 Phase-1 research by @ai-specialist
(2026-08-10).

**DIA-063 fix (Option B, delegation-observer.ts):**

1. **Harden `evaluateTicketCorrelation` path-1** so an explicit OPEN DIA-id reference
   passes unconditionally (currently requires session-owned OR ≤24h-recent — over-fires
   on long-lived valid tickets).
2. **Add a boot-gate verification exemption** (DIA-061 checksum/sha256/handoff-integrity
   pattern) so mechanical boot verification is NOT treated as §10 work (breaks the boot
   circular deadlock).
3. **Narrow the `configWorkHint` scope regex** to exclude `.opencode/session/` transient
   files.

**DIA-075 guardrails:**

- **Layer 1** — `~/.config/snip/config.toml` `[filters.enable] jq = false`
  (user-home, NON-§10)
- **Layer 2** — coder prompt guardrail forbidding `snip jq` for hashing/integrity work
  - anti-loop rule (oh-my-opencode-slim.jsonc)
- **Layer 3** — orchestrator dispatch brief mandating the canonical `bash -c` jq
  passthrough

## Verification

Evidence from fix runs cod-2 + cod-3 (2026-08-10):

- **`make test-config` exit 0** — 18 passed / 0 failed / 33 warnings;
  `validate-opencode-config.sh` ok (all 4 JSONC valid); `validate-agent-names.sh`
  22 passed; validate-handoff 5 passed; probe PASS; tool-coverage 0 gaps.
- **`scripts/test-ticket-gate.sh` exit 0** — 6/6 regression checks PASS
  (path-1 tri-state marker, C1 explicit-id OPEN-only resolution, narrowed exemption
  regex with `sha256\b` arm dropped, configWorkHint first regex narrowed, no
  `.opencode\/` in configWorkHint, weak-correlation warn-not-throw branch).
- **tsc:** only pre-existing TS2792 (no deps) — not part of `test-config`.

## Fix

Implemented 2026-08-10 (fix lane, per DIA-063 Option B + DIA-075 3-layer guardrail).

**DIA-063 plugin fix (`.opencode/plugins/delegation-observer.ts`):**

- **A1 — Path-1 explicit-OPEN pass:** `evaluateTicketCorrelation` path-1 hardened to a
  tri-state (per audit re-fix C1): an explicit DIA-id reference resolves ONLY against
  OPEN tickets (explicit-id precedence) instead of requiring
  `isSessionOwned || isRecent` — kills the 24h recency-boundary over-fire on
  long-lived valid tickets.
- **A2 — Boot-gate exemption:** boot-gate verification dispatches exempted via the
  DIA-061 checksum/handoff-integrity pattern (`checksum\s+verif | handoff\s*integrit`),
  breaking the boot circular deadlock (boot deadlock observed 3×).
- **A3 — `configWorkHint` narrowed:** scope regex narrowed to
  `/opencode\.jsonc|AGENTS\.md|skill|plugin/i` — the `.opencode\/` arm dropped so
  `.opencode/session/` transient files are no longer flagged as §10 work.
- **A4 — Path-3 warn-not-throw:** weak-correlation path-3 now emits
  `ticket_gate_weak_correlation` as a `console.warn` (not a throw);
  explicit-ids-no-match remains a HARD throw.

**Re-fix cycle 1/2 (per ai--6 audit findings):**

- **C1 — tri-state explicit-id precedence** applied (see A1).
- **M1 — exemption regex narrowed:** bare `sha256\b` arm dropped; only
  `checksum\s+verif | handoff\s*integrit` remains.
- **m1 — Phase-6 reviewer drift fixed:** project AGENTS.md §2.5/§2.4 review matrix
  corrected → Phase-6 independent review is @ai-auditor's lane (not @ai-specialist).

**DIA-075 snip guardrails (3-layer):**

- **Layer 1 — `~/.config/snip/config.toml`** `[filters.enable] jq = false` created
  (user-home, NON-§10).
- **Layer 2 — coder prompt anti-snip guardrail** (forbids `snip jq` for hashing/integrity
  work + anti-loop rule) + **Layer 3 — orchestrator canonical checksum dispatch brief**
  (mandates the canonical `bash -c` jq passthrough), both appended to all 3 presets in
  `oh-my-opencode-slim.jsonc`.
- **Probe:** `scripts/test-ticket-gate.sh` created and wired into `make test-config`.

## Re-verify

- **ai--6 cycle 1/2 (2026-08-10):** C1, M1, m1 verified-closed on the implemented
  code (regression probe 6/6 covers C1 + M1; AGENTS.md §2.5/§2.4 matrix drift
  corrected per m1).
- **M2 (partial → now evidenced here):** M2's evidence gap closed by this
  Verification/Fix/Re-verify record (gate output + exit codes captured above).
- **M3 (post-restart smoke) — EVIDENCED 2026-08-10 (session ses_0157ee16cffegdBsSp9uGdasiy, orchestrator):**
  - **Boot-gate B2 exemption proven live:** checksum verification dispatch (cod-1, code-executor ses_0157db48effeHL0aMgFwslzjbn, registry seq 1770-1772) completed normally WITHOUT §10 ticket-gate block and without ticket correlation — computed checksum == stored == `6163028d5d57e13a263f4fc911e0726b65366285cda5269260edc967a175aa9f` via canonical `bash -c` jq passthrough (DIA-075 Layer-3 honored; no `snip jq`). Batch-approval gate presented + approved with zero gate deadlock.
  - **C1 tri-state proven live:** §10-scoped dispatch (ai--1, ai-specialist ses_014e750a0ffeIJBCOEvqi5DcLU, registry seq 1774) referencing DIA-071 (status OPEN, discovered 2026-08-08 → >48h old, owned by a different session) PASSED without ticket-gate block. Under the OLD gate this would have over-fired (recency/session-ownership requirement). Runtime proof the recency-cliff fix works.
  - **Plugin liveness on disk:** `.opencode/plugins/delegation-observer.ts` — A1 path-1 tri-state (L485-494), A2 exemption regex incl. `checksum\s+verif|handoff\s*integrit` (L873-879), A3 configWorkHint narrowed `/opencode\.jsonc|AGENTS\.md|skill|plugin/i` no `.opencode\/` arm (L848-854), A4 path-3 no-DIA-id → `console.warn` + allow + `ticket_gate_weak_correlation` row (L905-920), explicit-ids-no-OPEN → hard throw (L922-942).
  - **Negative branches (un-ticketed §10 block, path-3 warn-not-throw):** covered statically by `scripts/test-ticket-gate.sh` 6/6 regression checks wired into `make test-config` (probe PASS in fix evidence).
  - **Registry location resolved:** `.opencode/session/registry.jsonl` (1774 rows) + `.opencode/session/messages.jsonl` (1481 rows) EXIST on disk — the earlier "not found" glob result was gitignore, not absence (`.opencode/session/` is gitignored).

- **M4 (2-session durability) — COMPLETE (session 1 + session 2 both passed; 2026-08-10):**
  - **Session 1** (ses_0157ee16cffegdBsSp9uGdasiy, orchestrator): boot gate ran with checksum verification passing and zero developer intervention beyond the normal batch-approval approval; C1 + B2 smokes passed (evidence above). Registry rows seq 1770-1774; messages rows 1475-1481.
  - **Session 2 (close lane, code-executor, 2026-08-10):**
    - (a) **Boot-gate batch approval + canonical checksum MATCH:** boot batch-approval gate (G1, §7.3 six-step) presented and approved; canonical `bash -c "jq -c '.prognosis | to_entries | sort_by(.key) | from_entries' .opencode/session/current-handoff.json" | tr -d '\n' | sha256sum` re-executed → computed `0d70c13c127032b500415e23612ae51b5cd366164ffdfc716755cff0434a60f7` == stored (current-handoff.json L15 `checksum`) — MATCH, deterministic across 3 runs. No `snip jq` (DIA-075 Layer-3 canonical passthrough honored).
    - (b) **B2 exemption confirmed again:** session-2 checksum verification dispatch (cod-1, code-executor ses_0146a6425ffeHH6Yg3G5xpCwJM, registry seq 1800-1802, checksum lane) completed normally WITHOUT §10 ticket-gate block and with zero intervention.
    - (c) **C1 tri-state confirmed again:** §10-scoped sessions referencing long-lived OPEN tickets (DIA-071/DIA-077/DIA-078) passed zero-intervention — ai--1 DIA-078 §10 gate (ses_014693e89ffeftnU0Ue7JtP1ao, seq 1803-1805), ai--2 ground-truth audit (ses_0144a2262ffeAP7MDK0y5GeQri, seq 1815-1817), cod-4 DIA-078 fix (ses_014475a8dffe72utMHBqLHa7Y3, seq 1818-1820), ai--3 Phase-6 re-verify audit (ses_014422613fferxqtxtxcRPoLYY, seq 1821-1823), cod-5/cod-6 docs sessions. Under the OLD gate these long-lived-OPEN references would have over-fired on the recency/session-ownership requirement.
    - (d) **DIA-078 fix COMPLETED + audited:** `"doom_loop": "deny"` at opencode.jsonc L151 (coder permission block L147-153); `## Snip-prefix Guardrail (DIA-075, DIA-078)` at oh-my-opencode-slim.jsonc L70/256/444 (3 presets); learnings `.opencode/learnings/external-patterns/2026-08-10-dia078-snip-loop-hardening.md` present; ai-auditor verdict CONFORMS-WITH-CAVEATS; `make test-config` exit 0.
  - **M4 CLOSES:** both sessions passed with no gate intervention → DIA-076 → VERIFIED (frontmatter flipped this session) → archived per DIA-074 convention.
