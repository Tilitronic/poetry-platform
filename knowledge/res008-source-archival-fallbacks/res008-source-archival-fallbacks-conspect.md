Title: Source-archival fallback strategies for the knowledge pipeline (DIA-072)

Created: 2026-08-09

Sources (archived copies saved under ./sources/)

- GitHub: npm/registry — package-metadata.md (saved via trafilatura)
- npm crawler policy — docs.npmjs.com/policies/crawlers (saved via trafilatura)
- Trafilatura settings & troubleshooting (readthedocs) (saved via trafilatura)
- crawl4ai docs & repo (saved via trafilatura)
- npm policies: open-source terms (saved via trafilatura)
- npm registry JSON API: opencode-telemetry, opencode-token-monitor (saved as JSON)
- npmjs package page @devtheops/opencode-plugin-otel (NOT ARCHIVED — UA blocking)
- ccusage.com/guide/opencode (NOT ARCHIVED — UA blocking)

Executive summary

This conspect documents a validated three-tier archival fallback chain for our research pipeline when standard trafilatura extraction fails, and explains why certain npm/npmjs endpoints must be treated specially (registry JSON API vs website HTML). The chain tested here is:

1) registry JSON API (registry.npmjs.org) — use curl to fetch package JSON; this is authoritative and intended for programmatic access.
2) trafilatura CLI extraction — default first attempt for HTML pages.
3) curl with a browser User-Agent piped into trafilatura — for sites that block default tool UAs.
4) crawl4ai headless Chromium fallback — for JS-heavy or anti-bot pages (requires crawl4ai installed).

Key findings

- registry.npmjs.org serves package metadata as JSON. trafilatura produces 0 bytes for these endpoints because they are JSON APIs, not HTML pages; curl (or HTTP client) must be used and the JSON saved directly. Two registry URLs were archived as JSON successfully: opencode-telemetry (43,336 bytes) and opencode-token-monitor (21,987 bytes).
- npm's crawler policy (docs.npmjs.com/policies/crawlers) endorses programmatic access via CouchDB replication and requests experimental crawlers limit velocity to ≤1 request/second. High-velocity scraping of the website may be rate-limited or blocked.
- Trafilatura default settings have empty USER_AGENTS and minimal UA; some sites (npmjs and ccusage) block default tool UAs. Trafilatura's settings.cfg allows overriding USER_AGENTS or passing a config file; programmatic overrides are documented in settings.py and the CLI supports --config-file.
- For npmjs package pages (www.npmjs.com), trafilatura often returns empty extraction due to dynamic content and UA-based blocking; curl+UA piped into trafilatura also failed for the tested package page. crawl4ai (headless Chromium) is the intended fallback for JS-heavy pages but was not available in the test environment. Two previously-failing URLs remain NOT ARCHIVED: https://www.npmjs.com/package/@devtheops/opencode-plugin-otel and https://ccusage.com/guide/opencode/ (both marked in sources/ as NOT_ARCHIVED).

Per-URL archival results (methods attempted shown)

1. https://github.com/npm/registry/blob/master/docs/responses/package-metadata.md — SUCCESS (trafilatura, 10,626 bytes)
2. https://docs.npmjs.com/policies/crawlers/ — SUCCESS (trafilatura, 1,108 bytes)
3. https://trafilatura.readthedocs.io/en/latest/settings.html — SUCCESS (trafilatura, 6,384 bytes)
4. https://trafilatura.readthedocs.io/en/latest/troubleshooting.html — SUCCESS (trafilatura, 3,336 bytes)
5. https://docs.crawl4ai.com/core/browser-crawler-config/ — SUCCESS (trafilatura, 19,104 bytes)
6. https://github.com/unclecode/crawl4ai — SUCCESS (trafilatura, 42,070 bytes)
7. https://docs.npmjs.org/policies/open-source-terms — SUCCESS (trafilatura, 20,818 bytes)
8. https://registry.npmjs.org/opencode-telemetry — SUCCESS (curl JSON, 43,336 bytes)
9. https://registry.npmjs.org/opencode-token-monitor — SUCCESS (curl JSON, 21,987 bytes)
10. https://www.npmjs.com/package/@devtheops/opencode-plugin-otel — FAILED (trafilatura→curl+UA→crawl4ai not available) — marked [source not archived]
11. https://ccusage.com/guide/opencode/ — FAILED (trafilatura→curl+UA→crawl4ai not available) — marked [source not archived]

Why registry.npmjs.org must be handled as JSON

The registry endpoint is an HTTP API returning JSON; feeding it to an HTML extractor yields no meaningful output. The registry docs explicitly show the API contract (GET https://registry.npmjs.org/:package) and recommend using Accept headers for abbreviated vs full metadata. The proper archival is to save the raw JSON response (curl -s) and store as .json in sources/.

Trafilatura UA and settings considerations

- Trafilatura's default USER_AGENTS is empty. Sites that apply UA-based filtering will therefore treat trafilatura as a non-browser client and may return minimal/blocked content. Settings can be overridden by providing a settings.cfg with USER_AGENTS populated or by passing downloaded HTML produced by curl with a browser UA into trafilatura's stdin (programmatic fallback).
- The settings file also includes MIN_OUTPUT_SIZE and MIN_EXTRACTED_SIZE which control whether content is kept; increasing these can cause more discards, so for archival we should set MIN_OUTPUT_SIZE to a low value and rely on post-filtering instead.

crawl4ai headless fallback

- crawl4ai provides a headless Chromium crawler with configurable BrowserConfig; it is suitable for JS-rendered pages and stealth configuration. When available, it should be used after trafilatura and curl+UA fail. In the test environment crawl4ai was not installed; when present, use a headless BrowserConfig(headless=True) and save output as markdown.

Validated fallback chain (recommended implementation)

1) If host is registry.npmjs.org -> curl -s "<url>" > sources/<slug>.json (always first for registry hosts)
2) trafilatura -u "<URL>" --output-format markdown > sources/<slug>.md
3) If trafilatura small (<100 bytes) -> curl -sL -A "<browser UA>" "<URL>" | trafilatura --output-format markdown > sources/<slug>.md (or equivalent programmatic call)
4) If still small -> crawl4ai fetch "<URL>" -o sources/<slug>.crawl4ai.md (headless Chromium)

Test evidence summary (re-tested previously-failing URLs)

- registry.npmjs.org/opencode-telemetry — archived successfully via curl JSON; file saved as sources/registry.npmjs.org-opencode-telemetry.json (43,336 bytes)
- registry.npmjs.org/opencode-token-monitor — archived successfully via curl JSON; file saved as sources/registry.npmjs.org-opencode-token-monitor.json (21,987 bytes)
- www.npmjs.com/package/@devtheops/opencode-plugin-otel — trafilatura and curl+UA produced empty output in this environment; crawl4ai not available; marked NOT ARCHIVED. Likely cause: npmjs blocks non-browser UAs and uses client-side JS to render important content.
- ccusage.com/guide/opencode — similarly NOT ARCHIVED; UA blocking or content gate likely. Requires crawl4ai or alternative headless browser.

Memory Shelf registration

This conspect is registered under shelf.conspects in .opencode/memory-shelf.yaml as:

- name: "Source-archival fallback strategies (DIA-072)"
  description: "Validated tiered archival strategy for npm registry and JS-heavy pages (trafilatura, curl+UA, crawl4ai). Includes per-URL results for the DIA-072 acceptance list."
  path: "knowledge/res008-source-archival-fallbacks/res008-source-archival-fallbacks-conspect.md"
  created: 2026-08-09

Files created

- knowledge/res008-source-archival-fallbacks/
- knowledge/res008-source-archival-fallbacks/.source-urls.txt
- knowledge/res008-source-archival-fallbacks/sources/ (archived files and .NOT_ARCHIVED markers)
- knowledge/res008-source-archival-fallbacks/res008-source-archival-fallbacks-conspect.md

Remaining failures

- https://www.npmjs.com/package/@devtheops/opencode-plugin-otel — NOT ARCHIVED (requires headless browser or whitelisted UA)
- https://ccusage.com/guide/opencode/ — NOT ARCHIVED (requires headless browser or whitelisted UA)

Recommendations

1. Implement the validated 3–4 tier chain in the researcher → conspecter pipeline. Registry hosts get special handling (JSON save).
2. Provision crawl4ai (or another headless Chromium) in the dev environment (DIA ticket) so JS-heavy pages and UA-blocked sites can be archived.
3. Default trafilatura settings in production should include a USER_AGENTS list or we should prefetch HTML with a browser UA when safe and permitted by site policy.
4. Record NOT_ARCHIVED markers in .source-urls.txt and conspect with [source not archived] markers for acceptance evidence; do not silently skip.
