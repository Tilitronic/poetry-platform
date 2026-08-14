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

| Layer                   | Location                    | Owner           | Lifecycle                            |
| ----------------------- | --------------------------- | --------------- | ------------------------------------ |
| L0: Domain Vocabulary   | `CONTEXT.md` (root)         | domain-grilling | Lazily filled glossary (per session) |
| L1: System Architecture | `.sdd/` + `architecture.md` | @architector    | Long-lived (months/years)            |
| L2: Technical Specs     | `.tss/` (future)            | @architector    | Semi-stable                          |
| L3: Feature Specs       | `openspec/changes/`         | @openspec-plan  | Ephemeral (per change, archived)     |

## Conventions

- Each module or decision gets a numbered subdirectory
- Use ADR format for key decisions
- Cross-reference other .sdd/ documents where relevant
- Update via ADR lifecycle: proposed → accepted → deprecated → superseded

## Index

One module-level `.sdd/` document has been authored so far:
`dia-redispatch-cycle/architecture.md` (a 5-ADR seed for the cycle-management
protocol, produced as part of a dev-infra campaign — see row below). The system
architecture authority remains the root `architecture.md` (system boundaries,
schema decision framework, and open questions live there). When `@architector`
produces further module architecture documents, they are indexed here using the
`NN-<topic>/architecture.md` numbering convention:

> **Process note (dev-infra / non-system-architecture modules):** unnumbered
> directory names are permitted for dev-infra and other non-system-architecture
> modules — `dia-redispatch-cycle/` deliberately matches the
> `openspec/changes/` naming instead of the `NN-<topic>/` convention, and that is
> acceptable. Numbered names remain the default for system-architecture modules.

| Document                               | Summary                                                                                                                        |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `01-system-overview/architecture.md`   | System boundaries, guiding principles, data-flow overview (planned — not yet authored)                                         |
| `02-schema-decision/architecture.md`   | Why three schema technologies (FlatBuffers, Protobuf, native TS); decision framework for new boundaries (planned)              |
| `03-open-questions/architecture.md`    | Tracked blind spots and their resolution status (planned)                                                                      |
| `dia-redispatch-cycle/architecture.md` | 5-ADR seed for the cycle-management protocol (dev-infra campaign)                                                              |
| `dev-infra/architecture.md`            | Parallel dev model (worktrees), branch conventions, and safe/destructive operations (DIA-100)                                  |
| `opencode-config/architecture.md`      | Two ADRs for opencode-config batch patterns: parallel coders (Batch D, worktree-gated) and singleton-batch exemption (DIA-172) |
