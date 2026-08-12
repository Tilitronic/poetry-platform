# DIA-118 - scripts/worktrees.sh missing executable bit - direct invocation fails exit 126

<!-- Filed from session observation (S17, restart-verify smoke-test lane,
     2026-08-12). Observed while re-running the DIA-117 restart-verify smoke
     test: `scripts/worktrees.sh` direct invocation fails with exit 126
     (Permission denied) because the file lacks the executable bit. The
     established invocation `bash scripts/worktrees.sh` works (matches
     worktrees.bats usage), so all DIA-117 check results were unaffected.
     Planning ticket only - no implementation performed. -->

---

id: DIA-118
title: "scripts/worktrees.sh missing executable bit - direct invocation fails exit 126"
area: dev-infra
severity: Low
status: FIXED
blocked_by: [] # no blockers
discovered: 2026-08-12
source: session-observation (S17, restart-verify smoke-test lane, 2026-08-12)
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-12 (fixed)

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_00a01b8b1ffe5t0J9OnsRbo9Zm"
lane_id: ""
agent: "coder"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-118-worktrees-sh-missing-executable-bit.md"]
artifacts: []
evidence: []

---

## Description

The script `scripts/worktrees.sh` lacks the executable bit. Direct invocation
`scripts/worktrees.sh` fails with exit 126 (Permission denied). The established
invocation is `bash scripts/worktrees.sh`, which matches `worktrees.bats` usage
(`make test-shell` runs the suite via bash and passes 16/16).

Observed during the DIA-117 restart-verify smoke test (2026-08-12): all check
results were unaffected because the script was invoked via `bash`. The defect
is a footgun, not an active failure - a lane or developer following the
conventional `scripts/worktrees.sh <cmd>` syntax on a fresh clone gets exit 126
with no helpful message.

Candidate fix: `chmod +x scripts/worktrees.sh` and update any docs referencing
direct invocation; verify with `make test-shell` (worktrees.bats) - but confirm
no bats test or doc depends on the non-executable state before flipping the bit
(e.g., a test asserting the file is NOT executable, or a doc deliberately
showing the `bash` prefix).

**Reference files:** `scripts/worktrees.sh` (mode check - `ls -l`); any docs
showing direct invocation (grep for `scripts/worktrees.sh` in `docs/` and
`.opencode/skills/`).

## Verification

- Reproduce the defect: from the repo root run `scripts/worktrees.sh` directly
  and confirm exit 126 (Permission denied).
- Confirm the working path: `bash scripts/worktrees.sh` runs (e.g. `bash
scripts/worktrees.sh list` or `--help`).
- Confirm no test or doc depends on the non-executable state (grep
  `worktrees.bats` and docs for mode/executable assertions).
- After fix:
  1. `scripts/worktrees.sh` direct invocation runs (exit 0 for a no-op/help
     command).
  2. `make test-shell` worktrees.bats still 16/16.

## Fix

Fixed 2026-08-12 (implementation lane).

- **Mode before:** `-rw-r--r--` (100644) - no executable bit, direct invocation
  failed with exit 126 (Permission denied). Confirmed.
- **Mode after:** `-rwxr-xr-x` (100755) - `chmod +x scripts/worktrees.sh`.
- **Index recording:** repo-local `core.filemode=false` means git ignores
  filesystem mode changes; recorded the executable bit in the index explicitly
  with `git update-index --chmod=+x scripts/worktrees.sh` so the fix survives
  checkout/clone (plain `git add` would have silently dropped it).
- **Direct invocation after fix:** `scripts/worktrees.sh --help` runs (exit 2,
  usage - same as the established `bash`-prefix path); `scripts/worktrees.sh
list` exits 0 and lists the real worktree. No more exit 126.
- **No doc/test depended on the non-executable state:** worktrees.bats invokes
  via `bash` (still valid); no `test ! -x` or mode assertion on worktrees.sh
  exists. Docs (`worktree-conventions.md`, `.opencode/skills/`) all show the
  bash-prefix invocation, which remains valid, so no doc edits were needed.
  OpenSpec DIA-100 artifacts already spec the file as "executable", so this fix
  fulfills the spec.
- **worktrees.bats:** 16/16 (T1-T16) pass. Full `make test-shell`: 209/209
  pass, overall exit 0 (the DIA-119 pnpm sandbox failure did not manifest in
  this run).
- **Docker gate (DIA-094):** `poetry-dev` container Up 17 hours (healthy);
  pre-commit hook passed (container running).
- **Commit:** b26eaac (fix commit, mode change recorded in index).

## Re-verify

> To be filled at re-verify time.
