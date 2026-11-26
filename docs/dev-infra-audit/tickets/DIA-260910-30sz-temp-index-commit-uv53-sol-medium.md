# DIA-260910-30sz - temp-index-commit-uv53-sol-medium

---

id: DIA-260910-30sz
title: "temp-index-commit-uv53-sol-medium"
area: config
severity: Low
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-10
source: inventory
date: 2026-09-10
created: 2026-09-10
updated: 2026-09-10

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

Follow-up of closed DIA-260909-uv53 Sol Medium set. Commit the uv53 hunks
(registry + learnings + ticket + changelog) via isolated temp index
(GIT_INDEX_FILE), leaving the real index untouched.

Context:

- cod-4 isolation path verified
- cod-5 empty result noted
- partial result at .opencode/session/partial-results/ses_f75cdec0effe257dnENoxV6Csu.json

## Verification

- [ ] Temp-index commit created from uv53 hunks only
- [ ] Real index confirmed untouched (git status clean except intended)
- [ ] New commit SHA recorded as evidence

## Fix

2026-09-10 attempt: commit BLOCKED by repo-wide pre-commit hook failure.
No commit created. Escalated to orchestrator. Staged set fully verified
and reproducible from the worktree; real index restored to clean pre-state.

Verified uv53-only staged set (6 paths, 341 insertions, 2 deletions):

- knowledge/model-registry.yaml (12+ Sol entry, 0 sazr refs)
- .opencode/oh-my-opencode-slim.jsonc (2+/2- ai-auditor swap, uv53-only)
- .opencode/CHANGELOG.yaml (18+ two uv53 entries, 0 added sazr lines)
- .opencode/CHANGELOG.md (12+ two uv53 sections, 0 added sazr lines)
- docs/dev-infra-audit/tickets/DIA-260909-uv53-\*.md (new, 118 lines)
- .opencode/learnings/external-patterns/2026-09-09-dia-260909-uv53-ai-auditor-sol-medium.md (new, 179 lines)
  Temp index (db6abca-based) preserved at /tmp/uv53-index with identical content.

Root cause: lint-staged backup step runs `git stash store`, which fails with
`error: update_ref failed for ref 'refs/stash': cannot update the ref
'refs/stash': unable to append to '.git/logs/refs/stash': Permission denied`.
Both .git/refs/stash and .git/logs/refs/stash are owned root:root (created
2026-09-10 07:32, same window as the db6abca sazr commit); lane user is
dev (uid 1000). Every commit with staged changes fails the same way
(2 attempts: temp-index path and real-index path, identical hook error).
Hook failure is content-independent (tasks SKIPPED, failure in git plumbing).

Remediation (needs host/root): chown the two stash files to dev:dev
(or confirm stash@{0} 663d72e orphaned and recreate them), then:
git add <6 paths above> && git commit with message
"DIA-260909-uv53: ai-auditor swap to openai/gpt-5.6-sol medium
(isolated uv53-only commit)". Do NOT use --no-verify.

Note: sibling sazr lane landed db6abca mid-task; temp index was rebuilt
from db6abca. Pre-existing stash@{0} (663d72e, 91qy-era) left untouched.

## Re-verify

2026-09-10 retry RESULT: COMMITTED as a4e54a3 (amended from e86b5fb,
same message; amend folded the concurrent uv53-close CLOSED-status
fixup for the learnings file so the commit is self-consistent with
the committed ticket Closure section).

- Commit stat = 6 files, 342 insertions, 2 deletions (uv53-only).
- Added-lines grep for sazr = 0 (sazr strings in CHANGELOG hunks are
  context lines only, not additions).
- Hooks enabled (no --no-verify): lint-staged autofix passed twice;
  stash backup/restore worked after host chown fix.
- Real index clean post-amend (git diff --cached empty); worktree
  shows only other lanes' unstaged mods (memory x3, README) plus
  untracked files; stash list unchanged (pre-existing 663d72e only).
- HEAD chain: a4e54a3 on top of db6abca (HEAD unmoved since snapshot,
  no temp-index rebuild needed).

Verification commands (all in /workspace):

- git show --stat HEAD -> 6 files, 342+/2-
- git show HEAD | grep "^+" | grep -v "^+++" | grep -ci sazr -> 0
- git diff --cached --stat -> empty
- git stash list -> stash@{0} lint-staged backup (663d72e) only

## Closure

2026-09-10 close lane: commit a4e54a3 landed and verified.

- Commit: a4e54a3 "DIA-260909-uv53: ai-auditor swap to openai/gpt-5.6-sol medium (isolated uv53-only commit)"
- Stat: 6 files changed, 342 insertions, 2 deletions, uv53-only (added-lines sazr grep = 0).
- Hooks: passed with hooks enabled (no --no-verify); lint-staged autofix passed twice.
- Real index: clean post-commit (git diff --cached empty).
- Source: cod-8 session ses_f75b6f0b1ffeWW8RFRlN3eZowF.

Lesson (stash-perms): repo-wide pre-commit hook failed at `git stash store`
with `update_ref failed for ref refs/stash: Permission denied` because
.git/refs/stash and .git/logs/refs/stash were root-owned (created in the
db6abca sazr commit window). Fix was host/root chown of those two files to
dev:dev. Future lanes hitting identical hook-stage stash errors on any
staged content should check stash ref file ownership before retrying.
