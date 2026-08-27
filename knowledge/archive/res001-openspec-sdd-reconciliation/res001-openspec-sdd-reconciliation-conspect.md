# Conspect: OpenSpec, SDD/TSS, and code_architect Conflict — Reconciliation Analysis

**Date**: 2026-07-13
**Research ID**: res001
**Status**: Complete

---

## Sources

### Source 1: OpenSpec — Getting Started
- **URL**: https://github.com/Fission-AI/OpenSpec/blob/HEAD/docs/getting-started.md
- **Type**: Web page (GitHub raw markdown)
- **File**: `sources/01-getting-started.md`
- **MLA Citation**: Fission AI. "Getting Started." *OpenSpec Documentation*, 2025, raw.githubusercontent.com/Fission-AI/OpenSpec/HEAD/docs/getting-started.md.
- **Key Points**:
  - OpenSpec is a spec-driven development framework for AI coding assistants
  - Core loop: explore → propose → apply → archive
  - Two execution contexts: terminal (`openspec init`) vs AI chat (`/opsx:propose`)
  - Project structure: `openspec/specs/` (source of truth) + `openspec/changes/` (proposals)
  - Delta specs use ADDED/MODIFIED/REMOVED sections to describe changes incrementally
  - Artifacts chain: proposal (why/what) → specs (what exactly) → design (how) → tasks (steps) → implement

### Source 2: OpenSpec — Core Concepts Overview
- **URL**: https://github.com/Fission-AI/OpenSpec/blob/HEAD/docs/overview.md
- **Type**: Web page (GitHub raw markdown)
- **File**: `sources/02-overview.md`
- **MLA Citation**: Fission AI. "Core Concepts at a Glance." *OpenSpec Documentation*, 2025, raw.githubusercontent.com/Fission-AI/OpenSpec/HEAD/docs/overview.md.
- **Key Points**:
  - Five core ideas: specs as truth, change as unit of work, delta specs, artifact chaining, archiving folds back
  - Philosophy: **"Enablers, not gates"** — artifacts make the *next step possible*, not mandatory
  - Specs describe *current* system behavior, not desired state
  - Archiving merges delta specs into main specs for audit trail
  - Designed for existing codebases: deltas mean you don't need to document everything upfront

### Source 3: OpenSpec — OPSX Workflow
- **URL**: https://github.com/Fission-AI/OpenSpec/blob/HEAD/docs/opsx.md
- **Type**: Web page (GitHub raw markdown)
- **File**: `sources/03-opsx.md`
- **MLA Citation**: Fission AI. "OPSX Workflow." *OpenSpec Documentation*, 2025, raw.githubusercontent.com/Fission-AI/OpenSpec/HEAD/docs/opsx.md.
- **Key Points**:
  - OPSX is the standard workflow: fluid, iterative, action-based (not phase-locked)
  - Commands: `/opsx:explore`, `/opsx:propose`, `/opsx:new`, `/opsx:continue`, `/opsx:ff`, `/opsx:apply`, `/opsx:update`, `/opsx:verify`, `/opsx:sync`, `/opsx:archive`
  - Artifact dependency graph is a DAG: proposal → specs/design (parallel after proposal) → tasks → implement
  - Schema-driven customization: define custom workflows via `schema.yaml` + templates
  - Legacy workflow was phase-locked; OPSX allows iteration in any direction
  - State tracked via filesystem existence (BLOCKED → READY → DONE)
  - Config integrates project context and per-artifact rules

### Source 4: Octane0411 — opencode-plugin-openspec
- **URL**: https://github.com/Octane0411/opencode-plugin-openspec
- **Type**: Web page (GitHub README)
- **File**: `sources/04-opencode-plugin-openspec.md`
- **MLA Citation**: Octane0411. "opencode-plugin-openspec." *GitHub*, 2025, github.com/Octane0411/opencode-plugin-openspec.
- **Key Points**:
  - OpenCode plugin that integrates OpenSpec as a dedicated agent mode
  - Adds `openspec-plan` agent: focused exclusively on planning and specification
  - Smart permissions: write access to `project.md`, `AGENTS.md`, `openspec/**`, `specs/**`
  - **Read-only safety**: rest of codebase is read-only during planning phase
  - Addresses the problem of AI agents prematurely jumping to implementation
  - 143 stars, 10 forks (small community plugin)
  - Auto-detects OpenSpec project structure

### Source 5: gkusmierz — cc-sdd (Spec-Driven Development)
- **URL**: https://github.com/gkusmierz/cc-sdd
- **Type**: Web page (GitHub README)
- **File**: `sources/05-cc-sdd.md`
- **MLA Citation**: Gotalab (maintained by gkusmierz). "cc-sdd: Long-Running Spec-Driven Implementation for AI Coding Agents." *GitHub*, 2025, github.com/gkusmierz/cc-sdd.
- **Key Points**:
  - Alternative spec-driven development tool, Kiro-inspired
  - 17 skills per install, works across 8 AI coding agents
  - Workflow: discovery → spec-init → spec-requirements → spec-design → spec-tasks → impl
  - Long-running autonomous implementation with per-task TDD, independent reviewer, auto-debug
  - Boundary-first discipline: `design.md` includes File Structure Plan; tasks annotated with `_Boundary:_` and `_Depends:_`
  - Treats spec as contract between system parts, not master command document
  - Supports OpenCode via `--opencode-skills` flag (beta)

### Source 6: devcxl — opencode-spec
- **URL**: https://github.com/devcxl/opencode-spec/blob/master/docs/en/usage.md
- **Type**: Web page (GitHub raw markdown)
- **File**: `sources/06-opencode-spec-usage.md`
- **MLA Citation**: Devcxl. "Usage Guide." *opencode-spec*, 2025, raw.githubusercontent.com/devcxl/opencode-spec/master/docs/en/usage.md.
- **Key Points**:
  - OpenCode plugin for OpenSpec workflow integration
  - Workflow: propose → apply → archive (with explore as optional)
  - Entry points: commands (`/opsx-propose`, `/opsx-explore`, `/opsx-apply`, `/opsx-archive`) and skills
  - Built-in Node.js reference scripts replace external openspec CLI
  - Directly manipulates `openspec/` directory structure
  - 4 stars (experimental/small project)

### Project Sources (internal)
- **architecture.md** (project root)
- **AGENTS.md** (project root)
- **AGENTS.md** (`.opencode/`)
- **Files**: Not downloaded (internal project documentation)

---

## 1. What is OpenSpec?

OpenSpec (Fission-AI, 60.6K stars on GitHub, 4.2K forks) is a **lightweight agreement layer between developers and AI coding assistants** (Source 2). Its core insight is the shortest path to quality is **"agree first, then build confidently"** — writing down intent, scope, and requirements before any code is generated.

### Five Foundational Concepts

OpenSpec is built on five interconnected ideas (Source 2):

1. **Specs are the truth** — `openspec/specs/` describes current system behavior, organized by domain. Specs contain requirements (SHALL/MUST statements) and scenarios (Given/When/Then examples).

2. **A change is one unit of work** — Each change gets its own folder under `openspec/changes/<change-name>/` containing all artifacts: proposal, design, task list, and delta specs.

3. **Delta specs describe the diff, not the destination** — Instead of rewriting entire specs, changes use ADDED/MODIFIED/REMOVED sections. This makes OpenSpec practical for existing codebases (Source 1).

4. **Artifacts build on each other** — The chain is: `proposal (why/what) → specs (what exactly) → design (how) → tasks (steps) → implement (do it)`. Each artifact makes the next *possible*, not mandatory.

5. **Archiving folds change back into truth** — On completion, delta specs merge into main specs, and the change folder moves to `changes/archive/` with a date stamp.

### Philosophy: "Enablers, Not Gates"

A defining philosophical stance (Source 2): OpenSpec artifacts show what becomes *possible* next, not what you're *forced* to do next. This is explicitly contrasted with waterfall-style spec processes. The dependency chain exists so the AI has context, not to enforce linear progression. The tradeoff is that discipline must come from the team, not the tool.

### OPSX Workflow

The OPSX workflow (Source 3) replaces the legacy phase-locked approach with fluid actions:

| Command | Function |
|---------|----------|
| `/opsx:explore` | Think through ideas, investigate, clarify |
| `/opsx:propose` | Create change + generate planning artifacts (default quick path) |
| `/opsx:new` | Start change scaffold (expanded) |
| `/opsx:continue` | Create one artifact at a time (expanded) |
| `/opsx:ff` | Fast-forward all planning artifacts (expanded) |
| `/opsx:apply` | Implement tasks, updating artifacts as needed |
| `/opsx:update` | Revise planning artifacts (no code, no new artifacts) |
| `/opsx:verify` | Validate implementation against artifacts (expanded) |
| `/opsx:sync` | Sync delta specs to main |
| `/opsx:archive` | Archive completed change |

The artifact dependency graph is a DAG:
```
proposal (root)
    ├── specs (requires: proposal)
    └── design (requires: proposal)
           └── tasks (requires: specs + design)
                  └── apply phase (requires: tasks)
```

### Custom Schema System

OPSX supports customizable workflows via `schema.yaml` files (Source 3). Users can define custom artifact types, dependency graphs, and templates — stored project-locally (version controlled) or globally. This means a team could define a "research-first" schema, an "API-first" schema, etc., each with different artifact chains.

### Related Projects

Two OpenCode plugins implement OpenSpec integration:

- **opencode-plugin-openspec** (Octane0411, 143 stars): Adds a dedicated `openspec-plan` agent with read-only safety on implementation code (Source 4). The agent has smart permissions — `project.md`, `AGENTS.md`, `openspec/**`, `specs/**` are writable; everything else is read-only.

- **opencode-spec** (devcxl, 4 stars): Provides `/opsx-*` commands and skills backed by Node.js reference scripts that directly manipulate the `openspec/` directory structure, replacing the need for the external openspec CLI (Source 6).

A third related project, **cc-sdd** (gkusmierz, forked from gotalab), is a Kiro-inspired spec-driven development tool that supports OpenCode as a beta target. It provides 17 skills including discovery, spec authoring, and long-running autonomous implementation with per-task TDD and independent review (Source 5). Its key philosophy: "spec as contract between parts of the system, not master command document."

---

## 2. What is the `openspec-plan` Agent?

The `openspec-plan` agent exists in two distinct forms in this project's ecosystem:

### Agent Form (OMO Slim Config)

Defined in the OMO Slim configuration as a **Socratic-mode agent** that guides users through spec authoring via interview:

- **Role**: Guides users through creating `proposal.md`, `design.md`, `tasks.md` under `.openspec/`
- **Constraint**: Blocked from writing implementation code (designated as a "practice-protected zone" in both AGENTS.md files)
- **Interaction pattern**: Asks guiding questions, user provides answers, agent drafts artifacts
- **Workflow position**: Step 2 in the feature workflow chain (after `@code_architect`, before `@code_executor`)

### Plugin Form (opencode-plugin-openspec)

The Octane0411 plugin (Source 4) provides a second form — a dedicated agent mode added to the agent selector:

- **Agent name**: "OpenSpec Architect" (colored #FF6B6B)
- **Via**: Installing `opencode-plugin-openspec` in `opencode.json` plugins array
- **Permissions**: Write access for `project.md`, `AGENTS.md`, `openspec/**`, `specs/**`; read-only for everything else
- **Auto-detection**: Detects whether the workspace is an OpenSpec project

### The Core Tension Both Forms Solve

Both forms address the same fundamental problem (Source 4): *"When using OpenCode's standard 'Build mode' to create or modify OpenSpec planning documents, AI agents often attempt to start implementing code changes immediately, before the planning phase is complete."* The dedicated planning agent enforces separation of concerns — planning and implementation are distinct cognitive modes that require different permissions and context.

---

## 3. What is the `code_architect` (oracle) Agent?

Per the project's architecture.md and AGENTS.md:

- **Internal name**: `oracle`
- **Display name**: `@code_architect`
- **Lane**: Architecture and technical strategy
- **Scope**: System-level design, Architecture Decision Records (ADRs), Mermaid diagrams, trade-off analysis
- **Outputs**: `architecture-<module>.md` documents
- **Abstraction level**: Higher than `openspec-plan` — focuses on cross-cutting architectural concerns, module boundaries, technology choices, and system-wide patterns
- **Workflow position**: Step 1 in the feature workflow chain — called *before* `openspec-plan`

The `code_architect` produces artifacts at a different granularity than `openspec-plan`. Where `openspec-plan` produces feature-level spec artifacts (proposal, design, tasks for a *specific change*), `code_architect` produces system-level architecture documents that govern how modules relate to each other. Its outputs are meant to be *referenced by* downstream spec artifacts.

---

## 4. What are `.sdd/` and `.tss/`?

The project's AGENTS.md defines a **Design Authority chain** that must be consulted before any code change:

1. **`architecture.md`** — Authoritative system architecture and data flow (project root)
2. **`.sdd/`** — Software Design Documents (architecture decisions, component contracts, data models)
3. **`.tss/`** — Technical Specifications (feature specs, API contracts, constraint matrices)
4. **`.openspec/`** — OpenSpec native artifacts (proposal.md, design.md, tasks.md)

### `.sdd/` — Software Design Documents

The `.sdd/` directory is intended for authoritative architecture decisions and component contracts. It lives at a level between `architecture.md` (which is monolithic and loaded as an instruction file) and `.openspec/` artifacts (which are change-scoped). Where `architecture.md` defines the entire system overview, `.sdd/` documents would contain detailed design decisions for specific subsystems, with rationale, trade-offs, and ADRs.

**Current status**: `.sdd/` does not exist in this project. No `.sdd/` documents have been created.

### `.tss/` — Technical Specifications

The `.tss/` directory is intended for detailed technical specifications — API contracts, data schemas, constraint matrices, protocol definitions. These sit at a more concrete level than `.sdd/` documents, defining the exact interface boundaries between components.

**Current status**: `.tss/` does not exist in this project. No `.tss/` documents have been created.

### Conceptual vs Physical Overlap

The `.sdd/` + `.tss/` concept is conceptually similar to OpenSpec's `openspec/specs/` directory but with important differences:

| Dimension | `.sdd/` / `.tss/` | `.openspec/` / `openspec/specs/` |
|-----------|-------------------|----------------------------------|
| **Origin** | Project convention (AGENTS.md) | Fission-AI OpenSpec tooling |
| **Granularity** | Module-level, permanent | Change-scoped, evolves with work |
| **Lifecycle** | Long-lived design records | Start as proposals, archive as truth |
| **Format** | Undefined (freeform markdown) | Explicit: proposal → specs → design → tasks |
| **Automation** | Manual authoring | Tool-generated via `/opsx:*` commands |
| **Enforcement** | Human review (AGENTS.md instruction) | Tool-based (DAG dependency tracking) |

---

## 5. The Conflict: Three (or Four) Parallel Approaches

This project has a **design document proliferation problem**. There are multiple overlapping mechanisms for capturing design intent, with unclear boundaries:

### The Parallel Structures

1. **`architecture.md`** (monolithic, root level)
   - Loaded as a system instruction file
   - Contains the full system architecture, repository structure, data flow, technology rationales
   - Maintained manually — single file, high-level

2. **`.sdd/` + `.tss/`** (directories, do not exist yet)
   - Referenced in AGENTS.md as design authority chain
   - Intended for long-lived architecture decisions and detailed technical specs
   - No clear guidance on when to create vs update vs archive

3. **`.openspec/`** (generated by `openspec-plan` agent)
   - Native OpenSpec artifacts
   - Change-scoped: `proposal.md`, `design.md`, `tasks.md`
   - Tool-supported: has DAG tracking, archive cycle, validation

4. **`architecture-<module>.md`** (output of `code_architect`)
   - Agent produces these as analysis documents
   - No clear lifecycle — when are they authoritative vs exploratory?

### The Specific Conflict Points

**1. No clear granularity boundary.**
`code_architect` produces `architecture-<module>.md` documents. The Design Authority chain says to check `architecture.md` → `.sdd/` → `.tss/` → `.openspec/`. But where does an `architecture-editor-engine.md` go? Is it an `.sdd/` document? Is it a `code_architect` output? Is it a reference for `.openspec/` artifacts? There is no rule distinguishing these.

**2. Delta vs full-document tension.**
OpenSpec uses delta specs (only what's ADDED/MODIFIED/REMOVED). `.sdd/` documents, by contrast, seem intended as full-document snapshots. If a module's architecture evolves, does `.sdd/` get a delta update, a new version, or an entirely new document?

**3. Agent role ambiguity.**
- `@code_architect` writes architecture documents
- `openspec-plan` writes design.md (which in OpenSpec's own terms includes architecture decisions and approach)
- These overlap in content: both can contain Mermaid diagrams, trade-off analyses, and design decisions
- The boundary is supposed to be "system-level vs change-level" but this is not formally enforced

**4. Missing directories create uncertainty.**
Since `.sdd/` and `.tss/` don't exist yet, all design documentation has been flowing into `architecture.md` and `.openspec/`. When `.sdd/` and `.tss/` are eventually created, existing content would need to be migrated — but there is no migration plan or schema.

**5. The `openspec/config.yaml` vs `.sdd/`/`.tss/` overlap.**
OpenSpec's `config.yaml` can include project context and rules. The `.sdd/` directory would similarly hold project-level design decisions. These serve overlapping purposes but have no cross-reference mechanism.

---

## 6. Reconciliation Recommendation

Based on the research, here is a recommended framework for how these should work together:

### Principle: Three Layers of Design Authority

```
┌─────────────────────────────────────────────────────────────┐
│  L1: SYSTEM ARCHITECTURE (stable, long-lived)              │
│  ─────────────────────────────────────────────────────────  │
│  Owner: @code_architect (oracle)                            │
│  Location: architecture.md + .sdd/                          │
│  Contents: Module boundaries, data flow, technology         │
│  choices, ADRs, cross-cutting concerns.                     │
│  Lifecycle: Updated via ADR process.                        │
│  Enforced by: AGENTS.md design authority check              │
├─────────────────────────────────────────────────────────────┤
│  L2: TECHNICAL SPECIFICATION (semi-stable)                 │
│  ─────────────────────────────────────────────────────────  │
│  Owner: @code_architect or human architect                  │
│  Location: .tss/                                            │
│  Contents: API contracts, protocol definitions, data        │
│  schemas, constraint matrices, interface specs.             │
│  Lifecycle: Updated per feature or breaking change.         │
│  Enforced by: CI checks / contract tests                    │
├─────────────────────────────────────────────────────────────┤
│  L3: FEATURE SPEC (change-scoped, ephemeral)               │
│  ─────────────────────────────────────────────────────────  │
│  Owner: @openspec-plan (openspec-plan agent)                │
│  Location: .openspec/ (changes/ + specs/)                   │
│  Contents: proposal.md, design.md, tasks.md, delta specs    │
│  Lifecycle: Created per change, archived when done,         │
│  delta specs fold into openspec/specs/                      │
│  Enforced by: OpenSpec's DAG engine + practice-protected    │
│  zones in AGENTS.md                                         │
└─────────────────────────────────────────────────────────────┘
```

### Specific Recommendations

**1. Establish `.sdd/` as L1 extension for module-level architecture.**

`architecture.md` should remain the monolithic system overview. When `@code_architect` produces an `architecture-<module>.md` document, it should be placed in `.sdd/<module>/architecture.md` — NOT at the project root. This gives `.sdd/` concrete content and makes the Design Authority check practical (check `.sdd/<relevant-module>/` rather than guessing).

**2. Use `.tss/` for API contracts and interface definitions only.**

`.tss/` should document contracts at component boundaries — protobuf message shapes, REST API endpoints, event schemas. This is *different* from OpenSpec's `specs/`, which describes behavior (requirements + scenarios). `.tss/` describes structure; `specs/` describes behavior. This semantic distinction avoids duplication.

**3. Formalize the workflow chain.**

```
@code_architect ──► .sdd/<module>/architecture.md
       │
       ▼
@openspec-plan ──► .openspec/ (proposal.md → specs/ → design.md → tasks.md)
       │
       ▼
@code_executor ──► Implementation
       │
       ▼
openspec/archive ──► Delta specs fold into openspec/specs/
```

Architecture is produced *first*, specs reference architecture, tasks implement specs. The `code_architect` documents govern *what modules exist and how they communicate*. The `openspec-plan` artifacts govern *what a specific change does within those modules*.

**4. Create `.sdd/` and `.tss/` with seed content from `architecture.md`.**

The existing `architecture.md` contains sections that naturally map:
- "System overview" → `.sdd/01-system-overview/architecture.md`
- "Why not one schema technology" → `.sdd/02-schema-decision/architecture.md` (this is essentially an ADR)
- "Inter-module communication: decision framework" → `.sdd/03-inter-module-communication/architecture.md`
- "Open questions / blind spots" → `.sdd/04-open-questions/architecture.md`

Migrating these sections into `.sdd/` would establish the directory with real content and give `@code_architect` a clear home for future architecture documents.

**5. Configure OpenSpec's `openspec/config.yaml` to reference `.sdd/` and `.tss/`.**

```yaml
# openspec/config.yaml
schema: spec-driven

context: |
  Tech stack: TypeScript, Python, Rust/WASM
  Architecture docs: .sdd/ (Software Design Documents)
  Technical specs: .tss/ (API contracts, data schemas)
  Monorepo: Turborepo with pnpm workspaces
  See architecture.md for system overview

rules:
  design:
    - Reference relevant .sdd/ documents in "Approach" section
    - Include Mermaid diagrams for module interactions
  specs:
    - Cross-reference .tss/ contracts where applicable
    - Use Given/When/Then format for scenarios
```

This creates explicit traceability from feature-level design.md to L1 architecture documents.

**6. Remove agent role overlap by scoping output locations.**

| Agent | Writes to | Writes about |
|-------|-----------|-------------|
| `@code_architect` | `.sdd/<module>/architecture.md` | System-level decisions, ADRs, module boundaries |
| `openspec-plan` | `.openspec/changes/<name>/` | Feature-level proposal, design, tasks |
| Both | — | They SHOULD NOT write about the same thing |

If `code_architect` produces a document that belongs to a change being planned by `openspec-plan`, it should be written as an ADR in `.sdd/` that the `design.md` references, not duplicated.

**7. Adopt OpenSpec's delta spec pattern for `.sdd/` updates.**

When a change requires updating an `.sdd/` architecture decision, use OpenSpec's delta approach: ADDED (new module), MODIFIED (changed interface), REMOVED (deprecated component). This keeps `.sdd/` documents maintainable rather than requiring full rewrites.

---

## Key Takeaways

1. **OpenSpec** is a mature (60.6K stars) spec-driven framework focused on the "agree first, then build" philosophy, with delta specs, artifact chaining, and fluid iteration via OPSX.

2. **The project has four overlapping design documentation mechanisms**: `architecture.md`, `.sdd/`, `.tss/`, and `.openspec/` — plus `@code_architect` producing `architecture-<module>.md` documents.

3. **`.sdd/` and `.tss/` do not exist yet**, creating a vacuum where all design intent flows into `architecture.md` (monolithic) and `.openspec/` (change-scoped), with no middle layer for module-level architecture.

4. **The `code_architect`↔`openspec-plan` overlap** is real but resolvable: one owns system-level architecture (`.sdd/`), the other owns change-level specs (`.openspec/`). They should not produce overlapping content.

5. **The recommended reconciliation** is a three-layer model: L1 (`.sdd/` — architecture decisions), L2 (`.tss/` — API contracts), L3 (`.openspec/` — feature specs), with explicit traceability from feature artifacts to governing architecture documents.
