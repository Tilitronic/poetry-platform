# DIA-052 — Skill dup cleanup: 5 byte-exact dup skill dirs + two-tier dup detection in validate-skills.sh

<!-- Task T1 of openspec/changes/ai-self-improvement-auditor-and-cleanup (validated,
     openspec validate exit 0, 2026-08-06). Owner pre-approved the 5 deletions
     (ruling row 462; D2 of findings ai--1). THIS TICKET DOES NOT IMPLEMENT —
     implementation is scheduled; the ticket encodes the spec + acceptance. -->

---

id: DIA-052
title: "Skill dup cleanup: 5 byte-exact dup skill dirs + two-tier dup detection in validate-skills.sh"
area: scripts
severity: Major
status: DONE
blocked_by: []
discovered: 2026-08-06
source: inventory
date: 2026-08-06
created: 2026-08-06
updated: 2026-08-06

# --- Session Attribution (v2 schema, optional — GRANDFATHERED for DIA-001..049) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

**Summary:** OpenCode loads BOTH project skills (`.opencode/skills/`) and global
skills (`~/.config/opencode/skills/`), so a project skill that is byte-identical
to a global skill produces a duplicate `<available_skills>` entry — wasted
context and masked drift. Five byte-exact duplicate skill directories under
`.opencode/skills/` must be deleted, and `validate-skills.sh` must gain a
two-tier duplicate-detection pass so future duplicates fail the build.

**Defect (owner pre-approved, ruling row 462 / findings ai--1 D2):** delete these
5 byte-exact dup dirs: `book-rag`, `mermaid-diagramming`, `console-charting`,
`debugging-workflow`, `teaching`. Keeper set (DO NOT delete):
`playwright-browser` (project-local acceptance-test extensions; near-dupe vs
global with an intentional ~4-line diff → SOFT warn is expected) + `git-diff`
(project-local, intentionally better than the global version). Net effect:
`.opencode/skills/` drops from 20 to 15 entries.

**⚠ Pre-deletion audit is MANDATORY — do not delete blind.** Per tasks.md §T1.1,
for each candidate `$d`, sha256-compare `$d/SKILL.md` against
`~/.config/opencode/skills/$d/SKILL.md`; only delete on byte-exact match (and
not for `playwright-browser` / `git-diff`). Ticket-time spot-check (2026-08-06):
3 of the 5 are byte-exact on `SKILL.md` (`mermaid-diagramming`,
`console-charting`, `teaching`); **`book-rag` and `debugging-workflow` DIFFER**
from their global counterparts (book-rag: project-local `query_rag.py` path
references; debugging-workflow: `@coder` vs `@fixer` stage references). If a dir
fails byte-exact at implementation time, DO NOT delete — flag to the orchestrator
(design.md: the coder lane flags gaps rather than deciding silently). A 3-of-5
outcome changes the post-cleanup count to 17 (not 15) and requires orchestrator
disposition on the two near-dupes.

**Validator extension (`.opencode/scripts/validate-skills.sh`):** append a
dup-detection pass after the existing per-skill frontmatter loop, preserving the
existing 3-tier exit contract (0/1/2), HARD/SOFT partition, collect-all
discipline, and single-line `N passed, M failed, K warnings` summary (dup
counters fold into the existing accumulators — Q6 ruling):

- `GLOBAL_SKILLS_ROOT="${GLOBAL_SKILLS_ROOT:-$HOME/.config/opencode/skills}"`
  (new env seam mirroring `SKILLS_ROOT`).
- Missing global dir → exit 2 INFRA (stderr `error: global skills directory not
found: ...`). Empty global OR empty project dir → skip dup-detection, fall
  through to summary (exit 0).
- **Tier 1 — byte-exact HARD (exit 1):** single-pass `sha256sum` over every
  `SKILL.md` under both trees, group by hash; each hash with ≥2 entries spanning
  project+global emits `FAIL: duplicate skill '<name>' (byte-exact match with
global '<global-path>')` to stderr and increments `$failures`. O(n).
- **Tier 2 — near-dupe SOFT (warn only):** for each project skill NOT byte-exact,
  if a same-named global skill exists, `diff -r <project-dir> <global-dir>`; any
  differences → `warn: near-duplicate skill '<name>' (differs from global
'<global-path>')` to stderr + `$warnings`. Does NOT flip exit code.
- Script-header docs: case-sensitive exact + follow-symlinks policy (human
  contract, not programmatic enforcement).

**bats fixture matrix (`scripts/__tests__/validate-skills.bats`):** add 6
`@test` cases, RED-GREEN per tdd-craftsman (write tests first → they fail →
implement dup detection → green). Each test builds isolated fixture trees under
`$BATS_TEST_TMPDIR` and sets `SKILLS_ROOT` + `GLOBAL_SKILLS_ROOT` explicitly;
asserts via `assert_status` / `assert_output_contains` from `test-helper.bash`:

1. Valid (no dups) → exit 0.
2. Byte-exact duplicate → exit 1 + `FAIL: duplicate skill ...`.
3. Near-duplicate (whitespace/comment drift) → exit 0 + `warn: near-duplicate
skill ...`.
4. Empty project skills dir → exit 0.
5. Missing global dir (`GLOBAL_SKILLS_ROOT` → nonexistent path) → exit 2.
6. Multiple duplicates in one run → exit 1, one `FAIL:` line per duplicate
   (collect-all discipline).

**Routing:** AGENTS.md §2.4 (dev-infra shell validators + bats) → implement via
@coder, review by @reviewer (two-axis: Standards + Spec fidelity).

## Verification

1. `ls .opencode/skills/ | wc -l` — expect `15` (or `17` per the spot-check
   note above if only 3 of 5 qualify — orchestrator disposition required before
   closing).
2. Keeper skills byte-identical to pre-T1:
   `git diff HEAD@{1} -- .opencode/skills/playwright-browser/ .opencode/skills/git-diff/`
   is empty.
3. `bash .opencode/scripts/validate-skills.sh` — exit 0, summary
   `15 passed, 0 failed, 0 warnings` on the post-cleanup real config.
4. `make test-skills` — exit 0.
5. `make test-shell` — exit 0: pre-existing bats baseline + 6 new dup-detection
   cases pass.
6. `bash -n .opencode/scripts/validate-skills.sh` — exit 0 (via
   `bats-wrapper.sh`).
7. Fixture exit codes: byte-exact dupe → 1 with `FAIL:` naming the pair;
   near-dupe → 0 with `warn:` naming the pair; missing global → 2;
   multiple dupes → 1 with one `FAIL:` per duplicate.

## Fix

**Fix (2026-08-06, campaign T1 — ledger rows 478/481):** cod-5 (row 478) implemented
audit-first: sha256sum vs `~/.config/opencode/skills/` → **3 byte-exact skill dirs
deleted** (`mermaid-diagramming`, `console-charting`, `teaching`; 20→17; `book-rag` +
`debugging-workflow` KEPT as near-dupes per owner row 477/480); `validate-skills.sh`
appended the two-tier dup-detection pass (`GLOBAL_SKILLS_ROOT` env seam; HARD byte-exact
sha256sum group-by-hash → `FAIL:` + exit 1; SOFT near-dupe `diff -r` → `warn:`; missing
global → exit 2 INFRA; empty roots → skip; counters folded into existing summary) + 6
hermetic bats cases (RED→GREEN). cod-6 (row 481) applied review fixes S1 (`declare -A`
O(1) lookup) + S2 (`has_skill_dirs()` helper) + M1 spec errata (3 `> **Errata
(2026-08-06):**` blockquotes — 5→3 deletions / 20→17). Verification: bats **23/23**,
make test-skills exit 0 (`17 passed, 0 failed, 31 warnings`), make test-config exit 0,
bash -n exit 0.

## Re-verify

**Re-verify (2026-08-06 — ledger rows 479/482):** rev-1 two-axis review (row 479) — CLEAN,
no Blocker/Critical/Major; 2 Suggestion (S1/S2) + 1 Minor (M1), all accepted by owner
(row 480) and fixed by cod-6 (row 481). rev-2 re-review cycle 1/2 (row 482) — **ALL
VERIFIED-CLOSED** (S1/S2/M1 verified-closed; re-review observations NONE; 0 still-open,
0 partial). Ticket flipped **OPEN → DONE** (2026-08-06) per owner authorization (G1 gate
row 503 + certification path row 509).
