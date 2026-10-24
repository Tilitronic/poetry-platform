#!/usr/bin/env bash
# Logging wrapper for `make test-infra` (DIA-260927-vmpa, review FIX 1 + FIX 3).
#
# Usage: bash scripts/test-infra-log.sh <log-file> <command> [args...]
#
# Truncates <log-file>, runs <command>, mirrors its stdout and stderr into
# <log-file> while keeping this script's own stdout/stderr streams separate
# (one tee per stream - the console output stays identical to a bare run),
# appends the trailer line "==> test-infra exit code: N", and exits N.
# N is the COMMAND's exit status - never tee's.
#
# WHY the wrapper lives here instead of inline in the recipe: the exit-code
# guarantee used to rest on `set -o pipefail` running in whatever /bin/sh
# the Makefile happened to get. That is not a guarantee: a /bin/sh without
# pipefail (dash < 0.5.12) either dies at `set -o pipefail` before any of
# this runs (the log is never rewritten, so readers see the previous run's
# possibly-green file) or - shells that treat the bad option as non-fatal -
# continues with pipefail unset, where `rc=$?` reads the OUTER tee's status
# (0) and a FAILED run is logged as a green `exit code: 0`. Pinning the
# interpreter at the call site (`bash scripts/test-infra-log.sh ...`) makes
# the exit-code carry an explicit property of THIS script, not a property
# of the host's /bin/sh. The guard below fails loud if anyone ever invokes
# it through a non-bash shell anyway (shebang is bypassed by `sh script`).
[ -n "${BASH_VERSION:-}" ] || { echo "test-infra-log.sh: bash required" >&2; exit 2; }
set -o pipefail

if [ $# -lt 2 ]; then
  echo "usage: test-infra-log.sh <log-file> <command> [args...]" >&2
  exit 2
fi
log=$1
shift

mkdir -p "$(dirname "$log")" || exit 1
: >"$log" || exit 1 # truncate: every run starts a fresh log, never appends

# fd dance (structure unchanged from the inline recipe, DIA-260927-vmpa):
# the inner command's stdout goes to the outer tee (console stdout + log),
# its stderr to the inner tee (console stderr + log); pipefail carries the
# inner status past both tees into $rc. Inner tee gets 3>&- so it does not
# inherit - and therefore not hold open - the outer tee's pipe (review FIX 3
# fd-3 leak: as the tee's fd 3 was a write end of that pipe, outer-tee EOF
# waited on the inner tee instead of on the wrapped command).
{ { "$@"; } 2>&1 1>&3 3>&- | tee -a "$log" 3>&- >&2; } 3>&1 | tee -a "$log"
rc=$?
echo "==> test-infra exit code: $rc" | tee -a "$log"
exit $rc
