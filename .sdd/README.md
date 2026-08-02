# Software Design Documents (.sdd/)

Long-lived, module-level architecture decisions and design records
for the Poetry Platform monorepo.

## Purpose

.sdd/ documents capture **system-level architecture decisions** that:

- Outlive any single feature change
- Govern ALL features, not just one
- Must be consistent across changes
- Are produced by `@architector` on rare, deliberate occasions

These are **not** feature specs — those live in `openspec/changes/`.

## Three-Layer Model

| Layer                   | Location                    | Owner                     | Lifecycle                        |
| ----------------------- | --------------------------- | ------------------------- | -------------------------------- |
| L1: System Architecture | `.sdd/` + `architecture.md` | @architector              | Long-lived (months/years)        |
| L2: Technical Specs     | `.tss/` (future)            | @architector              | Semi-stable                      |
| L3: Feature Specs       | `openspec/changes/`         | @openspec-plan            | Ephemeral (per change, archived) |

## Conventions

- Each module or decision gets a numbered subdirectory
- Use ADR format for key decisions
- Cross-reference other .sdd/ documents where relevant
- Update via ADR lifecycle: proposed → accepted → deprecated → superseded

## Index

No module-level `.sdd/` documents have been authored yet. The current system
architecture authority is the root `architecture.md` (system boundaries, schema
decision framework, and open questions live there). When `@architector` produces
a module architecture document, it is indexed here using the
`NN-<topic>/architecture.md` numbering convention:

| Document                             | Summary                                                                                                 |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------- |
| `01-system-overview/architecture.md` | System boundaries, guiding principles, data-flow overview (planned — not yet authored)                  |
| `02-schema-decision/architecture.md` | Why three schema technologies (FlatBuffers, Protobuf, native TS); decision framework for new boundaries (planned) |
| `03-open-questions/architecture.md`  | Tracked blind spots and their resolution status (planned)                                               |
