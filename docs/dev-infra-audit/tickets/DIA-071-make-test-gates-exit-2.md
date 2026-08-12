# DIA-071 — make test-infra/test-shell exit 2 — host check-host-lsp gate fails

<!-- Discovered 2026-08-08 during DIA-067 verification (lane
     ses_01fd79d07ffe1ALaVr04mIjNnk). PRE-EXISTING — NOT caused by DIA-067:
     scripts/test-docker-smoke.sh `check-host-lsp` fails because
     typescript-language-server/pyright/rust-analyzer are absent from the HOST
     PATH. Zero references to DIA-067-changed files. -->

---

id: DIA-071
title: "make test-infra/test-shell exit 2 — host check-host-lsp gate fails"
area: dev-infra
severity: Major
status: OPEN
blocked_by: []
discovered: 2026-08-08
source: test-lane
date: 2026-08-08
created: 2026-08-08
updated: 2026-08-12

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

1. `make test-infra` — exit 2, failing at `check-host-lsp`.
2. `bash scripts/test-docker-smoke.sh` — exit 0 (smoke itself passes).
3. `which typescript-language-server pyright rust-analyzer` — all absent from
   host PATH.
4. Post-fix (see Fix direction): `make test-infra` — exit 0.

## Fix

**Fix direction:**

- Install the host LSPs (typescript-language-server, pyright, rust-analyzer) on
  the dev host, OR
- Make `check-host-lsp` tolerant/skippable when host tools are absent
  (documented decision — e.g. warn + skip instead of hard fail when the gate is
  host-tool dependent and the container provides the tooling).

**§10 routing note:** dev-infra change — per project AGENTS.md §2.4, spec for

> 20-line changes; review via @reviewer.

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

1. `make test-infra` — exit 0.
2. `make test-shell` — exit 0.

---

## Update 2026-08-12 (DIA-121 verification)

Re-checked the current state of this ticket during DIA-121 verification by
running `make test-config && make test-shell` INSIDE poetry-dev. The original
host-PATH gap is still live, plus a second gate gap was found. Both now block
EVERY pre-push because DIA-118 wired `make test-shell` into the pre-push hook
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
