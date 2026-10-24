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

---

## Description

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
