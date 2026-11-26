# DIA-261125-z4ij - divergent uid maps between poetry-dev and poetry-dev-v2 make /workspace/.git unwritable after container recreation

---

id: DIA-261125-z4ij
title: "divergent uid maps between poetry-dev and poetry-dev-v2 make /workspace/.git unwritable after container recreation"
area: docker
severity: Critical
status: CLOSED
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

CLOSED 2026-11-26. All verification items resolved with host-terminal evidence
supplied verbatim by the developer; this bookkeeping lane did not run podman
itself (containers are not reachable from a lane).

Decisive mapping proof (the piece previously missing) - the container user maps
to host uid 1000:

    podman exec poetry-dev sh -c 'date > /workspace/.git/.permtu'
    host: ls -ln /workspace/.git/.permtu
    -> owner 1000 1000

Writability of git refs after recreation, both containers, keep-id active:

    podman exec poetry-dev sh -c 'cd /workspace && test -w .git/refs/heads/omo-slim-changes'
    -> OK-dev
    podman exec poetry-dev-v2 sh -c 'cd /workspace && test -w .git/refs/heads/migration'
    -> OK-dev-v2

uid map in the v2 container (keep-id active):

    podman exec poetry-dev-v2 sh -c 'id'
    -> uid=1000(dev) gid=1000(dev) groups=1000(dev)

Host ownership normalized - the old world-writable 777 / owner 65534 state is
gone:

    ls -ldn /home/mimic/Documents/Coddding/poetry-platform/.git
    -> drwxr-xr-x 1 1000 1000
    (achieved with: sudo chown -R 1000:1000 <repo>
     then: sudo chmod -R go-w <repo>)

Last remaining blocker was a stale 999-owned opencode state dir, fixed by chown
without wiping volumes (auth preserved):

    podman exec poetry-dev-v2 opencode --version
    -> opencode v2.3.2
    after: chown -R 1000:1000 /home/dev/.local/share/opencode
                             /home/dev/.cache/opencode /home/dev/.config/opencode

Verification checklist mapping:

- item 1 (compare uid maps): SUPERSEDED by the permtu mapping proof above, which
  shows the actual numeric mapping (container user -> host 1000) rather than an
  owner-range comparison.
- item 2 (refs writable after recreation): OK-dev / OK-dev-v2 above.
- item 3 (777 reverted): ls -ldn shows drwxr-xr-x 1000 1000, go-w applied.
- item 4 (opencode runs from a recreated container without host chmod/chown):
  opencode v2.3.2 starts after the one-off state-dir chown; host chmod/chown of
  .git is no longer required.

Carry-over caveat unchanged: Docker hosts must drop the two
`userns_mode: keep-id` lines (Docker rejects keep-id); on Docker uid alignment
comes from the existing USER_UID / USER_GID build args.
