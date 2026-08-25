# DIA-260823-v9di - simplify skill duplicate: project vs global tree ownership/remedy

---

id: DIA-260823-v9di
title: "simplify skill duplicate: project vs global tree ownership/remedy"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-23
source: inventory
date: 2026-08-23
created: 2026-08-23
updated: 2026-08-24

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence: []

---

## Description

Reported symptom (developer): project `.opencode/skills/simplify/SKILL.md` is
byte-identical to the global `~/.config/opencode/skills/simplify/SKILL.md`, and
`validate-skills` rejects the duplicate, causing a `make test-config` failure.

Observed command evidence (this environment, 2026-08-23) CONTRADICTS the
premise on both counts:

1. Files are NOT byte-identical. `diff` shows 3 differing hunks:
   - L39: global `Do all existing tests still pass without modification?` vs
     project `What proportionate final-state verification will reveal a behavior change?`
   - L111-112: global `2. Run relevant tests` / `3. Keep it only if behavior is preserved`
     vs project `2. Use the proportionate final-state verification plan...` /
     `3. Keep it only when the evidence supports preservation`
   - L132-138: global `## Verification Checklist` (5 checkboxes) vs project
     `## Final-state verification` (prose paragraph).

2. `validate-skills` does NOT reject it. It emits a SOFT warn-only
   near-duplicate and exits 0:
   - `bash .opencode/scripts/validate-skills.sh` ->
     `warn: near-duplicate skill 'simplify' (differs from global '/app/.config/opencode/skills/simplify')`
     summary `26 passed, 0 failed, 41 warnings`; EXIT=0.
   - `bash scripts/test-interview-enforcement.sh` -> all 5 checks passed; EXIT=0.
   - Therefore `make test-config` (test-interview + test-skills) currently
     PASSES (exit 0). No current hard failure exists here.

Root-cause context (`.opencode/scripts/validate-skills.sh`, DIA-052 two-tier
cross-location duplicate detection):

- Tier 1 (HARD, exit 1): byte-exact duplicate (same sha256 in both trees) ->
  `FAIL: duplicate skill ...`.
- Tier 2 (SOFT, warn-only): near-duplicate (same dirname, different content) ->
  `warn: near-duplicate skill ...`.
  Current state hits Tier 2 only.

Latent risk: if the project copy is ever made byte-identical to the global
copy, Tier 1 HARD fires and `make test-config` would FAIL (exit 1). The
ownership question is therefore unresolved, not absent.

## Scope

Investigate the correct ownership/remedy for the `simplify` skill living in
BOTH the project tree (`/workspace/.opencode/skills/simplify/SKILL.md`) and the
global tree (`~/.config/opencode/skills/simplify/SKILL.md`, resolves here to
`/app/.config/opencode/skills/simplify/SKILL.md`):

- Is the project copy an intentional override of the global, or stale drift
  that should be removed?
- Which copy is canonical, and should the other be deleted, symlinked, or
  content-aligned?
- Should Tier 2 near-duplicate remain warn-only (and be documented as
  accepted), or should the check be tightened/excluded for this skill?
  Deliver a recommendation + the minimal change set. Do NOT modify any content
  in this ticket (see Non-goals).

## Non-goals

- Do NOT edit `.opencode/skills/simplify/SKILL.md` (project or global).
- Do NOT edit `.opencode/scripts/validate-skills.sh` or any config/code.
- Do NOT change the DIA-052 two-tier detection logic.
  This ticket is investigation + recommendation only; the actual fix is a
  separate follow-up (claimed from the recommendation).

## Verification

- [ ] Observed evidence captured: `diff` of the two SKILL.md files + full
      `validate-skills.sh` and `test-interview-enforcement.sh` output (exit 0)
      recorded above.
- [ ] Ownership decision documented: project copy is canonical / global is
      canonical / both intentional, with rationale.
- [ ] Remedy specified (delete project copy | symlink | align content |
      accept+document warn-only), with the exact file/line change identified
      but NOT applied.
- [ ] Acceptance gate: `make test-config` gets past this duplicate-skill check
      (no spurious failure from the `simplify` near-duplicate). Currently it
      already passes (exit 0, warn-only); the fix must preserve that and remove
      the latent Tier-1 HARD risk if the copies ever align.

## Fix

Applied 2026-08-24 as OpenSpec change `simplify-skill-ownership-remedy`
(DIA-260823-v9di remedy):

- **Deleted** the project `simplify` skill directory
  (`.opencode/skills/simplify/` — `SKILL.md`, `README.md`, `codemap.md`). No
  orphan references to the project path remain in live docs/config; the only
  remaining matches are this ticket's historical record (Description, lines
  39-93).
- **Canonical ownership:** the global OMO tree
  (`~/.config/opencode/skills/simplify/`) is the single canonical source. The
  project copy was stale drift from a DIA-084 pin, not an intentional override.
- **Current state vs latent risk:** pre-deletion, `validate-skills.sh` emitted a
  SOFT warn-only near-duplicate (`warn: near-duplicate skill 'simplify'`, exit 0)
  — no current hard failure. The latent hazard was Tier-1 HARD: byte-identical
  copies would fail `make test-config` (exit 1). Deletion removes the project
  copy, eliminating both the soft warn and the latent hard risk.
- **Docs updated:** `.opencode/skills/README.md` (project-pinned 23→22,
  global-only 8→9, `simplify` ownership note with current-state/latent-risk
  context) and `docs/onboarding.md` (Layer 2 `simplify` row removed).
  `simplify` remains non-load-bearing (per DIA-084).
- **Out of scope (unchanged):** global OMO `simplify` source,
  `validate-skills.sh` logic, CHANGELOG, and the learning-outcome field.

## Re-verify

- `make test-config` -> exit 0, no `simplify`-related warnings (near-duplicate
  warn gone after project-copy deletion).
- `grep -r ".opencode/skills/simplify" .` -> only this ticket's historical
  references; no live doc/config references to the deleted project path.
- `git status` -> shows the deletion + README/onboarding/ticket updates; other
  in-flight branch changes are unrelated to this remedy.
- Runtime note: a running OpenCode session must be restarted to drop the
  project `simplify` from its `<available_skills>`; the global copy still
  resolves, so behavior is unchanged (non-breaking).
