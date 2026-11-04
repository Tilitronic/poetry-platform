#!/usr/bin/env bats
# Behavioral tests for scripts/data-reduce.sh (DIA-181, RLM pattern).
#
# Stream contract under test:
#   stdout - the reduction result ONLY (pure, pipeable onward)
#   stderr - the savings line + diagnostics (measurement metadata)
#   exit   - 0 on success; the reduction command's exit code on failure;
#            2 on usage errors: no input, missing input file, reducer not
#            on the allowlist (jq rg wc head tail cut tr uniq), a
#            command-executing flag (--pre, --pre-glob, --pre=*, --pre-glob=*),
#            or a reducer-scoped argument (uniq non-option token - positional
#            INPUT/OUTPUT or option value, rg -z/--search-zip and short z
#            clusters (-nz/-zc), tail -f/--follow/--follow=* and short f/F
#            clusters (-F/-nf))
#
# Isolation: fixtures live under $BATS_TEST_TMPDIR; the script's own mktemp
# workdir is self-cleaning (EXIT trap). No Docker, no network, no repo
# mutation.

load test-helper

bats_require_minimum_version 1.5.0

REDUCE="$SCRIPTS_DIR/data-reduce.sh"

# assert_stderr_contains <substring>: stderr-only counterpart of the
# test-helper assert_output_contains (with --separate-stderr, $output is
# stdout and $stderr is stderr).
assert_stderr_contains() {
  [[ "$stderr" == *"$1"* ]] || {
    echo "assert_stderr_contains: missing substring: $1" >&2
    echo "--- stderr ---" >&2
    echo "$stderr" >&2
    return 1
  }
}

# mk_fixture <line_count> <out_file>: writes <line_count> lines of exactly
# 43 bytes each ("line-%04d-" + 32 x's + newline) - deterministic, so the
# byte-level savings-line assertions below are stable.
mk_fixture() {
  local lines="$1" out="$2"
  seq 1 "$lines" | awk '{ printf "line-%04d-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\n", $1 }' > "$out"
}

@test "data-reduce: file mode with default reduction prints a savings line" {
  local f="$BATS_TEST_TMPDIR/blob.txt"
  mk_fixture 200 "$f"

  run --separate-stderr bash "$REDUCE" "$f"

  assert_status 0
  # stdout is the pure wc -lc result (line count + byte count) - no savings
  # line pollution on the result stream.
  assert_output_contains "200"
  assert_output_contains "8600"
  assert_output_not_contains "saved"
  # stderr carries the canonical savings line. The exact token count is NOT
  # asserted here: `wc` pads its output to column width, and the pad width
  # (and thus the result byte count) varies across platforms. The stable
  # prefix is asserted; the byte-exact format lock lives in the `-- true`
  # test below (zero-length result -> fully deterministic).
  assert_stderr_contains "input 8 KB -> result 0 KB (saved 100%, ~"
}

@test "data-reduce: explicit reduction command via -- separator" {
  local f="$BATS_TEST_TMPDIR/blob.txt"
  mk_fixture 100 "$f"

  # rg (allowlisted) instead of grep: the reducer allowlist pins the first
  # element to jq rg wc head tail cut tr uniq (DIA-260827-ft3z).
  run --separate-stderr bash "$REDUCE" "$f" -- rg -c '^line'

  assert_status 0
  assert_output_contains "100"
  assert_stderr_contains "input 4 KB -> result 0 KB (saved 100%"
}

@test "data-reduce: command form without -- separator works" {
  local f="$BATS_TEST_TMPDIR/blob.txt"
  mk_fixture 100 "$f"

  run --separate-stderr bash "$REDUCE" "$f" wc -l

  assert_status 0
  assert_output_contains "100"
  assert_stderr_contains "saved 100%"
}

@test "data-reduce: stream mode reads stdin and reduces" {
  local f="$BATS_TEST_TMPDIR/blob.txt"
  mk_fixture 100 "$f"

  run --separate-stderr bash "$REDUCE" - -- wc -l < "$f"

  assert_status 0
  assert_output_contains "100"
  assert_stderr_contains "saved 100%"
  assert_stderr_contains "tokens"
}

@test "data-reduce: reduction yielding empty output is safe (saved 100%)" {
  local f="$BATS_TEST_TMPDIR/blob.txt"
  mk_fixture 100 "$f"

  # head -n 0 (allowlisted) replaces the old `true` reducer: the allowlist
  # permits no shell builtins, and head -n 0 likewise emits nothing.
  run --separate-stderr bash "$REDUCE" "$f" -- head -n 0

  assert_status 0
  # empty output: stdout is empty, stderr reports the full savings.
  assert_stderr_contains "input 4 KB -> result 0 KB (saved 100%, ~1075 tokens)"
}

@test "data-reduce: empty input file is handled safely" {
  local f="$BATS_TEST_TMPDIR/empty.txt"
  : > "$f"

  run --separate-stderr bash "$REDUCE" "$f"

  assert_status 0
  # No division-by-zero percentage: a clear message instead.
  assert_stderr_contains "no data to reduce"
}

@test "data-reduce: reduction command failure propagates its exit code" {
  local f="$BATS_TEST_TMPDIR/blob.txt"
  mk_fixture 10 "$f"

  # jq -n 'error("boom")' (allowlisted) replaces the old `sh -c`: the
  # allowlist rejects shell interpreters. jq's error() aborts with exit 5
  # and prints "boom" on stderr, so the replay + propagation assertions hold.
  run --separate-stderr bash "$REDUCE" "$f" -- jq -n 'error("boom")'

  assert_status 5
  assert_stderr_contains "boom"
  assert_stderr_contains "reduction command failed (exit 5)"
}

@test "data-reduce: missing input file exits 2 with a clear message" {
  run --separate-stderr bash "$REDUCE" "$BATS_TEST_TMPDIR/does-not-exist.txt" -- wc -l

  assert_status 2
  assert_stderr_contains "input not found"
}

@test "data-reduce: no arguments prints usage and exits 2" {
  run --separate-stderr bash "$REDUCE"

  assert_status 2
  assert_stderr_contains "Usage:"
}

# --- reducer allowlist boundary (DIA-260827-ft3z) ---------------------------
# The permission layer sees only the raw prefix text of the invocation and
# cannot pin the argv boundary after `--`; the script can, so these cases pin
# the script-side boundary: allowlisted reducers run, everything else is a
# usage error (exit 2) before any input is read.

@test "data-reduce: allowlisted reducer still runs and prints the savings line" {
  local f="$BATS_TEST_TMPDIR/blob.txt"
  mk_fixture 100 "$f"

  run --separate-stderr bash "$REDUCE" "$f" -- head -n 5

  assert_status 0
  assert_output_contains "line-0001"
  assert_output_not_contains "line-0006"
  assert_stderr_contains "input 4 KB -> result 0 KB (saved"
  assert_stderr_contains "tokens"
}

@test "data-reduce: non-allowlisted reducer (python3 -c) exits 2 with the allowlist message" {
  local f="$BATS_TEST_TMPDIR/blob.txt"
  mk_fixture 10 "$f"

  run --separate-stderr bash "$REDUCE" "$f" -- python3 -c "print('pwned')"

  assert_status 2
  assert_stderr_contains "allowlist"
  assert_stderr_contains "python3"
  # the allowlist itself is named in the message, and nothing executed
  assert_stderr_contains "allowed: jq rg wc head tail cut tr uniq"
  assert_output_not_contains "pwned"
}

@test "data-reduce: slash-qualified first element exits 2" {
  local f="$BATS_TEST_TMPDIR/blob.txt"
  mk_fixture 10 "$f"

  run --separate-stderr bash "$REDUCE" "$f" -- /bin/cat

  assert_status 2
  assert_stderr_contains "/bin/cat"
  assert_stderr_contains "allowlist"
}

@test "data-reduce: sort is rejected (its -o flag writes files)" {
  local f="$BATS_TEST_TMPDIR/blob.txt"
  mk_fixture 10 "$f"

  run --separate-stderr bash "$REDUCE" "$f" -- sort

  assert_status 2
  assert_stderr_contains "sort"
  assert_stderr_contains "allowlist"
}

@test "data-reduce: no-CMD default still works (stdin input)" {
  local f="$BATS_TEST_TMPDIR/blob.txt"
  mk_fixture 100 "$f"

  # no CMD: the default wc -lc path passes through the allowlist check
  # unchanged (the file-mode default is covered by the first case above).
  run --separate-stderr bash "$REDUCE" - < "$f"

  assert_status 0
  assert_output_contains "100"
  assert_output_contains "4300"
  assert_stderr_contains "saved"
}

# --- reducer flag boundary (DIA-260827-ft3z) --------------------------------
# A clean NAME is not enough: ripgrep's --pre / --pre-glob run an arbitrary
# program as the file preprocessor, so `rg --pre bash '' x.sh` passes the
# name pin and executes x.sh. These cases pin the flag side of the boundary
# and prove the program does NOT run: the payload creates a marker file AND
# prints a canary line, so "it ran" would be visible either way.

# mk_payload <script> <marker>: payload that creates <marker> and prints
# "pwned-output". rg invokes it as `bash <script>` (program token + the file
# argument it is given).
mk_payload() {
  local script="$1" marker="$2"
  cat > "$script" <<EOF
#!/usr/bin/env bash
touch "$marker"
printf 'pwned-output\n'
EOF
}

@test "data-reduce: rg --pre (command-executing flag) exits 2 and the program does not run" {
  local f="$BATS_TEST_TMPDIR/blob.txt"
  local marker="$BATS_TEST_TMPDIR/side.marker"
  local payload="$BATS_TEST_TMPDIR/run.sh"
  mk_fixture 10 "$f"
  mk_payload "$payload" "$marker"

  # the confirmed vector: allowlisted NAME, payload as the rg file argument,
  # --pre pointing the preprocessor at `bash` so rg runs `bash <payload>`.
  run --separate-stderr bash "$REDUCE" "$f" -- rg --pre bash '' "$payload"

  assert_status 2
  assert_stderr_contains "command-executing flag"
  assert_stderr_contains "--pre"
  # demonstrably did not run: no marker file, no canary output
  [ ! -e "$marker" ]
  assert_output_not_contains "pwned-output"
}

@test "data-reduce: rg --pre= form exits 2 and the program does not run" {
  local f="$BATS_TEST_TMPDIR/blob.txt"
  local marker="$BATS_TEST_TMPDIR/side.marker"
  local payload="$BATS_TEST_TMPDIR/run.sh"
  mk_fixture 10 "$f"
  mk_payload "$payload" "$marker"

  run --separate-stderr bash "$REDUCE" "$f" -- rg --pre=bash '' "$payload"

  assert_status 2
  assert_stderr_contains "command-executing flag"
  assert_stderr_contains "--pre=bash"
  [ ! -e "$marker" ]
  assert_output_not_contains "pwned-output"
}

@test "data-reduce: rg --pre-glob exits 2 on the blanket flag rule" {
  local f="$BATS_TEST_TMPDIR/blob.txt"
  mk_fixture 10 "$f"

  # bare --pre-glob (no --pre) executes nothing by itself, but it is one
  # half of the same vector and is rejected without proving intent.
  run --separate-stderr bash "$REDUCE" "$f" -- rg --pre-glob '*' -c '^line'

  assert_status 2
  assert_stderr_contains "command-executing flag"
  assert_stderr_contains "--pre-glob"
}

@test "data-reduce: flag guard leaves a normal rg -c invocation untouched" {
  local f="$BATS_TEST_TMPDIR/blob.txt"
  mk_fixture 100 "$f"

  run --separate-stderr bash "$REDUCE" "$f" -- rg -c '^line'

  assert_status 0
  assert_output_contains "100"
  assert_stderr_contains "input 4 KB -> result 0 KB (saved 100%"
  assert_stderr_contains "tokens"
}

# --- reducer-scoped argument boundary (DIA-260827-ft3z) ----------------------
# `uniq INPUT [OUTPUT]` made the allowlist write-capable: sort is excluded for
# exactly the same reason (sort -o FILE), but uniq's OUTPUT positional was
# never rejected - `uniq - <file>` truncates and writes any path in the repo,
# defeating the knowledge/* edit scope. rg -z/--search-zip spawn an external
# decompressor (exact tokens alone missed the clustered -nz/-zc spellings);
# tail -f/--follow never terminate (an unattended lane hangs; the same holds
# for the clustered -F/-nf spellings). The short-cluster arms require a letter
# right after the dash, so long options such as --glob=*.zip are NOT caught -
# the precision test below pins that. The scoping is part of the contract:
# cut -f is a field spec and cut -z is --zero-terminated, so the rejects must
# fire ONLY for the named reducer.

@test "data-reduce: uniq positional OUTPUT is rejected without creating or truncating the target" {
  local f="$BATS_TEST_TMPDIR/blob.txt"
  local target="$BATS_TEST_TMPDIR/uniq-target.txt"
  mk_fixture 10 "$f"

  # absent target stays absent - the guard fires before the command runs
  run --separate-stderr bash "$REDUCE" "$f" -- uniq - "$target"
  assert_status 2
  assert_stderr_contains "non-option argument"
  assert_stderr_contains "writes an arbitrary file"
  assert_file_not_exists "$target"

  # pre-existing target keeps its bytes - no truncation either
  printf 'sentinel\n' > "$target"
  run --separate-stderr bash "$REDUCE" "$f" -- uniq - "$target"
  assert_status 2
  assert_stderr_contains "non-option argument"
  assert_file_contains "$target" "sentinel"
}

@test "data-reduce: uniq -c still succeeds (options are not positionals)" {
  local f="$BATS_TEST_TMPDIR/blob.txt"
  mk_fixture 10 "$f"

  run --separate-stderr bash "$REDUCE" "$f" -- uniq -c

  assert_status 0
  assert_output_contains "line-0001"
  assert_stderr_contains "saved"
}

@test "data-reduce: rg -z and --search-zip are rejected (external decompressor)" {
  local f="$BATS_TEST_TMPDIR/blob.txt"
  mk_fixture 10 "$f"

  run --separate-stderr bash "$REDUCE" "$f" -- rg -z -c '^line'
  assert_status 2
  assert_stderr_contains "decompressor flag"
  assert_stderr_contains "-z"

  run --separate-stderr bash "$REDUCE" "$f" -- rg --search-zip -c '^line'
  assert_status 2
  assert_stderr_contains "decompressor flag"
  assert_stderr_contains "--search-zip"
}

@test "data-reduce: rg short decompressor clusters (-nz, -zc) are rejected" {
  local f="$BATS_TEST_TMPDIR/blob.txt"
  mk_fixture 10 "$f"

  # O2 (DIA-260827-ft3z re-review): exact tokens alone let the clustered
  # spellings through - `-nz` (z after a leading letter) and `-zc` (z-leading)
  # both spawn the decompressor just like bare `-z`.
  local flag
  for flag in -nz -zc; do
    run --separate-stderr bash "$REDUCE" "$f" -- rg "$flag" -c '^line'
    assert_status 2
    assert_stderr_contains "decompressor flag"
    assert_stderr_contains "$flag"
  done
}

@test "data-reduce: rg --glob=*.zip survives the short-cluster guard (precision)" {
  local f="$BATS_TEST_TMPDIR/blob.txt"
  mk_fixture 100 "$f"

  # False-positive avoidance pin: the short-cluster arm is `-[a-zA-Z]...`
  # (a letter right after the dash), and long options start with `--`, so a
  # literal `z` inside --glob=*.zip must NOT be read as a decompressor
  # cluster. The reduction itself still runs to completion.
  run --separate-stderr bash "$REDUCE" "$f" -- rg --glob='*.zip' -c '^line'

  assert_status 0
  assert_output_contains "100"
  assert_stderr_contains "saved"
}

@test "data-reduce: tail -f, -F, -nf, --follow and --follow=* are rejected (never terminate)" {
  local f="$BATS_TEST_TMPDIR/blob.txt"
  mk_fixture 10 "$f"

  # O4 (DIA-260827-ft3z re-review): every invocation is bounded by
  # `timeout 5` so a regression fails cleanly (timeout kills the follower and
  # reports 124, a non-2 exit) instead of the suite hanging forever - on the
  # pre-fix guard `tail -f` follows stdin to EOF and never returns.
  local flag
  for flag in -f -F -nf --follow --follow=1; do
    run --separate-stderr timeout 5 bash "$REDUCE" "$f" -- tail "$flag"
    assert_status 2
    assert_stderr_contains "follow flag"
    assert_stderr_contains "$flag"
  done
}

@test "data-reduce: scoped rejects leave cut -f (a legitimate field spec) working" {
  local f="$BATS_TEST_TMPDIR/blob.txt"
  mk_fixture 10 "$f"

  # Regression guard for OVER-broad scoping: -f/-z must be rejected only for
  # the reducers that named them, never globally.
  run --separate-stderr bash "$REDUCE" "$f" -- cut -f 1
  assert_status 0
  assert_output_contains "line-0001"
  assert_stderr_contains "saved"
}
