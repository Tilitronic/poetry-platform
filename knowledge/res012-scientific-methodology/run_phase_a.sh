#!/usr/bin/env bash
set -euo pipefail
# Phase A archival script for res012-scientific-methodology
# Usage: run from repository root: bash knowledge/res012-scientific-methodology/run_phase_a.sh

BASE=knowledge/res012-scientific-methodology
SRC="$BASE/sources"
URLFILE="$SRC/.source-urls.txt"
REPORT="$BASE/phase_a_report.txt"
UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'

mkdir -p "$SRC"
if [ ! -f "$URLFILE" ]; then
  echo "ERROR: URL file not found: $URLFILE" >&2
  exit 1
fi

echo "Phase A archival run: $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$REPORT"
echo "Base: $BASE" >> "$REPORT"

# Detect trafilatura in dev container
CONTAINER_TRAF=1
if docker compose exec -T dev bash -lc "command -v trafilatura >/dev/null 2>&1" >/dev/null 2>&1; then
  echo "Container trafilatura: available" | tee -a "$REPORT"
else
  CONTAINER_TRAF=0
  echo "Container trafilatura: not available" | tee -a "$REPORT"
fi

# Probe host converters if container trafilatura not available
HOST_METHOD="none"
if [ "$CONTAINER_TRAF" -eq 0 ]; then
  if command -v trafilatura >/dev/null 2>&1; then
    HOST_METHOD="trafilatura"
  elif command -v pandoc >/dev/null 2>&1; then
    HOST_METHOD="pandoc"
  elif command -v lynx >/dev/null 2>&1; then
    HOST_METHOD="lynx"
  elif command -v w3m >/dev/null 2>&1; then
    HOST_METHOD="w3m"
  else
    if python3 - <<'PY'
try:
    import html2text
    print('yes')
except Exception:
    pass
PY
    then
      HOST_METHOD="html2text"
    else
      HOST_METHOD="curl"
    fi
  fi
  echo "Host method: $HOST_METHOD" | tee -a "$REPORT"
fi

archived=0
failed_urls=()
total=0

sanitize_slug() {
  # simple slug: index-host-path, non-alphanum -> -
  local url="$1" idx="$2"
  local hostpath
  hostpath=$(echo "$url" | sed -E 's#^https?://##; s#[/:?#].*##' )
  # fallback more complete slug
  local slug
  slug=$(printf "%03d-%s" "$idx" "$url" | tr '[:upper:]' '[:lower:]' | sed -E 's#https?://##g; s#[^a-z0-9]+#-#g; s#-+$##; s#^-+##')
  echo "$slug"
}

idx=0
while IFS= read -r line || [ -n "$line" ]; do
  line_trimmed=$(echo "$line" | sed -e 's/^[[:space:]]*//; s/[[:space:]]*$//')
  case "$line_trimmed" in
    ""|\#*)
      continue
      ;;
  esac
  total=$((total+1))
  idx=$((idx+1))
  url="$line_trimmed"
  slug=$(sanitize_slug "$url" "$idx")

  echo "Archiving ($idx/$total): $url" | tee -a "$REPORT"

  target_md="$SRC/$slug.md"
  target_html="$SRC/$slug.html"
  target_pdf="$SRC/$slug.pdf"

  archived_ok=0

  if [ "$CONTAINER_TRAF" -eq 1 ]; then
    # Use trafilatura inside dev container; it writes into mounted /workspace
    echo "Using container trafilatura for $url" | tee -a "$REPORT"
    if docker compose exec -T dev bash -lc "cd /workspace && trafilatura -u \"$url\" --output-format markdown > \"$PWD/$target_md\"" >/dev/null 2>&1; then
      if [ -s "$target_md" ]; then
        archived_ok=1
      fi
    fi
  else
    case "$HOST_METHOD" in
      trafilatura)
        echo "Using host trafilatura for $url" | tee -a "$REPORT"
        if trafilatura -u "$url" --output-format markdown > "$target_md" 2>/dev/null; then
          if [ -s "$target_md" ]; then archived_ok=1; fi
        fi
        ;;
      pandoc)
        echo "Using pandoc (curl -> pandoc) for $url" | tee -a "$REPORT"
        if curl -sL -A "$UA" "$url" | pandoc -f html -t gfm -o "$target_md" >/dev/null 2>&1; then
          if [ -s "$target_md" ]; then archived_ok=1; fi
        fi
        ;;
      html2text)
        echo "Using python html2text for $url" | tee -a "$REPORT"
        if curl -sL -A "$UA" "$url" | python3 -c "import sys,html2text; print(html2text.html2text(sys.stdin.read()))" > "$target_md" 2>/dev/null; then
          if [ -s "$target_md" ]; then archived_ok=1; fi
        fi
        ;;
      curl)
        echo "Falling back to raw curl for $url" | tee -a "$REPORT"
        # determine if likely pdf by extension
        if echo "$url" | grep -Ei '\\.pdf(\$|\?)' >/dev/null 2>&1; then
          curl -sL -A "$UA" "$url" -o "$target_pdf" || true
          # verify pdf
          if [ -f "$target_pdf" ]; then
            if file "$target_pdf" | grep -i pdf >/dev/null 2>&1; then
              archived_ok=1
            fi
          fi
        else
          curl -sL -A "$UA" "$url" -o "$target_html" || true
          if [ -f "$target_html" ] && [ $(wc -c < "$target_html") -gt 100 ]; then
            archived_ok=1
          fi
        fi
        ;;
      *)
        echo "No host method available, attempting raw curl for $url" | tee -a "$REPORT"
        curl -sL -A "$UA" "$url" -o "$target_html" || true
        if [ -f "$target_html" ] && [ $(wc -c < "$target_html") -gt 100 ]; then
          archived_ok=1
        fi
        ;;
    esac
  fi

  # Retry once with --compressed if initial attempt failed
  if [ "$archived_ok" -eq 0 ]; then
    echo "Initial attempt failed for $url, retrying with --compressed" | tee -a "$REPORT"
    if [ "$CONTAINER_TRAF" -eq 1 ]; then
      if docker compose exec -T dev bash -lc "cd /workspace && trafilatura -u \"$url\" --output-format markdown > \"$PWD/$target_md\"" >/dev/null 2>&1; then
        if [ -s "$target_md" ]; then archived_ok=1; fi
      fi
    else
      # retry curl-based fallback
      if echo "$url" | grep -Ei '\\.pdf(\$|\?)' >/dev/null 2>&1; then
        curl -sL --compressed -A "$UA" "$url" -o "$target_pdf" || true
        if [ -f "$target_pdf" ] && file "$target_pdf" | grep -i pdf >/dev/null 2>&1; then archived_ok=1; fi
      else
        curl -sL --compressed -A "$UA" "$url" -o "$target_html" || true
        if [ -f "$target_html" ] && [ $(wc -c < "$target_html") -gt 100 ]; then archived_ok=1; fi
      fi
    fi
  fi

  if [ "$archived_ok" -eq 1 ]; then
    echo "ARCHIVED: $url -> $(ls -1 "$SRC" | tail -n 1)" | tee -a "$REPORT"
    archived=$((archived+1))
  else
    echo "NOT ARCHIVED: $url" | tee -a "$REPORT"
    failed_urls+=("$url")
    # annotate the URL file with a NOT ARCHIVED marker (append marker line)
    sed -i "/$(echo "$url" | sed 's/[].*[^]/\&/g')/a # NOT ARCHIVED (all methods exhausted)" "$URLFILE" || true
  fi

done < "$URLFILE"

echo "Summary: total=$total archived=$archived failed=${#failed_urls[@]}" | tee -a "$REPORT"
if [ ${#failed_urls[@]} -gt 0 ]; then
  echo "Failed URLs:" >> "$REPORT"
  for u in "${failed_urls[@]}"; do
    echo "$u" >> "$REPORT"
  done
fi

echo "Phase A complete. See $REPORT and contents of $SRC for archived files." | tee -a "$REPORT"

exit 0
