# DIA-261125-z4ij - divergent uid maps between poetry-dev and poetry-dev-v2 make /workspace/.git unwritable after container recreation

---

id: DIA-261125-z4ij
title: "divergent uid maps between poetry-dev and poetry-dev-v2 make /workspace/.git unwritable after container recreation"
area: docker
severity: Critical
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-11-25
source: inventory
date: 2026-11-25
created: 2026-11-25
updated: 2026-11-26

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
evidence:

- commit:d62b576

---

## Description

After container recreation `/workspace/.git` becomes unwritable for the session
uid, so every git write fails (observed as `index.lock` permission-denied, with
no lock file ever created). This is the SECOND occurrence (2026-11-25).

Evidence:

- `poetry-dev` renders a host-root-owned `.git` as `nobody:nogroup`:
  `drwxrwxrwx. 1 nobody nogroup ... /workspace/.git`, and `stat -c '%u:%g %a'`
  returns `65534:65534 777`.
- `poetry-dev` and `poetry-dev-v2` have DIVERGENT uid maps, so the same numeric
  owner renders differently in each container; the owner name shown is not a
  reliable gate.
- A `chown` to `dev:dev` inside either container does NOT produce a writable
  `.git` for the session uid: after that chown the pre-flight `test -w
/workspace/.git` still returned `NOT-WRITABLE`, and two dispatch runs were
  blocked with zero writes.

Current workaround (host, temporary): `sudo chmod -R a+rwX /workspace/.git`.
This makes `.git` world-writable, so it MUST be reverted with
`sudo chmod -R go-w /workspace/.git` once a durable fix exists.

Durable fix direction (not decided here): align the two containers' uid maps, or
pin the repo owner to an identity that both maps resolve for the session uid.

## Verification

- [ ] Capture and compare both uid maps (`/proc/self/uid_map` in each container)
      and show the owner-range difference that makes one container see `999`
      and the other see `nobody:nogroup` for the same inode.
- [ ] After recreation WITHOUT the workaround, `sh -c 'test -w /workspace/.git
  && echo WRITABLE || echo NOT-WRITABLE'` prints `WRITABLE` for the
      session uid.
- [ ] `stat -c '%a' /workspace/.git` is not `777`, and `chmod -R go-w` has been
      applied to revert the workaround.
- [ ] A `git commit` from a freshly recreated container succeeds with no host
      chmod or chown.

## Fix

Compose half PREPARED at d62b576: both `dev` and `dev-v2` now set
`userns_mode: keep-id` (podman-only; Docker does NOT accept keep-id). This maps
the container uid to the host user so both containers agree on file ownership
and `/workspace/.git` refs stay writable after recreation.

Remaining host-side steps (run on the HOST, not from a lane; this lane cannot
recreate containers):

1. Recreate BOTH containers so the compose setting applies, e.g.
   `docker compose --profile v2 up -d --force-recreate dev dev-v2`
   (podman-compose equivalent is fine).
2. From EACH container (poetry-dev and poetry-dev-v2), confirm a git write
   succeeds: `sh -c 'test -w /workspace/.git && echo WRITABLE || echo
NOT-WRITABLE'` must print WRITABLE.
3. Revert the temporary workaround:
   `sudo chmod -R go-w /home/mimic/Documents/Coddding/poetry-platform/.git`
   then confirm `sh -c 'test -w /workspace/.git'` still passes (exit 0).
4. Docker hosts must drop the two `userns_mode: keep-id` lines (Docker rejects
   keep-id); on Docker the uid alignment comes from the existing USER_UID /
   USER_GID build args instead.

## Re-verify

> To be filled at re-verify time.
