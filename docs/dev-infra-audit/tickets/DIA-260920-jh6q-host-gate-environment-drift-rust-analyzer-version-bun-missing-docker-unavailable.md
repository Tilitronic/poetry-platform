# DIA-260920-jh6q - host gate environment drift rust-analyzer version bun missing docker unavailable

---

id: DIA-260920-jh6q
title: "host gate environment drift rust-analyzer version bun missing docker unavailable"
area: scripts
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-20
source: inventory
date: 2026-09-20
created: 2026-09-20
updated: 2026-09-20

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

- ses_f415d413effe7YigrfBage4aCp: bun verdict - bun does NOT ship with opencode (package.json pnpm only, no volta pin; Dockerfile.dev bun is container-side); host bun REQUIRED (Makefile:54/70 host-side, verify-pre-push.sh:163-164 host-local). Root cause was PATH drift: bun 1.4.0 binary pre-existed at ~/.bun/bin but on no shell init path. Fixed via guarded PATH block in ~/.bashrc + ~/.profile (user-space, no sudo). Samples: registry 4/4, verify-pre-push 16/16, preset 9/9.
- ses_f41006023ffemXsV7w2oS0XMP1: residual 193/194 root cause - compose-overrides setup() never isolates CWD so launcher preflight scans live repo secrets/ (4x 644: anthropic/exa/github/openai; context7 600 ok); 323 root cause - WSL2 host appends wsl overlay so exact 2-file config assertion fails; launcher correct, assertion host-wrong.
- ses_f40fcd2d8ffepO9gu461uT1AtA: applied +8 compose-overrides setup fixture (cd tmpdir, secrets/api.key 600) +1 mock_grep_os native in opencode-dev #5; suites 15/15 and 14/14; live secrets untouched.
- ses_f40f4ff0fffebS7PpeNujhCbSS: full wrapper 717/717 exit 0, make test-shell exit 0 (container rust-analyzer 1.97.1 covers host 1.83.0 drift; yaml-ls warn only). Host rust-analyzer drift + bun 1.4.0 vs container 1.3.14 pin noted.
- Reviewer two-axis ABORTED per developer decision after 3 envelope refusals; record abort.
- Spurious cod-12/cod-16/cod-17 user rejected permission denials: developer confirmed they rejected nothing; system-side denials, recovered via fresh lanes.
- Recommend: close jh6q after developer confirms (all suites green), or keep OPEN for host rust-analyzer pin-sync + bun version sync follow-ups.
- .opencode/memory/lessons.md L20260920-2w0o-001 (drift-vs-regression classification; names this ticket as the drift tracker)
- scripts/check-host-lsp.sh:115-135 (container-first rust-analyzer probe, DIA-106; host 1.83.0 was the observed drift)
- scripts/lsp-versions.env (RUST_ANALYZER_VERSION=1.97.1, the pin install/check compare against)
- .mise.toml:13 + Dockerfile.dev:35 (bun = "1.4.2" pins vs host bun 1.4.0 observed in ses_f40f4ff0fffebS7PpeNujhCbSS)
- Makefile:258 (compose config validation is host-scoped, so a host without docker fails it by design)

---

## Description

Close the residual host-gate environment drift (host rust-analyzer version,
host bun version/PATH, docker availability expectations) after the PATH and
test-fixture failures were remediated.

## Problem

- Host gates failed for environment reasons, not code: `make test-shell`
  failed at `check-host-lsp` because host rust-analyzer was 1.83.0 while
  `scripts/lsp-versions.env` pins `RUST_ANALYZER_VERSION=1.97.1`; host bun
  was missing from PATH although host-local targets require it
  (`scripts/verify-pre-push.sh:169-170` runs `bun test` host-side,
  `Makefile:105` checks `.mise.toml` bun parity); docker CLI was absent so
  `make test-config` hard-failed at compose config. Evidence rows in this
  ticket's frontmatter (`ses_f40f4ff0fffebS7PpeNujhCbSS`, `ses_f415d413effe7YigrfBage4aCp`)
  and lesson `.opencode/memory/lessons.md:3101` ("host-side gate FAILs ...
  are environment drift, not regressions").
- Partially remediated: bun PATH guard added in `~/.bashrc` + `~/.profile`
  (`ses_f415d413effe7YigrfBage4aCp`), compose-overrides fixture made hermetic
  (`ses_f40fcd2d8ffepO9gu461uT1AtA`, suites 15/15 and 14/14), wrapper
  717/717 exit 0 recorded (`ses_f40f4ff0fffebS7PpeNujhCbSS`).
- Residual drift still open per the same row: host rust-analyzer not synced
  to the pin (mitigated but not fixed: `scripts/check-host-lsp.sh:115-135`
  now probes THROUGH the container, DIA-106) and host bun 1.4.0 vs the
  1.4.2 pins (`.mise.toml:13`, `Dockerfile.dev:35`).

## Verification

- [ ] `bash scripts/install-host-lsp.sh` reports rust-analyzer at
      `RUST_ANALYZER_VERSION` (or the container-first probe is accepted as
      the permanent posture, recorded here)
- [ ] `command -v bun && bun --version` on the host matches the 1.4.2 pin,
      or the accepted drift is recorded with a `ponytail:` note
- [ ] `make test-shell` exit 0 on the host; the docker-absent expectation for
      `check-compose-config` documented (Makefile:258 already scopes it
      host-side)
- [ ] Full bats wrapper green (baseline: 717/717 exit 0)

## Fix

Sync the host tools to the repo pins: `bash scripts/install-host-lsp.sh`
(installs rust-analyzer at `scripts/lsp-versions.env` value), align host bun
with `.mise.toml:13` (`bun = "1.4.2"`), and record in this ticket which
gates legitimately require docker on the host vs which are container-side.
Touch: host environment (user-space), this ticket; no repo code change
unless a version pin is deliberately bumped.

## Re-verify

```bash
bash scripts/check-host-lsp.sh          # exit 0 (container-first probe passes)
command -v bun && bun --version         # on PATH, matches .mise.toml 1.4.2 or documented drift
make test-shell                         # exit 0 on host
grep -n "rust-analyzer\|bun\|docker" docs/dev-infra-audit/tickets/DIA-260920-jh6q-*.md
                                        # dispositions recorded
```
