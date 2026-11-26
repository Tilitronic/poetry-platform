# DIA-071 — make test-infra/test-shell exit 2 — host check-host-lsp gate fails

<!-- MERGE NOTE 2026-08-14 (git-sync lane): this ticket absorbed BOTH parallel
     fix streams on omo-slim-changes — (a) the tolerant-gate fix below (warn +
     CHECK_HOST_LSP_STRICT, cod-23) AND (b) the teammate's dev-image gap fixes
     further down (Gap 1: rebuilt poetry-platform-dev for rust-analyzer 1.97.1;
     Gap 2: validate-skills.sh XDG-aware global-skills resolution + warn/skip).
     Frontmatter: status CLOSED (terminal, our closure), severity Major (the
     teammate's documented push-blocker raise). Both verification narratives
     retained. -->

<!-- UPDATE 2026-08-13 (IMPLEMENTED + REVIEWED + RE-VERIFIED - TICKET CLOSED):
     tolerant-gate fix implemented by cod-23 (ses_00346c535ffe9kGhJdUAgIkOve):
     scripts/check-host-lsp.sh now emits warn (exit 0) when a host LSP is
     MISSING (dev container provides all 3 LSPs per DIA-106),
     CHECK_HOST_LSP_STRICT=1 restores the pre-fix hard gate; version DRIFT on a
     present tool, container-path mismatch, and lsp-versions.env defects still
     hard-fail; summary line 'N ok, M fail, W warn, K skip'. Files:
     scripts/check-host-lsp.sh (+36/-14), scripts/__tests__/check-host-lsp.bats
     (9->10 tests incl strict-mode), docs/dev-infra/host-lsp-setup.md
     (+51/-36). Validation: make test-shell exit 0 (252 tests), make
     check-host-lsp exit 0 (3 ok), fresh-host simulation BEFORE exit 1 / AFTER
     exit 0 (3 warn) / AFTER+STRICT exit 1, bash -n clean. Review rev-2
     (ses_003383779ffeFS1TxG81xhrKfw): Standards 2 Minor judgement calls
     (em-dashes repo-consistent; summary-stream divergence vs check-host-jq -
     both ACCEPTED no change), Spec 1 Major (test-infra not run) + 1 Minor
     (STRICT container-path semantics defensible, ACCEPTED). Developer
     disposition 2026-08-13: ACCEPT + run test-infra; minors accepted without
     code change. Re-verify PASSED 2026-08-13 (this lane): make test-infra exit
     0 (252 bats + 6 pytest tests ok) with dev container up. Ticket CLOSED per
     Re-verify convention; commit deferred to end-of-session.

     Discovered 2026-08-08 during DIA-067 verification (lane
     ses_01fd79d07ffe1ALaVr04mIjNnk). PRE-EXISTING — NOT caused by DIA-067:
     scripts/test-docker-smoke.sh `check-host-lsp` fails because
     typescript-language-server/pyright/rust-analyzer are absent from the HOST
     PATH. Zero references to DIA-067-changed files. -->

---

id: DIA-071
title: "make test-infra/test-shell exit 2 — host check-host-lsp gate fails"
area: dev-infra
severity: Major
status: CLOSED
blocked_by: []
discovered: 2026-08-08
source: test-lane
date: 2026-08-08
created: 2026-08-08
updated: 2026-08-13

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_01fd79d07ffe1ALaVr04mIjNnk"
lane_id: ""
agent: "coder"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: ["ses_01fd79d07ffe1ALaVr04mIjNnk (DIA-067 verification lane)"]

---

## Description

`make test-infra` and `make test-shell` exit 2 in this environment because the
host-side `check-host-lsp` gate in `scripts/test-docker-smoke.sh` fails:
`typescript-language-server`, `pyright`, and `rust-analyzer` are absent from
the HOST PATH.

**Pre-existing — NOT a regression of DIA-067:** the failing script has zero
references to DIA-067-changed files (Dockerfile.dev, test-docker-smoke.sh
probes). The smoke test itself passes (`exit 0`); `make test-opencode-docker`
exit 0; bats suite 183/183 ok.

**Impact:** `make test-infra` / `make test-shell` never exit 0 in this
environment → verification gate friction for every dev-infra change (the
DIA-067 lane had to document exit 2 with the pre-existing-cause explanation).

## Verification

- [x] 1. `make test-infra` — exit 2, failing at `check-host-lsp`. (2026-08-08 pre-fix evidence; post-fix exit 0 — see UPDATE.)
- [x] 2. `bash scripts/test-docker-smoke.sh` — exit 0 (smoke itself passes).
- [x] 3. `which typescript-language-server pyright rust-analyzer` — all absent from
     host PATH.
- [x] 4. Post-fix (see Fix direction): `make test-infra` — exit 0. RE-RUN 2026-08-13
     (closure lane, dev container UP per DIA-094): `make test-infra` REAL exit 0 —
     gen-jsconfig ok, test-shell 252/252 bats ok (incl check-host-lsp 3 ok / 0 fail /
     0 warn / 0 skip), docker smoke passed (container LSP probes: all 3 present per
     DIA-106), pytest 2+4=6 passed. Last 5 output lines (final docker-compose down
     of the smoke chain): `Container poetry-postgres Stopped` / `Removing` /
     `Removed` / `Network poetry-platform_poetry-net Removing` / `Removed`.

## Fix

**Fix direction:**

- Install the host LSPs (typescript-language-server, pyright, rust-analyzer) on
  the dev host, OR
- Make `check-host-lsp` tolerant/skippable when host tools are absent
  (documented decision — e.g. warn + skip instead of hard fail when the gate is
  host-tool dependent and the container provides the tooling).

**§10 routing note:** dev-infra change — per project AGENTS.md §2.4, spec for

> 20-line changes; review via @reviewer.

FIX COMPLETE 2026-08-13 (cod-23): tolerant gate with CHECK_HOST_LSP_STRICT=1
escape hatch (Option 1, ticket Fix direction #2). See top UPDATE.

## Re-verify

RE-VERIFY PASS 2026-08-13: make test-shell exit 0 (252), make check-host-lsp
exit 0, make test-infra exit 0 (see top UPDATE).

1. `make test-infra` — exit 0.
2. `make test-shell` — exit 0.

---

## Update 2026-08-12 (DIA-145 verification)

Re-checked the current state of this ticket during DIA-145 verification by
running `make test-config && make test-shell` INSIDE poetry-dev. The original
host-PATH gap is still live, plus a second gate gap was found. Both now block
EVERY pre-push because DIA-142 wired `make test-shell` into the pre-push hook
(commit 9ac204f). Severity raised Low -> Major (push-blocker).

### Current gap (1): check-host-lsp rust-analyzer version mismatch

`make test-shell` fails inside poetry-dev:

```
fail: rust-analyzer - 1.83.0 on PATH, expected 1.97.1. Run scripts/install-host-lsp.sh
```

The poetry-platform-dev image ships rust-analyzer 1.83.0, but the Makefile
gate (via scripts/install-host-lsp.sh) expects 1.97.1.

### Current gap (2): validate-skills.sh cannot find global skills dir

`make test-config` fails inside poetry-dev:

```
error: global skills directory not found: /home/dev/.config/opencode/skills
```

poetry-dev's HOME is /home/dev; the global skills dir the validator expects
does not exist there (it exists in the opencode-docker container at
/app/.config/opencode/skills).

### Fix directions (decision points)

1. **rust-analyzer pin alignment** - decide: (a) update the Makefile /
   scripts/install-host-lsp.sh expectation to match the image's shipped
   1.83.0, or (b) bump the rust-analyzer toolchain in the dev image build and
   rebuild poetry-platform-dev. Recommend (a) - update the gate expectation to
   match the shipped image - unless the 1.97.1 pin exists for a documented
   reason.
2. **Canonical global skills dir** - decide the single canonical location for
   the global skills directory and either make validate-skills.sh resolve it
   consistently (e.g. respect XDG_CONFIG_HOME / the container's own path), or
   provision /home/dev/.config/opencode/skills in the dev image. Recommend
   making the validator resolve the canonical location rather than patching
   the image, so host and container behavior stay in sync.

Both fixes are dev-infra changes; per project AGENTS.md section 2.4, spec and
review via the standard chain.

---

## Fix applied 2026-08-12 (coder lane, DIA-063 ticket gate)

### Gap 1 - rust-analyzer pin mismatch: gate was RIGHT, image was STALE

Root cause: NOT a pin drift. `scripts/lsp-versions.env:6` pins
`RUST_ANALYZER_VERSION=1.97.1` and `Dockerfile.dev:44` (ARG
`RUST_ANALYZER_VERSION=1.97.1`) + `Dockerfile.dev:205-207` provision 1.97.1 on
its own rustup toolchain with a `/usr/local/bin/rust-analyzer` wrapper — the
intentional DIA-106 design (a986481, closed+approved). The RUNNING
`poetry-platform-dev:latest` image was built 2026-08-11 14:08, BEFORE a986481,
so it shipped only the rustup shim of the 1.83.0 default toolchain
(`which rust-analyzer` = /opt/rust/cargo/bin/rust-analyzer, version 1.83.0,
no wrapper). Inside poetry-dev the container-first probe cannot run anyway
(no docker socket in the dev service, docker-compose.yml:29-78), so
check-host-lsp.sh fell back to the host-PATH probe, which correctly reported
the drift: `fail: rust-analyzer - 1.83.0 on PATH, expected 1.97.1`.

Fix: rebuilt `poetry-platform-dev:latest` from the current Dockerfile.dev
(`docker build`, exit 0; compose Bake path unavailable without the buildx
CLI plugin and /app is read-only in the opencode container) and recreated
poetry-dev. Recreation needed a transient compose override pinning bind
sources to daemon-host-absolute paths (`/tmp/opencode/docker-compose.override.yml`,
derived from `docker inspect poetry-dev`; the base file's `./secrets` paths
resolve against the CLI container, not the host). New image verified:
`rust-analyzer --version` = 1.97.1 via /usr/local/bin wrapper. NO repo-file
change was needed or made for Gap 1 — downgrading the pin to 1.83.0 would
have reverted the approved DIA-106 decision and inverted the gate's drift
detection (the honest fix is the image, which the gate told us to rebuild).

### Gap 2 - validate-skills.sh global skills dir: contract too strict for poetry-dev

Root cause: `.opencode/scripts/validate-skills.sh:385`
`GLOBAL_SKILLS_ROOT="${GLOBAL_SKILLS_ROOT:-$HOME/.config/opencode/skills}"`
(HOME-derived) and `:392-395` exited 2 INFRA when the dir was absent (DIA-052
contract). poetry-dev legitimately has NO global skills dir anywhere
(HOME=/home/dev; only opencode-docker ships one at /app/.config/opencode/skills;
Dockerfile.dev does not provision one) — so the dup-detection hygiene tier
could never run there and the exit-2 false-classified the environment as
broken, blocking test-config.

Fix (`.opencode/scripts/validate-skills.sh`):

1. Resolution now XDG-aware: `GLOBAL_SKILLS_ROOT="${GLOBAL_SKILLS_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode/skills}"` (canonical opencode location).
2. Absent global dir -> `warn:` + skip the DIA-052 dup tier (exit 0), instead of exit 2. The global tree is OPTIONAL input for a hygiene check; its absence cannot invalidate the DIA-037 project-frontmatter core. The tier's own `has_skill_dirs` guard already tolerated a missing root; only the explicit guard was too strict. sha256sum stays exit-2 ONLY when the tier actually runs.
3. Header/contract comments updated; `scripts/__tests__/validate-skills.bats:486-493` test rewritten to assert warn + exit 0.

### Follow-up found while verifying: verify-pre-commit/verify-pre-push bats tests were non-hermetic inside poetry-dev

`make test-shell` HUNG (previously it failed fast at check-host-lsp, masking
this): those bats tests run the real `scripts/verify-pre-*.sh` with only
`docker` mocked, but inside poetry-dev the REAL hostname IS `poetry-dev`, so
`is_in_dev_container` (verify-pre-commit.sh:24 / verify-pre-push.sh:26)
flipped to the direct-execution path and recursively ran the real gate chain
(unbounded). Once Gap 1 was fixed, the recursion engaged.

Fix: fake `hostname` (echoes "host-machine") in the setup() of both
`verify-pre-commit.bats` and `verify-pre-push.bats` so host-context tests
take the delegation path with the recording fake docker (their header
contract: "never touching a real container"); the dedicated
"runs ... directly when already inside the dev container" tests shadow the
fake with their own poetry-dev hostname. Also added the missing temp
`~/.bash_profile` re-prepend to the pre-commit direct test (mirror of the
proven verify-pre-push pattern — Debian /etc/profile drops the fake bindir
from `bash -lc` PATH otherwise).

### Verification evidence (all INSIDE poetry-dev, current image)

- `make test-config` -> EXIT 0 (test-skills: 24 passed, 0 failed, 39 warnings; all other validators green).
- `make test-shell` -> EXIT 0. check-pin-sync 4 ok; check-host-jq 1 ok;
  check-host-lsp 3 ok / 0 fail (`ok: rust-analyzer 1.97.1 (host, version
matches scripts/lsp-versions.env)`); bats suite 195 ok, 0 not-ok
  (incl. rewritten validate-skills missing-global-dir test + all 16
  verify-pre-commit/verify-pre-push tests green).
- `bash scripts/verify-pre-push.sh` -> EXIT 0: all 6 steps pass
  (make test-shell, make test-config, pnpm verify:format, verify:js
  (7 tasks successful), verify:js-tests, verify:python (4 passed + 4 passed)).
  "== poetry-platform pre-push: verification passed ==".
- DIA-052 dup tier still runs when the global dir EXISTS (opencode-docker
  context, HOME=/app): covered by the bats fixtures (byte-exact/near-dup
  tests still green).
- Files changed (git diff): `.opencode/scripts/validate-skills.sh`,
  `scripts/__tests__/validate-skills.bats`,
  `scripts/__tests__/verify-pre-commit.bats`,
  `scripts/__tests__/verify-pre-push.bats`, this ticket.

### Open questions / notes

- The dev image rebuild was executed from this lane (daemon network OK).
  Any FUTURE Dockerfile.dev change still requires the standard host-side
  rebuild; the gate remains the drift signal.
- The transient compose override lives in /tmp (NOT committed); plain
  `make up` on the host needs no override.
- DIA-052's documented "missing global dir -> exit 2" contract (archived
  openspec + DIA-052 ticket) is superseded by the warn+skip change above;
  the DIA-071 coder lane made this call per developer direction in the
  ticket's Fix directions - reviewer re-verify per AGENTS.md section 2.3.1
  remains.
