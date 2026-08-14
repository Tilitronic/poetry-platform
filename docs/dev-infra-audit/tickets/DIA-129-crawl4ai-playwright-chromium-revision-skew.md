# DIA-129 - crawl4ai crwl fallback fails: Playwright pins chromium revision 1228, host cache has 1234 only

<!-- UPDATE 2026-08-13 (FIX + RE-VERIFY PASS - TICKET CLOSED): Remediation = ticket
     OPTION 1 (install pinned revision via crawl4ai's own Playwright driver).
     crawl4ai 0.9.2 (uv tool at ~/.local/share/uv/tools/crawl4ai) pins Playwright
     1.61.0 -> chromium v1228 (Chrome for Testing 149.0.7827.55). Host cache
     previously held only chromium-1234. Fix: ran `playwright install chromium`
     through crawl4ai's OWN driver (compute_driver_executable + install chromium,
     RC=0); chromium-1228 (177MiB) + chromium_headless_shell-1228 (114.2MiB) landed
     in ~/.cache/ms-playwright/. Additive + reversible; ZERO repo changes; no
     config/env override; no crawl4ai upgrade. RE-VERIFY PASS: `playwright install
     --dry-run` (crawl4ai driver) now shows 1228 install locations PRESENT; three
     real crawls (github.com/unclecode/crawl4ai README 75,139 bytes;
     crawl4ai.com/mcp-server/; docs.crawl4ai.com/core/cli/ 14,824 bytes) all exit 0
     with real content >100 bytes; `Executable doesn't exist` and `has no
     attribute` error strings = 0 across outputs; the single browser_type hit is
     README content (`browser_type="undetected"`), NOT the NoneType error. Full
     DIA-126 re-verify can now re-run the conspecter JS-heavy archival path. Future
     guard: skew recurs on Playwright minor-bump mismatch; cheap periodic guard =
     `playwright install --dry-run` vs cache compare or crawl4ai-doctor.

     Bug ticket filed 2026-08-13 from the DIA-126 restart-verify partial result.
     The conspecter test session proved the permission gate passes (bash tool
     present, `crwl *` runs with arguments) but the crawl4ai crwl fallback
     fails at runtime because Playwright's chromium revision pin does not match
     the host browser cache. This is a runtime/infra gap, NOT a permission gap.
     Documentation ticket - no config or code changes were made for this
     ticket; the wildcard permission fix landed separately in the DIA-126
     wildcard cycle. -->

---

id: DIA-129
title: "crawl4ai crwl fallback fails: Playwright pins chromium revision 1228, host cache has 1234 only"
area: dev-infra
severity: Medium
status: CLOSED
blocked_by: [] # no blockers
discovered: 2026-08-13
source: test-lane (DIA-126 restart-verify conspecter test session, 2026-08-13)
date: 2026-08-13
created: 2026-08-13
updated: 2026-08-13

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_005a18eb8ffe9m92BcMsR668Fk"
lane_id: ""
agent: "conspecter"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: [docs/dev-infra-audit/tickets/DIA-129-crawl4ai-playwright-chromium-revision-skew.md, docs/dev-infra-audit/tickets/README.md]
artifacts: []
evidence: ["knowledge/test-dia126-archival/"]

---

## Description

The crawl4ai `crwl` CLI fallback (conspecter Phase A tier (d), used for
JS-heavy page archival) fails at RUNTIME even though the permission gate
passes. The failure is a Playwright chromium revision skew:

- The crawl4ai Playwright version (pinned inside the crawl4ai install) expects
  chromium revision **1228** (chromium_headless_shell-1228).
- The host Playwright browser cache contains only revision **1234**.

Reproduced in the DIA-126 restart-verify conspecter test session
(ses_0059b11dbffegxB19B4ywdBVs5, evidence path knowledge/test-dia126-archival/):

- Runtime error (verbatim): `BrowserType.launch: Executable doesn't exist at ...chromium_headless_shell-1228...`
- crwl browser start fails with: `'NoneType' object has no attribute 'browser_type'` (the launch failure surfaces as a NoneType attribute error when the browser instance is never created).

Why it matters: the DIA-126 verification proved the permission layer works
(`crwl *` runs with arguments, bash tool present and executable, webfetch
denied), but JS-heavy source archival via the crwl fallback still fails
end-to-end. The permission fix alone does not make Phase A archival succeed
for dynamic pages; this runtime gap blocks the FULL DIA-126 re-verify.

## Verification

How to confirm the defect exists (before fix):

1. Run `crwl` browser start on the host (bash): attempt a crawl of a JS-heavy
   page, e.g. `crwl crawl https://example.com -o markdown` (or the archival
   form used in the DIA-126 test).
2. Observe the `BrowserType.launch: Executable doesn't exist at ...chromium_headless_shell-1228...` error followed by the `'NoneType' object has no attribute 'browser_type'` failure.
3. Compare Playwright version expectations: `playwright install --dry-run`
   (or the crawl4ai venv Playwright version) vs the host cache revision
   listing; the skew is 1228 expected vs 1234 present.
4. Confirm the permission gate is NOT the cause: the same command passes the
   bash allow gate (proven by the DIA-126 test session); the failure is
   purely at the browser-launch layer.

> To be filled at fix time with the full verification result.

## Remediation options (NOT implemented - documentation only)

The following options close the revision skew; the developer decides which at
fix time:

1. **Install the pinned revision for the crawl4ai Playwright version:**
   run `playwright install chromium` against the Playwright version used by
   the crawl4ai install (the version that pins 1228), so the
   chromium_headless_shell-1228 binary lands in the host browser cache.
2. **Upgrade crawl4ai** to a version whose Playwright pin matches the host
   cache revision 1234 (check crawl4ai release notes / dependency pin for the
   newer Playwright).
3. **Override the browser path explicitly:** set `PLAYWRIGHT_BROWSERS_PATH`
   or write the path file `~/.crawl4ai/.crawl4ai/chromium.path` so crawl4ai
   resolves to the installed chromium revision instead of its pinned one.

Routing note: any fix touches host tooling (Playwright cache, crawl4ai
install/upgrade, env vars), so it must route through the normal
dev-infrastructure change chain (spec -> implement -> test -> review ->
persist) per AGENTS.md section 2.4, with the section-10 gate applied if the
fix touches `.opencode/` config. DIA-063 section-10 ticket gate is satisfied
by this ticket.

## Fix

Remediation = ticket OPTION 1 (install the pinned revision via crawl4ai's own
Playwright driver). Additive + reversible host-cache-only fix: ZERO repo
changes, no config/env override, no crawl4ai upgrade.

- crawl4ai 0.9.2 (uv tool at ~/.local/share/uv/tools/crawl4ai) pins Playwright
  1.61.0 -> chromium v1228 (Chrome for Testing 149.0.7827.55). Host cache
  previously held only chromium-1234 (the skew).
- Ran `playwright install chromium` through crawl4ai's OWN driver
  (compute_driver_executable + install chromium) - RC=0.
- Landed in ~/.cache/ms-playwright/: chromium-1228 (177MiB) +
  chromium_headless_shell-1228 (114.2MiB).

## Re-verify

RE-VERIFY PASS (2026-08-13). Verdict: SKEW_CLOSED.

- `playwright install --dry-run` (crawl4ai driver) now shows 1228 install
  locations PRESENT (was: missing before the fix).
- Three real crawls, all exit 0 with real content >100 bytes:
  - github.com/unclecode/crawl4ai README - 75,139 bytes.
  - crawl4ai.com/mcp-server/
  - docs.crawl4ai.com/core/cli/ - 14,824 bytes.
- Error-string sweep: `Executable doesn't exist` and `has no attribute` = 0
  across all outputs; the single browser_type hit is README content
  (`browser_type="undetected"`), NOT the NoneType launch error.
- Full DIA-126 re-verify can now re-run the conspecter JS-heavy archival path.
- Future guard: skew recurs on Playwright minor-bump mismatch; cheap periodic
  guard = `playwright install --dry-run` vs cache compare or crawl4ai-doctor.
