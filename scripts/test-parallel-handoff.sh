#!/usr/bin/env bash
# DIA-085 T4.1 - parallel-handoff smoke test (S2 seam, design.md section 6).
# Exercises the six acceptance scenarios from proposal.md success criteria:
# two-session smoke, forced race, same-session rewrite (archive), legacy
# fallback, pointer stale recovery, pointer mismatch recovery.
#
# WHY the writer is SIMULATED (direct file manipulation, not a bun import):
# this is a HOST gate (wired into `make test-config` by T5.1; host has bash +
# jq, no bun). The real TS writer is covered by the S1 bun harness
# .opencode/plugins/__tests__/parallel-handoff.test.mjs (T4.2, in-container).
# This script owns the S2 filesystem protocol: slot/pointer/archive layout +
# DIA-061 canonical checksum + the validate-handoff.sh resolution chain. The
# simulated writer mirrors the plugin's POSIX-atomic temp->rename pattern and
# the exact canonical checksum pipeline from scripts/validate-handoff.sh (jq
# sorted-keys + printf %s + sha256sum; change one, change both).
#
# HERMETIC: all fixtures live under a mktemp workspace (default /tmp); the real
# .opencode/session/ is NEVER touched (HANDOFFS_DIR / LEGACY_HANDOFF /
# HANDOFF_TEMPLATE env overrides point validate-handoff.sh at the fixtures).
#
# DIA-079: ASCII-only. DIA-094: exit 0 only when all six scenarios pass.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATE="$ROOT/scripts/validate-handoff.sh"
HANDOFF_TEMPLATE="$ROOT/openspec/templates/HANDOFF.md" # read-only terminal fallback

WORKSPACE="$(mktemp -d "${TMPDIR:-/tmp}/dia085-t41.XXXXXX")"
trap 'rm -rf "$WORKSPACE"' EXIT

PASS=0
FAIL=0
FAILED_SCENARIOS=()
NOLEGACY="$WORKSPACE/no-legacy.json" # validator must never resolve real session state

# ---------------------------------------------------------------------------
# Simulated DIA-085 writer (see header "WHY")
# ---------------------------------------------------------------------------

# make_prognosis <file> <summary>: 5-key prognosis fixture. Key insertion order
# is deliberately NON-alphabetical so the canonical jq sort is what makes the
# checksum reproducible - a missing sort in the validator would flip every
# checksum below.
make_prognosis() {
  jq -n --arg ss "$2" --arg fa "fix: $2" --arg ot "DIA-085" \
    --arg vr "verify: $2" --arg ri "resume: $2" \
    '{session_summary: $ss, fixes_applied: [$fa], open_tickets: [$ot], verification_request: [$vr], resume_instructions: $ri}' \
    > "$1"
}

# canonical_prognosis_checksum <file-with-prognosis>: DIA-061 checksum over the
# canonical serialization (compact JSON, top-level prognosis keys byte-sorted,
# SHA256 hex, no trailing newline) - MUST stay byte-identical to the pipeline
# in scripts/validate-handoff.sh and the plugin.
canonical_prognosis_checksum() {
  local canonical
  canonical="$(jq -c '.prognosis | to_entries | sort_by(.key) | from_entries' "$1")"
  printf '%s' "$canonical" | sha256sum | cut -d' ' -f1
}

# write_slot <handoffs_dir> <session_id> <prognosis_file>: design.md section 1
# slot schema; checksum recomputed over the SLOT's own prognosis after writing
# so it is provably consistent with what the validator reads. POSIX-atomic
# temp->rename.
write_slot() {
  local hd="$1" sid="$2" prog="$3"
  local tmp="$hd/.$sid.json.tmp"
  jq -n --arg sid "$sid" --arg cyc "c-$sid" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" \
    --argjson prognosis "$(jq -c . "$prog")" \
    '{status: "done", session_id: $sid, cycle_id: $cyc, timestamp: $ts, checksum: "0000000000000000000000000000000000000000000000000000000000000000", prognosis: $prognosis}' \
    > "$tmp"
  local checksum
  checksum="$(canonical_prognosis_checksum "$tmp")"
  jq --arg cs "$checksum" '.checksum = $cs' "$tmp" > "$tmp.patched" && mv "$tmp.patched" "$hd/$sid.json"
  rm -f "$tmp"
}

# write_pointer <handoffs_dir> <session_id>: design.md section 1 pointer
# schema. Written AFTER the slot, same atomic pattern. The tmp name is
# per-session (NOT the plugin's fixed .active.json.tmp): the race scenario runs
# two pointer writers concurrently, and a shared tmp path would let one writer's
# mv transiently fail (the plugin catches that with a warn; the simulator must
# not emit noise or risk a nondeterministic wait failure). Atomic rename
# semantics - the observable contract - are unchanged.
write_pointer() {
  local hd="$1" sid="$2"
  local tmp="$hd/.active.json.tmp.$sid"
  jq -n --arg sid "$sid" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" \
    '{active_session_id: $sid, timestamp: $ts, pointer_version: 1}' > "$tmp"
  mv "$tmp" "$hd/active.json"
}

# write_legacy <file>: legacy current-handoff.json (same JSON schema as a slot)
# with a valid checksum, for the legacy-fallback scenario.
write_legacy() {
  local file="$1" prog="$WORKSPACE/.legacy-prog.json"
  make_prognosis "$prog" "legacy summary"
  jq -n --arg sid "ses_legacy" --arg ts "2026-08-15T09:05:59.000Z" \
    --argjson prognosis "$(jq -c . "$prog")" \
    '{status: "done", session_id: $sid, cycle_id: null, timestamp: $ts, checksum: "0000000000000000000000000000000000000000000000000000000000000000", prognosis: $prognosis}' \
    > "$file"
  local checksum
  checksum="$(canonical_prognosis_checksum "$file")"
  jq --arg cs "$checksum" '.checksum = $cs' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

# ---------------------------------------------------------------------------
# Assertion helpers
# ---------------------------------------------------------------------------

# check <description> <cmd...>: runs cmd; non-zero exit prints the description
# and returns 1. Fail-fast per scenario via `|| return 1`.
check() {
  local desc="$1"
  shift
  if ! "$@"; then
    echo "    FAIL: $desc" >&2
    return 1
  fi
}

# out_has <needle> <haystack>: substring grep over captured validator output.
out_has() {
  printf '%s\n' "$2" | grep -qF -- "$1"
}

# run_validator <handoffs_dir> <legacy_file>: runs validate-handoff.sh
# hermetically against the fixture tree. Captures combined output in $OUT and
# the exit code in $RC (globals - single-threaded; the race scenario's
# background writers never call this).
run_validator() {
  set +e
  OUT="$(HANDOFFS_DIR="$1" LEGACY_HANDOFF="$2" HANDOFF_TEMPLATE="$HANDOFF_TEMPLATE" \
    bash "$VALIDATE" 2>&1)"
  RC=$?
  set -e
}

# validator_ok <expected-info-line>: asserts the last run_validator exited 0
# and reported the expected resolution line + checksum verification.
validator_ok() {
  check "validate-handoff.sh exit 0" test "$RC" -eq 0 || { printf '%s\n' "$OUT" >&2; return 1; }
  check "validator reported: $1" out_has "$1" "$OUT" || return 1
  check "validator verified checksum" out_has "ok: checksum verified" "$OUT" || return 1
}

# ---------------------------------------------------------------------------
# The six acceptance scenarios
# ---------------------------------------------------------------------------

scenario_1_two_session_smoke() {
  local hd="$WORKSPACE/s1/handoffs"
  mkdir -p "$hd"
  make_prognosis "$WORKSPACE/s1/progA.json" "session A summary"
  make_prognosis "$WORKSPACE/s1/progB.json" "session B summary"
  write_slot "$hd" "ses_A" "$WORKSPACE/s1/progA.json"
  write_pointer "$hd" "ses_A"
  write_slot "$hd" "ses_B" "$WORKSPACE/s1/progB.json"
  write_pointer "$hd" "ses_B"

  check "slot ses_A.json exists" test -f "$hd/ses_A.json" || return 1
  check "slot ses_B.json exists" test -f "$hd/ses_B.json" || return 1
  check "pointer -> ses_B (last writer)" \
    test "$(jq -r '.active_session_id' "$hd/active.json")" = "ses_B" || return 1
  check "archive/ empty after first writes" \
    test -z "$(find "$hd/archive" -type f 2>/dev/null | head -1)" || return 1
  check "ses_A checksum matches its prognosis" \
    test "$(canonical_prognosis_checksum "$hd/ses_A.json")" = "$(jq -r '.checksum' "$hd/ses_A.json")" || return 1
  check "ses_B checksum matches its prognosis" \
    test "$(canonical_prognosis_checksum "$hd/ses_B.json")" = "$(jq -r '.checksum' "$hd/ses_B.json")" || return 1

  run_validator "$hd" "$NOLEGACY"
  validator_ok "resolved slot via active pointer -> ses_B" || return 1
  return 0
}

scenario_2_forced_race() {
  local hd="$WORKSPACE/s2/handoffs"
  mkdir -p "$hd"
  make_prognosis "$WORKSPACE/s2/progA.json" "racer A summary"
  make_prognosis "$WORKSPACE/s2/progB.json" "racer B summary"

  # Two writers racing within the same second (parallel subshells, POSIX-atomic
  # writes). Different session ids -> different slot files, no collision by
  # construction; the shared pointer is last-atomic-rename-wins.
  ( write_slot "$hd" "ses_raceA" "$WORKSPACE/s2/progA.json"; write_pointer "$hd" "ses_raceA" ) &
  ( write_slot "$hd" "ses_raceB" "$WORKSPACE/s2/progB.json"; write_pointer "$hd" "ses_raceB" ) &
  wait || return 1

  check "no file lost: both race slots survive" \
    test -f "$hd/ses_raceA.json" -a -f "$hd/ses_raceB.json" || return 1
  local active
  active="$(jq -r '.active_session_id // empty' "$hd/active.json")"
  check "pointer points to one of the racers" \
    test "$active" = "ses_raceA" -o "$active" = "ses_raceB" || return 1
  local found
  found="$(find "$hd" -maxdepth 1 -type f -name '*.json' ! -name 'active.json' | wc -l)"
  check "mtime scan finds both slots ($found/2)" test "$found" -eq 2 || return 1

  run_validator "$hd" "$NOLEGACY"
  check "validator passes after race (exit 0)" test "$RC" -eq 0 || { printf '%s\n' "$OUT" >&2; return 1; }
  return 0
}

scenario_3_same_session_rewrite() {
  local hd="$WORKSPACE/s3/handoffs"
  mkdir -p "$hd/archive"
  make_prognosis "$WORKSPACE/s3/prog1.json" "first write summary"
  make_prognosis "$WORKSPACE/s3/prog2.json" "refreshed write summary"
  write_slot "$hd" "ses_A" "$WORKSPACE/s3/prog1.json"
  write_pointer "$hd" "ses_A"

  # G2 HANDOFF-REFRESH: archive the prior slot to
  # archive/<session-id>.<iso-hyphenated-ts>.json (colons -> hyphens), write
  # the new slot; pointer identity stays ses_A.
  local ts archive_name archived
  ts="$(date -u +%Y-%m-%dT%H-%M-%S.000Z)"
  archive_name="ses_A.$ts.json"
  mv "$hd/ses_A.json" "$hd/archive/$archive_name"
  archived="$hd/archive/$archive_name"
  write_slot "$hd" "ses_A" "$WORKSPACE/s3/prog2.json"

  check "archive created exactly one prior-slot file" test -f "$archived" || return 1
  check "archive name follows <session-id>.<iso-hyphenated-ts>.json" \
    test "$(basename "$archived")" = "$archive_name" || return 1
  check "archived slot carries the OLD prognosis" \
    test "$(jq -r '.prognosis.session_summary' "$archived")" = "first write summary" || return 1
  check "archived slot checksum still matches its (old) prognosis" \
    test "$(canonical_prognosis_checksum "$archived")" = "$(jq -r '.checksum' "$archived")" || return 1
  check "slot replaced with the NEW prognosis" \
    test "$(jq -r '.prognosis.session_summary' "$hd/ses_A.json")" = "refreshed write summary" || return 1
  check "pointer unchanged (still ses_A)" \
    test "$(jq -r '.active_session_id' "$hd/active.json")" = "ses_A" || return 1

  run_validator "$hd" "$NOLEGACY"
  validator_ok "resolved slot via active pointer -> ses_A" || return 1
  return 0
}

scenario_4_legacy_fallback() {
  local hd="$WORKSPACE/s4/handoffs"
  mkdir -p "$hd"
  local legacy="$WORKSPACE/s4/current-handoff.json"
  write_legacy "$legacy"

  run_validator "$hd" "$legacy"
  validator_ok "no handoff slots present - validating legacy current-handoff.json" || return 1
  return 0
}

scenario_5_pointer_stale_recovery() {
  local hd="$WORKSPACE/s5/handoffs"
  mkdir -p "$hd"
  make_prognosis "$WORKSPACE/s5/prog.json" "survivor summary"
  write_slot "$hd" "ses_survivor" "$WORKSPACE/s5/prog.json"
  write_pointer "$hd" "ses_survivor"
  rm -f "$hd/active.json" # pointer deleted -> mtime scan must resolve

  run_validator "$hd" "$NOLEGACY"
  validator_ok "resolved newest slot by mtime (ses_survivor.json)" || return 1
  return 0
}

scenario_6_pointer_mismatch_recovery() {
  local hd="$WORKSPACE/s6/handoffs"
  mkdir -p "$hd"
  make_prognosis "$WORKSPACE/s6/prog.json" "survivor summary"
  write_slot "$hd" "ses_survivor" "$WORKSPACE/s6/prog.json"
  write_pointer "$hd" "ses_deleted" # points to a slot that does not exist

  run_validator "$hd" "$NOLEGACY"
  check "validator exit 0 (stale-pointer recovery)" test "$RC" -eq 0 || { printf '%s\n' "$OUT" >&2; return 1; }
  check "validator reports stale pointer" \
    out_has "active pointer points to missing slot 'ses_deleted'" "$OUT" || return 1
  check "validator resolved newest surviving slot by mtime" \
    out_has "resolved newest slot by mtime (ses_survivor.json)" "$OUT" || return 1
  return 0
}

# ---------------------------------------------------------------------------
# Runner: PASS/FAIL per scenario; exit 0 iff all six pass.
# ---------------------------------------------------------------------------
main() {
  local scenarios=(
    "1 two-session smoke"         scenario_1_two_session_smoke
    "2 forced race"               scenario_2_forced_race
    "3 same-session rewrite"      scenario_3_same_session_rewrite
    "4 legacy fallback"           scenario_4_legacy_fallback
    "5 pointer stale recovery"    scenario_5_pointer_stale_recovery
    "6 pointer mismatch recovery" scenario_6_pointer_mismatch_recovery
  )
  local i fn label
  for ((i = 0; i < ${#scenarios[@]}; i += 2)); do
    label="${scenarios[i]}"
    fn="${scenarios[i + 1]}"
    echo "scenario $label: running"
    # Subshell isolates set -e from the scenario's internal failures so a
    # failed scenario reports FAIL instead of aborting the whole script.
    if ( "$fn" ); then
      PASS=$((PASS + 1))
      echo "scenario $label: PASS"
    else
      FAIL=$((FAIL + 1))
      FAILED_SCENARIOS+=("$label")
      echo "scenario $label: FAIL"
    fi
  done

  echo
  echo "RESULT: $PASS passed, $FAIL failed"
  if [ "$FAIL" -gt 0 ]; then
    printf 'failed scenarios: %s\n' "${FAILED_SCENARIOS[*]}" >&2
    exit 1
  fi
  exit 0
}

main "$@"
