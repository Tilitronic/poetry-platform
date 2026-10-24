# DIA-067 — Docker dev-tool access gap — agents cannot invoke trafilatura (blocks res003 persistence)

<!-- Discovered 2026-08-08: res003 persistence pipeline (research-pipeline
     skill → conspecter Phase A) requires the trafilatura CLI to archive 11
     source URLs for the tool-enumeration research (DIA-066 pre-scoping).
     Conspecter (con-1) twice attempted Phase A — all 11 source files created
     EMPTY (0 bytes). New root blocker for the res003 persistence pipeline;
     cross-references DIA-057/058 context.
     UPDATE 2026-08-08: IMPLEMENTED (coder lane, DIA-067 openspec change
     dia-067-docker-trafilatura). Fix touches Dockerfile.dev +
     scripts/test-docker-smoke.sh. See Fix. NOT yet VERIFIED — runtime
     re-verify (conspecter re-dispatch) is a separate lane.
     UPDATE 2026-08-08: VERIFIED — conspecter re-dispatch (con-5) completed:
     11/11 sources/*.md > 0 bytes, Phase B conspect + memory-shelf entry
     under id res004, make test-config exit 0. See Re-verify. -->

---

id: DIA-067
title: "Docker dev-tool access gap — agents cannot invoke trafilatura (blocks res003 persistence)"
area: docker
severity: Blocker
status: VERIFIED
blocked_by: []
discovered: 2026-08-08
source: test-lane
date: 2026-08-08
created: 2026-08-08
updated: 2026-08-08

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_02091ea93ffeguuvio9O3jjI9J"
lane_id: "dia-067-docker-trafilatura"
agent: "coder"
model: ""
parent_session_id: ""
attempts: 1
lease_expires_at: ""
files_touched: ["Dockerfile.dev", "scripts/test-docker-smoke.sh", "docs/dev-infra-audit/tickets/DIA-067-docker-dev-tool-access-gap.md"]
artifacts: []
evidence: ["ses_02110793fffeKFqhWUcZSiXLYI (conspecter con-1: Phase A ×2 attempts, 11 source files EMPTY 0B)", "implementation lane: docker compose build dev exit 0; smoke test exit 0 incl. trafilatura probe", "ses_01e1416c3ffeX6ulgERMXvzHHE (conspecter con-5 re-verify: Phase A 11/11 sources > 0B + Phase B conspect res004 + memory-shelf entry; make test-config exit 0)"]

---

## Description

res003 persistence pipeline (research-pipeline skill → conspecter Phase A)
requires the trafilatura CLI to archive 11 source URLs for the
tool-enumeration research (DIA-066 pre-scoping). Conspecter (con-1,
ses_02110793fffeKFqhWUcZSiXLYI) twice attempted Phase A: all 11 source files
were created EMPTY (0 bytes) — `/bin/bash: trafilatura: command not found` on
host; pip/ensurepip unavailable; apt needs root.

Docker IS running on the host and (per developer) provides dev tooling, but
there is NO bridge from the host-side OpenCode environment (where agents
execute) into the container's binaries. Design expectation (developer,
2026-08-08): "Docker must provide all dev instruments".

**Impact:** this blocks the res003 conspect + memory-shelf registration
(research-pipeline Phase 3-4) under `knowledge/res003-tool-enumeration/`.

- **blocked_by:** (none — new root blocker)
- **blocks:** res003 persistence pipeline (knowledge/res003-tool-enumeration/)

## Verification

Tests to run at fix time:

1. `docker ps` — container running.
2. `docker exec <container> trafilatura --version` — tool present in container.
3. `which trafilatura` host-side — expected absent (documents the gap).

## Fix

**Implemented 2026-08-08 (coder lane; openspec change `dia-067-docker-trafilatura`).**

**Strategy (developer-approved):** Option C (`uv tool install`) with
`ENV UV_TOOL_BIN_DIR=/usr/local/bin` — per ana001 analysis
(`knowledge/ana001-docker-trafilatura-strategy/`, Option C 9.0/10).

**FALLBACK APPLIED:** Option C proved broken at runtime (T1 verification
failed). `UV_TOOL_BIN_DIR=/usr/local/bin` moved the launcher symlink to
`/usr/local/bin`, but the uv tool environment stayed under
`/root/.local/share/uv/tools/` (build-time `ENV HOME=/root`), and `/root` is
`drwx------` — the non-root `dev` user could not read the symlink target
(`trafilatura --version` → Permission denied; `which trafilatura` → rc 1).
Switched to the design-sanctioned fallback **Option A**
(`uv pip install --system --break-system-packages trafilatura==2.2.0`, the
playwright/crawl4ai pattern at Dockerfile.dev:203). See design.md §Risk 1 /
§Migration Plan fallback.

**Files changed:**

- `Dockerfile.dev` — trafilatura install block after uv install (~line 149),
  before Rust toolchain: `ARG TRAFILATURA_VERSION=2.2.0` +
  `RUN uv pip install --system --break-system-packages trafilatura==${TRAFILATURA_VERSION} && trafilatura --version`
  (with comment documenting the Option C → Option A fallback and why).
- `scripts/test-docker-smoke.sh` — trafilatura probe after the openspec/make
  probe (~line 131), before the mise probe; asserts `trafilatura --version`
  contains `2.2.0`; header list updated (`6.5 trafilatura ...`).

**Verification evidence (exit codes + output):**

- `docker compose build dev` — exit 0 (image rebuilt; Option C layer was
  already cached from a prior partial build; Option A build re-exported image
  `poetry-platform-dev:latest`).
- Container recreated (`docker compose up -d` → `Container poetry-dev
Recreated`).
- `docker compose exec -T dev which trafilatura` → `/usr/local/bin/trafilatura`
  (exit 0).
- `docker compose exec -T dev trafilatura --version` →
  `Trafilatura 2.2.0 - Python 3.13.5` (exit 0).
- `docker compose exec -T dev bash -c 'whoami && trafilatura --version'` →
  `dev` + `Trafilatura 2.2.0 - Python 3.13.5` (confirms non-root dev user can
  invoke it).
- `bash scripts/test-docker-smoke.sh` — exit 0; probe pass line:
  `ok: trafilatura Trafilatura 2.2.0 - Python 3.13.5`; full run ends
  `ok: docker smoke test passed`.
- `make test-infra` — exit 2 (pre-existing host gate `check-host-lsp` fails:
  typescript-language-server/pyright/rust-analyzer absent from host PATH;
  script has no references to Dockerfile.dev or test-docker-smoke.sh — not a
  regression of this change). Smoke test itself passes.
- `make test-shell` — exit 2 (same pre-existing `check-host-lsp` host gate).
- `make test-opencode-docker` — exit 0.
- bats suite (`bash scripts/__tests__/bats-wrapper.sh`) — 183 ok, 0 fail,
  exit 0.

Status: OPEN → IMPLEMENTED → VERIFIED. Runtime re-verify (conspecter
re-dispatch, all 11 `sources/*.md` > 0 bytes) PASSED — see Re-verify.

## Re-verify

**RE-VERIFY PASSED 2026-08-08 (conspecter con-5 re-dispatch,
ses_01e1416c3ffeX6ulgERMXvzHHE).** All four re-verify items complete:

1. **DONE — Phase A: all 11 `sources/*.md` > 0 bytes** (total 69094 B; min
   `issue-1142-tool-list.md` 280 B, max `opencode-cli-docs.md` 14890 B). Byte
   counts per source: agent-defaults-source.md 13516; debug-agent-handler-source.md
   7843; issue-1142-tool-list.md 280; opencode-book-ch9-permissions.md 5480;
   opencode-cli-docs.md 14890; opencode-permissions-v1-docs.md 4859;
   opencode-permissions-v2-docs.md 7871; opencode-plugins-docs.md 4971;
   opencode-show-tools-npm.md 1153; opencode-tools-docs.md 5053;
   pr-9980-mcp-tools.md 3178.
   - **Two recovered gap sources:** `opencode-tools-docs.md` (5053 B)
     re-captured successfully; `opencode-show-tools-npm.md` (1153 B) is a
     **DIAGNOSTIC capture** — npmjs.com served a Cloudflare JS challenge; the
     source file records `html_title "Just a moment..."`,
     `cloudflare_challenge_present: true`, `saved_html_bytes: 5752`, and a
     transparent note that full README/metadata require a headless browser or
     npm registry API. **No content fabricated** — documented npm-capture
     limitation.
2. **DONE — Phase B conspect synthesized:**
   `knowledge/res004-tool-enumeration/res004-tool-enumeration-conspect.md`
   ("Tool enumeration in OpenCode — CLI mechanisms, permission model, plugin
   registration").
3. **DONE — Phase 4 memory-shelf entry present:** `.opencode/memory-shelf.yaml`
   `shelf.conspects` entry **id res004** ("Tool enumeration in OpenCode", path
   `knowledge/res004-tool-enumeration/res004-tool-enumeration-conspect.md`,
   created 2026-08-08). **Documented deviation:** the ticket's literal res003
   was already claimed by `knowledge/res003-telemetry-reentrancy-guards/`;
   `res004` chosen per developer decision (stale abandoned
   `knowledge/res003-tool-enumeration/` placeholder dir removed).
4. **DONE — `make test-config` exit 0** (2026-08-08).

**Conclusion:** DIA-067 FULLY VERIFIED — the trafilatura fix unblocked the
research-persistence pipeline end-to-end (Phase A capture → Phase B conspect →
Phase 4 shelf registration).
