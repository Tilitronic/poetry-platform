## Purpose

Provide deliberate, durable OpenCode preset selection per canonical workspace while preventing an invalid selection from silently changing model routing or cost.

## ADDED Requirements

### Requirement: Canonical workspace identity

The system SHALL use the canonical absolute workspace path returned by `realpath` as the only project-selection key. Symlinked launches that resolve to the same path SHALL share the selection. The system SHALL NOT use a repository name, Git remote, or other repository identity fallback.

#### Scenario: Symlinked launch shares selection

- **GIVEN** a workspace and a symlink that resolve to the same canonical path
- **WHEN** a preset is saved from either path
- **THEN** a subsequent launch from the other path resolves the same stored selection
- **AND** the workspace identity seam is exercised

#### Scenario: Moved or recloned workspace has no inherited selection

- **GIVEN** a preset selection stored for one canonical workspace path
- **WHEN** OpenCode launches from a moved or separately cloned workspace path
- **THEN** it has no stored selection for that path and uses the no-preset default
- **AND** the workspace identity seam is exercised

### Requirement: Effective preset resolution

Before agent setup, the system SHALL resolve one effective selection in this order: exact `PRESET=NAME` one-run override, valid stored workspace selection, then no preset. A valid selection SHALL use an exact preset name from the effective configuration for that launch. The system SHALL print the resolved preset or no-preset state and its source at startup.

#### Scenario: One-run override wins

- **GIVEN** a workspace has a valid stored preset selection
- **WHEN** it launches with a valid exact `PRESET=NAME` override
- **THEN** the launch uses the override without changing the stored selection
- **AND** the startup resolution seam is exercised

#### Scenario: No selection starts without a preset

- **GIVEN** neither an override nor a stored workspace selection exists
- **WHEN** OpenCode launches
- **THEN** it starts with no preset as the documented default and reports that source
- **AND** the startup resolution seam is exercised

### Requirement: Invalid selection fails closed

The system SHALL reject an invalid or unknown explicit override and an invalid, corrupt, stale, or unknown stored selection. It SHALL abort before agent setup, preserve a stored entry that caused the failure, and report the invalid value, canonical workspace key, and available exact preset names. It SHALL NOT silently fall back.

#### Scenario: Removed stored preset blocks startup

- **GIVEN** a stored workspace selection names a preset no longer in the effective configuration
- **WHEN** OpenCode launches without an override
- **THEN** startup aborts before agent setup and reports the stale name, canonical key, and available names
- **AND** the fail-closed startup seam is exercised

#### Scenario: Invalid one-run override blocks startup

- **GIVEN** `PRESET` names an unknown or non-exact preset
- **WHEN** OpenCode launches
- **THEN** startup aborts before agent setup without changing stored data
- **AND** the fail-closed startup seam is exercised

### Requirement: Explicit next-launch selection commands

The system SHALL provide `/preset NAME` and `make preset NAME=NAME`. Each SHALL accept exactly one exact preset name, validate it against the effective configuration, and persist it only for the canonical workspace. On success, it SHALL report the name, canonical workspace key, and next-launch effect. It SHALL NOT alter models in the current session.

When invoked without a name, each selector SHALL display the current stored selection or `none` and concise usage. Extra arguments or an invalid name SHALL fail without writing.

#### Scenario: Selector persists a valid preset without live switching

- **GIVEN** a valid preset name and an isolated user configuration directory
- **WHEN** `/preset NAME` or `make preset NAME=NAME` succeeds
- **THEN** a new process for the same workspace resolves that name, while the current session model routing is unchanged
- **AND** the selector command seam is exercised

#### Scenario: Invalid selector input does not write

- **GIVEN** an invalid name or more than one selector argument
- **WHEN** a selector command runs
- **THEN** it reports failure and leaves all workspace selections unchanged
- **AND** the selector command seam is exercised

### Requirement: Durable truthful writes

The system SHALL lock the selection store, read and validate its contents, atomically replace the updated store, then re-read and verify the target workspace entry before reporting success. It SHALL preserve all other workspace entries. Lock, parse, write, or verification failure SHALL report failure and SHALL NOT report a saved selection.

#### Scenario: Write failure is not reported as saved

- **GIVEN** the selection store cannot be locked, parsed, written, or verified
- **WHEN** a selector attempts to save a preset
- **THEN** it reports the failure, does not report success, and preserves the prior store state where possible
- **AND** the durable-write seam is exercised
