# DIA-260824-a3mk - make opencode fails: PermissionDenied opening /home/dev/.local/share/opencode/log/opencode.log

<!-- UPDATE 2026-08-24 (REGISTRATION - pre-implementation registration lane for
     DIA-260824-a3mk; NO implementation edits to Dockerfile.dev /
     dev-entrypoint.sh / Makefile / compose files per task scope):
     GRILLING-GATE APPLICATION (DIA-104): the privilege-model change in this
     ticket is cross-cutting (touches container lifecycle, entrypoint, Makefile,
     compose) and hard-to-reverse (uid/gid + chown strategy is expensive to
     redo), so it triggers the grilling gate. The developer grilling interview
     CONFIRMED the privilege-model decision:
       - root-owned log evidence: the opencode.log path / parent dirs are owned
         by a different uid/gid than the runtime dev user (image build as root or
         prior root run); the append open fails on that mismatch.
       - narrow state chown: chown ONLY /home/dev/.local/share/opencode and its
         log/ subdir to the dev uid/gid - NOT the whole home tree.
       - root entrypoint then gosu dev: entrypoint runs as root only long enough
         to chown state, then drops to dev via gosu; no persistent root.
       - no compose service user: do NOT set a `user:` field in compose; drop
         privilege in the entrypoint instead.
       - Makefile --user dev: `make opencode` already execs as --user dev;
         confirmed correct, keep.
       - Podman keep-id verification requirement: under Podman the host uid maps
         via keep-id; the chown/entrypoint strategy MUST be verified under Podman
         (not only Docker) before merge.
       - Q4 correction: an earlier Q4 audit note implying a compose `user:`
         field was acceptable is wrong - entrypoint drop only.
     This ticket's gate markers are set (gate_state: grilled; gate_triggers:
     [cross-cutting, hard-to-reverse]) to record the confirmed grill. Findings
     registered in
     .opencode/learnings/external-patterns/2026-08-24-opencode-log-ownership-root-preflight.md
     (ai-specialist read-only research, DIA-260824-a3mk gate step). -->

---

id: DIA-260824-a3mk
title: "make opencode fails: PermissionDenied opening /home/dev/.local/share/opencode/log/opencode.log"
area: docker
severity: Blocker
status: OPEN
blocked_by: [DIA-260823-v9di, DIA-260822-oldn] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "grilled" # grilled | waived | bypassed | partial | skipped
gate_triggers: ["cross-cutting", "hard-to-reverse"] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers:

- waiver: podman-keep-id-verification
  reason: "developer sign-off 2026-08-25"
  evidence: "Docker-only acceptance passed; risk accepted"
  gate_override: "" # free-text: developer signal + reason; empty = no override
  discovered: 2026-08-24
  source: fix-lane
  date: 2026-08-24
  created: 2026-08-24
  updated: 2026-08-25

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

`make opencode` (runs OpenCode inside the `poetry-dev` container as the `dev`
user) fails to start because OpenCode cannot open its log file:

    PermissionDenied opening /home/dev/.local/share/opencode/log/opencode.log

This blocks OpenCode restart and therefore blocks the config smoke
verification step of the OpenCode Configuration Changes workflow
(AGENTS.md 2.5 step 5). The dev container is required by the Docker gate
(DIA-094) for any implementation work, so this is a hard blocker on the
config-change path.

### Observed reproduction

1. Host: `make up` brings up `poetry-dev` + `poetry-postgres`.
2. Host: `make opencode` execs OpenCode inside `poetry-dev` as the `dev`
   user (see `Makefile` `opencode` target / `dev-entrypoint.sh`).
3. OpenCode attempts to open `/home/dev/.local/share/opencode/log/opencode.log`
   for append and aborts with `PermissionDenied`.
4. OpenCode does not start; config smoke verification cannot run.

Root cause hypothesis (to confirm in scope): the log file or one of its
parent directories (`/home/dev/.local/share/opencode/log/`) is owned by a
different uid/gid (e.g. created during image build as root, or by a prior
run as root) than the runtime `dev` user, so the append open fails. The
directory tree may be created lazily by OpenCode at first run, or pre-created
by the image/entrypoint as root.

### Scope (trace file ownership / creation across container lifecycle)

- Identify every point that creates `/home/dev/.local/share/opencode/` or its
  `log/` subdir or `opencode.log`:
  - Dockerfile.dev (image build, root context)
  - dev-entrypoint.sh (container start, may run as root before dropping to dev)
  - OpenCode's own first-run directory creation (runtime, dev user)
  - Volume mounts / bind mounts that may carry root-owned content from host
- Determine the effective uid/gid of the `dev` user vs the owner of the
  log path at each stage.
- Fix: ensure the log path is owned by / writable by the `dev` user before
  OpenCode opens it (entrypoint chown, or let OpenCode create it as dev, or
  mount a writable location). Minimal, root-cause fix at the shared creation
  point, not a per-invocation sudo.

### Non-goals

- Do NOT change OpenCode application logic or the log format.
- Do NOT change the Docker gate (DIA-094) or the config-change workflow.
- Do NOT add a new dependency or a wrapper service to manage the log file.
- Do NOT change which user runs OpenCode (stays `dev`).
- Do NOT touch unrelated container files; scope is strictly the log path
  ownership/creation across the container lifecycle.

### Relation to blocked tickets

- Blocks `DIA-260823-v9di`: the OpenCode config change cannot be smoke-verified
  because `make opencode` will not start until this log permission issue is
  resolved.
- Related to `DIA-260822-oldn`: same container-lifecycle / file-ownership class
  of defect; this ticket isolates the specific OpenCode log-path blocker so the
  config-change work can proceed once fixed.

## Verification

- [x] `make up` brings up `poetry-dev` cleanly (no permission errors at start). (evidence: `docker compose ps` shows poetry-dev Up)
- [x] `make opencode` starts OpenCode inside `poetry-dev` as the `dev` user
      without any `PermissionDenied` on `opencode.log`. (evidence: runtime acceptance: `opencode --version` as dev exits 0, no PermissionDenied)
- [x] OpenCode writes to `/home/dev/.local/share/opencode/log/opencode.log`
      successfully (log file is created/appendable under the `dev` user). (evidence: log dir owned dev:dev; opencode ran as dev uid 1000)
- [x] `ls -ld` of the log path and its parents shows ownership matching the
      runtime `dev` uid/gid (or is confirmed world/group-writable by design). (evidence: `/home/dev/.local/share/opencode/log` is dev:dev)
- [ ] A fresh container (clean volume) reproduces the fix: first `make opencode`
      after `make clean && make up` starts and logs safely. _(merge-gate: deferred — requires fresh-volume rebuild)_
- [x] Config smoke verification (AGENTS.md 2.5 step 5) can now run to
      completion, unblocking `DIA-260823-v9di`. (evidence: supported launch repaired ownership to dev:dev and ran as dev; `opencode --version` via launch exited 0)

## Fix

Self-healing launch remediation (developer-selected option). Root cause: any
`opencode` run as root re-owns `/home/dev/.local/share/opencode/log/opencode.log`,
defeating a one-shot start chown; `docker compose exec` bypasses the entrypoint
so the chown never re-applies to exec sessions.

- Dockerfile.dev: removed `USER` directive (entrypoint starts as root); added
  `gosu`; HEALTHCHECK now runs as dev (`CMD gosu dev opencode --version ...`) for
  defense-in-depth.
- dev-entrypoint.sh: before every command, if root, `chown -R dev:dev
/home/dev/.local/share/opencode` then `exec gosu dev "$@"` (runuser/su
  fallback). Self-heals a root-owned log on each launch.
- Makefile `opencode` target: routes through the entrypoint as root
  (`docker compose exec -it --user root dev /usr/local/bin/dev-entrypoint.sh
opencode`) so the chown runs, then drops to dev. Other targets keep
  `--user dev`.
- scripts/opencode-dev: opencode mode routes through the entrypoint as root
  (self-healing); bash/test modes use `--user dev`.
- scripts/dev-stack.sh: added `--user dev` to its `docker compose exec` calls.
- docker-compose.wsl.yml: retains `dev: {}` (defensive scaffold; already applied).
- Tests: scripts/**tests**/opencode-launch-routing.bats (static guard: no root
  opencode launcher outside the entrypoint self-heal); WSL merge-presence
  regression already in scripts/**tests**/compose-overrides.bats.

## Re-verify

Lane verification (DIA-260824-a3mk fix loop, self-healing launch):

- `bash -n` on dev-entrypoint.sh, scripts/opencode-dev, scripts/dev-stack.sh: pass.
- Static guard (opencode-launch-routing): no root opencode launcher outside
  entrypoint self-heal — pass (GUARD_EXIT=0).
- WSL merge regression (compose-overrides.bats logic): `docker compose config`
  of base+rootless-docker+wsl retains `dev` service — pass.
- OpenSpec validate dia-260824-opencode-log-permission-fix: valid.
- Docker behavioral acceptance (running poetry-dev, new entrypoint cp'd in):
  re-owned log as root:root, then the supported launch (entrypoint as root)
  repaired ownership to dev:dev and ran the command as dev (uid 1000);
  `opencode --version` via the supported launch exited 0 with no
  PermissionDenied. Healthcheck command `gosu dev opencode --version` exited 0.
- OPENAI/GITHUB env: unset (no secret values exposed).

Outstanding (merge-gate, not in this lane): full `docker compose build dev`

- restart; rootless Podman keep-id verification (no Podman in lane); fresh-volume
  `make clean && make up && make opencode` (waived: podman-keep-id-verification, developer sign-off 2026-08-25).
