# Deterministic OpenCode Restart Detection (2026-08-13)

- **Date:** 2026-08-13
- **Source:** DIA-123 Phase-1 GATE research (ai-specialist lane, web-fresh; ticket docs/dev-infra-audit/tickets/DIA-123-deterministic-restart-detection.md - OPEN planning ticket). Registered per AGENTS.md section 10 Phase 1 ("orchestrator registers the findings").
- **Status:** PENDING - gate research complete; fix design NOT implemented yet. DIA-123 awaits developer review/opt-in to start the section-10 implementation workflow.
- **Ticket:** DIA-123 (OPEN planning) - "deterministic opencode restart detection for the orchestrator".

## Context

The orchestrator cannot deterministically detect opencode process restarts. Today the only artifact proving tool load after restart is the needs-input-observer plugin's ticker.json boot re-seed, detected only via directory-mtime proof of file creation (weakness 1-5 documented in DIA-123). This research is section-10 Phase-1 gate research; the fix design is NOT implemented yet.

## Key findings (5 research questions)

### Q1: Boot/lifecycle events exposed to server plugins

- OpenCode exposes session lifecycle events via the `event` catch-all hook. `session.created` fires at session creation carrying sessionID + info (id, slug, projectID, parentID, title, version, time.created, time.updated, permission, agent). It identifies the SESSION, not the PROCESS (multiple sessions share one process in the orchestrator case).
- There is NO dedicated tool.load / plugin.load / process.start event in V1 or V2. The plugin function invocation itself (V1) or `setup()` (V2) IS the boot moment but is NOT surfaced as a subscribable event.
- `server.connected` fires when an SSE client connects - closest external "process started" signal but not a plugin boot event.
- Plugin init flow: internal plugins -> external plugins (PluginLoader.loadExternal) -> applyPlugin() calls plugin function -> config hook fires after all plugins loaded -> event bus subscription forwards events to hooks[].event. No post-init event emitted to the bus.
- Confidence: HIGH. Sources: opencode.ai/docs/plugins/ (V1), opencode.ai/v2/docs/build/plugins (V2), github.com/anomalyco/opencode packages/plugin/src/index.ts + packages/opencode/src/plugin/index.ts, @opencode-ai/sdk types.gen.d.ts (fetched 2026-08-13).

### Q2: Canonical boot marker / process start time conventions

- Pattern A (OS-level introspection): claude-mem uses /proc/<pid>/stat field 22 (starttime in jiffies) on Linux, ps -p <pid> -o lstart= on macOS, captured at write time, verified at read time; solves PID-reuse in containers.
- Pattern B (UUID-per-process + startup timestamp): boot_id = randomUUID() at process start, process_started_at = new Date().toISOString(), written to a boot marker file or first JSONL row. OpenCode Swarm uses createdAt + schemaVersion per record with append-only JSONL + file locking.
- Pattern C (session-id-as-boot-evidence): Claude Code and OpenCode use session UUID as process identity, but that identifies the session, not the process.
- RECOMMENDED: combine Pattern B with the plugin init moment: boot_id = randomUUID() at plugin function invocation, process_started_at recorded, written to a boot marker AND as the first event in registry.jsonl, plus boot_id/process_started_at fields in ticker.json separate from updated_at.
- Confidence: HIGH. Sources: github.com/thedotmack/claude-mem process-registry.ts, anthropics/claude-code issues #63758/#44607, github.com/ZaxbyHub/opencode-swarm plan-durability.md, code.claude.com/docs/en/agent-sdk/sessions.

### Q3: Boot markers in existing OpenCode plugins

- NO existing OpenCode plugin surveyed writes an explicit boot marker or process-start event. delegation-observer.ts seeds seq from existing row count at boot (line ~330-354) - a read-side reconstruction, not a write-side marker. needs-input-observer.ts seeds waiting/errors from ticker.json on boot; updated_at reflects last state change, not boot time.
- Community plugins (opencode-learning observations.jsonl, opencode-plugin-logger per-session JSONL, opencode-permission-audit with version field, OpenCode Swarm with createdAt + lock-based monotonic seq + .plan-write-marker) all lack an explicit boot marker. The exact gap DIA-123 addresses.
- Confidence: HIGH. Sources: github.com/keefetang/opencode-learning, frankhommers/opencode-plugin-logger, prandelicious/opencode-permission-audit, ZaxbyHub/opencode-swarm; local .opencode/plugins/delegation-observer.ts + needs-input-observer.ts.

### Q4: Monotonic sequence numbers in registry.jsonl

- Root cause of non-monotonicity (35 out-of-order transitions, last 2898 -> 2866): the writer seeds seq from LINE COUNT (lines.filter(Boolean).length, delegation-observer.ts:330-354), NOT max(seq). If rows are externally removed (compaction, hand-edit, rotation, concurrent plugin instances), line count drops below max seq and new rows collide or regress. Confirmed at registry.jsonl lines 2899-2900 (2898->2866), 196-197 (196->172), 232-233 (229->176).
- RECOMMENDED (Option A + B): (A) seed from max(seq) by parsing existing rows; (B) in-writer guard: before append, read last seq; if >= counter, jump ahead (handles concurrent writers/external appends; one extra file read per append is negligible at ~3000 rows). Option C (timestamp+uuid, drop seq) is breaking for seq-sorting consumers. Minimal code change, backwards-compatible.
- Confidence: HIGH. Source: local delegation-observer.ts:330-354, 394-417; local registry.jsonl non-monotonic rows.

### Q5: Unified event writer - is there an OpenCode-native event stream?

- There is NO single OpenCode-native persistent event stream for plugins. The event bus is an in-process pub/sub (plugins subscribe via event hook; SSE /event endpoint is ephemeral, first event server.connected). OpenCode's own persistence is SQLite; the .opencode/session/*.jsonl sidecars are entirely plugin-managed. Community plugins follow the same plugin-local JSONL sidecar pattern.
- RECOMMENDED: keep the dual-file approach (registry.jsonl = plugin lifecycle, messages.jsonl = orchestrator semantic events) but extract a shared appendJsonl(filePath, row) helper with consistent identity, atomic-append semantics and the fail-soft policy - formalizing the pattern both writers already follow reduces divergence risk.
- Confidence: HIGH. Sources: opencode.ai/docs/plugins/, opencode.ai/docs/server/ (fetched 2026-08-13); local code.

## Synthesized recommendation for the DIA-123 fix design (NOT yet implemented; awaits developer review/opt-in)

1. Boot event: use the plugin function invocation as the boot moment; generate BOOT_ID = randomUUID(), PROCESS_STARTED_AT = new Date().toISOString(); write a `boot` event as the FIRST registry.jsonl row (event, boot_id, process_started_at, opencode_plugin_version, registered_tools, writer).
2. ticker.json: add boot_id and process_started_at fields separate from updated_at.
3. Monotonicity: seed from max(seq) + in-writer regression guard (Option A+B).
4. Unified writer: shared appendJsonl helper with fail-soft policy.

## Delta: current state vs best practice

| Aspect | Current | Proposed |
| Boot evidence | None (ticker.json dir-mtime only) | Explicit boot event in registry.jsonl + boot_id/process_started_at in ticker.json |
| Boot identity | No boot_id | randomUUID() per plugin load |
| Process start time | Not recorded | ISO timestamp at plugin invocation |
| Seq monotonicity | Seed from line count (fragile) | Seed from max(seq) + regression guard |
| Unified writer | Two independent appenders | Shared helper |
| Event stream | Plugin-local JSONL (correct) | No change - no OpenCode-native alternative |

## Outcome field (fill at decision time)

Decision: PENDING developer review (DIA-123 awaits opt-in to start section-10 implementation workflow). [Update this field after the developer decides.]

## Tags

DIA-123, deterministic-restart-detection, boot-marker, registry-jsonl, monotonic-seq, plugin-boot, section-10-gate, ai-specialist
