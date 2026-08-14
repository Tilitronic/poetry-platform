# DIA-134 - Batch D infra hardening: worktree hooks, test persistence, branch-ownership payloads, dispatch tokens (DIA-132 retrospective)

---

id: DIA-134
title: "Batch D infra hardening: worktree hooks, test persistence, branch-ownership payloads, dispatch tokens (DIA-132 retrospective)"
area: dev-infra
severity: Major
status: DONE
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-14
source: DIA-132 retrospective (2026-08-14)
date: 2026-08-14
created: 2026-08-14
updated: 2026-08-14

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_00078deedffeAmEyVDDmZYLtrx"
lane_id: "docs"
agent: "coder"
model: "opencode-go/deepseek-v4-flash"
parent_session_id: "ses_00327cd6effet7lPBAkPxJ0M3U"
attempts: 0
lease_expires_at: ""
files_touched: [docs/dev-infra-audit/tickets/DIA-134-batch-d-infra-hardening.md, docs/dev-infra-audit/tickets/README.md]
artifacts: []
evidence: []

---

## Description

DIA-132 (parallel coders, batch D) shipped 2026-08-14, but the retrospective
identified 6 infra-hardening items that caused friction during that run. Each
item below is self-contained: problem / proposed change / verification.

### 1. Worktree husky-shim gap (DIA-094 not enforced)

**Problem:** freshly created git worktrees have no `.husky/_` directory.
`core.hooksPath` points to untracked runtime state that is materialized only in
the main tree, so husky pre-commit silently NEVER runs on worktree commits.
Result: the DIA-094 docker gate is NOT enforced on worktree commits.

**Proposed change:** `scripts/worktrees.sh create` (or a follow-up step)
materializes the `.husky/_` shim in each new worktree (copy from main tree or
run `husky install`), so pre-commit + `scripts/verify-pre-commit.sh` fire on
worktree commits.

**Verification:** a commit in a fresh worktree runs the hook (visible output),
and the hook hard-fails when the dev container is down.

### 2. Test persistence for plugin/config behavioral tests

**Problem:** DIA-132 RED/GREEN/merge-verify relied on throwaway tests in
`/tmp/opencode/batch-d-tests/`, which the OS tmp-cleanup wiped between
sessions. The merge-phase coder had to RECONSTRUCT equivalent tests; counts
drifted (10/10 -> 15/15), breaking the same-test contract.

**Proposed change:** keep the plugin/config behavioral tests as a persistent,
gitignored suite under `scripts/__tests__/` (node `.test.mjs`, no new deps),
or wire them into `make test-config`, so RED/GREEN/merge-verify always re-run
the SAME files.

> SUPERSEDED by DIA-136 F2 (2026-08-14): the suite file was un-gitignored and
> is now git-tracked - the gitignored-by-design plan no longer applies.

**Verification:** run the suite from a fresh session after a tmp wipe and
confirm identical assertions/expected counts.

### 3. Branch-ownership in batch D payloads

**Problem:** during the DIA-132 fix loop, the append-worktree coder edited the
3 preset texts in `oh-my-opencode-slim.jsonc` because it did not know those
files belonged to a sibling branch (`feature/dia132-prompts`). Required a
revert commit (af6e019) to avoid a merge conflict.

**Proposed change:** extend the batch D coder directive
(`coder_append.md` worktree-confinement bullet) with an explicit branch model:
"worktree base = <shared sha>; sibling branches own other slices' files; edit
ONLY your assigned files".

**Verification:** a batch D dispatch payload states base sha + owned files,
and a follow-up batch D run produces zero out-of-scope edits.

### 4. Ticket-ID token in dispatch/resume prompts (DIA-063 friction)

**Problem:** two DIA-132 agent resumes were BLOCKED by the ticket-gate scan
because the resume prompts lacked the literal "DIA-132" token. Wasted cycles.

**Proposed change:** codify in AGENTS.md section 2.3 (or the orchestrator
operating rules) that every dispatch AND resume prompt must contain the ticket
ID; optionally relax DIA-063 for resume prompts.

**Verification:** a resume prompt without the token still blocks (gate
intact); with the token it passes.

### 5. Architector design persistence

**Problem:** the DIA-132 docs reviewer flagged FALSIFICATION-1 ("ADR not
verbatim") because the architector's original design text lives only in the
orchestrator session, not in the repo. The reviewer could not verify the
source; the finding was a false positive but cost a review cycle.

**Proposed change:** after each @architector design dispatch, the orchestrator
persists the design text into the DIA ticket (or a `.sdd` draft) before
implementation so reviewers can diff verbatim claims.

**Verification:** the next architector-driven ticket contains the design text
at review time.

### 6. Merge-gate container evidence

**Problem:** the DIA-132 merge phase was attempted twice against a DOWN
container (`poetry-dev` exited 137 ~10h) despite a claim that commits were
configured. Only a real `docker compose ps` (dev service Up) satisfies the
gate.

**Proposed change:** the merge phase may only start with recorded
`docker compose ps` evidence showing the dev service running (commit the gate
output into the merge report), and the session log must record container state
before merge dispatch.

**Verification:** merge dispatch requires the evidence line; no merge attempt
happens without it.

## Scope

Six independent infra-hardening items from the DIA-132 retrospective (see
Description sections 1-6): worktree husky shim, persistent behavioral test
suite, branch-ownership payload contract, ticket-ID dispatch token, architector
design persistence, merge-gate container evidence. Spans scripts + opencode
config; dominant area recorded as dev-infra.

## Verification

Self-check evidence for this ticket's own creation:

- Frontmatter parses: all fields present (id/title/area/severity/status/
  blocked_by/discovered/source/date/created/updated/parent_session_id/
  session_id/lane_id/agent/model/attempts/lease_expires_at/files_touched/
  artifacts/evidence).
- All 5 body sections present: Description / Scope / Verification / Fix /
  Re-verify.
- README index row added after the DIA-132 row.
- README summary counts updated: Major 33->34, OPEN 30->31; all other counts
  unchanged.

For the 6 scope items: see each item's own verification under Description.

## Fix

Applied 2026-08-14 via OpenSpec change 'batch-d-infra-hardening' (implemented
on 4 worktree feature branches: shim/tests/prompts/process, base c9aaa33;
reviewed + ai-auditor APPROVE + combined review MERGE-READY; merged 2026-08-14
via 4 serialized squash-merges 05c75fe..510e60b on omo-slim-changes). All 6
items implemented across slices S1-S4:

> Note (2026-08-14): item 2's gitignored-suite claim is SUPERSEDED by DIA-136
> F2 - the suite file is now un-gitignored and tracked.

1. **Worktree husky-shim gap (S1, feature/dia134-shim 644c3a1):**
   `scripts/worktrees.sh create` now materializes the `.husky/_` shim in each
   new worktree (copied from the main tree, real directory not symlink);
   pre-commit + `scripts/verify-pre-commit.sh` now fire on worktree commits.
   Bats T17-T19 cover it (materialize / fail-loud when main tree lacks
   .husky/\_ / directory-not-symlink).
2. **Test persistence (S2, feature/dia134-tests f810db5 + 7a96fab):** the
   plugin/config behavioral suite lives as a persistent, gitignored file
   `scripts/__tests__/batch-d-infra.test.mjs` (43 tests, plain node ESM, zero
   npm deps) and is wired into `make test-config` via Makefile, so
   RED/GREEN/merge-verify always re-run the SAME file. Suite file GITIGNORED
   per design.md DD2 (not carried by git; see deferrals). SUPERSEDED by
   DIA-136 F2 (2026-08-14): file un-gitignored and now tracked (ADR 10
   supersedes ADR 9). .gitignore rule
   added; .sdd/dev-infra/architecture.md ADR 9 (persistent behavioral suite
   gitignored by design) + DD1 ADR.
3. **Branch-ownership in batch D payloads (S3, feature/dia134-prompts
   2a8ea4f + 9339b54):** `coder_append.md` worktree-confinement directive
   extended with the explicit branch model — "worktree base = <shared sha>";
   "sibling branches own other slices' files"; "edit ONLY your assigned
   files"; "disjoint file sets"; payloads "name the owned files" per slice
   (5 required phrases, asserted by suite S3 AC 3.1).
4. **Ticket-ID token in dispatch/resume prompts (S4, feature/dia134-process
   b732713 + fb7c0c4):** orchestrator_append.md R1 + AGENTS.md section 2.3
   codify that EVERY dispatch AND resume prompt MUST carry the literal ticket
   ID; DIA-063 gate blocks prompts without it.
5. **Architector design persistence (S4):** orchestrator_append.md R2 +
   AGENTS.md section 2.3: after each @architector design dispatch, persist the
   design text into the DIA ticket (or a .sdd draft) before implementation, so
   reviewers can diff verbatim claims.
6. **Merge-gate container evidence (S4):** orchestrator_append.md R3 +
   AGENTS.md section 2.3 tail: the merge phase may start only with recorded
   `docker compose ps` output showing the dev service Up, committed into the
   merge report; session log must record container state before merge
   dispatch. This ticket's own close-out satisfied it (poetry-dev Up,
   evidence in the S5 merge session).

Process: TDD RED-GREEN per worktree; two-axis reviews closed; ai-auditor
independent audit APPROVE; combined review MERGE-READY; merged via 4
serialized squash-merges (05c75fe S1, aec1bd3 S2, 6a35466 S3, 510e60b S4);
husky pre-commit hook PASSED on every merge commit (no --no-verify, DIA-094
docker gate respected — poetry-dev Up at merge time).

Post-merge verification (2026-08-14, exit codes all 0):

- `TEST_ROOT=/workspace node scripts/__tests__/batch-d-infra.test.mjs`:
  43/43 PASS, exit 0.
- bats over scripts/**tests**: 240 ok incl. T17-T19, exit 0.
- `bash .opencode/scripts/validate-opencode-config.sh`: exit 0.
- `bash scripts/validate-agent-names.sh`: 24 passed, 0 failed, exit 0.
- Lockstep greps green: 'two coders' 0 in oh-my-opencode-slim.jsonc +
  orchestrator_append.md; architector in batch A in all 3 presets + A1;
  batch D clause present (3 presets); R1/R2/R3 phrases in
  orchestrator_append.md + AGENTS.md; 5 branch-ownership phrases in
  coder_append.md.

Accepted deferrals:

- Suite file `scripts/__tests__/batch-d-infra.test.mjs` is gitignored per
  design.md DD2; on fresh clones / worktrees it must be copied from the S2
  worktree (`.worktrees/feature-dia134-tests/scripts/__tests__/`) when
  re-materializing — `make test-config` will fail on main until copied.
  SUPERSEDED by DIA-136 F2 (2026-08-14): file un-gitignored and now tracked -
  fresh clones get it via git; this deferral no longer applies.

## Re-verify

> To be filled at re-verify time.
