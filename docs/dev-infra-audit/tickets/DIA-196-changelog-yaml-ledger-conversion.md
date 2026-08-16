# DIA-196 - changelog YAML-ledger conversion: YAML source + derived MD view (ana024 Variant B)

<!-- IMPLEMENTATION TICKET (developer GO 2026-08-15 on ana024 EBDV Variant B).
     Do NOT implement here - this ticket records scope + routing + gate state.
     ana024: knowledge/ana024-artifact-format-ebdv/ana024-artifact-format-ebdv-report.md -->

---

id: DIA-196
title: "changelog YAML-ledger conversion: YAML source + derived MD view (ana024 Variant B)"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: "DIA-194" # optional DIA-NNN parent epic ticket (DIA-125 keep-local extension; scripts/tickets emits this field always)

# DIA-104 grilling-gate markers (ai--7 validated design): fill at creation time

# with the defaults below (absent = legacy/skipped, grandfather precedent).

gate_state: "partial" # grilled | waived | bypassed | partial | skipped
gate_triggers: [schema-state, cross-boundary] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "developer GO on ana024 EBDV 2026-08-15; section 2.5 chain sets final markers" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-15
source: developer-requirement
date: 2026-08-15
created: 2026-08-15
updated: 2026-08-15

# --- Session Attribution (v2 schema, optional - GRANDFATHERED for DIA-001..049) ---

session_id: "ses_ff8c75bc9ffetkMu9NEU4pw11e" # OpenCode session ID that owned this ticket
lane_id: "cod-merge-lane" # e.g. cod-1, ai--3
agent: "coder" # agent name (coder, reviewer, etc.)
model: "deepseek-v4-flash" # model ID used
parent_session_id: "" # orchestrator's session ID (populated via get-my-session-id tool)
attempts: 0 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: # list of file paths modified
[
'docs/dev-infra-audit/tickets/DIA-196-changelog-yaml-ledger-conversion.md',
'docs/dev-infra-audit/tickets/README.md',
]
artifacts: [] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

IMPLEMENTATION ticket (developer GO 2026-08-15 on ana024 EBDV Variant B):
convert `.opencode/CHANGELOG.md` (228,346 bytes / 88 sections / 738 lines of
prose, ~57,086 tokens full read at ~4 chars/token heuristic) to a YAML-ledger
source of truth plus a derived Markdown view. The ana024 analysis (DIA-194
Deliverable B, EBDV matrix) recommends Variant B over Variant A (status quo),
Variant C (hybrid), and Variant D (MD + grep partial-read) - see ana024
sections 2, 7. This ticket records scope + routing + gate state ONLY; no
implementation happens here (DIA-084 guardrail: analysis recommends,
conversions spawn follow-up tickets - this is that follow-up).

Key ana024 evidence:

- Token economy: ~3.7x full-read reduction (57,086 -> ~15,400 tokens) and
  ~326x per-entry reduction (57,086 -> ~175 tokens per entry via `yq`).
- Deliverable A reuse (DIA-180-A, merged bcb8379): yaml-language-server LSP
  pin + memory-shelf JSON Schema gate pattern + validate-memory-shelf.sh wired
  into `make test-config`. The schema/validator/bats pattern is directly
  extensible; ~30-40% of conversion effort is already done (no new
  LSP/schema/gate machinery needed).
- Derived-view pattern is the THIRD instance of an established repo shape
  (scripts/session-log render: messages.jsonl -> messages.md; scripts/tickets
  rollup: tickets/\*.md frontmatter -> tickets/README.md).
- Rollback is clean: single-commit migration, `git revert` restores the prose
  file.

## Verification

- `make test-config` exit 0 with the new changelog schema validator wired in.
- Derived MD regenerates deterministically: render script produces
  byte-identical output across runs on unchanged YAML input (bats fixture).
- Per-DIA query via `yq '.[] | select(.ticket == "DIA-NNN")'
.opencode/CHANGELOG.yaml` returns a single entry (~700-771 bytes / ~175-193
  tokens).
- Token measurement matches the ana024 band: full-read ~15,400-16,950 tokens
  (~61,600-67,848 bytes), per-entry ~175-193 tokens. Re-measure against
  native telemetry (DIA-182 surface) to replace the ~4 chars/token heuristic
  with ground truth (ana024 section 3 uncertainty band).
- Prettier: YAML passes `npx prettier --check` (test block-scalar prose on
  the first sample entry before committing the migration, ana024 section 6b).
- ASCII-only (DIA-079) holds on YAML keys; prose values follow the same
  DIA-079 rules as MD prose (user-facing text exemption per DIA-189 ruling).

## Scope (from ana024, vertical slice - test-first per tdd-craftsman)

1. **Schema (test-first):** `scripts/schemas/changelog.schema.json` (YAML
   entry shape: date/ticket/severity/status/area/scope/route/files/summary/
   verification), following the memory-shelf schema pattern (DIA-180-A);
   fixtures `scripts/__tests__/fixtures/changelog-*.yaml` (valid/minimal/
   malformed); `scripts/validate-changelog.sh` + bats; wire into
   `make test-config`.
2. **Render script (test-first):** `scripts/changelog-render` (bash + jq +
   yq per DIA-137 settled standards) renders CHANGELOG.yaml -> CHANGELOG.md
   (derived view); bats over the render function; a `make` target
   (e.g. `make changelog-render`) for regeneration.
3. **Migration:** convert the 88 prose sections of `.opencode/CHANGELOG.md`
   into `.opencode/CHANGELOG.yaml` entries (one-time coder lane task);
   spot-check rendered MD matches legacy prose for N=5 random sections.
4. **Derived-view strategy decision (developer):** (a) commit the rendered
   CHANGELOG.md alongside CHANGELOG.yaml (dual-file, human-readable PR
   review), OR (b) gitignore CHANGELOG.md and render on-demand (single-file,
   cleaner git). ana024 section 9 Q1 - explicit developer decision required.
5. **Prompt updates:** update prompts that reference CHANGELOG lookup
   (orchestrator_append.md, NEXT-RUN.md) to point agents at the `yq` per-DIA
   query pattern.
6. **Prettier / DIA-079 / DIA-105 validation:** confirm YAML passes
   `npx prettier --check`; confirm ASCII-only on keys and prose values;
   confirm the DIA-105 edit-time formatter handles YAML block-scalar prose.
7. **Token-economy re-measurement:** post-conversion measurement against the
   ana024 band (see Verification).

## Rollback

Clean single-commit revert: the migration (YAML source + schema + validator +
render script + derived view) lands in ONE commit on a feature branch
(branch omo-slim-changes per standing convention); `git revert <commit>`
restores the prose CHANGELOG.md with no residual state (ana024 section 6d).

## Routing

AGENTS.md section 2.5 (opencode-config / AI-devtools modernization workflow):
ai-specialist Phase 1 gate research -> developer review -> design (architect)
-> coder (test-first implementation) -> ai-auditor Phase 6 independent
review -> validate (make test-config + restart smoke) -> register
(CHANGELOG, learnings, memory-manager). Estimated effort ~1 day of focused
work (one section-10 cycle, ana024 section 2 Variant B).

## Gate markers (DIA-104)

- gate_state: partial - no Socratic grill has run yet. The developer GO on
  the ana024 EBDV matrix (2026-08-15) is the design-review signal for this
  ticket; the section 2.5 chain (ai-specialist gate research + architect
  design) sets the final markers (grilled/waived + triggers/waivers) during
  the first implementation dispatch.
- gate_triggers: schema-state (new changelog.schema.json + YAML source of
  truth), cross-boundary (opencode-config surface change: prompts, prompts
  files, make target).
- gate_override: "developer GO on ana024 EBDV 2026-08-15; section 2.5 chain
  sets final markers".

## Acceptance criteria

- `make test-config` exit 0 with validate-changelog.sh wired in.
- Rendered CHANGELOG.md matches (or closely approximates) the legacy prose
  for spot-checked sections; regeneration is deterministic.
- Per-DIA query via `yq` returns a single entry (~700 bytes / ~175 tokens).
- Token measurement matches the ana024 band (full-read ~15.4k, per-entry
  ~175).
- Rollback verified: single-commit revert restores the prose file.
- ASCII-only (DIA-079) on all source files added/changed.

## Fix

> Filled by the implementation lane (coder, commit 28d1a2d, branch
> omo-slim-changes, unpushed).

Implementation landed 2026-08-16 as commit 28d1a2d (single-commit migration
per the Rollback section: YAML ledger + schema + validator + render script +
derived MD + prompt updates all in ONE commit):

- `.opencode/CHANGELOG.yaml` (NEW): 90-entry ledger migrated from the prose
  CHANGELOG.md (89 sections + the headerless DIA-154 orphan + the DIA-183
  2026-08-16 entry), reverse-chronological, every entry schema-valid.
- `scripts/schemas/changelog.schema.json` (NEW): strict entry shape
  (additionalProperties: false; date/ticket/scope/files/summary/verification
  required), mirroring memory-shelf.schema.json conventions (DIA-180-A).
- `scripts/validate-changelog.sh` (NEW): JSON Schema gate + embedded
  structural fallback (clone of validate-memory-shelf.sh, two-layer parity
  pinned by bats), wired into `make test-config`.
- `scripts/changelog-render` (NEW, executable): deterministic derived-view
  generator (CHANGELOG.yaml -> CHANGELOG.md), defensive on empty/missing keys.
- `scripts/__tests__/validate-changelog.bats` + `changelog-render.bats` +
  9 fixtures (NEW): 12+1 tests covering valid/missing/malformed/extra/empty/
  empty-array/missing-file/empty-files/datetime-date cases.
- `.opencode/CHANGELOG.md`: regenerated derived view (90 entries).
- Prompts: AGENTS.md section 2.5 Phase 7 (register via YAML ledger + render)
  and `.opencode/oh-my-opencode-slim/orchestrator_append.md` (Changelog Read
  Protocol: partial reads via yq/python3, never the full file).

Design deviations (recorded in the commit message; reviewer diff anchor is
the DIA-194 UPDATE block):

1. Render/validator use the settled PyYAML stack (bash + python3) instead of
   the design's "bash + yq" wording - yq is not installed on host or dev
   container and DIA-137 explicitly rejected it (res027 section 2.7).
2. No opencode.jsonc edit needed: global bash baseline is "\*": allow, so yq
   read/write are already permitted (design section 7's allow-list item is
   moot).

Re-review cycle 1/2 (2026-08-16): developer approved fixing all actionable
findings. The fix loop landed as TWO commits (attribution corrected, re-review
accuracy fix D2): `bbd3a40` = FIX-1 + FIX-2 (scripts/tests: validate-changelog.sh
structural fallback `files: []` parity, changelog-render datetime normalization,
new fixtures + bats), `d0e0626` = FIX-3..FIX-6 (docs/tickets: AGENTS.md dead yq
branch removed, orchestrator delegation scope clarified, Python prefix-match
fallback parity, ticket Fix/Re-verify populated).

## Re-verify

> Filled by the implementation lane; status stays OPEN pending reviewer
> re-verification (re-review cycle 1/2).

Evidence recorded by the implementation lane (coder, 2026-08-16):

- `make test-config` exit 0 (56 pass / 0 fail, incl. validate-changelog.sh).
- `make test-shell` exit 0 (402 bats, incl. the 12 changelog validator/render
  tests + the new FIX-1 empty-files parity test + FIX-2 datetime-date test).
- `scripts/validate-changelog.sh` against the committed ledger exit 0 (the
  FIX-1 proof: DIA-189b's `files: []` entry passes).
- Derived MD regenerates deterministically (byte-identical across runs);
  rendered MD closely approximates the legacy prose for spot-checked sections.
- Prettier: `.opencode/CHANGELOG.yaml` passes `npx prettier --check`.
- Per-DIA query works via the documented yq/python3 forms; full-read size is
  ~238 KB (lossless migration per design section 3; the ana024 full-read
  token band assumed condensed entries - recorded deviation, per-entry
  partial reads deliver the token win).
- git status at commit time showed only the intended files changed; sibling
  dirty files untouched; no push (branch omo-slim-changes).

Pending reviewer confirmation of FIX-1..FIX-6 before status flip to CLOSED.
