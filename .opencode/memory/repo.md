Repository facts (irrecoverable pointers)

- Dev orchestration helpers live under scripts/ and are the canonical place for host-level orchestration wrappers (scripts/dev-stack.sh, scripts/test-docker-smoke.sh).
- Dev-infra tests are in scripts/__tests__/ and vendorised bats-core is pinned into scripts/__tests__/vendor/.
- Python API tests are under apps/api-server/tests/ with pytest configuration in pyproject.toml.
- Makefile targets: test-shell, test-python, test-infra, test-config are the developer entrypoints for dev-infra verification.
- Opencode config validators live in .opencode/scripts/validate-opencode-config.sh

Note: These are navigational facts to help future humans find the infra/test artifacts quickly; they do not duplicate commit history or diffs.

- Context7 API host facts (2026-08-02): api.context7.com is dead (NXDOMAIN). The live REST base used by the implemented pipeline is https://context7.com/api (v2 endpoints such as /api/v2/libs/search and /api/v2/context). Do NOT reintroduce api.context7.com; prefer the canonical base and verify via DNS before use. This is an operational repo fact recorded because DNS/host state is not recoverable from the repository commits.

- Ledger status convention (campaign-specific, 2026-08-03): during the dev-infra audit the owner chose a campaign-level ledger convention that is NOT fully recoverable from git because session logs are gitignored. The rule applied in this run: DEFERRED tickets remain listed with status OPEN in the canonical tickets index (docs/dev-infra-audit/tickets/README.md) with disposition explained in the ticket body/overview; IMPLEMENTED tickets are synced into the ledger index (OPEN -> IMPLEMENTED + rollup recount) only after the owner-authorized registration step. This convention and the owner-driven atomic-commit-after-restart pattern are session-scoped operational facts and should be consulted when reconciling the tickets ledger vs session messages.

- OTel GenAI JSONL sidecar pin (irrecoverable location): during the §10 campaign we adopted the OpenTelemetry GenAI semantic conventions and pinned the schema reference to open-telemetry/semantic-conventions-genai v1.42.0. The pin was written into the session-scoped file `.opencode/session/README.md` (gitignored). Because the session/ directory is not tracked, the pin and the fact that the orchestrator now emits a JSONL sidecar with gen_ai.* attributes (Development status) would be lost on a fresh clone. Record: semconv attributes remain "Development"/unstable — treat schema changes as potentially breaking and verify the pinned version when re-running orchestration.

- Model context-window authoritative source (2026-08-03): do NOT rely on NEXT-RUN.md's static table as a primary source for model context windows. During the "dia-redispatch-cycle" campaign we discovered that the NEXT-RUN.md lookup listed `deepseek-v4-flash` as 64,000 tokens (this was the V3 value). The correct, upstream context window for deepseek-v4-flash is 1,000,000 tokens (verified via models.dev, DeepSeek official docs, HF model card, and arXiv:2606.19348). Models.dev should be consulted as the authoritative catalog for model context limits when making operational handoff/threshold decisions. Record: the repository's docs table is a convenience copy and can silently drift from live model metadata.

- Permission model fact (DIA-055, 2026-08-08): opencode.jsonc now includes per-agent `token_*": "deny"` entries for a total of 13 token_* deny records (7 pre-existing + 6 newly-added for coder, code-navigator, researcher, designer, observer, memory-manager). This per-agent deny model is the owner-approved permission-hardening approach; record this count here because cumulative permission surface is not always reconstructible from a single commit diff across layered configs. Also: DIA-066 was opened as a follow-up ticket to implement a tool-coverage audit script.

- Debug-agent permission surface & tool-registry facts (res003 / DIA-066 context):
  - Key facts:
    1. `opencode debug agent <name>` shows per-tool enabled booleans and the agent's permission ruleset. Unlisted tools default to allow in some runtimes (behaviour varies by version); certain high-sensitivity tools (doom_loop, external_directory) default to ask while `.env` access is denied by default.
    2. There is a runtime divergence between v1 and v2 permission semantics; plugins currently lack a registry-enumeration API (tool presence is observable only by runtime tool.execute.* events). An undocumented `/experimental/tool/ids` endpoint exists in some deployments.
  - Why record: res003 (conspecter) was PAUSED due to missing trafilatura CLI and the research lane could not finish. Since res003 is paused, capture these debug-agent facts now because they materially informed the DIA-066 tool-coverage audit design and are not yet fully recorded elsewhere.
  - Tracking: res003 remains paused; further research should be resumed under the res003 ticket when the trafilatura/docker host blocker is resolved (tracked as DIA-067).

- Telemetry command docs portability note (2026-08-08):
  - Observation: runtime plugin behaviour was observed to rewrite `.opencode/commands/telemetry-report.md` and `telemetry-inspect.md`, injecting a literal `/home/qualt/...` path rather than preserving the `$HOME` placeholder. Because this rewrite happens at plugin load time, it reintroduced portability regressions into working trees and tripped the pre-commit guard_no_home_qualt intermittently.
  - Why stored here: commit history recorded the repeated reverts but did not explain the runtime source; this repo-level pointer records the provenance and that the long-term fix belongs in the plugin registerCommands() implementation.


- DIA-070 telemetry DB & cache facts (2026-08-08):
  - Telemetry DB path observed at runtime: `~/.local/share/opencode-telemetry/data.db` (session-local; verify on host). The telemetry plugin stores schema_version in a `_meta` key/value table (key `schema_version`) — PRAGMA user_version remained 0 in observed runs.
  - Runtime caches observed: `~/.cache/opencode/packages/` (pnpm-style per-package cache) and `~/.config/opencode/node_modules/` (user-installed node_modules). Vendored patches must consider both paths and any pnpm/volta store aliases.
  - Why irrecoverable: exact DB path, live schema_version value, and runtime cache resolutions are environment-state observations from the campaign and are not reconstructible from git or plugin source alone.

- Local dev host Python/YAML fact (2026-08-03): this developer host has PyYAML 6.0.3 installed for the system python3 interpreter. During the DIA-037 work that exercised .opencode/scripts/validate-skills.sh the primary PyYAML code path ran (the script's optional fallback parser was NOT exercised on this host). The fallback parser path is still relevant for CI/containers that lack PyYAML; the fallback behavior (extra nested-skip WARN messages) was validated by forcing a PYTHONPATH stub on this host. Record this host-level environment fact because the presence/absence of PyYAML on a developer/CI machine is not recoverable from repository commits.

- Agent naming runtime semantics (irrecoverable repo fact):
  - Creating a file under `.opencode/agents/` (an agent .md) auto-registers/auto-loads that agent at OpenCode startup; this directory is an active runtime source (S4) and is not merely documentation. In practice this means adding/removing .md files can enable or disable agent names at runtime.
  - The top-level `council` block in oh-my-opencode-slim.jsonc contains model-seat identifiers (example: deepseek, gemini-3.1-pro, gpt-5.3-codex, claude-sonnet-4.5, qwen3.7-plus) and is not a source of canonical agent names. Treat council entries as model/preset seats, not agent name declarations.
  - Store: AGENTS.md §9 remains the human-canonical list (S1). The enforced contract chosen for this campaign is containment (each canonical name must resolve in at least one of the runtime sources) rather than strict 4-way equality. Record this runtime semantic because it is not obvious from diffs alone and will prevent future re-discovery.

- Delegation-observer sidecar location (2026-08-10): the delegation-observer plugin writes runtime sidecars to `.opencode/session/` including `registry.jsonl` (append-only dispatch/start/finish rows) and `messages.jsonl` (session message sidecar). These files are gitignored and therefore invisible to default ripgrep/glob queries that respect .gitignore. Operational tip: if a search reports "not found", check the session directory directly (`ls -la .opencode/session/`) or use the read tool to inspect these files; do not assume absence from a glob search implies files are missing. Record this here because the earlier campaign confusion (session-level "not found" glob result) was caused by this visibility property and is not reconstructible from repo diffs.

- pnpm named-volume staleness (2026-08-04): observed staleness in a named pnpm store Docker volume produced MODULE_NOT_FOUND errors after dependency changes (example: author-studio @quasar/app-vite). Root cause: lockfile/host working-tree `pnpm install` updates were not reflected inside the long-lived pnpm_store Docker volume. Remediation used during the campaign: `docker compose run --rm dev pnpm install` (refreshes the store inside the container). Notes:
  - The test-docker-smoke.sh smoke skip-guard checks binary presence but does not guard for volume freshness; consider enhancing smoke checks to validate pnpm store freshness or run `pnpm install` in CI when lockfile changed.
  - If this is tracked in DIA-048, reference the ticket and avoid duplicate action here.

- OpenCode LSP host-state (2026-08-06, research c-20260804-0900): repo + global opencode.jsonc enable the built-in LSP client ("lsp": true) and the orchestrator has "lsp": "allow" permission, but the language server binaries are not present on the developer host PATH. Typescript and Rust language servers are installed only inside the project's Docker dev container (Dockerfile.dev installs typescript-language-server/typescript and rust-analyzer via rustup); the host lacks typescript-language-server and rust-analyzer and .mise.toml only pins node/pnpm. Net effect: OpenCode's native LSP on the host is effectively non-functional despite lsp: true. This is a cross-file, operational repo fact (config + Dockerfile + host PATH) not recoverable from a single commit or file. Remediation options: install the language-server binaries on host PATH, define a project `lsp` object that points to containerized servers, or rely on VS Code's devcontainer / remote LSP in the dev container. Record this here to help future devs avoid assuming host LSP is available.

- RUST_ANALYZER_VERSION rationale (2026-08-06): the pinned `RUST_ANALYZER_VERSION=1.83.0` in `scripts/lsp-versions.env` was chosen to match the project's Dockerfile.dev `RUST_VERSION=1.83.0` pin and because rust-analyzer is installed inside the dev image via `rustup component add rust-analyzer` on that toolchain. The selection is an intentional alignment with the container toolchain rather than a live host stable-channel probe; on hosts with a different active rustup toolchain the owner should either update the env pin or set `SKIP_RUST=1` as described in docs/dev-infra/host-lsp-setup.md. The env value itself is stored in repo files; this short rationale (why the pin matches the container toolchain) is an operational decision not captured elsewhere in the repository.

- Ticket ledger drift: DIA-063 README/Index mismatch (2026-08-08):
  - Observation: the ticket file `docs/dev-infra-audit/tickets/DIA-063.md` exists but is not listed in the tickets README index/count. This ledger-index drift was noticed during the campaign and indicates a bookkeeping mismatch between ticket files and the canonical index.
  - Recommendation: reconcile the tickets README index with the tickets directory; prefer a scripted index regeneration in `scripts/` to avoid manual drift. Record this repo fact because ticket inventory and README sync state is not always reconstructible from git alone when working-tree edits are in-flight.

- Gate-script layout (2026-08-12): the pre-push hook gate lives at `scripts/verify-pre-push.sh` and runs the full dev-infra gate suite (`make test-shell` + `make test-config` + pnpm gates). Its bats coverage is `scripts/__tests__/verify-pre-push.bats` (9 tests). Because the script invokes the full suite, it must carry a re-entrancy env-flag guard (VERIFY_PRE_PUSH_RUNNING) to prevent recursion when run inside the dev container — see the DIA-142 fork-bomb ADR in adr.md. Navigational pointer only; mechanics recoverable from the files.

- Git worktrees parallel-dev (DIA-100, 2026-08-12): the worktree lifecycle CLI
  lives at `scripts/worktrees.sh` (`create` / `remove` / `list`); bats coverage
  is `scripts/__tests__/worktrees.bats` (T1-T16). The authoritative design
  conventions (branch naming, path mapping, squash-merge strategy, DIA-096
  safe/destructive mapping, cleanup, conflict escalation, session isolation,
  orchestrator dispatch templates) are in
  `docs/dev-infra-audit/worktree-conventions.md`. Worktrees materialize under
  `.worktrees/` at the repo root (git-ignored; also mirrored in
  `tools/opencode-docker/`). This is a navigational pointer only; the mechanics
  themselves are recoverable from those tracked files.

- Executable-bit management (DIA-118, 2026-08-12): the repo sets
  `core.filemode=false` in `.git/config` (repo-local, not committed), so plain
  `chmod +x` on a tracked file is silently dropped at commit time. Any new
  executable script (e.g. scripts/worktrees.sh, which must stay 100755) must be
  staged with `git update-index --chmod=+x <file>` and verified via
  `git ls-files -s <file>`. This config value is not recoverable from the repo
  tree, so future authors must know it is set. Cross-reference: lessons.md S18
  core.filemode=false chmod trap.

- Bats hermetic-sandbox seeding pattern (DIA-119, 2026-08-12): bats cases in
  `scripts/__tests__/verify-pre-push.bats` and `verify-pre-commit.bats` that fake
  pnpm/npx seed a sandbox `package.json` importer manifest (with the four
  `verify:*` scripts for pre-push) and a `node_modules/.bin/<cmd>` executable
  stub (for pre-commit's lint-staged). Real npx resolves from node_modules/.bin,
  not package.json scripts, so the stub location is the fix. These two files are
  the canonical reference implementation for the resolution-independent sandbox
  pattern. Recoverable from code; listed as a navigational pointer only.

- Bats vendored-version drift (DIA-121, CLOSED 2026-08-12): resolved by
  re-pinning. `scripts/__tests__/bats-wrapper.sh` now holds
  `BATS_VENDOR_VERSION="1.14.0"` as the SINGLE source of truth for the pinned
  bats-core version (package.json format, no leading "v"); the clone uses
  `--branch "v${BATS_VENDOR_VERSION}"`. The git-ignored vendor dir
  `scripts/__tests__/vendor/bats-core` had drifted to v1.14.0 while the old pin
  claimed v1.11.0; the wrapper now runs
  `scripts/__tests__/check-bats-vendor-drift.sh "$BATS_VENDOR_VERSION" "$VENDOR_DIR"`
  on every run to close the gap. The drift check extracts the TOP-LEVEL
  package.json version with an awk brace-depth state machine (string-aware;
  deliberately not a naive first-match sed because a nested object can carry its
  own "version" key). On mismatch the check warns to stderr and exits 1, but the
  wrapper does NOT propagate the exit (warn-and-continue: not re-clone, not
  hard-fail) to avoid destructive/network-dependent behavior and developer
  lockout. Bats coverage: `scripts/__tests__/check-bats-vendor-drift.bats`
  (10 tests). Navigational pointer only; the design rationale is documented
  in-code and in the DIA-121 ticket. See lessons.md S19 for the prettier
  frontmatter workaround that bit this ticket's fix twice.

- Needs-input ticker runtime artifacts (DIA-122, 2026-08-13):
  - `.opencode/session/ticker.json` is the plugin-written state (JSON schema:
    `version` number, `updated_at` timestamp, `waiting` list, `errors` list;
    entries carry session_id/title/agent/reason/detail/since). It is GITIGNORED
    and written atomically by `.opencode/plugins/needs-input-observer.ts`.
  - `.opencode/session/ticker.md` is a DERIVED VIEW (markdown table of waiting
    sessions oldest-first, plus an `## Errors` section) regenerated by
    `scripts/ticker-render.sh` - never edit ticker.md by hand.
  - `scripts/ticker-render.sh` honors the env seams `TICKER_FILE` (default
    `.opencode/session/ticker.json`) and `TICKER_OUTPUT` (default
    `.opencode/session/ticker.md`); requires jq; exits 0 always (missing/malformed
    ticker.json renders the empty state). Both session artifacts are gitignored, so
    a glob/ripgrep that respects .gitignore will not find them - check the
    `.opencode/session/` dir directly (same visibility caveat as registry.jsonl,
    see the 2026-08-10 delegation-observer sidecar entry).

- Knowledge-base additions (2026-08-13, DIA-125 + DIA-123):
  - `knowledge/res018-ticket-management-automation/` holds the DIA-125
    decision-support conspect (22 archived sources). Its durable recommendation:
    a HYBRID - keep the git-backed markdown ledger
    (`docs/dev-infra-audit/tickets/`) and add a THIN local CLI/MCP writer, with
    Tier 1/2/3 implementation options. Brief pointer: consult res018 before
    re-researching ticket-automation options.
  - `.opencode/learnings/external-patterns/2026-08-13-deterministic-restart-detection.md`
    is the DIA-123 section-10 Phase-1 gate research on deterministic restart
    detection.
  - The conspects are tracked in git; this entry records only the one-line
    recommendation pointer so a future session does not re-research the same
    decision space.

- Research-lane tool-gap recurrence (2026-08-13, DIA-067 class):
  - The conspecter lane this night-run had NO shell/exec primitive and used its
    webfetch tool instead of the mandated trafilatura/curl/crawl4ai CLI chain
    (Phase A), yet still satisfied archive-before-claim (22/22 archived, claims
    traced). This is a recurrence of the DIA-067-class tool-gap (res003 paused on
    missing trafilatura CLI).
  - Observation for orchestrator: this recurrence may warrant a NEW ticket when
    DIA-067 is resolved/closed (recorded here; no ticket created this run). The
    webfetch-substitution path is a viable fallback but should not become the
    permanent research-archive mechanism.

- Ticket-management CLI & coordination protocol (DIA-125, CLOSED 2026-08-13):
  `scripts/tickets` provides `new` / `rollup [--check]` / `frontier` / `help`
  for the DIA ledger under docs/dev-infra-audit/tickets/. The multi-device
  claim/coordination convention (shared git remote, session_id +
  lease_expires_at single-writer token, fetch-before-take) is documented in
  docs/dev-infra-audit/tickets/COORDINATION.md. Bats coverage:
  scripts/__tests__/tickets.bats (19 tests). Navigational pointer only; the
  CLI behavior and protocol are recoverable from those tracked files and the
  DIA-125 ticket.
