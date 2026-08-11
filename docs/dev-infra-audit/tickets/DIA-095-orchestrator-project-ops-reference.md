# DIA-095 - Orchestrator needs an optimized project-ops reference - how to run the project, bring up docker, required gates

<!-- Campaign c-20260809-residual-closure, session 6. Filed by the coder lane
     per the developer directive (2026-08-11): "Analyze the dev infrastructure
     well and create a ticket to give the ORCHESTRATOR a reference on how the
     project works, how to run it, how to bring up docker, and all that. We
     already have this in a special file, but maybe the orchestrator needs an
     optimized version." The orchestrator is read-restricted and CANNOT read
     the existing setup docs (docs/docker-dev.md, CONTAINER-SETUP.md,
     docs/onboarding.md, architecture.md, Makefile, docker-compose.yml, most
     of docs/), so the project-ops knowledge must be surfaced in a readable
     or prompt-injected location. Related: DIA-094 (docker gate - work must
     not start without docker up), DIA-063 (ticket gate), DIA-080
     (orchestrator stops - setup knowledge reduces guesswork).
     Status: OPEN, needs fix. -->

---

id: DIA-095
title: "Orchestrator needs an optimized project-ops reference - how to run the project, bring up docker, required gates"
area: dev-infra/opencode-config
severity: Major
status: OPEN
blocked_by: [] # cross-referenced in Description: DIA-094, DIA-063, DIA-080
discovered: 2026-08-11
source: developer-directive
date: 2026-08-11
created: 2026-08-11
updated: 2026-08-11

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_00f8e7d76ffeMoY9eKTE4tb7J1"
lane_id: "coder"
agent: "coder"
model: "deepseek-v4-flash"
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-095-orchestrator-project-ops-reference.md", "docs/dev-infra-audit/tickets/README.md"]
artifacts: []
evidence: ["orchestrator read permission block (opencode.jsonc: read allows only .opencode/session/*, docs/dev-infra-audit/NEXT-RUN.md, docs/dev-infra-audit/tickets/*, docs/dev-infra-audit/tickets/archive/*, .opencode/practice-protected.md, AGENTS.md)", "existing setup docs: docs/docker-dev.md (primary), CONTAINER-SETUP.md (superseded), docs/onboarding.md (onboarding), architecture.md (design)", "bring-up commands: make up / docker compose up -d; make shell; make dev; make opencode; make test-infra; make test-config; make test-shell"]

---

## Description

**Summary:** the developer directive (2026-08-11) asks for a reference that
gives the ORCHESTRATOR knowledge of how the project works, how to run it, and
how to bring up docker - an optimized version of the existing setup doc
(`docs/docker-dev.md`). The orchestrator's read scope is restricted, so the
existing setup documentation is NOT readable by it. Without the knowledge being
surfaced in a readable or prompt-injected location, the orchestrator cannot
answer basic project-ops questions ("how do I bring up docker?", "which gates
need the container?", "what is the docker-up gate?") and cannot enforce the
DIA-094 rule that work must not start without docker up. Related requirement:
work must NOT start without docker up (ties to DIA-094) - the reference must
include the docker bring-up gate + required pre-work gates.

### Developer directive (2026-08-11)

"Analyze the dev infrastructure well and create a ticket to give the
ORCHESTRATOR a reference on how the project works, how to run it, how to bring
up docker, and all that. We already have this in a special file, but maybe the
orchestrator needs an optimized version."

### Existing setup documentation (Part B findings)

| File                 | Coverage (1-line)                                                                                                                                                                      |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `docs/docker-dev.md` | PRIMARY setup+run doc: dev container + postgres architecture, quick start (`make up`, `make shell`, `make install`, `make dev`), full Makefile target table, secrets, dev image notes. |
| `CONTAINER-SETUP.md` | Older (2026-07-27) container guide, superseded by `docs/docker-dev.md`; retained as minimal base-tools reference (Dockerfile, branch state, OmO-slim test run).                        |
| `docs/onboarding.md` | New-developer onboarding: project overview, quick start (pnpm install/dev/test), AI workflow layers; docker bring-up mentioned only via mise/dev-container notes.                      |
| `architecture.md`    | System design reference (data flow, component boundaries) - not a run/bring-up doc.                                                                                                    |
| `Makefile`           | The actual run/bring-up commands (targets `up`, `shell`, `dev`, `opencode`, `install`, `test-infra`, `test-config`, `test-shell`).                                                     |
| `docker-compose.yml` | Service definitions: `dev` (poetry-dev) + `postgres` (poetry-postgres); header documents `docker compose up -d` usage.                                                                 |
| `CONTEXT.md`         | Domain glossary only - no setup/run knowledge.                                                                                                                                         |

There is NO `README.md` at the repo root. The "special file" the developer
refers to is `docs/docker-dev.md` (with `CONTAINER-SETUP.md` as the older
reference and `Makefile`/`docker-compose.yml` as the executable truth).

### Dev-infra essentials (Part B findings)

**How the stack runs:** `docker compose up -d` (wrapped as `make up`) starts
the full stack: the `dev` workstation container (`poetry-dev` - opencode + OMO
slim, Node 24, Python 3, pnpm, bun, mise, uv, Rust wasm32, Playwright,
crawl4ai; monorepo bind-mounted at `/workspace`; secrets mounted read-only from
`secrets/` into `/run/secrets` via `dev-entrypoint.sh`) plus the `postgres`
service (`poetry-postgres`, postgres:16-alpine, named volume `pgdata`). `make
shell` enters the container, `make dev` runs `pnpm dev` (turbo starts
author-studio only - api-server is Python/uvicorn and publishing-platform has
no dev script), `make opencode` runs opencode inside the container. Tear down
with `make down` (keep data) or `make clean` (wipe volumes). First run: `cp
.env.example .env` then `make up`.

**What the dev container provides:** a single toolchain container holding the
full dev stack (runtimes, package managers, browser automation under Xvfb) and
the gates that run inside it: husky pre-commit lint-staged autofix
(`scripts/verify-pre-commit.sh` container path), the Python pytest suites
(`make test-python` via `docker compose exec dev`), and the heavy Docker smoke
test (`scripts/test-docker-smoke.sh`). Config/shell gates that do NOT need the
container: `make test-config` (validate-opencode-config.sh, validate-skills,
validate-agent-names, validate-handoff, test-ticket-gate, agent-tool-coverage
audit) and `make test-shell` (bats with docker mocked, plus check-pin-sync /
check-host-jq / check-host-lsp / check-opencode-docker).

**Gates that depend on the container:** (1) husky pre-commit ->
`scripts/verify-pre-commit.sh` -> `docker compose exec dev npx lint-staged`
(container path; HARD-FAILS when container is down - DIA-094); (2) `make
test-infra` (requires a running Docker daemon; builds + smoke tests the stack,
then runs `test-python` inside the container); (3) `make test-python` (runs
pytest inside the dev container); (4) `make dev` / `make install` / `make
opencode` / `make shell` (all `docker compose` invocations).

**Orchestrator read-scope interaction:** the orchestrator's `read` permission
block (opencode.jsonc) allows ONLY `.opencode/session/*`,
`docs/dev-infra-audit/NEXT-RUN.md`, `docs/dev-infra-audit/tickets/*` (+
archive), `.opencode/practice-protected.md`, and `AGENTS.md` - everything else
is deny. It CANNOT read `docs/docker-dev.md`, `CONTAINER-SETUP.md`,
`docs/onboarding.md`, `architecture.md`, `Makefile`, `docker-compose.yml`,
`dev-entrypoint.sh`, or most of `docs/`. Project-ops knowledge must therefore
be surfaced in one of the readable locations (AGENTS.md, NEXT-RUN.md) or in a
new rule file referenced by the orchestrator operating rules.

### Impact

- The orchestrator boots cold with no project-ops knowledge: it cannot tell
  the developer (or a delegated lane) how to bring up docker, what the
  container provides, or which gates require the container.
- Without an explicit docker bring-up gate in its readable knowledge, the
  orchestrator cannot enforce the DIA-094 rule that implementation work AND
  commits must not proceed without a running docker dev container - the exact
  failure class (work done without the full toolchain) the developer called
  "categorically wrong" on 2026-08-11.
- Every session that needs docker guidance currently requires the developer to
  repeat the bring-up commands manually - setup knowledge reduces guesswork
  and orchestrator stops (DIA-080).

### Related tickets

- **DIA-094** - husky pre-commit docker gate: work must NOT start / commits
  must NOT land without a running docker dev container; this reference must
  carry that bring-up gate.
- **DIA-063** - ticket-creation gate: no engineering work starts without a DIA
  ticket; this ticket satisfies that gate for the reference work.
- **DIA-080** - orchestrator halts/stops mid-work repeatedly: setup knowledge
  in a readable location reduces the guesswork that contributes to stops.

## Verification

- Reproduce the gap: from the orchestrator's readable set alone (AGENTS.md,
  NEXT-RUN.md, `.opencode/practice-protected.md`, `.opencode/session/*`,
  `docs/dev-infra-audit/tickets/*`), confirm there is NO mention of the docker
  bring-up commands (`make up` / `docker compose up -d`), the container's role,
  or the docker-required gate. A cold orchestrator session cannot answer "how
  do I bring up docker?".
- Confirm the permission boundary: opencode.jsonc orchestrator `read` block
  allows only the paths listed above; `docs/docker-dev.md` and `Makefile` are
  NOT readable.
- After fix: a fresh orchestrator session, using only its readable files, can
  state (a) the docker bring-up commands (`cp .env.example .env`, `make up` /
  `docker compose up -d`), (b) the container-provided gates (pre-commit
  lint-staged, test-python, test-infra), (c) the host-runnable gates
  (test-config, test-shell), and (d) the rule that implementation work and
  commits MUST NOT proceed without a running docker dev container (DIA-094).

## Fix

> To be filled at fix time. Proposed options (from the coder lane, 2026-08-11):

### Option A - Add a compact "Project Ops Quick Reference" section to AGENTS.md (project)

Add a short section (bring-up commands, container role, container-dependent vs
host-runnable gates, docker-required rule) to the project `AGENTS.md`. AGENTS.md
is already in the orchestrator's read scope AND is injected into orchestrator
prompts, so the knowledge arrives with zero extra boot steps.

- Pros: highest visibility - the orchestrator always has it; no new files;
  also helps every other agent and the developer; single place to keep current.
- Cons: AGENTS.md grows (must stay compact); edits to AGENTS.md are
  OpenCode-config-adjacent and route through the Section 10 (S10)/ai-specialist
  workflow if they touch operating rules.

### Option B - Create `.opencode/rules/project-ops.md` referenced by the orchestrator operating rules

A dedicated rule file that the orchestrator operating rules (AGENTS.md / the
OMO orchestrator prompt append) tell the orchestrator to read on boot.

- Pros: keeps AGENTS.md lean; the reference lives in one focused file with a
  stable path; explicit read step makes the knowledge auditable.
- Cons: requires the orchestrator to actually read it (boot-step dependency -
  if the read step is forgotten, the knowledge is invisible again); new file +
  new reference wiring (config change, S10 route).

### Option C - Add a compact section to docs/dev-infra-audit/NEXT-RUN.md (already orchestrator-readable)

Add the project-ops quick reference to NEXT-RUN.md, which is already in the
orchestrator's read scope and is part of its boot sequence (Section 1 step 3).

- Pros: zero new permissions; the orchestrator already reads this file at
  every boot; low friction.
- Cons: NEXT-RUN.md is campaign-specific operating manual - mixing in
  general project-ops knowledge blurs its purpose; less visible to other
  agents/developers than AGENTS.md.

### Content the reference should carry (from Part B)

- Bring-up: `cp .env.example .env` (first run), `make up` (=
  `docker compose up -d`) - starts `dev` (poetry-dev) + `postgres`
  (poetry-postgres); `make shell` to enter; `make dev` for `pnpm dev` (turbo,
  author-studio only); `make opencode` for opencode in the container; `make
down` / `make clean` to stop.
- Container-provided gates: husky pre-commit lint-staged
  (`scripts/verify-pre-commit.sh` container path - DIA-094), `make test-python`
  (pytest in container), `make test-infra` (needs Docker daemon).
- Host-runnable gates: `make test-config`, `make test-shell` (bats, docker
  mocked).
- Rule: implementation work AND commits MUST NOT proceed without a running
  docker dev container (DIA-094); the pre-commit hook HARD-FAILS when the
  container is down; never work around it with `--no-verify` / manual host
  checks.

### Recommendation

**Option A** (AGENTS.md quick reference) is recommended: AGENTS.md is already
orchestrator-readable AND prompt-injected, so the knowledge is guaranteed to
reach the orchestrator without any new boot-step dependency, and it also helps
every other agent and the developer. Option C (NEXT-RUN.md section) is a cheap
complementary pointer for the campaign context. Option B (dedicated rule file)
is the more structured alternative if AGENTS.md must stay lean, but it adds a
read-step dependency. Whichever option is chosen, the reference MUST include
the docker bring-up gate + required pre-work gates per the developer directive
and the tie to DIA-094.

## Re-verify

> To be filled at re-verify time. Expected: a fresh orchestrator session can
> answer "how do I bring up docker?" and "which gates require the container?"
> using only its readable files, and refuses to start implementation work when
> the dev container is down (DIA-094 docker gate). Record the actual boot/test
> evidence.
