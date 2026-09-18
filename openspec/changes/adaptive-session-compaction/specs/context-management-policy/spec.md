## Purpose

Provides adaptive session-compaction guidance to prevent context rot and maintain session quality through progressive thresholds (60% warning, 85% proactive compaction, post-compaction handoff) with state tracking that survives plugin restarts.

## ADDED Requirements

### Requirement: Context measurement via usage_fraction

The system SHALL measure context pressure using `context_usage.usage_fraction` (token-accurate, compaction-aware). The measurement SHALL be performed on each session status update.

#### Scenario: Successful measurement

- **WHEN** session status updates
- **THEN** system retrieves `usage_fraction` from `context_usage` tool
- **THEN** system stores value as `lastUsage` in `ContextPolicyState`

#### Scenario: Measurement failure

- **WHEN** `context_usage` tool returns error
- **THEN** system emits `context-policy-error` event to `registry.jsonl`
- **THEN** system continues session without blocking
- **THEN** `lastUsage` remains unchanged

### Requirement: 60% readiness warning

The system SHALL emit a readiness warning on the first upward crossing of 60% usage. The warning SHALL be rate-limited: subsequent warnings only after usage drops below 60% and crosses upward again.

#### Scenario: First upward crossing of 60%

- **WHEN** `lastUsage` transitions from ≤60% to >60%
- **THEN** system emits `context-warning-60` event to `registry.jsonl`
- **THEN** system shows user a short readiness warning message
- **THEN** system sets `warned60 = true` in state
- **THEN** system does NOT snapshot, pause, or compact

#### Scenario: Rate-limited subsequent warning

- **WHEN** `warned60 = true` and `lastUsage` remains >60%
- **THEN** system does NOT emit another `context-warning-60` event

#### Scenario: Warning after drop and re-crossing

- **WHEN** `warned60 = true` and `lastUsage` drops to ≤60%
- **THEN** system sets `warned60 = false`
- **WHEN** `lastUsage` subsequently crosses >60% again
- **THEN** system emits `context-warning-60` event (rate limit reset)

### Requirement: 85% proactive compaction

The system SHALL emit a proactive compaction request on the first upward crossing of 85% usage. The request SHALL include a concise continuation instruction and a request to manually run `/compact`. The system SHALL NOT force compaction.

#### Scenario: First upward crossing of 85% (no prior compaction)

- **WHEN** `lastUsage` transitions from ≤85% to >85%
- **WHEN** `compacted = false` in state
- **THEN** system emits `context-compact-85` event to `registry.jsonl`
- **THEN** system shows user a concise continuation instruction
- **THEN** system requests user to manually run `/compact`
- **THEN** system does NOT force compaction
- **THEN** system does NOT create separate `HANDOFF.md`

#### Scenario: Native compaction safety net

- **WHEN** `lastUsage` reaches 96-99%
- **THEN** native OpenCode auto-compaction fires (unchanged behavior)

### Requirement: Post-compaction handoff

The system SHALL trigger a plugin-managed session handoff after one completed compaction when usage crosses 85% upward again. This SHALL occur before a second manual `/compact`.

#### Scenario: Upward crossing of 85% after compaction

- **WHEN** `compacted = true` in state
- **WHEN** `lastUsage` transitions from ≤85% to >85%
- **THEN** system emits `context-new-session-post-compact` event to `registry.jsonl`
- **THEN** system shows user a concise continuation instruction
- **THEN** system recommends user to begin a new session
- **THEN** system does NOT force compaction

#### Scenario: Compaction event tracking

- **WHEN** native OpenCode compaction completes (detected via `session.compacted` hook or `experimental.compaction.autocontinue`)
- **THEN** system sets `compacted = true` in state
- **THEN** system sets `warned85PostCompact = false` in state

### Requirement: State persistence and recovery

The system SHALL maintain policy state in an in-memory `Map<string, ContextPolicyState>` seeded from `registry.jsonl` at boot. State SHALL include `lastUsage`, `warned60`, `compacted`, `warned85PostCompact`.

#### Scenario: Boot seeding from registry.jsonl

- **WHEN** plugin initializes
- **THEN** system parses `registry.jsonl` for most recent events: `context-warning-60`, `context-compact-85`, `context-new-session-post-compact`, `session.compacted`
- **THEN** system reconstructs `ContextPolicyState` from parsed events
- **THEN** system stores state in in-memory `Map<string, ContextPolicyState>`

#### Scenario: State loss on crash

- **WHEN** plugin crashes before state is persisted to `registry.jsonl`
- **THEN** state is lost (acceptable — policy is advisory, not critical)
- **THEN** system resumes with empty state on restart

#### Scenario: Malformed registry.jsonl

- **WHEN** `registry.jsonl` contains malformed JSON
- **THEN** system fails soft (starts with empty state)
- **THEN** system continues operation without blocking

### Requirement: User-directed triggers

The system SHALL NOT automate task/domain switch or confirmed context rot detection. These SHALL remain user-directed triggers.

#### Scenario: User-initiated task switch

- **WHEN** user switches task or domain
- **THEN** system does NOT automatically trigger handoff or compaction
- **THEN** user manually decides to `/compact` or start new session

#### Scenario: User-confirmed context rot

- **WHEN** user observes context rot (e.g., repeated mistakes, lost context)
- **THEN** system does NOT automatically detect or respond
- **THEN** user manually decides to `/compact` or start new session
