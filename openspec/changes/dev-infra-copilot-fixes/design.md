# Design: dev-infra-copilot-fixes

> **Proposal:** `openspec/changes/dev-infra-copilot-fixes/proposal.md`
> **Scope:** implementation design only — no system architecture decisions, no `.sdd/` escalation required. The change is within existing module boundaries; both commit chains route through pre-established review paths (§2.4 / §10).

## Approach

This change stays entirely within existing module boundaries. It does not introduce any new module, does not alter any data flow described in `architecture.md` (root), and does not affect the DIA redispatch cycle or any other governed protocol. The `.sdd/` directory contains only `.sdd/dia-redispatch-cycle/architecture.md` + `README.md` — no module doc governs `scripts/`, `dev-entrypoint.sh`, `tools/opencode-docker/`, or `.opencode/`. Per AGENTS.md §3, the absence of a governing `.sdd/` is a documentation gap, but one this change does not fill: the fixes are local, bounded, and the parity requirement between the two secret loaders is enforced by this change's own tests and the companion `secrets/README.md` note.

Existing patterns followed:

- **Hermetic bats + namespace isolation:** the new empty-secret tests use the `run_entrypoint_ns` helper from `scripts/__tests__/test-helper.bash`, matching the existing `dev-entrypoint.bats` convention.
- **Static-grep Dockerfile assertions:** the new arch-fail-fast test extends `scripts/__tests__/opencode-docker.bats` (existing seam).
- **Stderr-degraded-boot idiom:** `[dev-entrypoint] [skip] ...` to stderr + `exit 0` mirrors the existing Docker-daemon check at `dev-entrypoint.sh:26-28` and the `dev-stack.sh` early-exit pattern.
- **`${HOME:?...}` guard:** standard POSIX fail-fast parameter expansion, adopted here for the telemetry commands.
- **`.gitignore` for generated artifacts:** `knowledge/*/sources/` pattern extended to `.config/opencode/skills/book-rag/knowledge-bases.yaml`.

## Files changed

### Commit A — dev-infra (§2.4 → `@reviewer`)

| File                                                                                                            | Change                                                                                                                                                                                                                                                                                          | Exact location                                                                                                                                                             |
| --------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `scripts/dev-stack.sh`                                                                                          | Replace misleading output block with accurate messaging: name only `author-studio` as turbo-managed; note `api-server` and `publishing-platform` must be started separately; drop fabricated URLs. No behavior change to `docker compose exec -it dev pnpm dev`.                                | Lines 44-47 (the four `echo` statements immediately before the turbo invocation at line 48).                                                                               |
| `tools/opencode-docker/Dockerfile`                                                                              | Add `*)` fail-fast branch to all four arch-dispatch `case` statements. Each branch: `*) echo "ERROR: unsupported TARGETARCH='${TARGETARCH}'. Supported: amd64, arm64." >&2; exit 1 ;;`.                                                                                                         | Lines 33, 57, 65, 75 (the four `*_ARCH=$(case "${TARGETARCH:-$(uname -m)}" in ...)` blocks).                                                                               |
| `dev-entrypoint.sh`                                                                                             | Insert strict zero-byte check `[ ! -s "$file" ]` between the `if [ -f "$file" ]` gate and the export. Empty/zero-byte files emit `[dev-entrypoint] [skip] secret '<name>': file empty or zero-byte, not wiring` to stderr and `continue` the loop (do NOT `exit 1` — degraded boot, not crash). | Line 26 (the `if [ -f "$file" ]` block).                                                                                                                                   |
| `scripts/dev-secrets-profile.sh`                                                                                | Parity fix: insert the same `[ ! -s "$secret" ]` check, same `[dev-secrets-profile] [skip] secret '<name>': ...` stderr message, same `continue` on empty.                                                                                                                                      | Lines 17-24 (the `for secret in /run/secrets/*` loop body).                                                                                                                |
| `secrets/README.md`                                                                                             | Add a short sync note in the "Empty placeholder files are the valid initialization state" section making the skip behavior explicit: "empty/zero-byte secret files are SKIPPED, not wired; dev env boots degraded".                                                                             | After line 38 (the current paragraph describing the skip behavior); the note should clarify that the code now actively enforces what the prose already implied.            |
| `scripts/__tests__/opencode-docker.bats` (append) or new `scripts/__tests__/opencode-docker-arch-failfast.bats` | Hermetic static-grep test asserting each of the four `*_ARCH=$(case` blocks in `tools/opencode-docker/Dockerfile` contains a `*)` arm. One assertion per variable name so a regression dropping a single branch fails specifically.                                                             | New test block at end of existing `opencode-docker.bats` (preferred — matches the existing Dockerfile-shape assertions in that file).                                      |
| `scripts/__tests__/dev-entrypoint.bats` (append)                                                                | New test: create a zero-byte whitelisted secret file, run the entrypoint via `run_entrypoint_ns`, assert the env var is unset AND stderr contains `[dev-entrypoint] [skip] secret '<name>': file empty or zero-byte, not wiring`.                                                               | New `@test` block appended to the existing file; uses the `run_entrypoint_ns` helper from `test-helper.bash`.                                                              |
| (Optional companion) `scripts/__tests__/dev-secrets-profile.bats` or append to `dev-entrypoint.bats`            | Same shape of test for `scripts/dev-secrets-profile.sh` — depends on whether a hermetic runner for the profile script exists; if not, defer to follow-up (the entrypoint test provides the parity signal).                                                                                      | Decision: append to `dev-entrypoint.bats` if possible; otherwise create `dev-secrets-profile.bats`. The implementation task will decide based on test-helper capabilities. |

### Commit B — AI-tooling config (§10 → `@ai-specialist`)

| File                                                    | Change                                                                                                                                                                                                                                                                                                                                                                                          | Exact location                                  |
| ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| `.opencode/commands/telemetry-report.md`                | Replace the hardcoded `/home/qualt/.cache/opencode/packages/opencode-telemetry@0.1.19/...` paths with `${HOME:?HOME is not set; cannot locate opencode-telemetry package}/.cache/opencode/packages/opencode-telemetry@0.1.19/...`. Both the `bun run` and the `node` fallback paths use the same `$HOME` expansion.                                                                             | Line 8 (the bash code block body).              |
| `.opencode/commands/telemetry-inspect.md`               | Same `${HOME:?...}` guard as `telemetry-report.md`. Both `bun run` and `node` paths.                                                                                                                                                                                                                                                                                                            | Line 9 (the bash code block body).              |
| `.config/opencode/skills/book-rag/knowledge-bases.yaml` | DELETE the file. It is a committed runtime cache (environment-specific timestamps `cached_at`/`ttl_seconds` + test data `test_kb`) regenerated on demand by `.opencode/scripts/query_rag.py` (the consumer referenced at `.opencode/skills/book-rag/SKILL.md:38`, with cache-path logic at lines 109–117: `_CACHE_DIR`/`_CACHE_FILENAME`). Version-controlling this cache produces noise diffs. | Whole file deletion.                            |
| Root `.gitignore`                                       | Add a path-scoped entry with comment: `# Generated RAG index cache (book-rag skill); regenerate via book-rag skill` followed by `.config/opencode/skills/book-rag/knowledge-bases.yaml`. Placed in a new "Generated RAG / skill caches" section near the existing `knowledge/*/sources/` entry to group related ignores.                                                                        | After the existing `knowledge/` ignore section. |
| `.opencode/memory/failures.md`                          | Collapse the duplicated "MCP header-name mismatch risk" bullet. Currently line 11 (no indent) and line 12 (one-space indent) are duplicates; line 13 carries the Resolution. Result: one bullet (use the line 11 form — cleaner indentation) followed by its Resolution. No other changes to `failures.md`.                                                                                     | Lines 11-13.                                    |

## Implementation details

### Fix #1 — `scripts/dev-stack.sh` output rewrite

Current (lines 44-47):

```bash
echo "-> starting all app services (turbo run dev)..."
echo "   author-studio : http://localhost:9000"
echo "   api-server    : http://localhost:8000"
echo "   publishing    : http://localhost:3000"
docker compose exec -it dev pnpm dev
```

New (accurate-only output — E4):

```bash
echo "-> starting author-studio via turbo (docs/docker-dev.md)..."
echo "   author-studio : http://localhost:9000"
echo "   (api-server and publishing-platform are NOT started by turbo;"
echo "    start them separately — see docs/docker-dev.md)"
docker compose exec -it dev pnpm dev
```

Rationale:

- Names only `author-studio` as turbo-managed — matches `docs/docker-dev.md:14-18`.
- Explicitly says api-server and publishing-platform are separate, with a pointer to the authoritative doc — no fabricated URLs for services that are not running.
- No doc-path citation _inside_ the URLs — the pointer is in the human-readable note (E4).

### Fix #4 — four identical `*)` fail-fast branches

Each of the four `case` statements in `tools/opencode-docker/Dockerfile` (lines 33, 57, 65, 75) gets the same shape of default arm:

```bash
*) echo "ERROR: unsupported TARGETARCH='${TARGETARCH}'. Supported: amd64, arm64." >&2; exit 1 ;;
```

Placement: immediately after the last concrete arm in each `case` block, before `esac)`. The `exit 1` propagates through Docker's `RUN` instruction and fails the build — no malformed download URL is ever reached. Each error message names the offending `TARGETARCH` value to aid debugging (e.g., if a developer passes `--platform linux/riscv64`).

The four affected variables: `NODE_ARCH`, `MISE_ARCH`, `SNIP_ARCH`, `UV_ARCH`. Each has distinct concrete mappings (x64/arm64 for Node/mise, amd64/arm64 for snip, x86_64/aarch64 for uv) — the `*)` branch is **identical text** across all four (the error message references `${TARGETARCH}` which is the same input variable for all four blocks).

### Fix #6 — `dev-entrypoint.sh` empty-secret skip

Current (lines 24-29):

```bash
for secret in "${ALLOWED_SECRETS[@]}"; do
  file="/run/secrets/${secret}"
  if [ -f "$file" ]; then
    var_name=$(echo "${secret}" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
    export "${var_name}=$(cat "$file")"
  fi
done
```

New:

```bash
for secret in "${ALLOWED_SECRETS[@]}"; do
  file="/run/secrets/${secret}"
  if [ ! -f "$file" ]; then
    continue
  fi
  if [ ! -s "$file" ]; then
    echo "[dev-entrypoint] [skip] secret '${secret}': file empty or zero-byte, not wiring" >&2
    continue
  fi
  var_name=$(echo "${secret}" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
  export "${var_name}=$(cat "$file")"
done
```

Notes:

- Strict zero-byte check `[ ! -s "$file" ]` (E1 — whitespace-only files still load).
- `continue` (not `exit 1`) — degraded boot, not crash.
- `[skip]` marker makes the log grep-able.
- Message goes to stderr (not stdout) — matches the Docker-daemon check pattern at lines 26-28.

### Fix #7 — `scripts/dev-secrets-profile.sh` parity

Same shape applied inside the `for secret in /run/secrets/*` loop body (lines 17-24):

```bash
for secret in /run/secrets/*; do
  [ -f "$secret" ] || continue
  name=$(basename "$secret")
  if [ ! -s "$secret" ]; then
    echo "[dev-secrets-profile] [skip] secret '${name}': file empty or zero-byte, not wiring" >&2
    continue
  fi
  case "$name" in
    anthropic_api_key|openai_api_key|context7_api_key|github_token|exa_api_key)
      var_name=$(echo "$name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
      export "${var_name}=$(cat "$secret")"
      ;;
  esac
done
```

The `[skip]` tag differs (`[dev-entrypoint]` vs `[dev-secrets-profile]`) so the two loaders are distinguishable in combined logs.

### Fix #2 / #3 — `${HOME:?...}` guard in telemetry commands

Current (telemetry-report.md line 8):

```bash
bun run "/home/qualt/.cache/opencode/packages/opencode-telemetry@0.1.19/node_modules/opencode-telemetry/scripts/report.ts" || node "/home/qualt/.cache/opencode/packages/opencode-telemetry@0.1.19/node_modules/opencode-telemetry/scripts/report.js"
```

New:

```bash
bun run "${HOME:?HOME is not set; cannot locate opencode-telemetry package}/.cache/opencode/packages/opencode-telemetry@0.1.19/node_modules/opencode-telemetry/scripts/report.ts" || node "${HOME:?HOME is not set; cannot locate opencode-telemetry package}/.cache/opencode/packages/opencode-telemetry@0.1.19/node_modules/opencode-telemetry/scripts/report.js"
```

The `telemetry-inspect.md` command gets the same substitution, with `$ARGUMENTS` preserved at the end.

Notes:

- `${HOME:?msg}` emits `HOME: msg` to stderr and exits with status >0 if `HOME` is unset or empty. Hard exit — not a silent fallback (Q5).
- No `/home/qualt` literal remains anywhere in either file.

### Fix #5 — `knowledge-bases.yaml` deletion + `.gitignore` entry

Delete `.config/opencode/skills/book-rag/knowledge-bases.yaml`. The file is a runtime cache produced by `.opencode/scripts/query_rag.py` (the consumer referenced by `.opencode/skills/book-rag/SKILL.md:38`, with cache-path logic at lines 109–117: `_CACHE_DIR`/`_CACHE_FILENAME`). The committed content contains environment-specific timestamps (`cached_at`/`ttl_seconds`) and test data (`test_kb`) — churn that belongs in `.gitignore`, not version control.

Add to the root `.gitignore` (in a new section grouped near the existing `knowledge/*/sources/` ignore):

```gitignore
# === Generated RAG / skill caches ===
# Generated RAG index cache (book-rag skill); regenerate via book-rag skill
.config/opencode/skills/book-rag/knowledge-bases.yaml
```

The comment explains what the file is and how to regenerate it, so a future developer who deletes it locally knows how to restore it.

### Fix #8 — `failures.md` dedup

Current (lines 11-13):

```
- Failure mode: MCP header-name mismatch risk (opencode.jsonc configured CONTEXT7_API_KEY header literal). Root cause: naming mismatch between env var and accepted server header names. Preventive action: update MCP mapping to Authorization: Bearer or X-Context7-API-Key and include an MCP integration smoke test.
 - Failure mode: MCP header-name mismatch risk (opencode.jsonc configured CONTEXT7_API_KEY header literal). Root cause: naming mismatch between env var and accepted server header names. Preventive action: update MCP mapping to Authorization: Bearer or X-Context7-API-Key and include an MCP integration smoke test.
   Resolution: Fixed by updating the Context7 MCP registration in .opencode/opencode.jsonc and tools/opencode-docker/config/opencode.json to use "Authorization: Bearer {env:CONTEXT7_API_KEY}", set "oauth": false to avoid false OAuth detection, and increase MCP timeout to 15000ms to accommodate remote latency. See .opencode/learnings/external-patterns/2026-08-02-context7-mcp-registration.md for source-verified details. Keep this failure entry for historical context; mark as resolved by the above config updates.
```

New:

```
- Failure mode: MCP header-name mismatch risk (opencode.jsonc configured CONTEXT7_API_KEY header literal). Root cause: naming mismatch between env var and accepted server header names. Preventive action: update MCP mapping to Authorization: Bearer or X-Context7-API-Key and include an MCP integration smoke test.
  Resolution: Fixed by updating the Context7 MCP registration in .opencode/opencode.jsonc and tools/opencode-docker/config/opencode.json to use "Authorization: Bearer {env:CONTEXT7_API_KEY}", set "oauth": false to avoid false OAuth detection, and increase MCP timeout to 15000ms to accommodate remote latency. See .opencode/learnings/external-patterns/2026-08-02-context7-mcp-registration.md for source-verified details. Keep this failure entry for historical context; mark as resolved by the above config updates.
```

One bullet, its Resolution. The duplicate line 12 is removed. No other edits to `failures.md`.

## Seams

> Per `openspec/config.yaml`: "Include a Seams section listing the pre-agreed public boundaries where tests will live. Prefer existing seams; propose new ones only at the highest level necessary."

| Seam                                                          | What it is                                                                                                     | Test location                                                                         | Test type                                                                                                        |
| ------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| **Arch-dispatch fail-fast in the opencode-docker Dockerfile** | Each of the four `*_ARCH=$(case ...)` blocks must contain a `*)` arm                                           | `scripts/__tests__/opencode-docker.bats` (existing seam — append)                     | Static grep (structural assertion, no Docker build)                                                              |
| **Empty-secret skip in `dev-entrypoint.sh`**                  | A zero-byte whitelisted secret file must not export its env var; must emit `[dev-entrypoint] [skip]` to stderr | `scripts/__tests__/dev-entrypoint.bats` (existing seam — append)                      | Behavioral test in `unshare -r -m` namespace via `run_entrypoint_ns`                                             |
| **Empty-secret skip in `scripts/dev-secrets-profile.sh`**     | Parity with entrypoint                                                                                         | `scripts/__tests__/dev-entrypoint.bats` (preferred) or new `dev-secrets-profile.bats` | Behavioral test (decision in T3)                                                                                 |
| **`${HOME:?...}` guard in telemetry commands**                | The two telemetry commands must use `${HOME:?...}`, not `/home/qualt`                                          | Implicit: `make test-config` schema validation + visual review by `@ai-specialist`    | No automated test — the fix is a one-line substitution in a markdown code block; structural review is sufficient |
| **`knowledge-bases.yaml` deletion + `.gitignore` entry**      | The runtime cache must not be re-committed                                                                     | `git check-ignore .config/opencode/skills/book-rag/knowledge-bases.yaml` exits 0      | One-shot check in the implementation task                                                                        |
| **`failures.md` dedup**                                       | Only one "MCP header-name mismatch" bullet remains                                                             | Implicit: visual review                                                               | No automated test                                                                                                |
| **`dev-stack.sh` accurate output**                            | Output names only `author-studio` as turbo-managed                                                             | Implicit: visual review + `make test-infra` smoke                                     | No automated test — output messaging is a UX concern, verified manually                                          |

### New seams vs. existing seams

- **Arch-fail-fast static grep:** extends the existing `opencode-docker.bats` seam (preferred) rather than creating a new file. No new seam.
- **Empty-secret behavioral test:** extends the existing `dev-entrypoint.bats` seam via the existing `run_entrypoint_ns` helper. No new seam.
- **Telemetry path guard, gitignore check, failures.md dedup, dev-stack.sh output:** no automated seam — these are small, bounded, review-verified fixes. The cost of a new bats test for each would exceed the risk of regression.
- **`dev-secrets-profile.sh` parity test:** conditional — if the existing test-helper supports running the profile script in a namespace, append to `dev-entrypoint.bats`; otherwise create `dev-secrets-profile.bats` as a new seam (justified only if necessary).

### Testability env seams

No new env overrides needed for this change. The existing `NS_SECRETS_DIR` (set by `run_entrypoint_ns` to point at a tmpfs-mounted secrets directory) is reused by the new empty-secret test.

## Design constraints and trade-offs

### Why commit on the §2.4 / §10 routing boundary

The 8 fixes are not a single conceptual unit — 5 are dev-infra, 3 are AI-tooling config. The project's AGENTS.md already defines two distinct review chains for these domains (§2.4 dev-infra → `@reviewer`; §10 AI-tooling → `@ai-specialist`). Splitting the PR into two commits along that boundary means each reviewer sees only the commits in their lane, and the PR description can explicitly route each commit. If one chain raises concerns, it can be reverted without affecting the other.

### Why static-grep for the Dockerfile arch test (not a throwaway `docker build`)

A real `docker build --platform linux/<unsupported-arch>` would require multi-arch build infra that the project does not have. The structural assertion "does the file contain a `*)` arm in each `case` block" is exactly what we want to guarantee — a missing arm is a text-level defect, not a runtime one. Static grep catches the defect in milliseconds with zero infrastructure. Manual build verification (Q7) covers the happy path (real amd64/arm64 builds still download the right artifacts).

### Why `${HOME:?...}` (hard exit) not `${HOME:-/default/path}` (silent fallback)

A silent fallback would mask misconfiguration — if `HOME` is unset on a developer's machine, the command would silently look in `/default/path/...` and fail with a confusing "file not found" error. The hard-exit idiom makes the failure mode obvious (`HOME: HOME is not set; ...`) and self-documenting. This is the confirmed decision (Q5).

### Why `continue` on empty secrets (not `exit 1`)

A zero-byte secret file is documented as "the valid initialization state" (`secrets/README.md:28-38`). Crashing the boot on an expected state would break the documented developer workflow ("fill the placeholder before starting the stack" — the stack must still start, just without that secret). Degraded boot is correct: the env var is unset, the app will fail with a clear "API key missing" error if it needs that secret, and the developer sees `[skip]` in the logs.

### Why strict zero-byte check (`[ ! -s ]`) not trim-and-test (E1)

Trim-and-test would silently load whitespace-only files as empty, which is a different behavior than what the README documents. The README says "non-empty to actually be loaded" — a file containing only whitespace is technically non-empty. The strict zero-byte check matches the documented intent and is simpler to reason about. Whitespace-only files are a pathological edge case that does not warrant special handling.

### Why one commit per routing chain (not one commit per fix)

Six commits (one per fix) would produce a noisy commit history for a single PR whose purpose is "address 8 Copilot review comments". Two commits (one per chain) reflects the conceptual structure: dev-infra hardening, then AI-tooling config cleanup. Each commit is independently reviewable, independently revertable, and independently testable.
