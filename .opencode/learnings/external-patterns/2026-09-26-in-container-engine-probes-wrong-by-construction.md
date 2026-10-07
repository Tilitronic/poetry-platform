# In-container engine probes are wrong by construction

Date: 2026-09-26
Ticket: DIA-260922-cp0m (re-audit container topology)

## Summary

The AGENTS.md section 6 Docker-gate wording (DIA-094) induces agents to
probe for a docker daemon from INSIDE the dev container. No engine socket
is mounted into the dev service by design, so any such probe fails with
"failed to connect to the docker API at unix:///var/run/docker.sock" and
produces a false blocker. The pre-commit hook does NOT probe a socket:
it detects the container by hostname (scripts/in-container.sh:10-12) and
SKIPS the host gate entirely when inside. The defect is in the prose, not
in the code.

## Verified findings

1. The false premise and its cost. AGENTS.md section 6 (DIA-094 wording,
   currently around lines 198-203) states: "implementation work AND commits
   MUST NOT proceed without a running docker dev container. The pre-commit
   hook HARD-FAILS when the container is down. Never bypass with
   --no-verify or manual host checks." Read from INSIDE the container, this
   induces the agent to probe for a daemon. A coder lane obeyed it, ran a
   docker/compose probe, received "failed to connect to the docker API at
   unix:///var/run/docker.sock ... No such file or directory", and
   correctly stopped -- producing a FALSE BLOCKER that halted a legitimate
   Makefile fix.

2. The hook does NOT probe a socket. scripts/verify-pre-commit.sh:31
   sources scripts/in-container.sh; scripts/in-container.sh:10-12 defines
   is_in_dev_container() as [ "$(hostname)" = "poetry-dev" ];
   docker-compose.yml:40-41 sets container_name/hostname to poetry-dev;
   scripts/verify-pre-commit.sh:63 therefore takes the in-container branch
   and SKIPS the host gate entirely. The socket probe exists only on the
   host path (scripts/container-engine.sh:133), unreachable from inside.
   CONCLUSION: committing from inside the container works today; no live
   bug; the fix required is documentation-only.

3. Prior art proves this already happened. .opencode/memory/lessons.md
   2297-2299 (lesson L20260901-003): a commit-lane dispatch that injected
   a "/var/run/docker.sock + docker info + docker compose ps" gate
   HARD-BLOCKED a legitimate in-container commit; the corrected dispatch
   "succeeded by simply running git commit". The lesson exists yet the rule
   wording keeps inducing the same error -- this is why the wording, not
   the lane, is the defect.

4. Engine neutrality. The code is already engine-neutral:
   scripts/container-engine.sh:11-18 treats docker|podman authoritatively;
   .env.example:31 sets COMPOSE_ENGINE=podman;
   docker-compose.podman.yml exists. Only the AGENTS.md prose says "runs
   inside Docker" (line ~168), which is stale for a Podman host.

5. No engine socket inside the dev container, by design -- so ANY
   in-container daemon probe is wrong by construction, regardless of engine.

6. Brittle content-lock discovered: scripts/__tests__/batch-d-infra.test.mjs
   457 asserts that AGENTS.md literally contains the string "docker compose
   ps". This locks the merge-gate wording (DIA-174 R3) and blocks
   rewording, while asserting no behavior. Developer decision:
   remove/refactor that assertion.

7. Two workflow variants exist and the rule must be DETECTION-BASED, not
   axiomatic: cp0m records a Linux colleague running opencode INSIDE the
   container, and (as of 2026-09-22) the developer running opencode on a
   WSL HOST. The developer now states they run make up -> make opencode
   inside the container via Podman. Correct rule form: determine location
   the way the hook does (hostname == poetry-dev), then: if inside, the
   container is up by construction and no daemon/socket probe is ever
   valid; if on the host, the host-path checks apply. If container status
   is genuinely needed, ASK THE DEVELOPER to run the command on the host
   and paste the output.

## Sources / evidence

- AGENTS.md ~lines 198-203 (DIA-094 Docker-gate wording)
- AGENTS.md ~line 168 ("runs inside Docker")
- AGENTS.md ~line 74 (DIA-174 R3 merge-gate bullet)
- AGENTS.md ~lines 183-189 (gates table)
- scripts/in-container.sh:10-12 (hostname detection)
- scripts/verify-pre-commit.sh:31,63 (sourcing + in-container branch)
- scripts/container-engine.sh:11-18,133 (engine-neutral adapter, host-side socket probe)
- scripts/verify-pre-push.sh:43-44,134,138 (in-container source + delegation)
- docker-compose.yml:40-41 (container_name/hostname)
- .env.example:31 (COMPOSE_ENGINE=podman)
- docker-compose.podman.yml (Podman variant)
- .opencode/memory/lessons.md 2297-2299 (L20260901-003 prior art)
- scripts/__tests__/batch-d-infra.test.mjs:457 (brittle content-lock)
- .husky/pre-push:1-5 (pre-push hook delegates to verify-pre-push.sh)
- .opencode/opencode.jsonc:29 (git push allow), :69-110 (deny overrides)
- .husky/pre-commit (pre-commit hook)

## Implication

The fix set is documentation-only plus one test assertion removal. No
behavioral code changes are needed -- the hooks already detect the
container correctly by hostname. The agent-prose in AGENTS.md section 6
must be rewritten to be detection-based and engine-neutral, and the
brittle "docker compose ps" content assertion in the test must be
refactored.

## Addendum: WSL path completeness, R3 replacement probe, developer decisions (2026-09-26)

### 1. THE WSL IN-CONTAINER PATH IS COMPLETE

Entry points for a Windows/WSL developer, all from the WSL host terminal:

- .devcontainer/devcontainer.json:3-4 (VS Code "Reopen in Container",
  dockerComposeFile=../docker-compose.yml, service=dev)
- `make up && make opencode`
- `make up && make shell`
- `make up && make dev`
- raw `docker compose exec dev ...`

Engine auto-detection covers WSL: scripts/compose-env.sh:64 detects WSL
via /proc/version and appends docker-compose.wsl.yml. No remaining gap
was found; the bare-host opencode path is NOT required for anything.

### 2. THE STALE CLAIM SET (annotated, not rewritten)

The claim "Developer: Windows. Runs opencode on the WSL HOST, never
inside the container" appears at:

- docs/dev-infra-audit/tickets/DIA-260922-cp0m:61 (2026-09-22,
  labelled authoritative at the time)
- .opencode/memory/lessons.md:3135 (lesson L20260922-env-fact)

Both conflate "the developer was using the host path at that moment"
with "the container path is unavailable". The container path is fully
functional on WSL. Current truth: BOTH developers work inside the Poetry
Dev container (developer on Linux+Podman, colleague on Windows+WSL).

### 3. R3 ENFORCEMENT INVENTORY

R3 is enforced ONLY by string-presence assertions that assert no behaviour:

- scripts/__tests__/batch-d-infra.test.mjs:431-432 asserts
  /docker compose ps/ in orchestrator_append
- :434-435 asserts /dev service/
- :437-438 asserts /before merge dispatch/
- :440-441 asserts /session log/
- :457-458 asserts /docker compose ps/ in AGENTS.md

The R3 rule text itself lives at
.opencode/oh-my-opencode-slim/orchestrator_append.md:448-453 and in
AGENTS.md around line 74. So any R3 rewording must update: those two
text files AND those five assertions.

### 4. THE STATUS-QUO DEFECT

R3 is a rule that looks enforced but cannot be satisfied from the most
common execution context -- the worst configuration. The lessons file
already carries an undocumented workaround (.opencode/memory/lessons.md
2531-2561: accept the pre-commit hook exit 0 as implicit evidence the
container is up), which is not in any committed gate text.

### 5. THE R3 REPLACEMENT OPTIONS

(a) keep R3, re-source the evidence to the host (developer runs and
    pastes); loses: nothing, but requires a manual developer step.
(b) replace the `docker compose ps` requirement with an in-container
    readiness/health evidence line (the probe verified in Part 1 of this
    addendum). `docker compose ps` is not runnable from inside the dev
    container at all -- neither the container-engine CLI nor its socket is
    mounted -- so it was never a valid option; the in-container TCP probe
    is the only viable check; loses: nothing.
(c) delete R3 entirely; loses: the original motivation (a merge once
    proceeded without evidence the stack was up, per the DIA-172
    retrospective).

CHOSEN: option (b). The in-container TCP probe is viable (see Part 1
results below). `docker compose ps` is not runnable from inside the dev
container (no engine CLI or socket mounted), so the in-container TCP
probe is the only viable merge-gate evidence: the agent verifies that
postgres is reachable from inside the dev container, proving both the
network path AND the service are up -- no engine socket required.

### 6. DEVELOPER DECISIONS (2026-09-26)

- PUSH RULES STAY AS-IS. Do NOT change AGENTS.md, the git-permissions
  skill, or any permission config for push, and do NOT add a push deny.
  The developer pushes from the host in this session because the agent
  cannot push from inside the container; that is a session practice, not
  a new rule.
- The batch-d-infra.test.mjs assertion that AGENTS.md must literally
  contain "docker compose ps" is MEANINGLESS and must be removed or
  refactored so it asserts no wording.
- The Docker-gate prose must be corrected so an in-container agent never
  probes for a daemon/socket.
- R3 must be either replaced by a mechanism the agent can actually execute
  from inside, or removed.

### 7. PART 1 PROBE RESULTS (in-container readiness probe viability)

Commands run from inside the dev container:

1. `command -v pg_isready` -> exit 1 (NOT PRESENT)
2. `command -v psql` -> exit 1 (NOT PRESENT)
3. DATABASE_URL from docker-compose.yml:62 environment:
   postgresql://poetry:poetry@postgres:5432/poetry
   Host: postgres, Port: 5432
4. `python3 -c "import socket; s=socket.socket(); s.settimeout(3);
   s.connect(('postgres',5432)); print('PORT_OPEN'); s.close()"`
   -> PORT_OPEN, exit 0
5. `node -e "const net=require('net');const s=net.connect(5432,'postgres');
   s.on('connect',()=>{console.log('PORT_OPEN');s.end();process.exit(0)});
   s.on('error',e=>{console.log('ERROR:'+e.message);process.exit(1)});
   setTimeout(()=>{console.log('TIMEOUT');process.exit(1)},3000)"`
   -> PORT_OPEN, exit 0
6. Full postgres protocol handshake via python3: AUTH_REQUEST received,
   postgres is reachable and responding, exit 0.

No engine/compose commands needed. The probe works entirely via TCP
socket -- no daemon socket, no compose binary, no docker binary.

VIABLE COMMAND (recommended, uses only python3 which is in the image):

  python3 -c "import socket; s=socket.socket(); s.settimeout(3);
  s.connect(('postgres',5432)); print('REACHABLE'); s.close()"

VIABLE COMMAND (Node.js alternative):

  node -e "const net=require('net');const s=net.connect(5432,'postgres');
  s.on('connect',()=>{console.log('REACHABLE');s.end();process.exit(0)});
  s.on('error',e=>{process.exit(1)});setTimeout(()=>process.exit(1),3000)"

VERDICT: VIABLE. An in-container readiness probe works with no engine
socket. The exact command above proves postgres reachability from inside
the dev container.

### Addendum 2: R3 replacement design frozen (2026-09-26)

CONSTRAINT from the developer: the R3 replacement must execute IDENTICALLY
from inside a Docker container on WSL and inside a Podman container on
Fedora, must not emit double signals or signals open to different readings
across platforms or across different users of this setup.

WHY THAT HOLDS: the only platform difference is the engine, and the
replacement touches NO engine command; it runs inside the SAME image
(Dockerfile.dev) on both paths. pg_isready and psql are NOT present in
the image at all, so no platform-dependent client can leak in.

DECISION: promote the probe from an ad-hoc command to a VERSIONED script
with a FROZEN contract, because a hand-typed one-liner varies per user and
emits a traceback (a double signal) on failure.

THE FROZEN CONTRACT (verbatim):
  exit 0 => stdout is exactly the single token STACK_READY;
  exit non-zero => stdout is exactly the single token STACK_NOT_READY;
  stderr carries diagnostics only and is NEVER parsed;
  no other exit codes;
  no engine/compose invocation;
  no pg_isready/psql/nc/curl used for readiness;
  the database host and port come from the SAME source the application
    uses (DATABASE_URL), never hardcoded;
  an explicit bounded timeout;
  testable by overriding the connection target so the negative case can
    be exercised without stopping postgres;
  the "not running inside the dev container" case also yields
    STACK_NOT_READY (one case, one signal -- for the merge gate both
    mean "no evidence").

RATIONALE vs the old rule: `docker compose ps` is not runnable from
inside the dev container (neither the engine CLI nor its socket is
mounted), so it must never be prescribed for in-container verification.
The dev container's own liveness is self-evident because the probe
executes inside it. What needs verifying is that the database is
reachable from the container's network namespace -- exactly what the
probe proves.
