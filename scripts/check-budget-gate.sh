#!/usr/bin/env bash
# check-budget-gate.sh -- commit-time enforcement of the F binding budget.
#
# WHY: the F budget (prod LOC ceiling, shell LOC ceiling, no test-scaffold
# duplication) was enforced only by hand-recorded numbers in a ticket; without
# a machine gate the de-bloat gains silently regress. A naive global LOC gate
# would block normal feature work, so scope comes from an explicit per-commit
# trailer backed by a ticket-bound manifest (campaign ticket DIA-260903-o7n0).
#
# Usage:
#   check-budget-gate.sh <message-file>   commit-msg hook mode ($1 is the file
#                                         git passes to commit-msg hooks)
#   check-budget-gate.sh --range <rev>     pre-push/CI mode: one evaluation per
#                                         commit in the range, always blocking
# Env:
#   BUDGET_MANIFEST    manifest path (default scripts/budget-baselines.json)
#   TICKETS_DIR        ticket ledger dir (default docs/dev-infra-audit/tickets)
#   BUDGET_PLUGIN_ROOT plugin tree root (default .opencode/plugins); a staged
#                      path is scoped iff it sits under this root, role by
#                      layout: delegation-observer.ts = prod+shell, lib/ = prod,
#                      __tests__/ = test
#   BUDGET_GATE_MODE=report  hook mode only: never blocks, still measures and
#                      prints every violation plus a warn: line; range mode
#                      ignores it entirely
# Streams: ok: lines to stdout; FAIL:/warn: lines to stderr.
# Exits: 0 pass (or report-only allow), 1 block, 2 usage error.
set -uo pipefail

# ---------------------------------------------------------------------------
# Small utilities
# ---------------------------------------------------------------------------

fail_emit() { printf 'FAIL: %s\n' "$*" >&2; }
ok_emit() { printf 'ok: %s\n' "$*"; }
warn_emit() { printf 'warn: %s\n' "$*" >&2; }

# budget_normalize: the B-detector canonicalizer (design.md "Duplication
# detector"): strip ALL whitespace, fold every quote byte (', ", backtick) to
# one marker, so re-indentation, line-splitting, and quote flips cannot evade
# the fixed-string match below.
#
# ponytail: literal match only; string-concat splitting ("@opencode-ai" +
# "/plugin") and identifier renaming evade this detector. Upgrade path: AST
# call-shape match. Trigger: an observed real bypass, not a hypothetical one.
budget_normalize() { tr -d '[:space:]' | tr '\047"\140' 'x'; }

# parse_trailer <file> <key>: last occurrence wins; strict ASCII "Key: value"
# head, lenient trailing whitespace. Prints the value or nothing.
parse_trailer() {
  [ -f "${1:-}" ] || return 0
  grep -a "^${2}: " "$1" 2>/dev/null | tail -n 1 | sed -e "s/^${2}: //" -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' || true
}

# ---------------------------------------------------------------------------
# Repo / path setup (shared by both modes)
# ---------------------------------------------------------------------------

CWD_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  fail_emit "budget gate: not inside a git repository"
  exit 1
}
# Gated-repo discovery: the tree that owns the scoped plugin paths. An
# explicit BUDGET_PLUGIN_ROOT (absolute in hermetic fixtures, relative
# otherwise) relocates the gated repo to the repo containing it, so fixture
# runs gate the fixture tree instead of the caller's checkout; unset means
# the caller's checkout, exactly as before. Unresolvable override falls back
# to the caller's checkout (fail-closed verdicts still apply per commit).
ROOT="$CWD_ROOT"
if [ -n "${BUDGET_PLUGIN_ROOT:-}" ]; then
  case "$BUDGET_PLUGIN_ROOT" in
    /*) _PR="$BUDGET_PLUGIN_ROOT" ;;
    *) _PR="$CWD_ROOT/$BUDGET_PLUGIN_ROOT" ;;
  esac
  if _RR="$(git -C "$_PR" rev-parse --show-toplevel 2>/dev/null)"; then
    ROOT="$_RR"
  fi
fi

MANIFEST="${BUDGET_MANIFEST:-$ROOT/scripts/budget-baselines.json}"
case "$MANIFEST" in /*) ;; *) MANIFEST="$ROOT/$MANIFEST" ;; esac
TICKETS_DIR="${TICKETS_DIR:-$ROOT/docs/dev-infra-audit/tickets}"
PLUGIN_ROOT="${BUDGET_PLUGIN_ROOT:-$ROOT/.opencode/plugins}"
case "$PLUGIN_ROOT" in */) PLUGIN_ROOT="${PLUGIN_ROOT%/}" ;; esac
case "$MANIFEST" in */) MANIFEST="${MANIFEST%/}" ;; esac

case "$PLUGIN_ROOT" in "$ROOT"/*) PLUGREL="${PLUGIN_ROOT#$ROOT/}" ;; *) PLUGREL="$PLUGIN_ROOT" ;; esac

ZERO_SHA="0000000000000000000000000000000000000000"

# ---------------------------------------------------------------------------
# Tree accessors (indirection so hook mode reads the index and range mode
# reads a committed tree; the verdict logic below is mode-blind)
# ---------------------------------------------------------------------------

EVAL_MODE="hook"
EVAL_SHA=""

# tree_show <repo-rel-path>: blob bytes to stdout; non-zero when absent.
tree_show() {
  if [ "$EVAL_MODE" = "range" ]; then
    git -C "$ROOT" show "$EVAL_SHA:$1" 2>/dev/null
  else
    git -C "$ROOT" show ":$1" 2>/dev/null
  fi
}

# tree_ls: NUL-delimited repo-relative paths of the tracked tree.
tree_ls() {
  if [ "$EVAL_MODE" = "range" ]; then
    git -C "$ROOT" ls-tree -r --name-only -z "$EVAL_SHA" -- "$PLUGREL" 2>/dev/null || true
  else
    git -C "$ROOT" ls-files -z -- "$PLUGREL" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Manifest (loaded once per process; fail-closed on any defect)
# ---------------------------------------------------------------------------

MANIFEST_OK=0
MANIFEST_ERR=""
PROD_CEIL=""
SHELL_CEIL=""
PATTERNS_TSV=""   # id \t canonical \t baseline_count \t authorized_site
CAMPAIGNS_TSV=""  # scope \t status \t ticket

manifest_load() {
  if ! command -v jq >/dev/null 2>&1; then
    MANIFEST_ERR="jq unavailable; cannot parse budget manifest"
    return 1
  fi
  if [ ! -f "$MANIFEST" ]; then
    MANIFEST_ERR="budget manifest not found: $MANIFEST"
    return 1
  fi
  if ! jq -e '
    (.prod_ceiling | type == "number") and
    (.shell_ceiling | type == "number") and
    (.patterns | type == "array") and
    (.campaigns | type == "array") and
    ([.patterns[] | ((.id | type) == "string" and (.canonical | type) == "string"
      and (.baseline_count | type) == "number"
      and (.authorized_site | type) == "string")] | all) and
    ([.campaigns[] | ((.ticket | type) == "string" and (.ticket | length > 0)
      and (.scope | type) == "string" and (.status | type) == "string")] | all)
  ' "$MANIFEST" >/dev/null 2>&1; then
    MANIFEST_ERR="budget manifest invalid (not JSON or schema violation): $MANIFEST"
    return 1
  fi
  PROD_CEIL="$(jq -r '.prod_ceiling' "$MANIFEST")"
  SHELL_CEIL="$(jq -r '.shell_ceiling' "$MANIFEST")"
  PATTERNS_TSV="$(jq -r '.patterns[] | [.id, .canonical, (.baseline_count | tostring), .authorized_site] | join("\t")' "$MANIFEST")"
  CAMPAIGNS_TSV="$(jq -r '.campaigns[] | [.scope, .status, .ticket] | join("\t")' "$MANIFEST")"
  MANIFEST_OK=1
  return 0
}

# has_backing <scope>: an approved campaign entry for the declared scope
# (exact field match on "scope \t approved \t ticket").
has_backing() {
  [ -n "${1:-}" ] || return 1
  printf '%s\n' "$CAMPAIGNS_TSV" | awk -F '\t' -v s="$1" '$1 == s && $2 == "approved" { found = 1 } END { exit !found }'
}

# ---------------------------------------------------------------------------
# Per-commit evaluation. Globals in: MSGFILE, CHANGED (newline list of
# repo-relative changed paths). Globals out: EVAL_FAILS (newline list),
# EVAL_OK (report line). Returns 0 pass, 1 block.
# ---------------------------------------------------------------------------

MSGFILE=""
CHANGED=""
EVAL_FAILS=""
EVAL_OK=""

eval_commit() {
  EVAL_FAILS=""
  EVAL_OK=""
  local scoped=0 manifest_touched=0
  local p abs

  while IFS= read -r p; do
    [ -n "$p" ] || continue
    abs="$ROOT/$p"
    if [ "$abs" = "$MANIFEST" ]; then
      manifest_touched=1
    fi
    case "$abs" in "$PLUGIN_ROOT" | "$PLUGIN_ROOT"/*) scoped=1 ;; esac
  done <<< "$CHANGED"

  # Fast path: nothing scoped and no manifest edit -> pass without reading
  # the manifest (so untouched-path commits never depend on manifest state).
  if [ "$scoped" -eq 0 ] && [ "$manifest_touched" -eq 0 ]; then
    EVAL_OK="no scoped paths touched; budget gate skipped"
    return 0
  fi

  # Scope / exception trailers (last occurrence wins; unknown scope values
  # are treated as absent, i.e. feature: a typo'd scope can only downgrade
  # to report-only, never to a blocking refactor claim).
  local scope_raw scope exc
  scope_raw="$(parse_trailer "$MSGFILE" "Budget-Scope")"
  exc="$(parse_trailer "$MSGFILE" "Budget-Exception")"
  scope=""
  case "$scope_raw" in refactor | test-debloat | feature) scope="$scope_raw" ;; esac

  if [ "$MANIFEST_OK" -ne 1 ]; then
    EVAL_FAILS="budget manifest failed to load ($MANIFEST_ERR); failing closed"
    return 1
  fi

  local backed=0
  if [ "$scope" = "refactor" ] || [ "$scope" = "test-debloat" ]; then
    if has_backing "$scope"; then
      backed=1
    else
      EVAL_FAILS="${EVAL_FAILS}
Budget-Scope $scope has no approved backing campaign in manifest; failing closed (no backing)"
      # No rescue: an exception never repairs scope/manifest state.
      return 1
    fi
  fi

  # Manifest edits demand the normal refactor-family trailer with backing;
  # a Budget-Exception trailer alone never authorizes a manifest edit.
  local manifest_violation=0
  if [ "$manifest_touched" -eq 1 ]; then
    if [ "$backed" -ne 1 ]; then
      EVAL_FAILS="${EVAL_FAILS}
manifest edit requires Budget-Scope refactor/test-debloat with approved backing (got '${scope_raw:-<none>}'); exception trailers never authorize manifest edits"
      manifest_violation=1
    fi
  fi

  # --- Budgets A/C: production + shell LOC from the evaluated tree ---------
  # Production set = delegation-observer.ts (prod+shell) plus single-level
  # lib/*.ts (prod). Each file is read through the tree accessor so hook
  # mode measures staged content and range mode measures the commit tree.
  local prod_total=0 shell_total=0
  local rel f lines sub
  while IFS= read -r -d '' f; do
    [ -n "$f" ] || continue
    rel="${f#$PLUGREL/}"
    if [ "$rel" = "delegation-observer.ts" ]; then
      :
    else
      sub="${rel#lib/}"
      case "$rel" in lib/*.ts) ;; *) continue ;; esac
      case "$sub" in */*) continue ;; esac
    fi
    lines="$(tree_show "$f" 2>/dev/null | wc -l)"
    lines="$(printf '%s' "$lines" | tr -d ' ')"
    case "$lines" in '' | *[!0-9]*) lines=0 ;; esac
    prod_total=$((prod_total + lines))
    if [ "$rel" = "delegation-observer.ts" ]; then
      shell_total="$lines"
    fi
  done < <(tree_ls)

  local ac_violation=0
  if [ "$backed" -eq 1 ]; then
    if [ "$prod_total" -gt "$PROD_CEIL" ]; then
      EVAL_FAILS="${EVAL_FAILS}
production LOC $prod_total exceeds prod ceiling $PROD_CEIL (scope $scope)"
      ac_violation=1
    fi
    if [ "$shell_total" -gt "$SHELL_CEIL" ]; then
      EVAL_FAILS="${EVAL_FAILS}
shell LOC $shell_total exceeds shell ceiling $SHELL_CEIL (scope $scope)"
      ac_violation=1
    fi
  fi

  # --- Budget B: normalize-then-fixed-string over scoped test paths --------
  local b_violation=0
  if [ -n "$PATTERNS_TSV" ]; then
    local pid pcanon pbase pauth ncanon count base
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      pid="$(printf '%s' "$line" | cut -f1)"
      pcanon="$(printf '%s' "$line" | cut -f2)"
      pbase="$(printf '%s' "$line" | cut -f3)"
      pauth="$(printf '%s' "$line" | cut -f4)"
      ncanon="$(printf '%s' "$pcanon" | budget_normalize)"
      count=0
      while IFS= read -r -d '' f; do
        [ -n "$f" ] || continue
        case "$f" in *.mjs) ;; *) continue ;; esac
        case "$f" in *__tests__/*) ;; *) continue ;; esac
        base="$(basename "$f")"
        [ "$base" = "$pauth" ] && continue
        if tree_show "$f" 2>/dev/null | budget_normalize | grep -qF -- "$ncanon"; then
          count=$((count + 1))
        fi
      done < <(tree_ls)
      case "$pbase" in '' | *[!0-9]*) pbase=0 ;; esac
      if [ "$count" -gt "$pbase" ]; then
        EVAL_FAILS="${EVAL_FAILS}
duplication pattern $pid matched $count files above baseline $pbase"
        b_violation=1
      fi
    done <<< "$PATTERNS_TSV"
  fi

  # No violations recorded (EVAL_FAILS holds only blank lines, if anything).
  if [ -z "$(printf '%s' "$EVAL_FAILS" | tr -d '[:space:]')" ]; then
    if [ "$backed" -eq 1 ]; then
      EVAL_OK="scope $scope backed; prod $prod_total/$PROD_CEIL shell $shell_total/$SHELL_CEIL"
    else
      EVAL_OK="feature scope (report-only); prod $prod_total/$PROD_CEIL shell $shell_total/$SHELL_CEIL"
    fi
    return 0
  fi

  # Violations exist. Manifest-edit violations are never rescuable.
  if [ "$manifest_violation" -eq 1 ]; then
    return 1
  fi

  # Exception flow: valid only after scope + manifest resolved (no rescue),
  # and every exception requires an explicit scope trailer.
  if [ "$ac_violation" -eq 1 ] || [ "$b_violation" -eq 1 ]; then
    local exc_msg
    if try_exception "$exc" "$scope"; then
      exc_msg="$(printf '%s' "$TRY_EXCEPTION_LINE")"
      EVAL_OK="exception $exc applied ($exc_msg); prod $prod_total/$PROD_CEIL shell $shell_total/$SHELL_CEIL"
      EVAL_FAILS=""
      return 0
    else
      EVAL_FAILS="${EVAL_FAILS}
${TRY_EXCEPTION_LINE}"
      return 1
    fi
  fi

  return 1
}

TRY_EXCEPTION_LINE=""

# try_exception <exc-id> <scope>: validates the approval record. Prints
# nothing; sets TRY_EXCEPTION_LINE to the report (success) or failure reason.
try_exception() {
  local exc_id="$1" scope="$2"
  TRY_EXCEPTION_LINE=""
  if [ -z "$exc_id" ]; then
    TRY_EXCEPTION_LINE="no Budget-Exception trailer present"
    return 1
  fi
  if [ -z "$scope" ]; then
    TRY_EXCEPTION_LINE="Budget-Exception $exc_id without an explicit Budget-Scope trailer is refused"
    return 1
  fi
  local ticket
  ticket="$(ls -1 "$TICKETS_DIR/$exc_id"*.md 2>/dev/null | sort | head -n 1)"
  if [ -z "${ticket:-}" ]; then
    TRY_EXCEPTION_LINE="Budget-Exception $exc_id matches no ticket record in $TICKETS_DIR"
    return 1
  fi
  if ! grep -q '^status: *OPEN' "$ticket" 2>/dev/null; then
    TRY_EXCEPTION_LINE="Budget-Exception $exc_id ticket is not OPEN: $ticket"
    return 1
  fi
  local field
  for field in Reason Delta Paths Applicability; do
    if ! grep -q "^Exception-$field:" "$ticket" 2>/dev/null; then
      TRY_EXCEPTION_LINE="exception record $ticket missing Exception-$field: line"
      return 1
    fi
  done
  local app today
  app="$(grep '^Exception-Applicability:' "$ticket" 2>/dev/null | tail -n 1 | sed -e 's/^Exception-Applicability: *//' -e 's/[[:space:]]*$//')"
  case "$app" in
  expiry\ *)
    app="${app#expiry }"
    app="$(printf '%s' "$app" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    case "$app" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
    *)
      TRY_EXCEPTION_LINE="exception record $ticket has malformed expiry applicability: $app"
      return 1
      ;;
    esac
    today="$(date +%F)"
    if [[ "$app" < "$today" ]]; then
      TRY_EXCEPTION_LINE="Budget-Exception $exc_id expired on $app (expiry $app before $today)"
      return 1
    fi
    ;;
  commit\ *)
    app="${app#commit }"
    app="$(printf '%s' "$app" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    if [ -z "$app" ]; then
      TRY_EXCEPTION_LINE="exception record $ticket has empty commit applicability"
      return 1
    fi
    if [ "$EVAL_MODE" = "range" ]; then
      case "$EVAL_SHA" in "$app"*)
        ;;
        *)
          TRY_EXCEPTION_LINE="Budget-Exception $exc_id commit applicability $app does not cover $EVAL_SHA"
          return 1
          ;;
      esac
    fi
    ;;
  *)
    TRY_EXCEPTION_LINE="exception record $ticket has unknown applicability (want 'commit <sha>' or 'expiry <YYYY-MM-DD>'): $app"
    return 1
    ;;
  esac
  TRY_EXCEPTION_LINE="Exception-Reason: $(grep '^Exception-Reason:' "$ticket" 2>/dev/null | tail -n 1 | sed 's/^Exception-Reason: *//') [ticket $exc_id]"
  return 0
}

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

print_fails() {
  local line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    fail_emit "$line"
  done <<< "$EVAL_FAILS"
}

report_mode_active() { [ "${BUDGET_GATE_MODE:-}" = "report" ]; }

emit_report_warning() {
  warn_emit "BUDGET_GATE_MODE=report active: budget violations are reported, not blocked (local kill-switch; pre-push --range mode stays blocking)"
}

# ---------------------------------------------------------------------------
# Hook mode: check-budget-gate.sh <message-file>
# ---------------------------------------------------------------------------

hook_mode() {
  MSGFILE="${1:-}"
  if [ -z "$MSGFILE" ]; then
    fail_emit "budget gate usage: check-budget-gate.sh <message-file> | --range <rev>"
    exit 2
  fi
  CHANGED="$(git -C "$ROOT" diff --cached --name-only -z 2>/dev/null | tr '\0' '\n')"

  if ! manifest_load; then
    # Fail-closed only matters when scoped content is staged; the fast path
    # inside eval_commit decides. Pre-seed the error for eval to use.
    :
  fi

  if eval_commit; then
    ok_emit "$EVAL_OK"
    if report_mode_active; then
      emit_report_warning
    fi
    exit 0
  fi

  if report_mode_active; then
    print_fails
    emit_report_warning
    exit 0
  fi
  print_fails
  exit 1
}

# ---------------------------------------------------------------------------
# Range mode: check-budget-gate.sh --range <rev> (always blocking)
# ---------------------------------------------------------------------------

range_mode() {
  local rev="${1:-}"
  if [ -z "$rev" ]; then
    fail_emit "budget gate usage: check-budget-gate.sh --range <rev>"
    exit 2
  fi
  local shas
  if ! shas="$(git -C "$ROOT" rev-list "$rev" 2>/dev/null)"; then
    fail_emit "budget gate: bad range spec: $rev"
    exit 1
  fi
  if ! manifest_load; then
    : # per-commit fail-closed below
  fi
  EVAL_MODE="range"
  local failed=0 sha msg tmp
  tmp="$(mktemp)"
  for sha in $shas; do
    EVAL_SHA="$sha"
    git -C "$ROOT" log -1 --format=%B "$sha" > "$tmp" 2>/dev/null
    MSGFILE="$tmp"
    CHANGED="$(git -C "$ROOT" diff-tree --no-commit-id --name-only -r --root "$sha" 2>/dev/null || true)"
    if eval_commit; then
      ok_emit "$sha $EVAL_OK"
    else
      failed=1
      {
        printf 'FAIL: commit %s blocked:\n' "$sha"
        while IFS= read -r line; do
          [ -n "$line" ] || continue
          printf 'FAIL: [%s] %s\n' "${sha:0:12}" "$line"
        done <<< "$EVAL_FAILS"
      } >&2
    fi
  done
  rm -f "$tmp"
  if [ "$failed" -ne 0 ]; then
    exit 1
  fi
  exit 0
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

if [ "${1:-}" = "--range" ]; then
  range_mode "${2:-}"
else
  hook_mode "${1:-}"
fi
