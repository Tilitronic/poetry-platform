# DIA-260926-kksa - shell script standards: documented convention + shellcheck/shfmt adoption

---

id: DIA-260926-kksa
title: "shell script standards: documented convention + shellcheck/shfmt adoption"
area: scripts
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-26
source: inventory
date: 2026-09-26
created: 2026-09-26
updated: 2026-09-26

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

### Problem

- No documented shell-script standard exists anywhere (AGENTS.md, docs/, .sdd/).
- shellcheck and shfmt are not installed, not configured, and not run anywhere.
- The only shell gate is `bash -n` (syntax only), wired via scripts/**tests**/bats-wrapper.sh (line 116) and the lint-staged "\*.sh" entry. It CANNOT catch a missing -u, a missing -o pipefail, or a bad shebang.

### Evidence (two read-only audits, same session)

Strict mode across 59 project scripts: 48 full `set -euo pipefail` (81%), 3 partial (5%), 8 none (14%). All 8 omissions are justified and classified:

- sourced helpers: scripts/in-container.sh, scripts/guards/home-qualt.sh
- husky one-line delegators: .husky/pre-commit, .husky/pre-push, .husky/commit-msg
- profile snippets that must tolerate missing paths: scripts/dev-git-turbo-profile.sh, scripts/dev-secrets-profile.sh
- bats :load helper: scripts/**tests**/test-helper.bash
- documented soft-failure harness: scripts/eval-lite.sh (line 39, comment at lines 44-46)
- intentionally -e-less scanners WITHOUT an explanatory comment: scripts/check-budget-gate.sh (line 35), scripts/check-secrets-ownership.sh (line 13)
  Shebang hygiene is clean: 49 scripts use #!/usr/bin/env bash, 3 use #!/usr/bin/env sh (delegators that invoke bash explicitly - safe), bats files use #!/usr/bin/env bats. No sh-shebang-plus-bash-syntax bug.

Trap/cleanup audit: only 8 trap statements exist, all EXIT-only (temp file/dir cleanup and docker teardown). Zero ERR traps and zero INT/TERM traps - correct, because no script needs them, and an ERR trap without `set -e` would be dead code. The one real cleanup gap - the Makefile test-infra recipe (lines 175-178) can leave the compose stack up when test-python fails - is ALREADY tracked by DIA-260827-wawy. Do not duplicate that here.

### Proposed scope

1. Document the standard (a "Shell Script Standards" section in AGENTS.md, or docs/shell-standards.md): every new standalone shell script uses `set -euo pipefail` on the line after the shebang; explicit exemptions are sourced helpers, bats files, and husky one-line delegators; ANY other exception must carry a comment explaining why.
2. Adopt shellcheck: add a repository config, wire it into the shell lint path (lint-staged "\*.sh" and/or a dedicated make target), and agree a severity policy.
3. Decide on shfmt: adopt for formatting, or explicitly record the decision to decline.
4. Add the two missing explanatory comments (scripts/check-budget-gate.sh:35, scripts/check-secrets-ownership.sh:13).
5. Make the gate actually catch a missing -u, a missing -o pipefail, and a bad shebang.
6. Document the trap/cleanup convention: a script that allocates a managed resource must free it via an EXIT trap; ERR is NOT used for cleanup (an ERR trap only fires under set -e, and EXIT already covers that path, so it would be dead code); INT/TERM traps only when an action must run at signal time. Record the verified counterpart: the repo currently has exactly 8 traps, all EXIT-only, and zero ERR/INT/TERM traps, which is correct; the single genuine cleanup gap is the Makefile test-infra recipe (lines 175-178), already owned by DIA-260827-wawy.

### Relations

- Related OPEN ticket: DIA-260827-wawy (heavy infra cleanup not guaranteed after test failure) - related, not duplicated.
- No OPEN ticket covers shell standards, shellcheck, or shfmt.

## Verification

- [ ] The standard is documented and discoverable.
- [ ] shellcheck runs in the shell gate with the agreed policy; a deliberately non-strict scratch script FAILS the gate (RED proof).
- [ ] The two missing explanatory comments are added (scripts/check-budget-gate.sh:35, scripts/check-secrets-ownership.sh:13).
- [ ] Existing gates stay green (test-shell, test-config).
- [ ] The Makefile compose-teardown gap is explicitly NOT addressed here (owned by DIA-260827-wawy).
- [ ] The trap/cleanup convention is documented, plus a detection path for a missing EXIT trap.

## Fix

> To be completed when the fix is implemented.

## Re-verify

> To be filled at re-verify time.
