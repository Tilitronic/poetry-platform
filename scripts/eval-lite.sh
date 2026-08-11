#!/usr/bin/env bash
# eval-lite.sh -- M5 eval-lite harness (DIA-086 task 6.1).
#
# WHY: a lightweight, host-runnable regression sweep over the curated task
# manifest docs/dev-infra/eval-lite-tasks.md (6-field TSV: ticket-id TAB
# command TAB expected-exit-code TAB source-suite TAB failure-evidence TAB
# container-bound). Each command is a single shell invocation string executed
# serially via `bash -c`; the observed exit code is compared to the expected
# one, failures are reported as FAIL blocks, and a trailing summary line
# reports "N passed, M failed, K skipped".
#
# Container awareness (design.md Decision 7): the dev-container state is
# probed ONCE at harness start via `docker compose ps --format json dev`
# (JSON parsed with host jq) and cached in CONTAINER_UP for the whole run.
# Tasks whose 6th field is `yes` are SKIPPED with a WARN line when the
# container is unavailable and counted in K -- skip-as-pass semantics
# (design.md Decision 6): skips never fail the run. The docker binary is
# resolved from PATH so tests can shadow it with a fake docker stub (same
# pattern as check-host-jq.sh's FAKE_JQ_* mechanism).
#
# Exit-code contract (design.md Seam S5):
#   0  all non-skipped tasks pass (container-bound skips count as pass)
#   1  any non-skipped task fails (FAIL blocks + summary printed)
#   2  manifest file missing (ERROR line, exact wording from task 6.1)
#   3  manifest exists but contains no task lines (only comments / empty)
#
# Stdout-only (locked decision #4, task 6.1 AC6): every harness message goes
# to stdout; task command output is suppressed (>/dev/null 2>&1) so the run
# stays quiet. No --log flag, no persistent results file.
#
# Test seam: EVAL_LITE_MANIFEST overrides the manifest path so bats fixtures
# (task 7.1) can point the harness at synthetic manifests.
#
# NOTE on parsing: the manifest is read raw (IFS= read -r line) so the field
# count can be validated with awk (task 6.1 AC5), then split with the
# prescribed `IFS=$'\t' read -r ticket cmd expected source evidence
# container_bound` form. A 5-field row is accepted as container-bound: no
# for backward compatibility with pre-M5 manifests (task 6.1 AC9).
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${EVAL_LITE_MANIFEST:-${ROOT_DIR}/docs/dev-infra/eval-lite-tasks.md}"

if [ ! -f "${MANIFEST}" ]; then
  echo "ERROR: docs/dev-infra/eval-lite-tasks.md not found. Run the curator script or restore from git."
  exit 2
fi

# --- Container detection (once, cached for the whole run) ------------------
# `docker compose ps --format json dev` emits a single JSON object on
# compose v5 but an array on compose v2; Status starts with "Up" when the
# dev service is running (design.md Decision 7). Any failure (daemon
# unreachable, compose absent, empty output, status not Up) => unavailable.
CONTAINER_UP=no
if container_json="$(docker compose ps --format json dev 2>/dev/null)"; then
  if [ -n "${container_json}" ]; then
    if jq -e 'if type == "array" then (.[0].Status // "" | startswith("Up")) else (.Status // "" | startswith("Up")) end' >/dev/null 2>&1 <<<"${container_json}"; then
      CONTAINER_UP=yes
    fi
  fi
fi

# --- Parse + run -----------------------------------------------------------
passed=0
failed=0
skipped=0
task_count=0
line_no=0

# The manifest is read from dedicated fd 3 (not stdin): every `bash -c`
# child would otherwise inherit the manifest as its stdin and a command
# that reads stdin (e.g. `cat`) would consume manifest lines and starve
# the loop. Child commands additionally get </dev/null (belt + suspenders).
while IFS= read -r line <&3; do
  line_no=$((line_no + 1))
  line="${line%$'\r'}" # tolerate CRLF manifests
  [ -z "${line}" ] && continue
  case "${line}" in \#*) continue ;; esac # comment lines start with #

  # Field-count guard (AC5): a task line must carry 5 or 6 tab-separated
  # fields; anything else is skipped with a WARN and processing continues.
  nfields="$(printf '%s\n' "${line}" | awk -F'\t' '{ print NF }')"
  if [ "${nfields}" -ne 5 ] && [ "${nfields}" -ne 6 ]; then
    echo "WARN: line ${line_no} has ${nfields} fields (expected 5 or 6) -- skipping"
    continue
  fi

  if [ "${nfields}" -eq 5 ]; then
    # Backward compat (AC9): 5-field row (missing 6th) accepted as
    # container-bound: no, with a WARN noting the missing field.
    IFS=$'\t' read -r ticket cmd expected source evidence <<< "${line}"
    container_bound="no"
    echo "WARN: line ${line_no} has 5 fields (missing container-bound field) -- assuming container-bound: no"
  else
    IFS=$'\t' read -r ticket cmd expected source evidence container_bound <<< "${line}"
  fi

  # Defensive: expected-exit-code must be a non-negative integer (manifest
  # AC3). A non-numeric value would make `test -eq` error to stderr, which
  # violates the stdout-only contract -- skip the row with a WARN instead.
  case "${expected}" in
    ''|*[!0-9]*)
      echo "WARN: line ${line_no} has non-numeric expected-exit-code '${expected}' -- skipping"
      continue
      ;;
  esac

  task_count=$((task_count + 1))

  # Container-bound tasks only run when the dev container is up (Decision 7).
  # A missing or non-yes 6th field is treated as host-runnable (no).
  case "${container_bound}" in
    [Yy][Ee][Ss])
      if [ "${CONTAINER_UP}" != "yes" ]; then
        echo "WARN: skipping container-bound task ${ticket} (dev container not running)"
        skipped=$((skipped + 1))
        continue
      fi
      ;;
  esac

  bash -c "${cmd}" </dev/null >/dev/null 2>&1
  observed=$?

  if [ "${observed}" -eq "${expected}" ]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    echo "FAIL: ${ticket}"
    echo "  command: ${cmd}"
    echo "  expected-exit: ${expected}"
    echo "  observed-exit: ${observed}"
    echo "  source-suite: ${source}"
    echo "  failure-evidence: ${evidence}"
  fi
done 3< "${MANIFEST}"

if [ "${task_count}" -eq 0 ]; then
  echo "ERROR: docs/dev-infra/eval-lite-tasks.md contains no task lines (only comments or empty) -- nothing to run"
  exit 3
fi

echo "${passed} passed, ${failed} failed, ${skipped} skipped"

if [ "${failed}" -gt 0 ]; then
  exit 1
fi
exit 0
