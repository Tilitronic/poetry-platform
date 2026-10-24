## Context

Two runtimes consume OMO pins independently:

1. Project container runtime: `.opencode/opencode.jsonc:724`
   (`oh-my-opencode-slim@2.2.19`) + `Dockerfile.dev:32`
   (`ARG OMO_VERSION=2.2.19`, pre-baked into the plugin cache) + full routing
   in `.opencode/oh-my-opencode-slim.jsonc` (`preset: promo`).
2. Standalone runtime: `tools/opencode-docker/config/opencode.json:25`
   (`oh-my-opencode-slim@2.2.14`), minimal MCP (context7 + gh_grep), no preset
   block, no routing overrides. Served to `bin/opencode-docker` users.

DIA-188 DD3 declares the project-side lockstep (opencode.jsonc + tui.json +
Dockerfile ARG); the legacy file fell out of it at 2.2.14. This change
re-aligns the single token and nothing else.

Governing module doc: `.sdd/opencode-config/architecture.md` (opencode-config
boundary; batch/instance-separation ADRs). This change operates within that
boundary - a config pin value, no new module, no new public API, no
architecture decision. No `@architector` escalation needed.

Constraints:

- ASCII-only input/output (DIA-079).
- Exactly one token changes; no formatting churn, no key reorder.
- `make test-config` must stay green (dedupe + coverage consumers).
- Retire stays out (owned by DIA-260824-8k62).

See proposal.md for motivation, alternatives, and ticket linkage.

## Goals / Non-Goals

**Goals:**

- Align the standalone pin to `oh-my-opencode-slim@2.2.19`, restoring
  project/standalone parity.
- Prove the file still parses and passes every existing consumer gate.
- Prove the pinned plugin still resolves/loads for the standalone path.

**Non-Goals:**

- Retiring, deprecating, or moving `tools/opencode-docker/config/opencode.json`
  (owned by DIA-260824-8k62).
- Adding a slim-preset block or expanding the MCP set in the legacy file
  (Q3 ruling: out of scope; minimal-standalone is intentional).
- Touching `.opencode/opencode.jsonc`, `.opencode/oh-my-opencode-slim.jsonc`,
  `Dockerfile.dev`, or any project-side pin.
- New validators, new tests, new `.sdd/` document.

## Decisions

### D1: Single-token bump, no parity expansion

**Choice:** change only `oh-my-opencode-slim@2.2.14` to
`oh-my-opencode-slim@2.2.19` on line 25 of the legacy file.

**Rationale:** the drift is the version token; MCP/preset shape is
intentionally minimal for the standalone path and any expansion is a unified-
runtime design call under 8k62, not a stopgap call.

**Alternatives considered:** bump plus preset/MCP parity (rejected - scope
creep into 8k62 territory); see proposal.md.

### D2: Existing gates are the verification seam (no new tests)

**Choice:** verify via JSON parse + `make test-config` (dedupe + coverage)

- plugin load check. No new script, no new bats, no new validator.

**Rationale:** three existing consumers already read this file on every
`make test-config`; a one-token change does not justify a new harness. Matches
the `dev-infra-pin-sync` precedent (reuse gates before inventing gates).

**Alternatives considered:** new pin-parity validator across the three OMO
sync points (rejected - worthy follow-up, but out of scope for a stopgap;
noted as follow-up candidate below).

### D3: No delta spec

**Choice:** `skip_specs: true`. No capability change; externally visible
behavior is "same standalone runtime, current plugin generation".

**Rationale:** specs describe behavior contracts; this change restores parity,
it does not define new behavior.

## Seams

**Test seams (all pre-existing, confirmed with user):**

- JSON parse seam: `jq -e '.plugin[]' tools/opencode-docker/config/opencode.json`
  (validity + value assertion).
- `make test-config` seam: runs `scripts/validate-observer-dedupe.sh` (legacy
  file is an explicit input at line 50) and
  `scripts/audit-agent-tool-coverage.sh tools/opencode-docker/config/opencode.json`
  (via `Makefile:236`).
- Plugin load seam: standalone config resolves `oh-my-opencode-slim@2.2.19`
  (bun/npm install dry-run or container startup log; implementer picks the
  cheapest available at build time).

**Public boundaries:**

- `tools/opencode-docker/config/opencode.json` plugin array (the changed seam).
- `make test-config` target (the gate seam).

**No new production module boundaries.**

## Risks / Trade-offs

**Risk:** 2.2.19 introduces a breaking change for the minimal standalone config
(e.g., requires a preset block the file lacks).
-> **Mitigation:** plugin load check (D2 third leg) catches it; rollback is one
commit. OMO 2.2.x history shows additive preset evolution, so likelihood is low.

**Risk:** bumping the standalone pin without bumping anything else re-opens
drift the next time the project pin moves.
-> **Mitigation:** accepted and documented; a cross-file pin-parity validator is
the correct long-term fix (follow-up candidate, not this change).

**Risk:** implementer "helpfully" expands scope (preset block, MCP additions).
-> **Mitigation:** tasks.md carries explicit scope guards; reviewer checks the
diff is one token.

**Trade-off:** stopgap leaves two runtimes instead of one. Acceptable - the
unified runtime is 8k62's gated decision, not this change's.

## Migration Plan

**Deployment:** single-commit config edit. No build, no migration, no service
restart beyond normal standalone startup.

**Rollback:** `git revert` the one commit (one-token revert 2.2.19 -> 2.2.14).
No data migrations, no side effects. Rollback restores the drifted but working
2.2.14 standalone state.

**Config chain verification:**

1. `jq` parse + pin assertion on the legacy file.
2. `make test-config` exits 0 (dedupe + coverage included).
3. Plugin load check passes for the standalone config.
4. `openspec validate dia-260827-docker-omo-pin-drift` passes.
5. `@reviewer` two-axis review (Standards + Spec fidelity), diff must be one
   token.

**Follow-up candidate (not this change):** cross-file OMO pin-parity validator
(opencode.jsonc + Dockerfile.dev ARG + legacy config) in the
`dev-infra-pin-sync` shape, so the next project-side bump cannot silently
re-open this drift.

**Open Questions:** none - Q2 (scope: file-only), Q3 (MCP/preset parity: out),
Q4 (verification: gates above), Q5 (rollback: one-commit revert), Q6 (tickets:
bry9 governs / 8k62 non-goal / bm5k verification ref) all closed per developer
rulings in the resumption brief.
