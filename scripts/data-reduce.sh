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
#            2 on usage errors (no input, missing input file)
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
