# DIA-153 - Push omo-slim-changes to origin: lineage reconciliation (rebase) + SSH transport setup (openssh-client in opencode-docker, origin remote to SSH)

<!-- NOTE ON NUMBERING: the developer directive requested id DIA-140, but
     DIA-140 is already allocated to a CLOSED ticket
     (DIA-140-task-parallelization-analysis.md). To avoid a duplicate-ID
     collision in the ledger, this ticket takes the next free number,
     DIA-153. See the renumbering precedent DIA-115 -> DIA-139 (duplicate-ID
     collision resolution, developer decision). -->

---

id: DIA-153
title: "Push omo-slim-changes to origin: lineage reconciliation (rebase) + SSH transport setup (openssh-client in opencode-docker, origin remote to SSH)"
area: dev-infra
severity: Major
status: OPEN
blocked_by: []
discovered: 2026-08-14
source: developer-directive ("ok, teper mozhna pushyty zminy na rimoout, sprobuy" (transliterated Ukrainian, 2026-08-14))
date: 2026-08-14
created: 2026-08-14
updated: 2026-08-14

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_ffeec4d88ffex9115da44X2wDd"
lane_id: "cod-lane"
agent: "coder"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-153-push-omo-slim-changes-to-origin.md", "docs/dev-infra-audit/tickets/README.md"]
artifacts: []
evidence: []

---

## Description

DIA-179 (full test-suite audit, F1-F7; was DIA-139 before the phase-1 renumber) is
DONE and its work is committed locally on omo-slim-changes (5 squash-merges + merge
report + closure commits). The developer ordered a push to origin. The push is
blocked by two independent blockers:

1. Lineage divergence: origin/omo-slim-changes (2fa1672) is NOT an ancestor of local
   HEAD. Lineage reconciliation via interactive rebase is in progress (38-step todo,
   stopped at step 6/38 with the conflict resolved; needs "git rebase --continue").
2. No GitHub credentials in the environment: no gh CLI, no ssh binary inside the
   opencode-docker image, and the host git exec-path is broken. The developer chose
   the SSH-agent-forwarding path (DIA-173, was DIA-133): openssh-client must be installed in the
   opencode-docker image, the image rebuilt, and the origin remote switched from
   HTTPS to SSH (git@github.com:...). The host agent now has a key loaded
   (ssh-add -l shows an identity).

IMPORTANT container note: coder lanes run inside the opencode-docker podman
container, NOT poetry-dev. poetry-dev needs no ssh. Therefore the ssh setup belongs
in the opencode-docker image only.

## Scope

1. Finish the in-progress rebase: "git rebase --continue" from step 6/38, resolve any
   remaining conflicts, and verify DIA-179 integrity post-rebase.
2. Add openssh-client to tools/opencode-docker/Dockerfile and rebuild the
   opencode-docker image.
3. Switch the origin remote to SSH:
   "git remote set-url origin git@github.com:Tilitronic/poetry-platform.git".
4. Push omo-slim-changes to origin via the DIA-096 safe lane push: the target branch
   is NOT main, no force, no bypass, and the pre-push hook must pass inside the
   container.

### Phase 1 (2026-08-14): DIA-ID collision renumber (docs-lane, remote lineage canonical)

The remote lineage (origin/omo-slim-changes, 2fa1672) is canonical. Local tickets
whose IDs collided with a DIFFERENT remote ticket of the same number were
renumbered to fresh IDs (157+, after remote's 154-156 and this ticket's 153).
Files marked SUPERSEDED duplicate the same work that the remote lineage already
carries at the listed remote ID (renumbered there via bab080c); they were kept
(not deleted) and marked SUPERSEDED. Cross-references to the old IDs were swept
repo-wide (memory shelf, learnings, openspec, knowledge, changelog, tickets).

| Old local ID | New local ID | Disposition                    | Remote ticket it collided with (kept)           |
| ------------ | ------------ | ------------------------------ | ----------------------------------------------- |
| DIA-114      | DIA-157      | SUPERSEDED (dup of remote 138) | DIA-138-agent-instruction-files-audit           |
| DIA-115      | DIA-158      | SUPERSEDED (dup of remote 139) | DIA-139-hook-test-coverage-audit                |
| DIA-116      | DIA-159      | SUPERSEDED (dup of remote 140) | DIA-140-task-parallelization-analysis           |
| DIA-117      | DIA-160      | SUPERSEDED (dup of remote 141) | DIA-141-fix-agent-instruction-findings          |
| DIA-118      | DIA-161      | SUPERSEDED (dup of remote 142) | DIA-142-wire-host-gates-into-hooks              |
| DIA-119      | DIA-162      | SUPERSEDED (dup of remote 143) | DIA-143-batch-dispatch-config-changes           |
| DIA-120      | DIA-163      | SUPERSEDED (dup of remote 144) | DIA-144-batch-aware-a1-plugin                   |
| DIA-121      | DIA-164      | SUPERSEDED (dup of remote 145) | DIA-145-opencode-docker-host-socket-access      |
| DIA-122      | DIA-165      | SUPERSEDED (dup of remote 146) | DIA-146-verify-pre-push-recursion-guard         |
| DIA-123      | DIA-166      | SUPERSEDED (dup of remote 147) | DIA-147-pre-push-suite-failure                  |
| DIA-124      | DIA-167      | SUPERSEDED (dup of remote 148) | DIA-148-test-infra-phase0-safety-wins           |
| DIA-125      | DIA-168      | SUPERSEDED (dup of remote 149) | DIA-149-test-infra-phase1-dedup                 |
| DIA-126      | DIA-169      | SUPERSEDED (dup of remote 150) | DIA-150-test-infra-phase2-critical-gaps         |
| DIA-127      | DIA-170      | SUPERSEDED (dup of remote 151) | DIA-151-test-infra-phase3-orchestrator-contract |
| DIA-131      | DIA-171      | SUPERSEDED (dup of remote 152) | DIA-152-install-docker-cli-poetry-dev-image     |
| DIA-132      | DIA-172      | renumbered (collision)         | DIA-132-coder-escalated-silent-failure          |
| DIA-133      | DIA-173      | renumbered (collision)         | DIA-133-dispatch-routing-benchmark-pricing      |
| DIA-134      | DIA-174      | renumbered (collision)         | DIA-134-overnight-hardening-baseline            |
| DIA-135      | DIA-175      | renumbered (collision)         | DIA-135-research-pipeline-optimization          |
| DIA-136      | DIA-176      | renumbered (collision)         | DIA-136-orchestrator-session-records            |
| DIA-137      | DIA-177      | renumbered (collision)         | DIA-137-orchestrator-routine-work               |
| DIA-138      | DIA-178      | renumbered (collision)         | DIA-138-agent-instruction-files-audit           |
| DIA-139      | DIA-179      | renumbered (collision)         | DIA-139-hook-test-coverage-audit                |

DIA-123 decision: remote DIA-123 = deterministic-restart-detection (title
divergence noted by the developer). Local had BOTH files at 123: the
restart-detection file matches remote (kept at 123); the pre-push-suite-failure
file (different work) collided and was renumbered to DIA-166.

DIA-124-127/131 decision: local test-infra phase files described the same work
as remote's renumbered DIA-148-152, so they were NOT renamed to 148-152 (that
would re-create collisions); they were marked SUPERSEDED and renumbered to
DIA-167-171.

Scope expansion (escalated): the developer's recon collision set was DIA-132-139
plus DIA-123 and DIA-124-127/131. Verified against origin via git ls-tree, the
full collision set also included local campaign files at DIA-114-122
(duplicates of remote DIA-138-146 work). Same principle applied; documented in
this table. Fresh IDs start at 157 (not 154) because remote already carries
DIA-154-156.

## Verification

- Post-rebase: origin/omo-slim-changes is an ancestor of HEAD
  ("git merge-base --is-ancestor origin/omo-slim-changes HEAD" exit 0); DIA-179
  integrity greps and gates pass (batch-d-infra.test.mjs exit 0,
  guards-home-qualt.bats 4 ok).
- Post-ssh-setup: "which ssh" inside opencode-docker resolves; "ssh-add -l" lists
  the host key inside the container.
- Push: "git push origin omo-slim-changes" succeeds (from..to shas on origin);
  pre-push hook gate exit codes recorded.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
