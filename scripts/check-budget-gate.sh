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
#                                         commit in the range, always blocking,
#                                         with ONE narrow exception: a commit
#                                         whose tree lacks
#                                         scripts/budget-baselines.json is a
#                                         pre-gate-history commit and is
#                                         skipped with a warn line (never
#                                         silently); any tree that HAS the
#                                         manifest keeps fail-closed behavior
# Env:
#   BUDGET_MANIFEST    manifest path (default scripts/budget-baselines.json)
#   TICKETS_DIR        ticket ledger dir (default docs/dev-infra-audit/tickets)
#   BUDGET_PLUGIN_ROOT plugin tree root (default .opencode/plugins); a staged
#                      path is scoped iff it sits under this root, role by
#                      layout: delegation-observer.ts = prod+shell, lib/ = prod,
#                      __tests__/ = test. A set-but-unresolvable value fails
#                      closed (never a silent gate-off).
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
# to the caller's checkout for manifest/ticket resolution, but scoping
# REFUSES (regression-5b): _PR_OK stays 0 and eval_commit fails closed, so a
# typo'd root can never silently scope nothing out.
ROOT="$CWD_ROOT"
_PR_OK=0
if [ -n "${BUDGET_PLUGIN_ROOT:-}" ]; then
  case "$BUDGET_PLUGIN_ROOT" in
    /*) _PR="$BUDGET_PLUGIN_ROOT" ;;
    *) _PR="$CWD_ROOT/$BUDGET_PLUGIN_ROOT" ;;
  esac
  if _RR="$(git -C "$_PR" rev-parse --show-toplevel 2>/dev/null)"; then
    ROOT="$_RR"
    _PR_OK=1
  fi
fi

MANIFEST="${BUDGET_MANIFEST:-$ROOT/scripts/budget-baselines.json}"
case "$MANIFEST" in /*) ;; *) MANIFEST="$ROOT/$MANIFEST" ;; esac
# Repo-relative manifest path for tree reads (M2): when the override points
# outside the gated repo there is no tree path, so tree_show fails and the
# gate fails closed for scoped commits.
case "$MANIFEST" in "$ROOT"/*) MANIFEST_REL="${MANIFEST#$ROOT/}" ;; *) MANIFEST_REL="$MANIFEST" ;; esac
# Ledger resolution split (DIA-260901-91qy): hook mode reads the ticket
# ledger from disk -- approvals are present-tense human state, and the hook
# gates what is about to be committed. Range mode instead reads each record
# from the evaluated commit tree ($EVAL_SHA, same git-show technique as the
# M2 manifest), so a historical commit is judged by the ticket status it saw:
# OPEN-then/CLOSED-today passes, CLOSED-already fails. A ledger outside the
# gated repo has no tree path and falls back to disk in both modes.
TICKETS_DIR="${TICKETS_DIR:-$ROOT/docs/dev-infra-audit/tickets}"
# Repo-relative ledger path for range tree reads: only meaningful when the
# ledger lives inside the gated repo (empty otherwise, meaning disk fallback).
_TD_ABS="$TICKETS_DIR"
case "$_TD_ABS" in */) _TD_ABS="${_TD_ABS%/}" ;; esac
case "$_TD_ABS" in /*) ;; *) _TD_ABS="$ROOT/$_TD_ABS" ;; esac
case "$_TD_ABS" in "$ROOT"/*) TICKETS_REL="${_TD_ABS#$ROOT/}" ;; *) TICKETS_REL="" ;; esac
# Absolutize exactly like _PR above (M1): a relative BUDGET_PLUGIN_ROOT
# resolves against the caller's checkout via the already-computed _PR. Without
# this a relative override never prefix-matches the absolute staged paths, so
# the gate silently scopes nothing out. Unset keeps the default plugin tree.
# A SET-but-unresolvable override (_PR_OK=0) also falls back to the default
# tree here; that path never enforces by itself (see the eval_commit refusal
# below), it only keeps every downstream path absolute and inside the repo.
if [ -n "${BUDGET_PLUGIN_ROOT:-}" ] && [ "$_PR_OK" -eq 1 ]; then
  PLUGIN_ROOT="$_PR"
else
  PLUGIN_ROOT="$ROOT/.opencode/plugins"
fi
case "$PLUGIN_ROOT" in */) PLUGIN_ROOT="${PLUGIN_ROOT%/}" ;; esac
case "$MANIFEST" in */) MANIFEST="${MANIFEST%/}" ;; esac

case "$PLUGIN_ROOT" in "$ROOT"/*) PLUGREL="${PLUGIN_ROOT#$ROOT/}" ;; *) PLUGREL="$PLUGIN_ROOT" ;; esac

# /home/qualt regression guard (F-6, DIA-179, M5): the same shared definition
# the sibling hooks source (verify-pre-commit.sh:58, verify-pre-push.sh:70).
# .husky/commit-msg delegates to this script instead of sourcing the guard
# itself, so the commit-msg path sources it here; COMMANDS_DIR mirrors the
# sibling POETRY_COMMANDS_DIR seam so bats fixtures stay hermetic. CWD_ROOT is
# already validated above, so the guard file always resolves in production.
COMMANDS_DIR="${POETRY_COMMANDS_DIR:-$ROOT/.opencode/commands}"
# shellcheck disable=SC1091
source "$CWD_ROOT/scripts/guards/home-qualt.sh"

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

# manifest_absent_from_tree: true iff the manifest path is absent from the
# commit under evaluation (EVAL_SHA). Range-mode only: an outside-repo
# manifest override is never "absent" (it fails closed instead).
manifest_absent_from_tree() {
  case "$MANIFEST" in "$ROOT"/*) ;;
    *) return 1 ;;
  esac
  ! git -C "$ROOT" cat-file -e "$EVAL_SHA:$MANIFEST_REL" 2>/dev/null
}

# tree_ls: NUL-delimited repo-relative paths of the tracked tree.
tree_ls() {
  if [ "$EVAL_MODE" = "range" ]; then
    git -C "$ROOT" ls-tree -r --name-only -z "$EVAL_SHA" -- "$PLUGREL" 2>/dev/null || true
  else
    git -C "$ROOT" ls-files -z -- "$PLUGREL" 2>/dev/null || true
  fi
}

# ticket_text <ticket-ref>: approval-record bytes to stdout. In range mode
# with an in-repo ledger <ticket-ref> is a repo-relative tree path (read via
# tree_show at $EVAL_SHA); otherwise it is a disk path (read via cat).
# Keeps the validation body below mode-blind.
ticket_text() {
  if [ "$EVAL_MODE" = "range" ] && [ -n "${TICKETS_REL:-}" ]; then
    tree_show "$1" 2>/dev/null
  else
    cat "$1" 2>/dev/null
  fi
}

# ticket_tree_first <id-prefix>: first sorted repo-relative ticket path in the
# EVAL_SHA tree whose basename matches "<prefix>"*.md (same sorted head -1
# contract as the disk ls). Prints nothing when the ledger lives outside the
# gated repo (TICKETS_REL empty) or no record matches. Range-only helper.
ticket_tree_first() {
  [ -n "${TICKETS_REL:-}" ] || return 0
  local prefix="$1" f base
  git -C "$ROOT" ls-tree -r --name-only "$EVAL_SHA" -- "$TICKETS_REL" 2>/dev/null |
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      base="${f##*/}"
      case "$base" in "$prefix"*.md) printf '%s\n' "$f" ;; esac
    done | sort | head -n 1
  return 0
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
  MANIFEST_OK=0
  if ! command -v jq >/dev/null 2>&1; then
    MANIFEST_ERR="jq unavailable; cannot parse budget manifest"
    return 1
  fi
  # Read the manifest from the EVALUATED tree (M2: staged index in hook mode
  # via "git show :path", commit tree in range mode via
  # "git show $EVAL_SHA:path"), never from working-tree disk. Disk content is
  # not what becomes history: unstaged drift must neither falsely block nor
  # falsely pass, and a range check must see the baselines as committed.
  local content
  if ! content="$(tree_show "$MANIFEST_REL" 2>/dev/null)"; then
    MANIFEST_ERR="budget manifest not found in evaluated tree: $MANIFEST"
    return 1
  fi
  if ! printf '%s' "$content" | jq -e '
    (.prod_ceiling | type == "number") and
    (.shell_ceiling | type == "number") and
    (.patterns | type == "array") and
    (.campaigns | type == "array") and
    ([.patterns[] | ((.id | type) == "string" and (.canonical | type) == "string"
      and (.baseline_count | type) == "number"
      and (.authorized_site | type) == "string")] | all) and
    ([.campaigns[] | ((.ticket | type) == "string" and (.ticket | length > 0)
      and (.scope | type) == "string" and (.status | type) == "string")] | all)
  ' >/dev/null 2>&1; then
    MANIFEST_ERR="budget manifest invalid (not JSON or schema violation): $MANIFEST"
    return 1
  fi
  PROD_CEIL="$(printf '%s' "$content" | jq -r '.prod_ceiling')"
  SHELL_CEIL="$(printf '%s' "$content" | jq -r '.shell_ceiling')"
  PATTERNS_TSV="$(printf '%s' "$content" | jq -r '.patterns[] | [.id, .canonical, (.baseline_count | tostring), .authorized_site] | join("\t")')"
  CAMPAIGNS_TSV="$(printf '%s' "$content" | jq -r '.campaigns[] | [.scope, .status, .ticket] | join("\t")')"
  MANIFEST_OK=1
  return 0
}

# has_backing <scope>: an approved campaign entry for the declared scope
# whose ticket resolves in the ledger (M4: same lookup as try_exception --
# filename prefix plus status OPEN minimum). The manifest must not be able to
# self-approve: a campaign entry naming a nonexistent or closed ticket is not
# backing, so the scope claim fails closed.
has_backing() {
  [ -n "${1:-}" ] || return 1
  local scope="$1" line c_scope c_status c_ticket tfile tpath
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    c_scope="$(printf '%s' "$line" | cut -f1)"
    c_status="$(printf '%s' "$line" | cut -f2)"
    c_ticket="$(printf '%s' "$line" | cut -f3)"
    if [ "$c_scope" = "$scope" ] && [ "$c_status" = "approved" ]; then
      # Range mode with an in-repo ledger reads the record from the evaluated
      # commit tree (authoritative: no disk fallback, so CLOSED-at-commit
      # cannot pass on today's OPEN). Hook mode and outside-repo ledgers
      # keep the disk OPEN requirement.
      if [ "$EVAL_MODE" = "range" ] && [ -n "${TICKETS_REL:-}" ]; then
        tpath="$(ticket_tree_first "$c_ticket")"
        if [ -n "${tpath:-}" ] && ticket_text "$tpath" | grep -q '^status: *OPEN'; then
          return 0
        fi
        continue
      fi
      tfile="$(ls -1 "$TICKETS_DIR/$c_ticket"*.md 2>/dev/null | sort | head -n 1)"
      if [ -n "${tfile:-}" ] && grep -q '^status: *OPEN' "$tfile" 2>/dev/null; then
        return 0
      fi
    fi
  done <<< "$CAMPAIGNS_TSV"
  return 1
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

  # Unresolvable plugin-root override fails closed (regression-5b), BEFORE the
  # fast path: with no resolvable tree the gate cannot scope anything, so
  # "no scoped paths touched" would be a silent gate-off, not a verdict.
  # Falling back to the default tree is NOT enough (a typo'd root still
  # scopes nothing under the default), so refuse outright. Hook report mode
  # still softens this to warn+allow per convention; range mode stays
  # blocking.
  if [ -n "${BUDGET_PLUGIN_ROOT:-}" ] && [ "$_PR_OK" -eq 0 ]; then
    EVAL_FAILS="BUDGET_PLUGIN_ROOT does not resolve to a git tree ($BUDGET_PLUGIN_ROOT); refusing to guess scope (unset it or point it at the plugin tree)"
    return 1
  fi

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
    local pid pcanon pbase pauth ncanon count base _match_status
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
        # Suspend pipefail for the match pipeline (M3): grep -q exits on the
        # first match, SIGPIPEing the upstream tr; under pipefail that
        # non-zero tr status would mask grep's match and undercount files
        # whose match sits early in the stream. Only grep's status decides.
        set +o pipefail
        tree_show "$f" 2>/dev/null | budget_normalize | grep -qF -- "$ncanon"
        _match_status=$?
        set -o pipefail
        if [ "$_match_status" -eq 0 ]; then
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
  # Range mode with an in-repo ledger resolves the record in the evaluated
  # commit tree (authoritative: no disk fallback, so CLOSED-at-commit cannot
  # pass on today's OPEN). Hook mode and outside-repo ledgers keep the disk
  # lookup. All content checks below read via ticket_text, so the validation
  # body stays mode-blind.
  if [ "$EVAL_MODE" = "range" ] && [ -n "${TICKETS_REL:-}" ]; then
    ticket="$(ticket_tree_first "$exc_id")"
  else
    ticket="$(ls -1 "$TICKETS_DIR/$exc_id"*.md 2>/dev/null | sort | head -n 1)"
  fi
  if [ -z "${ticket:-}" ]; then
    TRY_EXCEPTION_LINE="Budget-Exception $exc_id matches no ticket record in $TICKETS_DIR"
    return 1
  fi
  if ! ticket_text "$ticket" | grep -q '^status: *OPEN'; then
    TRY_EXCEPTION_LINE="Budget-Exception $exc_id ticket is not OPEN: $ticket"
    return 1
  fi
  local field
  for field in Reason Delta Paths Applicability; do
    if ! ticket_text "$ticket" | grep -q "^Exception-$field:"; then
      TRY_EXCEPTION_LINE="exception record $ticket missing Exception-$field: line"
      return 1
    fi
  done
  local app today
  app="$(ticket_text "$ticket" | grep '^Exception-Applicability:' | tail -n 1 | sed -e 's/^Exception-Applicability: *//' -e 's/[[:space:]]*$//')"
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
  TRY_EXCEPTION_LINE="Exception-Reason: $(ticket_text "$ticket" | grep '^Exception-Reason:' | tail -n 1 | sed 's/^Exception-Reason: *//') [ticket $exc_id]"
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
  # Shared /home/qualt guard (sourced at top level per sibling convention):
  # reject dirty files before any budget evaluation, exactly like the sibling
  # hooks do at theirs. The command -v guard keeps hermetic fixture runs (no
  # guard file under the fixture root) on the budget behavior alone.
  if command -v guard_no_home_qualt >/dev/null 2>&1; then
    guard_no_home_qualt
  fi
  # Close the silent gate-off (M1): an explicit plugin-root override relocates
  # scoping, so hook mode always names it when set. Production runs leave it
  # unset; hermetic fixtures set it to an isolated tree.
  if [ -n "${BUDGET_PLUGIN_ROOT:-}" ]; then
    warn_emit "BUDGET_PLUGIN_ROOT override active ($BUDGET_PLUGIN_ROOT): scoping to $PLUGIN_ROOT (fixture/test override; production runs leave it unset)"
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
  EVAL_MODE="range"
  local failed=0 sha msg tmp
  tmp="$(mktemp)"
  for sha in $shas; do
    EVAL_SHA="$sha"
    # Per-commit manifest (M2): the baselines as committed at $EVAL_SHA, never
    # current disk. Reset first so a prior commit's success cannot mask this
    # commit's load failure; per-commit fail-closed lands in eval_commit.
    MANIFEST_OK=0
    if ! manifest_load; then
      # Pre-gate-history exemption (obs1): a commit whose tree predates the
      # manifest holds no baselines to evaluate against, so skip it WITH a
      # mandatory warn line (never silently). A tree that HAS the manifest
      # keeps fail-closed behavior below: missing/invalid still blocks.
      if manifest_absent_from_tree; then
        warn_emit "budget gate: no manifest in commit ${sha:0:12} ($MANIFEST_REL absent from tree); skipping pre-gate-history commit"
        ok_emit "$sha skipped (pre-gate-history: no manifest in tree)"
        continue
      fi
      : # present-but-broken manifest: per-commit fail-closed below
    fi
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
