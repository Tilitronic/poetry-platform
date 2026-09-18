# Baseline traces — pre-refactor (Slice 0)

Captured against CURRENT delegation-observer.ts monolith on `2026-09-02T09:31:36Z` (normalized run, DIA-260902-eqgg S0).

Baseline was captured via `bun` harness running the real plugin with mocked `@opencode-ai/plugin` (mirrors `harness-scenario-replay.bats` corpus) inside poetry-dev container. Docker `compose exec` path was unavailable (daemon socket missing), so capture ran directly via `bun` in-container — same plugin code, same hook surface, same observable files.

## Scenarios

- `boot-only/` — fresh workspace, plugin load boot row only (1 registry row, boot.json)
- `empty-result-silent-failure/` — C5 scenario-1 (session.created → session.idle with zero edits → SILENT_FAILURE / empty_result_detected)
- `parallel-handoff-archive/` — C5 scenario-2 (same-session successive handoffs → distinct archive filenames via UUID suffix)
- `slot-identity-no-clobber/` — C5 scenario-3 (two pre-dispatch sessions → distinct slot files, no unknown.json)

Each dir contains:

- `registry.raw.jsonl` / `messages.raw.jsonl` — unmodified captures
- `registry.normalized.jsonl` / `messages.normalized.jsonl` — normalized per Q7 §3
- `boot.raw.json` / `boot.normalized.json` — boot marker (shares bootId/seq with registry boot row)
- `handoffs/` — snapshot of `handoffs/` slots/pointer/archive (normalized)
- `archive-listing.txt` / `archive-listing.normalized.txt` — archive file names (where applicable)
- `scenario-meta.json` — harness metadata

## Normalization (Q7 §3)

Replacements applied for later byte-equal diff on stable fields:

- ISO timestamps `YYYY-MM-DDTHH:MM:SS.mmmZ` → `<TIMESTAMP>` (also archive filename form `YYYY-MM-DDTHH-mm-ss.mmmZ`)
- UUIDs (boot_id, event_uuid, archive suffix, CAP payload id) → `<UUID>`
- Temp/workspace absolute paths (`/tmp/...`, `/<workspace>/...`) → `<TMPDIR>` / `<WORKSPACE>`
- Capability tokens `CAP-<payload>.<sig>` → `CAP-<PAYLOAD>.<SIG>`
- `seq`, `row_id`, event order/cardinality, checksums, stable payload fields preserved (parity target)
- Derived `active.json` pointer and `boot.json` seq/bootId linkage preserved in normalized form

Later slices diff normalized files byte-equal to detect behavior drift; raw files retained for audit.

## Capture command

`bun run /tmp/capture-baseline2.mjs` (resetting `globalThis[Symbol.for("delegation-observer.bootEmitted")]` between scenarios to simulate fresh process per workspace).

## Docker gate note

`docker compose ps` was unavailable (socket `/var/run/docker.sock` missing in this environment) — see task report `docker_gate: BLOCKED`. Baseline capture ran directly via `bun` without `docker compose exec -T dev`.
