## Why

<!-- Explain the motivation for this change. What problem does this solve? Why now? -->

## What Changes

<!-- Describe what will change. Be specific about new capabilities, modifications, or removals. -->

## Capabilities

### New Capabilities

<!-- Capabilities being introduced. Replace <name> with kebab-case identifier (e.g., user-auth, data-export, api-rate-limiting). Each creates specs/<name>/spec.md -->

- `<name>`: <brief description of what this capability covers>

### Modified Capabilities

<!-- Existing capabilities whose REQUIREMENTS are changing (not just implementation).
     Only list here if spec-level behavior changes. Each needs a delta spec file.
     Use existing spec names from openspec/specs/. Leave empty if no requirement
     changes. A change with no capabilities at all (pure refactor, tooling, docs)
     must set `skip_specs: true` in its .openspec.yaml - openspec validate rejects
     a zero-delta change without that marker. Do not invent a requirement just to
     satisfy validation. -->

- `<existing-name>`: <what requirement is changing>

## Impact

<!-- Affected code, APIs, dependencies, systems -->

## Alternatives considered

<!-- EBDV (DIA-115): enumerate the genuinely distinct options weighed for this
     change, each carrying evidence (Tier-1 committed/conspec pointer or
     Tier-2 dated URL; Tier-3 must be labeled [INFERENCE] and never the sole
     basis). Always include an abort/status-quo / do-nothing variant, and close
     with a 'Chosen option' line whose one-line 'because' justification
     references the evidence. Alternatives are decisions, not non-goals
     (Prisma create-pr rule). Mechanical validator:
     scripts/validate-decision-variants.sh (wired into make test-config). -->

- <alternative 1>: <what it is> - <why rejected / why not chosen, with evidence tier (Tier-1 pointer or Tier-2 dated URL)>
- <alternative 2>: ...
- Status-quo / do nothing: <why rejected or why acceptable>
  Chosen option: <name> - <one-line 'because' justification referencing the evidence>
