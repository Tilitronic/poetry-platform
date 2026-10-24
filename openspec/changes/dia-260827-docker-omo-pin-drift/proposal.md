## Why

The standalone runtime config `tools/opencode-docker/config/opencode.json` pins
`oh-my-opencode-slim@2.2.14` (line 25) while the project runtime
`.opencode/opencode.jsonc` pins `oh-my-opencode-slim@2.2.19` (line 724) and
`Dockerfile.dev` bakes `ARG OMO_VERSION=2.2.19` (line 32, DIA-188 DD3 lockstep).
The 2.2.14 entry dates from `openspec/changes/omo-self-sufficiency` (time-current
pin); nothing kept it in lockstep afterward. A prior reaudit
(`knowledge/ana-260831-6w4y-full-repository-four-lane-reaudit-report.md:410`)
already recorded project-vs-Docker drift (then 2.2.17 vs 2.2.14); the gap has
since widened to 5 patch versions (2.2.19 vs 2.2.14).

Impact: anyone running the standalone `bin/opencode-docker` path loads a stale
plugin generation (missing prompt, routing, and guard fixes shipped in
2.2.15-2.2.19), while project-container users get current behavior. The two
runtimes silently diverge.

Governing ticket: DIA-260827-bry9 'OMO version and model-routing drift from
baseline' (OPEN, High). Conflicting ticket: DIA-260824-8k62 'retire legacy
tools/opencode-docker only after unified-runtime acceptance' (OPEN, Medium,
blocked by 5 tickets, acceptance criteria template-empty). Prior recon pointer
DIA-260917-bm5k is template-empty (no retrievable cod-2 evidence body).

## What Changes

- Single-token bump in `tools/opencode-docker/config/opencode.json` plugin array:
  `oh-my-opencode-slim@2.2.14` -> `oh-my-opencode-slim@2.2.19`.
- No MCP changes, no preset block added, no other plugin touched.
- Retire of the legacy file is an explicit NON-GOAL, owned by DIA-260824-8k62
  after its unified-runtime acceptance lands.

## Capabilities

### New Capabilities

None. Version alignment within existing config; no behavior contract change.

### Modified Capabilities

None.

## Impact

- Config: `tools/opencode-docker/config/opencode.json` (one plugin-array token).
- Consumers verified, not modified:
  `scripts/validate-observer-dedupe.sh:50`,
  `scripts/audit-agent-tool-coverage.sh` (via `Makefile:236`),
  `openspec/changes/dia-260821-5r03-observer-registration-dedupe` design refs.
- Dependencies: none added.
- Systems: standalone `bin/opencode-docker` runtime only; project container
  runtime unchanged.

## Alternatives considered

- Retire now (delete/deprecate the legacy file, merge into 8k62): rejected -
  8k62 is gated on 5 blockers with empty acceptance criteria; retiring now
  strands `bin/opencode-docker` users with no accepted replacement. Evidence:
  Tier-1 (8k62 ticket frontmatter `blocked_by`, empty Verification section).
- Do nothing until 8k62 acceptance: rejected - leaves a live 5-patch drift
  with zero signal; the bump is one token and fully reversible. Evidence:
  Tier-1 (live pin reads 2.2.14 vs 2.2.19).
- Bump plus MCP/preset parity (add slim-preset block, expand MCP set):
  rejected - the legacy file is intentionally minimal for the standalone path;
  parity expansion is a design decision for 8k62's unified runtime, not this
  stopgap. Evidence: Tier-1 (legacy file has no `preset` key by design).
- Status-quo: rejected - same as do-nothing.

Chosen option: bump-only stopgap (A) - because it closes drift now, respects
the 8k62 blocker chain, and reverts in one commit.

## Testing Decisions

**What makes a good test for this change:** the existing config validators are
the right seam - a pin-format/parse check plus the observer-dedupe and tool-
coverage gates that already consume this file. No new test harness; the change
is one token in a JSON array.

**Which modules will be tested:** (1) JSON validity + pin value of
`tools/opencode-docker/config/opencode.json` (jq parse, plugin entry equals
`oh-my-opencode-slim@2.2.19`). (2) `make test-config` (runs
validate-observer-dedupe + audit-agent-tool-coverage against this file).
(3) Plugin load check (standalone config still resolves the pinned plugin).

**Prior art in the codebase:** `scripts/validate-observer-dedupe.sh`,
`scripts/audit-agent-tool-coverage.sh`, `Makefile:236` wiring;
`openspec/changes/dev-infra-pin-sync` (pin-parity validator precedent).

## Ticket linkage

- Governs: DIA-260827-bry9 (this change narrows its drift scope to the Docker
  pin; the global-model overlap half stays open under bry9).
- Non-goal ref: DIA-260824-8k62 (retire owner; this change does not advance or
  block it).
- Verification ref: DIA-260917-bm5k (cited prior recon; body empty at spec time
  - re-verify must re-capture evidence there).
