# Proposal: context7-docs-pipeline

> **Status:** proposed · **Scope:** dev-infra (scripts/, Makefile, .gitignore)
> **Escalation:** none — change is within existing module boundaries (per AGENTS.md §2.4, dev-infra changes do not require @architector)

## Motivation

The project's RAG knowledge pipeline (`book-rag` skill, `.opencode/memory/` learnings) depends on curated documentation context to ground AI-assisted development. [Context7](https://context7.com) provides up-to-date library documentation via a structured API — preferable to scraping, because the docs are pre-processed into LLM-friendly markdown with source attribution and code fences.

This change adds a **local documentation fetcher** that resolves the monorepo's workspace dependencies, deduplicates them, and pulls their docs from Context7 into `knowledge/context7-docs/` for offline consumption by AI agents and future RAG indexing.

Two operational constraints drive the design:

1. **API cost is bounded** — the free plan provides 1000 calls/month, then 20 bonus/day. This is a developer-triggered tool, not a CI gate. Running it on every build would exhaust the quota in days.
2. **Key-optional operation** — not every developer will have a Context7 API key, and CI environments must never require one. The script runs in **dry-run mode** (inventory + report only) when the key is missing, empty, or a placeholder.

## Scope

### In scope

1. **`scripts/context7-docs.mjs`** — Node ESM script (root `package.json` is `"type": "module"`, Node 24). Scans all pnpm workspaces, collects dependency declarations, deduplicates by package name (highest version wins), fetches docs from Context7, stores as markdown.
2. **Dry-run mode** — when `CONTEXT7_API_KEY` is absent, empty, or placeholder, the script produces only the inventory report (which libraries, resolved versions, version skew warnings) without making any API calls. Exits 0.
3. **Mock mode** — `CONTEXT7_MOCK=1` env flag routes API calls through a local fixture directory instead of the network. Used for unit testing without a real key.
4. **Version deduplication** — the same npm package may appear in multiple workspaces at different versions. Resolve to highest version found; log skew as a report warning. Fetch once per unique library.
5. **Context7 API integration** — search + fetch via the confirmed v2 API contract (`https://context7.com/api/v2/...`). Handles library states (finalized, not_finalized, error, delete), redirects (301), rate limits (429), and auth errors (401/402).
6. **Inventory report** — always produced, even in dry-run. Written to `knowledge/context7-docs/_inventory.json` and printed to stdout as a human-readable summary.
7. **Per-library error isolation** — one library's fetch failure does not abort the run (except fatal auth errors). Summary at end: N succeeded, M skipped, K failed.
8. **Makefile wiring** — `make context7-docs` target. Listed in the Makefile header comment.
9. **`.gitignore`** — add `knowledge/context7-docs/` (output directory, not source).
10. **bats tests** — `scripts/__tests__/context7-docs.bats` — validates dry-run path (inventory output shape, version dedup logic) using fixture workspaces. Mock mode tests via `CONTEXT7_MOCK=1`.

### Out of scope

- CI integration (the API quota is too limited; this is developer-triggered).
- Automatic refresh/renewal of stale docs (Context7 has a `/v1/refresh` endpoint, but scheduling it is a follow-up).
- Adding new libraries to Context7 (the `/v2/add/repo/github` endpoint) — only fetch existing ones.
- Changes to the `book-rag` skill or any RAG ingestion pipeline (that's a separate concern; this change produces the input files).
- Changes to `dev-entrypoint.sh` or the secrets whitelist (already wired: `secrets/context7_api_key` → `CONTEXT7_API_KEY`).
- Changes to application code, `turbo.json`, or any package's `package.json`.

## Design authority (.sdd/) reference

**No `.sdd/` document governs dev-infra.** The project's design authority layer (`architecture.md` + `.sdd/`) describes system architecture (editor, workers, contracts, cloud), not developer tooling. Per AGENTS.md §2.4, dev-infra changes within existing boundaries use the spec chain directly without architectural escalation.

**Relevant existing patterns this change follows:**

- **Secrets wiring:** `secrets/context7_api_key` is already whitelisted in `dev-entrypoint.sh` → `CONTEXT7_API_KEY` env var. No secrets infrastructure changes needed.
- **Script location:** `scripts/` is the established home for dev-infra scripts. All existing scripts are bash; this is the first Node script in `scripts/`, justified by JSON-heavy workload (parsing workspace package.json files, handling Context7 API JSON responses, semver comparison).
- **Test infrastructure:** `scripts/__tests__/` uses bats with vendor-on-demand (`bats-wrapper.sh`). The dry-run path is pure bash-compatible (file I/O, JSON shape validation via `jq`). Mock-mode tests for the Node script's API layer are in the same bats file via `CONTEXT7_MOCK=1`.
- **Output directory:** `knowledge/` already holds research conspects, analyses, and RAG bases. `knowledge/context7-docs/` fits the pattern.
- **Makefile composition:** `make test-shell` for bats, `make test-infra` for full stack. This change adds a standalone `make context7-docs` target (not wired into `test-infra` — API quota constraint).

## Rollback plan

Every artifact added by this change is independently revertable:

| Artifact | Revert |
|---|---|
| `scripts/context7-docs.mjs` | Delete file |
| `scripts/__tests__/context7-docs.bats` | Delete file |
| `knowledge/context7-docs/` | Delete directory (gitignored output) |
| Makefile `context7-docs` target | `git checkout` to prior version |
| `.gitignore` entry | Remove line |

No existing production code is modified. No data migrations. Rollback is file deletion / git checkout, with no side effects on running services.

## Testing Decisions

> Per `openspec/config.yaml`: "Include a Testing Decisions section that states what makes a good test for this change, which modules will be tested, and the prior art in the codebase."

### What makes a good test here

This is dev-infra with a network dependency — tests verify **output shape and error handling**, not API correctness. A good test is one that fails loudly when the inventory logic produces wrong deduplication, when the output format drifts, or when error states are mishandled. We do NOT test Context7's API behavior (it's third-party); we test our code's response to known response shapes.

### Three test layers

1. **Dry-run path (`scripts/__tests__/context7-docs.bats`, run by `make test-shell`)**
   - Uses fixture workspaces (synthetic `packages/test-*/package.json` files in a temp directory) to test the inventory logic without any API calls.
   - Asserts: valid JSON in `_inventory.json`, correct deduplication (same package at different versions → highest wins), version skew warnings present when expected, exit 0.
   - Catches: dedup logic regressions, semver comparison bugs, output format drift.

2. **Mock mode (`CONTEXT7_MOCK=1` in bats, also in `make test-shell`)**
   - Sets `CONTEXT7_MOCK=1` + `CONTEXT7_API_KEY=test-key` to route API calls through a local fixture directory instead of the network.
   - Fixture directory contains pre-recorded Context7 API responses (JSON) for known library IDs.
   - Asserts: markdown files are produced for each mocked library, fetch status in inventory is "succeeded", error simulation (e.g., a 202 fixture) produces "skipped" status.
   - Catches: API response parsing regressions, markdown formatting changes, error handling logic.

3. **Manual verification (developer runs the script with a real key)**
   - Not automated — the API quota is too limited for CI. Developer runs `node scripts/context7-docs.mjs` with their `CONTEXT7_API_KEY`, verifies output looks reasonable.
   - This is the only layer that exercises the real API; layers 1 and 2 cover all logic paths without network.

### What we explicitly do NOT test

- Real Context7 API responses in CI (quota cost, rate limit risk).
- Library search relevance or doc quality (Context7's problem, not ours).
- RAG ingestion of the output files (separate concern; this change produces input, not consumption).
- Network timeout behavior (hard to simulate deterministically; covered by code review of the retry logic).

### Prior art in the codebase

- bats shell-script behavior pattern: existing `scripts/__tests__/dev-entrypoint.bats` (namespace-isolated tests with `test-helper.bash`).
- bats-wrapper with vendor-on-demand: existing `scripts/__tests__/bats-wrapper.sh` (syntax-checks all scripts, vendors bats-core if missing).
- Fixture-based testing: not yet used in `scripts/__tests__/`, but the pattern is straightforward — create temp dirs with synthetic `package.json` files, run the script, assert output shape.
- Mock mode via env flag: not yet used, but the pattern is common in Node scripts (`NODE_ENV=test`, `AWS_MOCK=1`, etc.).

### Test risk and mitigation

**Risk:** dry-run bats tests require a fixture workspace that may drift from the real monorepo layout. **Mitigation:** fixtures are minimal (2-3 synthetic packages with known dependencies), not mirrors of the real workspace. They test the dedup logic in isolation, not the real workspace scan.

**Risk:** mock mode fixtures may not match real Context7 API response shapes. **Mitigation:** fixtures are recorded from real API responses (developer captures once, commits to `scripts/__tests__/fixtures/context7-mock/`). If the API changes, the fixtures need updating — but that's a deliberate maintenance action, not silent drift.

**Risk:** `CONTEXT7_MOCK=1` accidentally leaks into production runs. **Mitigation:** the script checks for `CONTEXT7_MOCK=1` and prints a clear warning to stderr: "MOCK MODE — no real API calls". Developer must explicitly set the flag; it's not a default.
