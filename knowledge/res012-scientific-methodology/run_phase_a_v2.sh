#!/usr/bin/env bash
# Phase A archival v2: HOST-only runner (docker bypassed per DIA-086 fix).
# Fixes the three previously diagnosed defects:
#   D1 docker stdin drain       -> no docker compose exec at all
#   D2 container write path     -> all writes happen on the host filesystem
#   D3 sed NOT-ARCHIVED escape  -> python exact-match annotation (delimiter-safe)
# Idempotent: re-runs skip URLs that already have an archived file, and
# previously annotated (failed) URLs are retried from scratch.
# Usage: bash knowledge/res012-scientific-methodology/run_phase_a_v2.sh
set -uo pipefail

BASE=knowledge/res012-scientific-methodology
SRC="$BASE/sources"
URLFILE="$SRC/.source-urls.txt"
REPORT="$BASE/phase_a_report.txt"
UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
MIN_BYTES=100
ANNOT='# NOT ARCHIVED (all methods exhausted)'

mkdir -p "$SRC"
if [ ! -f "$URLFILE" ]; then
  echo "ERROR: URL file not found: $URLFILE" >&2
  exit 1
fi
if ! command -v trafilatura >/dev/null 2>&1; then
  echo "ERROR: host trafilatura not found" >&2
  exit 1
fi

echo "Phase A archival run (v2 host-only): $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$REPORT"
echo "Method: host trafilatura + curl fallback (docker bypassed per DIA-086 fix)" >> "$REPORT"

archived=0; total=0; idx=0
md_count=0; html_count=0; pdf_count=0
failed_urls=()

sanitize_slug() {
  local url="$1" idx="$2" slug
  slug=$(printf "%03d-%s" "$idx" "$url" | tr '[:upper:]' '[:lower:]' \
    | sed -E 's#https?://##g; s#[^a-z0-9]+#-#g; s#-+$##; s#^-+##')
  echo "$slug"
}

# D3 fix: exact-match, delimiter-safe annotation (no sed escaping issues,
# no double-annotation on re-runs)
annotate_failed() {
  local url="$1"
  python3 - "$URLFILE" "$url" "$ANNOT" <<'PY' || true
import sys
path, url, annot = sys.argv[1], sys.argv[2], sys.argv[3]
out = []
for ln in open(path, encoding='utf-8').read().splitlines():
    stripped = ln.rstrip()
    if stripped == url and not stripped.endswith(annot):
        stripped = url + ' ' + annot
    out.append(stripped)
open(path, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
PY
}

is_pdf_url() {
  case "$url" in
    *.pdf|*.pdf\?*) return 0 ;;
    */pdf/*) return 0 ;; # arxiv pdf URLs lack a .pdf extension: /pdf/<id>
    https://aclanthology.org/*/) return 0 ;;
  esac
  return 1
}

# Direct curl for PDF URLs, verified with file(1); one --compressed retry.
fetch_pdf() {
  local url="$1" out="$2" src="$url"
  case "$url" in
    https://aclanthology.org/*/)
      src="${url%/}.pdf" ;;
  esac
  curl -sL --max-time 90 -A "$UA" "$src" -o "$out" || true
  if [ -s "$out" ] && file "$out" 2>/dev/null | grep -qi 'pdf document'; then
    return 0
  fi
  curl -sL --compressed --max-time 90 -A "$UA" "$src" -o "$out" || true
  if [ -s "$out" ] && file "$out" 2>/dev/null | grep -qi 'pdf document'; then
    return 0
  fi
  rm -f "$out"
  return 1
}

# Raw curl HTML with browser UA when trafilatura yields nothing useful.
fetch_html_fallback() {
  local url="$1" out="$2"
  curl -sL --max-time 90 -A "$UA" "$url" -o "$out" || true
  if [ -f "$out" ] && [ "$(wc -c < "$out")" -gt "$MIN_BYTES" ]; then
    return 0
  fi
  curl -sL --compressed --max-time 90 -A "$UA" "$url" -o "$out" || true
  if [ -f "$out" ] && [ "$(wc -c < "$out")" -gt "$MIN_BYTES" ]; then
    return 0
  fi
  rm -f "$out"
  return 1
}

# trafilatura to markdown; success only when > MIN_BYTES bytes are produced
# and the output is not a JS-blocked placeholder page (nature.com etc. return
# only "JavaScript is disabled..." to non-JS clients; those must fall through
# to the raw curl fallback which receives the real article HTML).
try_trafilatura() {
  local url="$1" out="$2"
  trafilatura -u "$url" --output-format markdown > "$out" 2>/dev/null
  if [ -f "$out" ] && [ "$(wc -c < "$out")" -gt "$MIN_BYTES" ] \
     && ! grep -q 'JavaScript is disabled in your browser' "$out" 2>/dev/null; then
    return 0
  fi
  rm -f "$out"
  return 1
}

while IFS= read -r line || [ -n "$line" ]; do
  line_trimmed=$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//; s/[[:space:]]*$//')
  # strip a prior NOT ARCHIVED annotation so failed URLs are retried on re-run
  line_trimmed=${line_trimmed% $ANNOT}
  case "$line_trimmed" in
    ""|\#*) continue ;;
  esac
  total=$((total+1)); idx=$((idx+1))
  url="$line_trimmed"
  slug=$(sanitize_slug "$url" "$idx")

  target_md="$SRC/$slug.md"
  target_html="$SRC/$slug.html"
  target_pdf="$SRC/$slug.pdf"

  # idempotency: keep an existing archive from a prior run
  if [ -f "$target_md" ] || [ -f "$target_html" ] || [ -f "$target_pdf" ]; then
    echo "SKIP (already archived): $url" | tee -a "$REPORT"
    archived=$((archived+1))
    if [ -f "$target_md" ]; then md_count=$((md_count+1))
    elif [ -f "$target_pdf" ]; then pdf_count=$((pdf_count+1))
    elif [ -f "$target_html" ]; then html_count=$((html_count+1))
    fi
    continue
  fi

  echo "Archiving ($idx/$total): $url" | tee -a "$REPORT"
  archived_ok=0

  if is_pdf_url; then
    echo "  pdf: curl direct" | tee -a "$REPORT"
    if fetch_pdf "$url" "$target_pdf"; then
      archived_ok=1; pdf_count=$((pdf_count+1))
    elif [[ "$url" == https://aclanthology.org/* ]]; then
      # .pdf sibling may 404; rescue via trafilatura on the landing page
      echo "  pdf fetch failed; rescue via trafilatura on landing page" | tee -a "$REPORT"
      if try_trafilatura "$url" "$target_md"; then
        archived_ok=1; md_count=$((md_count+1))
      fi
    fi
  else
    if [[ "$url" == https://arxiv.org/abs/* ]]; then
      arxiv_id=${url#https://arxiv.org/abs/}
      echo "  trafilatura (arxiv abs): $url" | tee -a "$REPORT"
      if try_trafilatura "$url" "$target_md"; then
        archived_ok=1; md_count=$((md_count+1))
      else
        # thin/empty abs page: retry the html rendering of the same paper
        echo "  thin abs page; trying arxiv html: https://arxiv.org/html/$arxiv_id" | tee -a "$REPORT"
        if try_trafilatura "https://arxiv.org/html/$arxiv_id" "$target_md"; then
          archived_ok=1; md_count=$((md_count+1))
        fi
      fi
    else
      echo "  trafilatura: $url" | tee -a "$REPORT"
      if try_trafilatura "$url" "$target_md"; then
        archived_ok=1; md_count=$((md_count+1))
      fi
    fi
    # fall back to raw curl HTML when trafilatura yielded nothing useful
    if [ "$archived_ok" -eq 0 ]; then
      echo "  trafilatura yielded nothing useful; curl html fallback" | tee -a "$REPORT"
      if fetch_html_fallback "$url" "$target_html"; then
        archived_ok=1; html_count=$((html_count+1))
      fi
    fi
  fi

  if [ "$archived_ok" -eq 1 ]; then
    echo "ARCHIVED: $url" | tee -a "$REPORT"
    archived=$((archived+1))
  else
    echo "NOT ARCHIVED: $url" | tee -a "$REPORT"
    failed_urls+=("$url")
    annotate_failed "$url"
  fi
done < "$URLFILE"

echo "Summary: total=$total archived=$archived (md=$md_count html=$html_count pdf=$pdf_count) failed=${#failed_urls[@]}" | tee -a "$REPORT"
if [ ${#failed_urls[@]} -gt 0 ]; then
  echo "Failed URLs:" >> "$REPORT"
  for u in "${failed_urls[@]}"; do
    echo "$u" >> "$REPORT"
  done
fi
echo "Phase A v2 complete. See $REPORT and $SRC for archived files." | tee -a "$REPORT"

exit 0
