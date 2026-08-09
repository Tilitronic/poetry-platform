# Tasks: context7-docs-pipeline

> **Proposal:** `openspec/changes/context7-docs-pipeline/proposal.md`
> **Design:** `openspec/changes/context7-docs-pipeline/design.md`
> **Workflow:** per `openspec/config.yaml`, each task is a vertical slice invoked via the `tdd-craftsman` skill. Write the failing test BEFORE production code. Work one slice at a time.

## Dependency graph

```
T1 (workspace scanner + dedup + inventory + dry-run tests)
 │
 └──▶ T2 (API client + mock mode + markdown writer + mock tests)
       │
       └──▶ T3 (Makefile + gitignore wiring)
```

**Critical path:** T1 → T2 → T3
**Parallel tracks:** none — each task depends on the previous.

**Rationale for sequential ordering:** T1 produces the pure-logic foundation (workspace scanning, dedup, inventory) that T2 consumes (the API client needs a list of unique libraries to fetch). T2 produces the full pipeline (scan → fetch → store) that T3 wires into the Makefile. Parallelizing would require stubbing interfaces between tasks, which adds complexity without saving time for a script this size.

---

## T1 — Workspace scanner + version dedup + inventory writer + dry-run bats tests

**Blockers:** none
**Vertical slice:** one complete dry-run path from workspace layout to inventory report, with automated tests validating the output shape.

### What changes

1. `scripts/context7-docs.mjs` (new file, executable):
   - **Workspace scanner:** reads `pnpm-workspace.yaml` at repo root, expands globs (`apps/*`, `packages/*`), reads `package.json` from each matched directory. Collects `dependencies`, `devDependencies`, `peerDependencies`, `optionalDependencies` into a flat list per workspace. Excludes `@poetry/*` workspace packages and `node:*` built-ins.
   - **Version dedup:** groups dependencies by package name across all workspaces. For each unique package, resolves to the highest version found (using semver comparison). If versions differ across workspaces, logs a warning to stderr: `"WARN: version skew for <pkg>: workspace A has X.Y.Z, workspace B has W.V.U — resolved to highest: X.Y.Z"`.
   - **Inventory writer:** writes `knowledge/context7-docs/_inventory.json` with the structure defined in design.md (mode: "dry-run", workspacesScanned, totalDependencies, uniqueLibraries, versionSkewWarnings, libraries array with status "dry-run", summary). Prints a human-readable summary to stdout.
   - **Key check:** at startup, checks `CONTEXT7_API_KEY` env var. If missing, empty, or starts with `"placeholder"`, runs in dry-run mode (inventory only, no API calls). Prints to stderr: `"No Context7 API key — running in dry-run mode (inventory only)"`. Exits 0.
   - **Directory creation:** ensures `knowledge/context7-docs/` exists before writing (creates if missing).
   - For this task, the API client and markdown writer are stubbed (not implemented yet — that's T2). The script exits after writing the inventory in dry-run mode.
   - **Semver comparison:** use a lightweight comparison function (parse major.minor.patch, compare numerically) rather than adding the `semver` npm package as a dependency. This keeps the script self-contained with no new dependencies. If edge cases arise (prerelease tags, build metadata), we can add `semver` later.

2. `scripts/__tests__/context7-docs.bats` (new file):
   - Follows the conventions in `scripts/__tests__/dev-entrypoint.bats` (load `test-helper` if needed).
   - **Test fixtures:** create a temp directory with synthetic workspace layout:
     - `pnpm-workspace.yaml` with `packages: ['packages/*']`
     - `packages/test-pkg-a/package.json` with `{"dependencies": {"codemirror": "^6.0.1", "next": "^14.0.0"}}`
     - `packages/test-pkg-b/package.json` with `{"dependencies": {"codemirror": "^6.0.3", "vue": "^3.4.0"}}`
     - This setup tests: dedup (codemirror appears twice at different versions), skew warning (codemirror 6.0.1 vs 6.0.3), multiple packages.
   - **Tests:**
     - **Dry-run mode:** unset `CONTEXT7_API_KEY`, run the script against the fixture workspace, assert exit 0.
     - **Inventory JSON valid:** `_inventory.json` is valid JSON (parseable by `jq`).
     - **Unique libraries correct:** inventory contains exactly 3 unique libraries (codemirror, next, vue), not 4 (codemirror should be deduplicated).
     - **Version resolution correct:** codemirror resolved to `6.0.3` (highest of 6.0.1 and 6.0.3).
     - **Skew warning present:** `versionSkewWarnings` array contains an entry for codemirror with both versions listed.
     - **Summary counts:** `summary.succeeded` is 0, `summary.skipped` is 0, `summary.failed` is 0 (dry-run mode doesn't fetch).
     - **Mode field:** `mode` is `"dry-run"`.
   - **Cleanup:** bats `teardown` removes the temp fixture directory.

3. `scripts/__tests__/bats-wrapper.sh`:
   - Add `node --check scripts/context7-docs.mjs` to the syntax-check loop (Node syntax checking, not `bash -n`). This catches syntax errors before runtime.

### Acceptance criteria (user perspective)

- Running `node scripts/context7-docs.mjs` without `CONTEXT7_API_KEY` set produces `knowledge/context7-docs/_inventory.json` and prints a summary to stdout. Exits 0.
- The inventory JSON contains the correct number of unique libraries (deduplication works), the highest resolved versions, and version skew warnings where expected.
- `make test-shell` passes, including the new `context7-docs.bats` tests.
- If a new `@poetry/*` package is added to the workspace, it is excluded from the inventory (workspace packages are not fetched).
- If a dependency appears in multiple workspaces at different versions, the skew warning is logged to stderr.

### Testing

- RED-GREEN: write the bats tests first (they fail because T1 may not yet handle all edge cases), then implement T1 until they pass.
- The dry-run path is fully testable without any API calls or fixtures — it's pure logic (workspace scanning, dedup, JSON generation).

---

## T2 — API client + mock mode + markdown writer + mock tests

**Blockers:** T1
**Vertical slice:** the full network + output layer — API client with retry/error handling, mock mode via fixtures, markdown writer with frontmatter. Completes the pipeline: scan → fetch → store.

### What changes

1. `scripts/context7-docs.mjs` (extend):
   - **API client:** implements the Context7 v2 API contract from design.md:
     - **Search:** `GET /api/v2/libs/search?libraryName=<pkg>&query=introduction%20and%20usage%20overview` with optional Bearer auth. Parses `results[0].id` as the `libraryId`. If `results` is empty, logs warning and skips.
     - **Fetch:** `GET /api/v2/context?libraryId=<id>&query=introduction%20and%20usage%20overview&type=txt`. Returns markdown body.
     - **Retry logic:** 202 (not finalized) → exponential backoff (3 attempts: 5s, 15s, 45s). 5xx → 2 attempts, 5s backoff. 429 → respect `Retry-After` header (default 60s), one retry. 401/402 → abort immediately.
     - **301 redirect:** follow `redirectUrl` from body, log warning.
     - **Error isolation:** per-library errors (202 after retries, 404, 5xx after retries) are logged as "skipped" or "failed" in the inventory, but do not abort the run. Only 401/402/second-429 abort.
   - **Mock mode:** if `CONTEXT7_MOCK=1` is set, the API client reads responses from `scripts/__tests__/fixtures/context7-mock/<endpoint>.json` instead of making real HTTP calls. The fixture directory contains pre-recorded responses for known library IDs (e.g., `search-next.json`, `context-vercel-next.js.json`). If a fixture is missing, the mock client returns a 404-like error (logged as "skipped").
   - **Markdown writer:** writes the fetched markdown to `knowledge/context7-docs/<slug>.md`, where `<slug>` is the `libraryId` with `/` replaced by `-` and leading `/` removed. Prepends YAML frontmatter:
     ```yaml
     ---
     libraryId: /vercel/next.js
     packageName: next
     resolvedVersion: 14.0.0
     fetchedAt: 2026-08-02T12:34:56Z
     ---
     ```
   - **Key check (real mode):** if `CONTEXT7_API_KEY` is present and valid (not placeholder), and `CONTEXT7_MOCK` is not set, run in real mode (actual API calls).
   - **Inventory update:** after fetching, update the `libraries` array in the inventory with each library's `status` ("succeeded", "skipped", "failed"), `statusDetail` (error message if failed), and `outputFile` (the markdown filename). Update `summary` counts.
   - **Mock mode warning:** if `CONTEXT7_MOCK=1`, print to stderr: `"MOCK MODE — no real API calls"`.

2. `scripts/__tests__/fixtures/context7-mock/` (new directory):
   - Pre-recorded Context7 API responses for mock mode. At minimum:
     - `search-next.json` — search response for "next" with `results[0].id = "/vercel/next.js"`.
     - `context-vercel-next.js.txt` — markdown response for `/vercel/next.js`.
     - `search-codemirror.json` — search response for "codemirror".
     - `context-vercel-codemirror.txt` — markdown response.
     - `search-not-found.json` — empty `results` array (to test the "no library found" path).
     - `search-not-finalized.json` — search response where `results[0].state = "processing"` (to test the 202 retry path; the mock client simulates 202 by checking the fixture's `state` field).
   - Fixtures are recorded from real API responses (developer captures once). If the API changes, fixtures need updating.

3. `scripts/__tests__/context7-docs.bats` (extend):
   - **Mock mode tests:** set `CONTEXT7_MOCK=1` + `CONTEXT7_API_KEY=test-key`, run the script against the fixture workspace from T1.
   - **Tests:**
     - **Markdown files produced:** `knowledge/context7-docs/vercel-next.js.md` exists and contains the fixture content.
     - **Frontmatter present:** the markdown file starts with `---` and contains `libraryId:`, `packageName:`, `resolvedVersion:`, `fetchedAt:` fields.
     - **Inventory status correct:** the inventory's `libraries` array contains entries with `status: "succeeded"` for libraries that had fixtures, and `status: "skipped"` for libraries with no fixture (e.g., "not-found").
     - **Summary counts correct:** `summary.succeeded` + `summary.skipped` + `summary.failed` equals `uniqueLibraries`.
     - **Mock mode warning:** stderr contains `"MOCK MODE"`.
     - **202 retry simulation:** if a fixture has `state: "processing"`, the script retries (mock client simulates 202 for the first 2 attempts, then returns the fixture on the 3rd). The library's status is "succeeded" (retry worked).
     - **401 abort simulation:** if `CONTEXT7_API_KEY=invalid-key`, the mock client returns 401. The script aborts immediately with a clear error message. Exit non-zero.

### Acceptance criteria (user perspective)

- Running `CONTEXT7_MOCK=1 CONTEXT7_API_KEY=test-key node scripts/context7-docs.mjs` produces markdown files in `knowledge/context7-docs/` for each library that has a fixture, with correct frontmatter.
- The inventory JSON accurately reflects the fetch status (succeeded, skipped, failed) for each library.
- Retry logic works: a library that returns 202 twice then succeeds on the third attempt is marked "succeeded" in the inventory.
- A 401 error aborts the script immediately with a clear error message.
- `make test-shell` passes, including the new mock mode tests.
- A developer with a real `CONTEXT7_API_KEY` can run `node scripts/context7-docs.mjs` and get real docs from Context7 (manual verification, not automated).

### Testing

- RED-GREEN: write the mock mode bats tests first (they fail because T2 may not yet handle all edge cases), then implement T2 until they pass.
- Mock mode tests exercise the full pipeline (scan → fetch → store) without consuming API quota.
- The real API path is NOT tested in CI (quota constraint). Manual verification by the developer is the only layer that exercises the real API.

---

## T3 — Makefile + gitignore wiring

**Blockers:** T1, T2
**Vertical slice:** end-to-end wiring so the script is runnable via `make context7-docs` and the output directory is gitignored.

### What changes

1. `Makefile`:
   - Add `context7-docs` to the `.PHONY` declaration.
   - Add `context7-docs` target:
     ```makefile
     context7-docs:
     \tnode scripts/context7-docs.mjs
     ```
   - Add to the header comment (lines 1-17):
     ```makefile
     #   make context7-docs  fetch library docs from Context7 (requires CONTEXT7_API_KEY; dry-run without it)
     ```
   - **NOT wired into `test-infra`** — the API quota is too limited (1000 calls/month). This is a developer-triggered tool, not a CI gate.

2. `.gitignore`:
   - Add a new section:
     ```
     # === Generated by scripts/context7-docs.mjs ===
     knowledge/context7-docs/
     ```

### Acceptance criteria (user perspective)

- `make context7-docs` runs the script. Without `CONTEXT7_API_KEY`, it runs in dry-run mode and exits 0. With `CONTEXT7_API_KEY`, it fetches docs (or in mock mode, uses fixtures).
- `git status` does NOT show `knowledge/context7-docs/` as untracked (it's gitignored).
- The Makefile header comment documents the new target.
- `make test-shell` still passes (the bats tests from T1 and T2 are unaffected by the Makefile change).

### Testing

- The wiring IS the test: if `make context7-docs` runs, the wiring is correct. No separate test needed.
- `git check-ignore knowledge/context7-docs/_inventory.json` exits 0 (ignored).

---

## Implementation order (suggested)

1. **Start with T1** (workspace scanner + dedup + inventory + dry-run tests) — no blockers, pure logic, fully testable without API. Write the bats tests RED, then implement until GREEN.
2. **Then T2** (API client + mock mode + markdown writer + mock tests) — extends T1 with the network + output layer. Write the mock mode bats tests RED, then implement until GREEN.
3. **Finally T3** (Makefile + gitignore) — wires everything together. Only starts after T1 and T2 are done.

## Out of scope for these tasks

- Real API testing in CI (quota constraint; manual verification only).
- Automatic refresh/renewal of stale docs (Context7 `/v1/refresh` endpoint; follow-up change).
- Adding new libraries to Context7 (`/v2/add/repo/github` endpoint; follow-up change).
- Integration with the `book-rag` skill or any RAG ingestion pipeline (separate concern).
- Changes to `dev-entrypoint.sh` or the secrets whitelist (already wired).
- Prerelease version handling in semver comparison (the lightweight comparison function handles major.minor.patch; prerelease tags are a follow-up if needed).
