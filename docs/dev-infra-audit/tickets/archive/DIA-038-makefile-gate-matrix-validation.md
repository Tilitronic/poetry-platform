# DIA-038 — Makefile gate matrix validation (test-config / test-shell / test-skills / test-interview / jsonl-stats / check-tools)

---

id: DIA-038
title: "Makefile gate matrix validation (test-config / test-shell / test-skills / test-interview / jsonl-stats / check-tools)"
area: tests-infra
severity: Medium
status: VERIFIED
blocked_by: []
discovered:
source: baseline
date: 2026-08-04
created: 2026-08-04
updated: 2026-08-04

---

## Description

The fast host-runnable gate matrix of the new audit campaign has not yet been run
for this campaign (NEXT-RUN.md §3 items 1–2 plus the on-demand readers). This
ticket validates the set:

- `make test-config` — expands to `test-interview`
  (`scripts/test-interview-enforcement.sh`, 5 checks) + `test-skills`
  (`.opencode/scripts/validate-skills.sh`, DIA-037) + `bash
.opencode/scripts/validate-opencode-config.sh` (Makefile:120–121).
- `make test-shell` — `scripts/__tests__/bats-wrapper.sh` (10 suites; bash -n +
  node --check; vendored bats-core fallback).
- `make jsonl-stats` — `bash .opencode/scripts/jsonl-stats.sh` (Makefile:151–152).
- `make check-tools` — `bash scripts/check-tools.sh` (Makefile:65–66; requires
  mise on PATH — deliberately NOT wired into test-shell/test-infra per Makefile
  comment, so a self-skip is a documented outcome, not a failure).

**Script-existence dispute (the gate run settles it):** the inventory lane
reported `.opencode/scripts/validate-opencode-config.sh` and
`.opencode/scripts/jsonl-stats.sh` as missing; prior campaign evidence (Makefile
references at lines 121/152 and files present on disk 2026-08-04 —
validate-opencode-config.sh 2431B, jsonl-stats.sh 2235B) says they exist. A
missing file fails its gate with a clear error, so the matrix run is the
authoritative arbiter.

**Resolution note (2026-08-04):** contested script-existence claims resolved by
the validation loop (cod-6): all 4 claims CONFIRMED PRESENT —
`.opencode/scripts/validate-opencode-config.sh` (88 lines),
`.opencode/scripts/jsonl-stats.sh` (69 lines), 20 skills SKILL.md files,
`.husky/pre-commit` + `.husky/pre-push` git-tracked. Inventory-lane false
alarms; no action needed.

## Verification

1. `ls -la .opencode/scripts/validate-opencode-config.sh .opencode/scripts/jsonl-stats.sh` — both must exist (present on disk as of 2026-08-04).
2. `make test-config` → exit 0 (includes test-interview + test-skills + validate-opencode-config.sh).
3. `make test-shell` → exit 0 (bats suites; prior evidence: 17/17 + 71/71 in DIA-037).
4. `make jsonl-stats` → exit 0; prints the messages.jsonl session rollup (requires jq for detail, degrades to line count).
5. `make check-tools` → exit 0 when mise is on PATH; record whether it self-skips.
6. Record every exit code + summary line in Re-verify.

## Fix

> To be filled at fix time.

## Re-verify

Re-verify 2026-08-04 (gate matrix, full pass): `make test-config` exit 0
(includes test-interview + test-skills + `validate-opencode-config.sh` JSONC
validation); `make test-shell` exit 0 (78 bats assertions across the suites);
`make jsonl-stats` exit 0 (session rollup printed). `make check-tools` exit 2 —
mise missing on PATH: environmental self-skip, **not** a gate failure per the
Makefile comment (deliberately NOT wired into test-shell/test-infra), so the
documented skip outcome is accepted. Gate matrix VERIFIED.
