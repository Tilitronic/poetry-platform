#!/usr/bin/env bash
# data-reduce.sh - run a reduction over a large blob and print the RLM
# savings line (DIA-181).
#
# WHY this exists: agents must never paste a multi-hundred-KB blob into the
# model context. The data-reducer skill (RLM pattern) reduces the blob in a
# worker process first; this script is the measurement layer that runs the
# reduction and makes the savings visible:
#
#   input N KB -> result M KB (saved P%, ~Q tokens)
#
# Stream contract (the result stream stays PURE - the savings line is
# measurement metadata, not part of the result):
#   stdout - the reduction command's output (the compact result; pipe it on)
#   stderr - the savings line + diagnostics
#   exit   - 0 on success; the reduction command's exit code on failure;
#            2 on usage errors (no input, missing input file, reducer not on
#            the allowlist)
#
# Reducer allowlist (script-layer boundary, DIA-260827-ft3z): the permission
# layer matches only the raw text of this invocation and cannot see the argv
# boundary after `--`, so the script enforces it. The boundary is NAME AND
# FLAGS. Name: CMD's first element must be a bare basename from: jq, rg, wc,
# head, tail, cut, tr, uniq. Slash-qualified names (/bin/cat, ./x, scripts/...)
# and everything else are usage errors (exit 2). `sort` is deliberately
# excluded: its -o flag writes files. Flags: no argv element may be --pre,
# --pre-glob, or start with --pre= / --pre-glob= - ripgrep's preprocessor
# runs an arbitrary program, so name-pinning alone lets
# `rg --pre bash '' x.sh` execute that script (also exit 2).
#
# Reducer-scoped argument rejects (same ticket, same exit 2): uniq rejects ANY
# positional - input always arrives on stdin and the wrapper captures stdout,
# so a positional OUTPUT (`uniq - /path`) is an arbitrary truncate+write
# primitive (the same class of hole that keeps sort out of the allowlist);
# rg rejects -z/--search-zip (they spawn an external decompressor as a child
# process); tail rejects -f/--follow/--follow=* (they never terminate, hanging
# an unattended lane). Scoped per reducer on purpose: cut -f is a legitimate
# field spec and cut -z is --zero-terminated, so no global -f/-z ban.
#
# The token count is the documented heuristic ~4 chars / token (see the
# data-reducer skill) - an estimate for context planning, NOT a billable
# number.
#
# Dependencies: bash + python3 + wc - all present in the dev container and on
# typical hosts. Zero new runtime dependencies.
#
# Not a streaming reducer: the input is fully materialized in $TMPDIR before
# the reduction runs (so input/output bytes are measured on the same
# artifact). For the project's ~100 KB threshold this is harmless; keep the
# helper out of pipelines that need true constant-memory streaming.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: data-reduce.sh INPUT [--] [CMD [ARGS...]]
       data-reduce.sh - [--] [CMD [ARGS...]]        (read stdin)

Run CMD over INPUT (a file path, or '-' for stdin) with the input fed to the
command's stdin. The reduction result is printed to stdout untouched; the
savings line is printed to stderr:

  input N KB -> result M KB (saved P%, ~Q tokens)

With no CMD the default reduction is `wc -lc` (line + byte count).

CMD's first element must be a bare name from the allowlist:
jq, rg, wc, head, tail, cut, tr, uniq
- no slashes (no /bin/cat, no ./x, no scripts/...)
- sort is deliberately excluded (its -o flag writes files)
- no command-executing flags: --pre, --pre-glob, --pre=*, --pre-glob=*
  are rejected (ripgrep runs them as a program)
- reducer-scoped argument rejects: uniq takes NO positional argument (input
  arrives on stdin, output is the wrapper's capture file - a positional
  OUTPUT would truncate+write an arbitrary file); rg rejects -z/--search-zip
  (they spawn an external decompressor); tail rejects -f/--follow/--follow=*
  (they never terminate). Scoped per reducer: cut -f (field spec) and cut -z
  (--zero-terminated) are NOT rejected.
Anything else is a usage error (exit 2).
EOF
}

# --- parse args -----------------------------------------------------------
# INPUT is the first positional arg before `--`; everything after `--` (or
# any later positional arg) is the reduction command. Both `INPUT -- CMD`
# and `INPUT CMD` forms work; `--` is just an explicit separator.
input=""
cmd=()
seen_sep=0
for arg in "$@"; do
  if [ "$seen_sep" = "1" ]; then
    cmd+=("$arg")
  elif [ "$arg" = "--" ]; then
    seen_sep=1
  elif [ -z "$input" ]; then
    input="$arg"
  else
    cmd+=("$arg")
  fi
done

if [ -z "$input" ]; then
  usage
  exit 2
fi

if [ "${#cmd[@]}" -eq 0 ]; then
  cmd=(wc -lc)
fi

# --- reducer command allowlist ---------------------------------------------
# Script-layer boundary (DIA-260827-ft3z): the permission layer matches only
# the raw prefix text of this invocation and cannot see the argv boundary
# after `--`, so the script enforces it here. The first element must be a
# bare basename from the allowlist - no slashes (no /bin/cat, no ./x, no
# scripts/...), no other commands. `sort` is deliberately NOT allowlisted:
# its -o flag writes files. The execution below stays argv-direct (no shell
# is introduced); the entry point AND the flags are pinned.
allowlist="jq rg wc head tail cut tr uniq"
first="${cmd[0]}"
case "$first" in
  */*)
    echo "data-reduce: reducer must be a bare name from the allowlist (no slashes): $first (allowed: $allowlist)" >&2
    exit 2
    ;;
esac
allowed=0
for c in $allowlist; do
  if [ "$c" = "$first" ]; then
    allowed=1
    break
  fi
done
if [ "$allowed" -ne 1 ]; then
  echo "data-reduce: reducer not in allowlist: $first (allowed: $allowlist)" >&2
  exit 2
fi

# --- command-executing flag boundary ----------------------------------------
# A correct NAME is not sufficient: ripgrep's --pre / --pre-glob run an
# arbitrary program as a preprocessor, so `rg --pre bash '' x.sh` passes the
# name pin and executes x.sh. Reject these flags across EVERY allowlisted
# reducer (not only rg) so a future allowlist entry cannot reintroduce the
# same class of hole, and check it before the input is materialized or the
# command runs. Bare --pre-glob alone executes nothing today, but it is
# rejected anyway: it is one half of the same execution vector, and a single
# blanket rule is cheaper than proving intent per invocation.
for a in "${cmd[@]}"; do
  case "$a" in
    --pre|--pre-glob|--pre=*|--pre-glob=*)
      echo "data-reduce: reducer rejected (command-executing flag): $a - --pre/--pre-glob execute an arbitrary command" >&2
      exit 2
      ;;
  esac
done

# --- reducer-scoped argument boundary (DIA-260827-ft3z) -----------------------
# The flag guard above is GLOBAL; these rejects are SCOPED to one named
# reducer each, because the same token is legitimate on a sibling (cut -f is a
# field spec, cut -z is --zero-terminated - a global -f/-z ban would break
# them). Matched as "$first:$a" so the reducer name pins every arm.
#   uniq INPUT [OUTPUT] - input always arrives on stdin and the wrapper
#   captures stdout itself, so BOTH positionals are unwanted; the OUTPUT one
#   (`uniq - /path`) truncates and writes an arbitrary file, defeating the
#   knowledge/* edit scope (the same reason sort -o is out of the allowlist).
#   A lone "-" is a positional (the stdin spelling), not an option.
#   Options (-c/-d/-u) change WHAT is reduced, not where bytes go: allowed.
#   rg -z/--search-zip - spawn an external decompressor (zcat/bzip2/gzip...)
#   as a child process: execution outside the allowlist.
#   tail -f/--follow/--follow=* - never terminate: an unattended lane hangs
#   forever.
# The slice starts AFTER the reducer name: the name itself would otherwise
# match its own "uniq:..." arm and reject a bare, argument-less `uniq`.
for a in "${cmd[@]:1}"; do
  case "$first:$a" in
    uniq:-|uniq:[!-]*)
      echo "data-reduce: reducer rejected (positional argument): $a - uniq takes options only; input arrives on stdin and output is the wrapper's capture file, so a positional INPUT/OUTPUT writes an arbitrary file" >&2
      exit 2
      ;;
    rg:-z|rg:--search-zip)
      echo "data-reduce: reducer rejected (decompressor flag): $a - rg -z/--search-zip spawn an external decompressor" >&2
      exit 2
      ;;
    tail:-f|tail:--follow|tail:--follow=*)
      echo "data-reduce: reducer rejected (follow flag): $a - tail -f/--follow never terminates and would hang the lane" >&2
      exit 2
      ;;
  esac
done

# --- materialize the input ------------------------------------------------
# Both modes copy into a temp file so the byte measurement is identical
# (wc -c on the same artifact) and the reduction command always reads a
# regular file via stdin redirection, never an odd inherited fd.
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
in_file="$workdir/input"
out_file="$workdir/output"
err_file="$workdir/cmd.err"

if [ "$input" = "-" ]; then
  cat > "$in_file"
elif [ ! -f "$input" ]; then
  echo "data-reduce: input not found: $input" >&2
  exit 2
else
  cp "$input" "$in_file"
fi

in_bytes="$(wc -c < "$in_file")"

# --- run the reduction ----------------------------------------------------
set +e
"${cmd[@]}" < "$in_file" > "$out_file" 2> "$err_file"
cmd_status=$?
set -e

if [ "$cmd_status" -ne 0 ]; then
  # Replay the command's stderr so its diagnostics are not lost, then exit
  # with ITS exit code - a failed reduction is not a successful measurement.
  cat "$err_file" >&2 || true
  echo "data-reduce: reduction command failed (exit $cmd_status)" >&2
  exit "$cmd_status"
fi
if [ -s "$err_file" ]; then
  cat "$err_file" >&2
fi

out_bytes="$(wc -c < "$out_file")"

# --- emit the reduction result -------------------------------------------
# The measurement is done; now the result stream (stdout) carries the
# reduction's output exactly as produced - pure and pipeable onward. The
# savings line below already went (and will go) to stderr only.
cat "$out_file"

# --- savings line ---------------------------------------------------------
# python3 for float arithmetic + sane rounding; the token estimate is the
# documented ~4 chars / token heuristic (clamped at 0 so a result that grew
# never reports negative token savings - the negative saved% says it all).
python3 - "$in_bytes" "$out_bytes" <<'PYEOF'
import sys

in_bytes = int(sys.argv[1])
out_bytes = int(sys.argv[2])


def kb(n):
    # banker's rounding is fine at the KB/% precision we report; the token
    # column uses // (floor) and is independent of this.
    return round(n / 1024)


if in_bytes == 0:
    # Nothing to reduce: a percentage would be a division-by-zero. Report
    # the sizes with a clear message instead of a bogus number.
    print(f"input 0 KB -> result {kb(out_bytes)} KB (no data to reduce)", file=sys.stderr)
    sys.exit(0)

pct = round((1 - out_bytes / in_bytes) * 100)
tokens = max(0, (in_bytes - out_bytes) // 4)
print(f"input {kb(in_bytes)} KB -> result {kb(out_bytes)} KB (saved {pct}%, ~{tokens} tokens)", file=sys.stderr)
PYEOF
