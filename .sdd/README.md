# Software Design Documents (.sdd/)

Long-lived, module-level architecture decisions and design records
for the Poetry Platform monorepo.

## Purpose

.sdd/ documents capture **system-level architecture decisions** that:
- Outlive any single feature change
- Govern ALL features, not just one
- Must be consistent across changes
- Are produced by `@code_architect` on rare, deliberate occasions

These are **not** feature specs — those live in `.openspec/changes/`.

## Three-Layer Model

| Layer | Location | Owner | Lifecycle |
|---|---|---|---|
| L1: System Architecture | `.sdd/` + `architecture.md` | @code_architect | Long-lived (months/years) |
| L2: Technical Specs | `.tss/` (future) | @code_architect | Semi-stable |
| L3: Feature Specs | `.openspec/changes/` | @openspec-plan | Ephemeral (per change, archived) |

## Conventions

- Each module or decision gets a numbered subdirectory
- Use ADR format for key decisions
- Cross-reference other .sdd/ documents where relevant
- Update via ADR lifecycle: proposed → accepted → deprecated → superseded

## Index

| Document | Summary |
|---|---|
| `01-system-overview/architecture.md` | System boundaries, guiding principles, data-flow overview |
| `02-schema-decision/architecture.md` | Why three schema technologies (FlatBuffers, Protobuf, native TS); decision framework for new boundaries |
| `03-open-questions/architecture.md` | Tracked blind spots and their resolution status |
