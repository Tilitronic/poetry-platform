# Tasks: dia-067-docker-trafilatura

> **Proposal:** `openspec/changes/dia-067-docker-trafilatura/proposal.md`
> **Design:** `openspec/changes/dia-067-docker-trafilatura/design.md`
> **Source ticket:** `docs/dev-infra-audit/tickets/DIA-067.md` (agents inside docker dev environment cannot invoke `trafilatura`).
> **Strategy analysis:** `knowledge/ana001-docker-trafilatura-strategy/ana001-docker-trafilatura-strategy-report.md` (Option C recommended, 9.0/10).
> **Workflow:** per `openspec/config.yaml`, each task is a vertical slice invoked via the `tdd-craftsman` skill. Write the failing test BEFORE production code. Work one slice at a time.
> **Routing:** AGENTS.md §2.4 (dev-infra within existing boundaries → `@reviewer`, two-axis: Standards + Spec fidelity). No §10 AI-tooling routing — the change only READS Dockerfile + smoke-test; it does not modify opencode config.

## Dependency graph

```
T1 (Dockerfile: ARG + uv tool install + ENV UV_TOOL_BIN_DIR)
 │
 │ (foundation — T2 builds on T1's install)
 │
 └──▶ T2 (Smoke-test probe: trafilatura --version assertion)
         │
         │ (depends on T1 — needs trafilatura installed in the image)
         │
         └──▶ T3 (Verification: make test-infra + conspecter re-dispatch)
                 │
                 │ (depends on T2 — needs the probe wired into the smoke test)
```

**Critical path:** T1 → T2 → T3 (linear; no parallelism possible because each task depends on the previous).

**Rationale for ordering:**

- **T1 is first** because it is the foundation (Dockerfile change). Without trafilatura installed in the image, T2 and T3 cannot run.
- **T2 depends on T1** because the smoke-test probe asserts trafilatura is present in the running container. The probe cannot pass until the image is built with trafilatura.
- **T3 depends on T2** because `make test-infra` runs the smoke test, which includes the probe from T2. The conspecter re-dispatch also requires the probe to pass (as part of `make test-infra` exit 0).
- **No parallelism** — each task is a single vertical slice that depends on the previous. This is intentional: the change is small (2 files, ~10 lines total), and parallelism would add coordination overhead without benefit.

---

## T1 — Dockerfile: ARG + uv tool install + ENV UV_TOOL_BIN_DIR

**Blockers:** none
**Vertical slice:** add the trafilatura install to Dockerfile.dev. After T1, `docker compose build dev` succeeds and the image contains trafilatura 2.2.0 on PATH for the dev user.

### What changes

1. **`Dockerfile.dev`** — insert the following block after line 147 (`uv --version`) and before line 149 (`# === Rust toolchain`):

   ```dockerfile
   # === trafilatura — source-capture CLI for @conspecter Phase A (DIA-067) ===
   # uv tools install to UV_TOOL_BIN_DIR (default: ~/.local/bin of the invoking
   # user). We set UV_TOOL_BIN_DIR=/usr/local/bin so the binary is on PATH for
   # all users (including the non-root `dev` user created later). This avoids the
   # root-vs-dev-user scope issue (uv tool install as root → /root/.local/bin
   # is not on the dev user's PATH). The tool's Python dependencies install to
   # uv's internal isolated environment (no system Python pollution).
   # Version pinned via ARG for deterministic builds (same pattern as UV_VERSION,
   # RUST_VERSION, MISE_VERSION, SNIP_VERSION). Fallback: if `uv tool install`
   # fails (dependency conflict, missing system library), replace with
   # `uv pip install --system --break-system-packages trafilatura==${TRAFILATURA_VERSION}`
   # (the playwright/crawl4ai pattern at line 186) — see design.md §Risk 1.
   ARG TRAFILATURA_VERSION=2.2.0
   ENV UV_TOOL_BIN_DIR=/usr/local/bin
   RUN uv tool install trafilatura==${TRAFILATURA_VERSION} && \
       trafilatura --version
   ```

2. **`Dockerfile.dev` ARG block** — add `ARG TRAFILATURA_VERSION=2.2.0` to the ARG block at the top of the file (lines 21-39) for consistency with the other version pins. **Alternatively**, keep the ARG declaration inline with the install step (as shown above) — this is a style choice. The inline approach is used by `MISE_VERSION` (line 131) and `TINI_VERSION` (line 34), so it has precedent.

   **Recommendation:** Inline ARG (as shown above) — matches the `MISE_VERSION` and `TINI_VERSION` precedent.

### Acceptance criteria (user perspective)

- `docker compose build dev` succeeds.
- The build log shows `trafilatura --version` output (version 2.2.0 or similar).
- `docker compose run --rm dev trafilatura --version` returns 2.2.0 (or contains 2.2.0).
- The non-root `dev` user can invoke `trafilatura` (not just root).

### Verification procedure

1. `docker compose build dev` — exits 0, build log contains `trafilatura --version` output.
2. `docker compose run --rm dev trafilatura --version` — returns `2.2.0` (or contains `2.2.0`).
3. `docker compose run --rm dev bash -c 'which trafilatura'` — returns `/usr/local/bin/trafilatura` (not `/root/.local/bin/trafilatura`).
4. `docker compose run --rm dev bash -c 'whoami && trafilatura --version'` — returns `dev` + version 2.2.0 (confirms the dev user can invoke it).

### Testing

No unit tests — this is a Dockerfile change. Verification is via Docker build + runtime probe (T2).

---

## T2 — Smoke-test probe: trafilatura --version assertion

**Blockers:** T1
**Vertical slice:** add a trafilatura probe to `scripts/test-docker-smoke.sh`. After T2, `bash scripts/test-docker-smoke.sh` asserts trafilatura is present + version 2.2.0 inside the running container.

### What changes

1. **`scripts/test-docker-smoke.sh`** — insert the following block after line 128 (end of the openspec/make probe) and before line 131 (start of the mise probe):

   ```bash
   echo "-> verifying trafilatura (DIA-067: source-capture for @conspecter)..."
   # DIA-067: trafilatura is installed via `uv tool install` in Dockerfile.dev.
   # The probe asserts the binary is on PATH for the dev user and the version
   # matches the pinned ARG. Follows the openspec version probe pattern (lines
   # 118-128): `docker compose exec -T dev <tool> --version` + version-string
   # assertion + `echo "ok: <tool> ${ver}"`.
   traf_ver="$(docker compose exec -T dev trafilatura --version 2>&1)"
   if [[ "$traf_ver" != *"2.2.0"* ]]; then
     echo "error: trafilatura --version is '$traf_ver', expected 2.2.0" >&2
     exit 1
   fi
   echo "ok: trafilatura ${traf_ver}"
   ```

2. **`scripts/test-docker-smoke.sh` comment header** — update the numbered verification list at the top of the file (lines 8-21) to include trafilatura:

   ```bash
   #   6.5 trafilatura is present and version 2.2.0 (DIA-067)
   ```

   **Alternatively**, renumber the list — but this would require updating all subsequent numbers. **Recommendation:** Insert `6.5` to avoid renumbering (same pattern as the existing list, which uses `6`, `7`, `8`, ...).

### Acceptance criteria (user perspective)

- `bash scripts/test-docker-smoke.sh` passes (exits 0) and the output contains `ok: trafilatura 2.2.0` (or similar).
- If trafilatura is absent or the wrong version, the probe fails with a clear error message: `error: trafilatura --version is '<actual>', expected 2.2.0`.
- The probe runs as part of the standard `make test-infra` flow (no separate target needed).

### Verification procedure

1. `docker compose up -d --build` — starts the stack with the new image.
2. `bash scripts/test-docker-smoke.sh` — exits 0, output contains `ok: trafilatura 2.2.0`.
3. Temporarily break the probe (e.g., change `2.2.0` to `9.9.9` in the probe) — `bash scripts/test-docker-smoke.sh` exits 1, stderr contains `error: trafilatura --version is '2.2.0', expected 9.9.9`.
4. Revert the probe change.

### Testing

No unit tests — this is a smoke-test probe. Verification is via `make test-infra` (T3).

---

## T3 — Verification: make test-infra + conspecter re-dispatch

**Blockers:** T2
**Vertical slice:** run `make test-infra` to verify the full flow (build + smoke test + Python tests). After T3, `make test-infra` exits 0 and the trafilatura probe passes. Then re-dispatch `@conspecter` to verify the end-to-end flow (Phase A source capture).

### What changes

No code changes — this is a verification task.

1. **Run `make test-infra`** — builds the image, runs the smoke test (including the trafilatura probe), runs Python tests. Expected: exit 0.

2. **Re-dispatch `@conspecter`** — for the 11 source URLs from the res003 tool-enumeration research (`knowledge/res003-tool-enumeration/sources/`). Expected: all 11 `sources/*.md` files > 0 bytes.

3. **Verify Phase B conspect** — the conspecter writes the Phase B conspect to `knowledge/res003-tool-enumeration/conspect.md`. Expected: conspect exists + > 0 bytes.

4. **Verify memory-shelf entry** — the conspecter registers the conspect in `.opencode/memory-shelf.yaml`. Expected: entry present.

5. **Verify host-side `which trafilatura`** — expected absent (DIA-067 ticket §Verification step 3 — documents the gap is closed inside the container, not on the host).

### Acceptance criteria (user perspective)

- `make test-infra` exits 0.
- The smoke-test output contains `ok: trafilatura 2.2.0` (or similar).
- All 11 `knowledge/res003-tool-enumeration/sources/*.md` files are > 0 bytes.
- `knowledge/res003-tool-enumeration/conspect.md` exists and is > 0 bytes.
- `.opencode/memory-shelf.yaml` contains a res003 entry.
- `which trafilatura` on the host returns nothing (or `not found`).

### Verification procedure

1. `make test-infra` — exits 0.
2. `ls -la knowledge/res003-tool-enumeration/sources/` — all 11 files > 0 bytes.
3. `ls -la knowledge/res003-tool-enumeration/conspect.md` — file exists + > 0 bytes.
4. `grep res003 .opencode/memory-shelf.yaml` — entry present.
5. `which trafilatura` — returns nothing (host-side).

### Testing

No unit tests — this is an integration verification task.

---

## Summary

| Task | Blockers | Vertical slice                                          | Exit criteria                                                                  |
| ---- | -------- | ------------------------------------------------------- | ------------------------------------------------------------------------------ |
| T1   | none     | Dockerfile: ARG + uv tool install + ENV UV_TOOL_BIN_DIR | `docker compose build dev` succeeds + `trafilatura --version` returns 2.2.0    |
| T2   | T1       | Smoke-test probe: trafilatura --version assertion       | `bash scripts/test-docker-smoke.sh` passes + output contains `ok: trafilatura` |
| T3   | T2       | Verification: make test-infra + conspecter re-dispatch  | `make test-infra` exits 0 + conspecter Phase A produces >0-byte source files   |

**Total tasks:** 3
**Estimated effort:** 2-4 hours (T1: 30 min, T2: 15 min, T3: 1-3 hours including conspecter re-dispatch)
**Critical path:** T1 → T2 → T3 (linear)

## Notes for the coder lane

1. **OPEN QUESTION 1 (design.md):** The `UV_TOOL_BIN_DIR=/usr/local/bin` env var is recommended to ensure uv tools install to a system-wide location. If this doesn't work (uv ignores the env var, or the tool still installs to `/root/.local/bin`), fall back to Option A: `uv pip install --system --break-system-packages trafilatura==${TRAFILATURA_VERSION}` (the playwright/crawl4ai pattern at line 186). Test T1's verification step 3 (`which trafilatura` should return `/usr/local/bin/trafilatura`) to confirm the approach works.

2. **OPEN QUESTION 2 (design.md):** The probe placement in `test-docker-smoke.sh` is recommended after line 128 (openspec/make probe). If the developer prefers a different location, adjust accordingly.

3. **No bats tests needed** — this is a Dockerfile + smoke-test change. The bats test suite (`scripts/__tests__/`) does not test Dockerfile contents. The smoke test is the integration test for Docker tooling.

4. **Fallback plan** — if `uv tool install` fails at build time (T1), switch to Option A (`uv pip install --system --break-system-packages`) and document the reason in the PR description. The smoke-test probe (T2) remains unchanged.

5. **Conspecter re-dispatch (T3)** — this is a manual step. The coder lane should coordinate with the orchestrator to re-dispatch `@conspecter` after T1 and T2 are complete. The conspecter will need the 11 source URLs from `knowledge/res003-tool-enumeration/sources/` (check the directory for the URL list).
