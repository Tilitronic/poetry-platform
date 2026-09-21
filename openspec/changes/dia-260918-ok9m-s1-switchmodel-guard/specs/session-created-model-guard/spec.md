## Purpose

This capability ensures every newborn session lands on the preset intent model at creation time, closing the /new stale-model gap where the footer and the routing disagree.

## ADDED Requirements

### Requirement: Divergent newborn session is switched once to preset intent

The system SHALL call switchModel exactly once for a newborn session whose model diverges from the preset intent when the preset env is present and no explicit user override exists.

#### Scenario: Divergent session with env and no override

- **WHEN** a session.created event arrives with model M, env OH_MY_OPENCODE_SLIM_PRESET resolves to intent P, M differs from P, and no synthetic override marker (info.override "model" or "agent") is present
- **THEN** the guard calls switchModel once with the session ID and P, and subsequent requests use P
- Seam: v2 session.created event hook (same channel family as delegation-observer "event" seam).

### Requirement: Explicit user override is never clobbered

The system SHALL NOT call switchModel when the newborn session carries the synthetic explicit-override marker.

Scope limit (rev-1 Critical): the marker is best-effort synthetic ONLY. A real --model flag or agent-model selection carries NO marker on session.created payloads in OMO 2.2.19 (verified against the vendored dist: zero info.override hits), so real --model sessions are NOT exempt and a divergent real --model newborn IS switched. The spec promises nothing the payload does not carry.

#### Scenario: Synthetic explicit-override marker is exempt

- **WHEN** a session.created event arrives carrying info.override "model" (synthetic explicit --model signal) or "agent" (synthetic agent-model selection), via the event payload or the session.get() mirror, with a divergent model and valid env
- **THEN** the guard makes zero switchModel calls and the session keeps its selected model
- Seam: v2 session.created event hook.

### Requirement: Slash-less env resolves as preset name

The system SHALL resolve a slash-less preset env value as a preset NAME via presets[<name>].orchestrator.model (first entry on array form) read live from the repo presets config; any lookup failure (missing file, bad JSON, missing preset, unusable ref) degrades to the unparsable one-log no-op and the session keeps its newborn model.

#### Scenario: Preset-NAME env switches divergent newborn via mapped model

- **WHEN** a session.created event arrives with model M, env OH_MY_OPENCODE_SLIM_PRESET holds a slash-less name N, presets[N].orchestrator.model resolves to intent P, and M differs from P with no synthetic override marker present
- **THEN** the guard calls switchModel once with the session ID and P
- Seam: v2 session.created event hook.

### Requirement: Absent env is a no-op

The system SHALL do nothing when the preset env is absent or empty.

#### Scenario: Env absent leaves session untouched

- **WHEN** a session.created event arrives and OH_MY_OPENCODE_SLIM_PRESET is absent or empty
- **THEN** the guard makes zero switchModel calls and the session keeps its newborn model
- Seam: v2 session.created event hook.

### Requirement: Already-correct session is a no-op

The system SHALL NOT call switchModel when the newborn session model already equals the preset intent.

#### Scenario: Matching model needs no switch

- **WHEN** a session.created event arrives with model M and the preset intent P where M equals P
- **THEN** the guard makes zero switchModel calls
- Seam: v2 session.created event hook.

### Requirement: Duplicate creation events fire only once

The system SHALL call switchModel at most once per session ID no matter how many session.created events arrive for it.

#### Scenario: Double event for same session ID

- **WHEN** two session.created events arrive for the same session ID with a divergent model and valid env
- **THEN** total switchModel calls for that session ID equal exactly one
- Seam: v2 session.created event hook (fired-set guard).

### Requirement: Guard failures never break session creation

The system SHALL degrade to a no-op with a single log line when the preset intent is unparsable, switchModel throws or rejects, or the v2 shape has drifted, and the session MUST survive on its newborn model with no retry.

#### Scenario: switchModel throws and session survives

- **WHEN** the guard attempts switchModel and the call throws or rejects
- **THEN** the error is caught and logged once, no retry is scheduled, and the session continues on its newborn model
- Seam: v2 session.created event hook (fail-soft boundary).
