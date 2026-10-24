# ana017 -- Specification Workflow Reference

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: finding
evidence-source: session-id + knowledge/ana004, knowledge/res001, knowledge/ana010, openspec/, .sdd/, architecture.md, AGENTS.md
confidence: High
shelf-registration: .opencode/memory-shelf.yaml (shelf.analyses)
-->

**Ticket:** DIA-102
**Author:** @analyzer
**Date:** 2026-08-13
**Methods applied:** MECE storage mapping, lifecycle state-machine synthesis, gap analysis
against three-layer model (res001), cross-reference audit (ana010 findings), agent
discovery path enumeration.
**Scope:** Synthesize existing analyses (ana004, res001, ana010) and current repository
state into a single spec-workflow REFERENCE document covering storage, lifecycle,
commit policy, obsolete handling, spec-impl linkage, and agent discovery.
**Constraint:** ASCII-only output (DIA-079). No edits to tickets, config, or
implementation code.

---

## 1. Executive Summary

The poetry-platform has a **working but incomplete** specification workflow. The
three-layer design authority model (L0 CONTEXT.md, L1 .sdd/, L3 openspec/) is
defined in AGENTS.md and res001, partially implemented in the repository, but
has significant gaps in discoverability, status tracking, and obsolete handling.

**Key metrics:**
- 15 active openspec changes on disk; only 5 registered in memory-shelf
- openspec/specs/ (main specs) is EMPTY -- delta specs never synced
- .sdd/ has 2 module documents; shelf.architectures is empty array
- 4 status mismatches between shelf and proposal.md files
- No formal spec-to-commit linkage exists
- No obsolete/deprecation lifecycle for .sdd/ documents

**Verdict:** The workflow is structurally sound but has operational gaps that
cause drift, lost context, and discoverability failures. This reference
document maps the current state, defines the intended reference, and enumerates
the gaps with prioritized remediation.

---

## 2. Storage Layout -- Current State Map

### 2.1 Complete Artifact Inventory

```
+-----+----------------------------+----------------------------+----------------+-----------+------------+
|  #  | Artifact                   | Path                       | Owner Lane     | Lifecycle | Retention  |
+-----+----------------------------+----------------------------+----------------+-----------+------------+
| A1  | Domain Glossary            | CONTEXT.md (root)          | domain-grilling| L0: lazy  | Permanent  |
| A2  | System Architecture        | architecture.md (root)     | @architector   | L1: rare  | Permanent  |
| A3  | Module Architecture (SDD)  | .sdd/<module>/architecture | @architector   | L1: rare  | Permanent* |
| A4  | SDD Index                  | .sdd/README.md             | @architector   | L1: rare  | Permanent  |
| A5  | Technical Specs (TSS)      | .tss/<module>/<spec>       | @architector   | L2: TBD   | NOT YET    |
| A6  | Change Proposal            | openspec/changes/<n>/propo | @openspec-plan | L3: per-  | Until arch |
| A7  | Change Design              | openspec/changes/<n>/desig | @openspec-plan | L3: per-  | Until arch |
| A8  | Change Tasks               | openspec/changes/<n>/tasks | @openspec-plan | L3: per-  | Until arch |
| A9  | Change Metadata            | openspec/changes/<n>/.open | @openspec-plan | L3: per-  | Until arch |
| A10 | Interview Transcript       | openspec/changes/<n>/inter | @openspec-plan | L3: per-  | Until arch |
| A11 | Delta Specs                | openspec/changes/<n>/specs | @openspec-plan | L3: per-  | Until arch |
| A12 | Change Fixtures            | openspec/changes/<n>/fixtu | @openspec-plan | L3: per-  | Until arch |
| A13 | Main Specs (synced)        | openspec/specs/            | @openspec-plan | L3: perm  | Permanent  |
| A14 | OpenSpec Config            | openspec/config.yaml       | project        | Static    | Permanent  |
| A15 | Templates                  | openspec/templates/        | project        | Static    | Permanent  |
| A16 | Archived Change            | openspec/changes/archive/Y | automated      | L3: dead  | Permanent  |
| A17 | Ticket Ledger              | docs/dev-infra-audit/ticke | orchestrator   | Ops       | Until arch |
| A18 | Archived Tickets           | docs/dev-infra-audit/ticke | automated      | Ops: dead | Permanent  |
| A19 | Memory Shelf               | .opencode/memory-shelf.yaml| memory-manager | Index     | Permanent  |
| A20 | Ticket Template            | docs/dev-infra-audit/ticke | project        | Static    | Permanent  |
+-----+----------------------------+----------------------------+----------------+-----------+------------+

  * A3 retention: "Permanent" with ADR deprecation lifecycle
    (proposed -> accepted -> deprecated -> superseded)
```

### 2.2 Directory Tree (Actual)

```
poetry-platform/
|-- architecture.md                           (A2: system architecture, ~1140 lines)
|-- CONTEXT.md                                (A1: domain glossary, 11 lines, 1 term)
|
|-- .sdd/                                     (L1: long-lived design records)
|   |-- README.md                             (A4: index, 55 lines)
|   |-- dia-redispatch-cycle/
|   |   +-- architecture.md                   (A3: 5 ADRs, 97 lines)
|   +-- dev-infra/
|       +-- architecture.md                   (A3: 8 ADRs, 150 lines)
|
|-- openspec/                                 (L3: change-scoped feature specs)
|   |-- config.yaml                           (A14: project config, 64 lines)
|   |-- specs/                                (A13: EMPTY -- no synced main specs)
|   |-- templates/
|   |   |-- HANDOFF.md                        (A15: cycle handoff template)
|   |   +-- T5-row.md                         (A15: extended task row template)
|   +-- changes/
|       |-- <name>/                           (15 active changes)
|       |   |-- .openspec.yaml                (A9: schema + created date)
|       |   |-- proposal.md                   (A6: why/what)
|       |   |-- design.md                     (A7: how, within boundaries)
|       |   |-- tasks.md                      (A8: vertical slices)
|       |   |-- [interview.md]                (A10: optional transcript)
|       |   |-- [specs/]                      (A11: optional delta specs)
|       |   +-- [fixtures/]                   (A12: optional test fixtures)
|       +-- archive/
|           |-- 2026-08-06-ai-self-improvem...  (A16: archived)
|           +-- 2026-08-11-dia-086-m1-m5-a...   (A16: archived)
|
+-- docs/dev-infra-audit/tickets/
    |-- _TEMPLATE.md                          (A20: ticket template)
    |-- DIA-NNN-<slug>.md                     (A17: active tickets)
    +-- archive/
        +-- DIA-NNN-<slug>.md                 (A18: 19 archived tickets)
```

### 2.3 .openspec.yaml Metadata (Current)

All 15 active changes share the same minimal metadata:

```yaml
schema: spec-driven
created: 2026-08-03     # varies per change
skip_specs: true        # present on all 15 changes
```

**MISSING fields:** status (proposed/implemented/obsolete), last_updated,
implemented_at, archived_at, source_ticket (DIA-NNN), implemented_by (session).

---

## 3. Lifecycle State Machine

### 3.1 Feature Spec Lifecycle (L3 -- openspec/)

```
                          FEATURE SPEC LIFECYCLE
                          ======================

    +---------+     +-----------+     +---------+     +---------+
    | INTER-  |     | PROPOSED  |     | IN      |     | IMPLEMENT|
    | VIEW    |---> |           |---> | PROGRESS|---> | ED       |
    | (opt)   |     | proposal. |     | coder   |     | all tasks|
    |         |     | design.   |     | working |     | done     |
    |         |     | tasks.    |     | tasks   |     |          |
    +---------+     | .openspec |     +---------+     +----+----+
                    | .yaml     |                          |
                    +-----------+                          |
                         |                                 |
                         |   openspec archive              |
                         v                                 v
                    +-----------+                    +-----------+
                    | ARCHIVED  | <----------------- | ARCHIVED  |
                    |           |                    |           |
                    | archive/  |                    | delta     |
                    | YYYY-MM-  |                    | specs --> |
                    | DD-<name> |                    | specs/    |
                    +-----------+                    +-----------+

    TRANSITIONS:
    ----------
    INTERVIEW -> PROPOSED:    @openspec-plan synthesizes artifacts from
                              interview transcript
    PROPOSED -> IN PROGRESS:  @coder begins first task from tasks.md
    IN PROGRESS -> IMPLEMENTED: all tasks.md items reach "done"
    IMPLEMENTED -> ARCHIVED:  `openspec archive` moves to archive/ with
                              date prefix; delta specs sync to specs/
```

### 3.2 Architecture Document Lifecycle (L1 -- .sdd/)

```
                    ARCHITECTURE DOCUMENT LIFECYCLE
                    ================================

    +-------------+     +-----------+     +-------------+
    | PROPOSED    |---> | ACCEPTED  |---> | DEPRECATED  |
    | (ADR draft) |     | (active)  |     | (superseded |
    |             |     |           |     |  or retired)|
    +-------------+     +-----+-----+     +-------------+
                              |                   ^
                              |  new ADR super-   |
                              |  sedes old        |
                              +-------------------+

    TRANSITIONS:
    ----------
    PROPOSED -> ACCEPTED:   @architector decision accepted by developer
    ACCEPTED -> DEPRECATED: A new ADR explicitly supersedes the old one;
                            old document gets "Superseded by: <ref>" header
    DEPRECATED is terminal: document remains on disk with deprecation
                            notice; never deleted
```

### 3.3 Ticket Lifecycle (ops -- tickets/)

```
    OPEN -> DISPATCHED -> RUNNING -> COMPLETE -> VERIFIED -> CLOSED
     |                                      |
     +-> BLOCKED (by DIA-NNN)               +-> MONITOR (watch for regressions)
     |
     +-> DEFERRED (scoped out)
```

---

## 4. Commit Policy

### 4.1 Current Policy (As Observed)

```
+-------------------------------+----------------------------+------------------+
| Artifact                      | Commit timing              | Evidence         |
+-------------------------------+----------------------------+------------------+
| openspec/changes/<n>/*.md     | Committed WITH implement-  | git log shows    |
| (proposal, design, tasks)     | ation commits in same PR   | spec + code in   |
|                               |                            | same commits     |
+-------------------------------+----------------------------+------------------+
| openspec/changes/archive/     | Committed as part of       | archive dates    |
| (archived changes)            | archive action             | match commits    |
+-------------------------------+----------------------------+------------------+
| .sdd/<module>/architecture.md | Committed separately       | Independent      |
|                               | (architecture decision)    | commit history   |
+-------------------------------+----------------------------+------------------+
| CONTEXT.md                    | Committed lazily when      | Part of feature  |
|                               | domain terms crystallize   | commits          |
+-------------------------------+----------------------------+------------------+
| openspec/specs/               | NEVER committed (empty)    | N/A              |
+-------------------------------+----------------------------+------------------+
```

### 4.2 Recommended Policy

```
RULE 1: Spec artifacts are committed in the SAME PR as the implementation.
        Rationale: spec and code must not drift. Review sees both together.

RULE 2: .sdd/ documents are committed in a SEPARATE PR from feature work.
        Rationale: architecture decisions are rare, reviewed independently,
        and should not be buried in feature PRs.

RULE 3: openspec/specs/ (main specs) are synced and committed during
        `openspec archive`. This is the delta-merge step.

RULE 4: Archived changes remain committed (never git-deleted).
        Rationale: audit trail, evidence for DIA tickets.

RULE 5: CONTEXT.md updates are committed in the feature PR that introduces
        the new domain term.
```

---

## 5. Obsolete / Archived Handling

### 5.1 openspec/ Changes

```
STATUS          LOCATION                        ACTION
---------       --------                        ------
active          openspec/changes/<name>/        Normal operations
archived        openspec/changes/archive/       `openspec archive` moves
                                                here with date prefix.
                                                Files unchanged.
empty/scaffold  openspec/changes/<name>/        Should be cleaned up or
              (no proposal/design/tasks)        completed. Found: dia-071.
```

**Archive naming convention:** `YYYY-MM-DD-<change-name>/`
**Evidence:** 2 archived changes follow this pattern.

### 5.2 .sdd/ Documents

```
STATUS          HEADER MARKER                   ACTION
---------       -------------                   ------
proposed        "Status: proposed"              Under review
accepted        "Status: accepted"              Active, governs features
deprecated      "Status: deprecated"            Superseded; "Superseded
              + "Superseded by: <ref>"          by" field points to new
```

**No deletion policy:** .sdd/ documents are never deleted. Deprecated
documents remain with a clear deprecation header.

### 5.3 Tickets

```
STATUS          LOCATION                        ACTION
---------       --------                        ------
OPEN..CLOSED    docs/dev-infra-audit/tickets/   Active
archived        docs/dev-infra-audit/tickets/   `scripts/tickets` or
              archive/                          manual move. 19 tickets
                                                currently archived.
```

### 5.4 Memory Shelf

```
STATUS          INDICATOR                       ACTION
---------       ---------                       ------
active          Entry in shelf.specs with       Normal
                status: proposed/implemented
archived        Entry in shelf.specs with       Path updated to
                status: archived                archive/ path
never           Not in shelf                    Gap: 10 changes not
registered                                      registered (ana010)
```

---

## 6. Spec-Implementation Linkage

### 6.1 Current Linkage Model

```
+--------------------+     +--------------------+     +-------------------+
| proposal.md        |     | design.md          |     | tasks.md          |
| (why/what)         |     | (how, within       |     | (vertical slices) |
|                    |     |  boundaries)       |     |                   |
| References:        |     | References:        |     | References:       |
| - .sdd/ docs       |     | - .sdd/ docs       |     | - Blocking edges  |
| - DIA tickets      |     | - Seams section    |     | - Acceptance      |
| - CONTEXT.md terms |     |   (test boundaries)|     |   criteria        |
+--------------------+     +--------------------+     +---------+---------+
                                                             |
                                                             v
                                                    +-------------------+
                                                    | @coder dispatch   |
                                                    |                   |
                                                    | Implements task   |
                                                    | TDD (tdd-crafts-  |
                                                    | man skill)        |
                                                    |                   |
                                                    | Tests at seams    |
                                                    | from design.md    |
                                                    +---------+---------+
                                                              |
                                                              v
                                                    +-------------------+
                                                    | @reviewer pass    |
                                                    |                   |
                                                    | Axis 1: Standards |
                                                    | Axis 2: Spec      |
                                                    | fidelity (checks  |
                                                    | design.md seams,  |
                                                    | tasks.md AC)      |
                                                    +-------------------+
```

### 6.2 Linkage Gaps

```
MISSING LINK                          IMPACT
-----------                           ------
No commit hash in tasks.md            Cannot trace which commit
                                      implemented which task
No ticket ref in .openspec.yaml       Cannot find the DIA ticket
                                      that spawned a change
No session_id in proposal.md          Cannot trace which session
                                      authored the spec
No reverse link: commit -> spec       A code commit has no pointer
                                      back to its governing spec
openspec/specs/ never synced          No durable main-spec body
                                      exists for agent discovery
```

### 6.3 Recommended Linkage Fields

```yaml
# .openspec.yaml -- extended metadata
schema: spec-driven
created: 2026-08-03
status: implemented            # NEW: proposed|in_progress|implemented|archived
source_ticket: DIA-100         # NEW: DIA-NNN that spawned this change
implemented_at: 2026-08-12     # NEW: date implementation completed
implemented_by: session-id     # NEW: session that did the implementation
archived_at: ""                # NEW: date of archive (empty if active)
skip_specs: true
```

```markdown
<!-- tasks.md task footer (per task) -->
## T1 -- Core script

...task description...

**Implemented:** commit abc1234 (2026-08-12)
**DIA ticket:** DIA-100
```

---

## 7. Agent Discovery -- How Agents Find Governing Specs

### 7.1 Discovery Paths (Current)

```
+------+-------------------------------------------+--------+------------------+
| Path | Mechanism                                 | Agent  | Reliability      |
+------+-------------------------------------------+--------+------------------+
| D1   | AGENTS.md section 3: design authority     | ALL    | Soft (prompt     |
|      | chain: architecture.md -> .sdd/ -> .tss/  |        | only, model      |
|      | -> openspec/                              |        | may skip)        |
+------+-------------------------------------------+--------+------------------+
| D2   | openspec/config.yaml rules.design:        | @open- | Soft (config     |
|      | "read .sdd/<module>/architecture.md"      | spec-  | rule, read       |
|      |                                           | plan   | at spec time)    |
+------+-------------------------------------------+--------+------------------+
| D3   | openspec validate <change>                | ALL    | Hard (CLI,       |
|      |                                           |        | exit code)       |
+------+-------------------------------------------+--------+------------------+
| D4   | memory-shelf shelf.specs entries          | @coder | Medium (shelf    |
|      | with path + status                        | @rev.  | must be up to    |
|      |                                           |        | date -- ana010   |
|      |                                           |        | found 10 missing)|
+------+-------------------------------------------+--------+------------------+
| D5   | .sdd/README.md index                      | @coder | Medium (manual   |
|      |                                           | @rev.  | index, 2 entries)|
+------+-------------------------------------------+--------+------------------+
| D6   | CONTEXT.md domain glossary                | ALL    | Soft (1 term     |
|      |                                           |        | only -- barely   |
|      |                                           |        | populated)       |
+------+-------------------------------------------+--------+------------------+
| D7   | design.md "Seams" section                 | @coder | Hard (within     |
|      | lists test boundaries                     | @rev.  | the change,      |
|      |                                           |        | always present)  |
+------+-------------------------------------------+--------+------------------+
```

### 7.2 Discovery Decision Tree (Recommended)

```
Agent needs governing spec for a task:
|
+-- Is this a FEATURE change?
|   |
|   +-- YES -> Check openspec/changes/ for active change
|   |          matching the DIA ticket.
|   |          |
|   |          +-- Found? Read proposal.md -> design.md -> tasks.md
|   |          |         Read .sdd/ references in design.md
|   |          |         Read design.md Seams section for test boundaries
|   |          |
|   |          +-- Not found? Check memory-shelf shelf.specs
|   |                    Check openspec/status if available
|   |
|   +-- NO -> Continue to architecture check
|
+-- Does this touch a MODULE BOUNDARY or TECHNOLOGY CHOICE?
|   |
|   +-- YES -> Read .sdd/<module>/architecture.md
|   |          Read .sdd/README.md for index
|   |          If module has no .sdd/ doc -> FLAG GAP,
|   |          escalate to @architector
|   |
|   +-- NO -> Continue to domain check
|
+-- Does this involve DOMAIN TERMINOLOGY?
    |
    +-- YES -> Read CONTEXT.md
    |
    +-- NO -> Proceed with architecture.md as needed
```

### 7.3 Discovery Gaps

```
GAP                                   SEVERITY    REMEDIATION
---                                   --------    -----------
10 openspec changes not in            HIGH        Register all active
memory-shelf shelf.specs                          changes in shelf

openspec/specs/ is empty              HIGH        Run sync-specs for
-- no main spec body exists                       implemented changes

CONTEXT.md has 1 term                 MEDIUM      Use domain-grilling
                                                skill to populate

No automated "find spec for           MEDIUM      Define openspec query
DIA-NNN" command                                  convention or script

.sdd/ docs not in shelf               MEDIUM      Register in shelf.
shelf.architectures is []                         architectures array

No status in .openspec.yaml           MEDIUM      Add status field;
-- only schema + created +                        use for discovery
skip_specs
```

---

## 8. Gap Analysis -- Current vs Ideal Reference

### 8.1 Gap Matrix

```
+----+---------------------------+----------+---------+--------+-----------------+
|  # | Gap                       | Severity | Effort  | Risk   | Recommendation  |
+----+---------------------------+----------+---------+--------+-----------------+
| G1 | 10 openspec changes not   | HIGH     | S (2h)  | Low    | Batch register  |
|    | registered in shelf.specs |          |         |        | in shelf        |
+----+---------------------------+----------+---------+--------+-----------------+
| G2 | openspec/specs/ empty --  | HIGH     | M (4h)  | Low    | Run sync-specs  |
|    | no delta specs ever       |          |         |        | for all         |
|    | synced                    |          |         |        | implemented     |
|    |                           |          |         |        | changes         |
+----+---------------------------+----------+---------+--------+-----------------+
| G3 | .openspec.yaml missing    | HIGH     | S (1h)  | Low    | Add status +    |
|    | status, source_ticket,    |          |         |        | source_ticket   |
|    | implemented_at fields     |          |         |        | to schema       |
+----+---------------------------+----------+---------+--------+-----------------+
| G4 | No commit->spec reverse   | MEDIUM   | M (4h)  | Medium | Add "Implement- |
|    | linkage (commit has no    |          |         |        | ed" footers     |
|    | pointer to spec)          |          |         |        | to tasks.md     |
+----+---------------------------+----------+---------+--------+-----------------+
| G5 | shelf.architectures is    | MEDIUM   | S (1h)  | Low    | Register 2 .sdd |
|    | empty; 2 .sdd docs not    |          |         |        | docs in shelf   |
|    | registered                |          |         |        |                 |
+----+---------------------------+----------+---------+--------+-----------------+
| G6 | CONTEXT.md has 1 term;    | MEDIUM   | M (4h)  | Low    | Populate via    |
|    | domain glossary barely    |          |         |        | domain-grilling |
|    | populated                 |          |         |        | skill           |
+----+---------------------------+----------+---------+--------+-----------------+
| G7 | 4 status mismatches       | MEDIUM   | S (1h)  | Low    | Reconcile shelf |
|    | (shelf vs proposal.md)    |          |         |        | status fields   |
+----+---------------------------+----------+---------+--------+-----------------+
| G8 | No automated "find spec   | MEDIUM   | M (6h)  | Medium | Define script   |
|    | for DIA-NNN" discovery    |          |         |        | or openspec     |
|    | command                   |          |         |        | query pattern   |
+----+---------------------------+----------+---------+--------+-----------------+
| G9 | .sdd/ has no deprecation  | LOW      | S (2h)  | Low    | Define ADR      |
|    | lifecycle enforcement     |          |         |        | deprecation     |
|    | (no "superseded by"       |          |         |        | header conven-  |
|    | enforcement)              |          |         |        | tion            |
+----+---------------------------+----------+---------+--------+-----------------+
|G10 | .tss/ does not exist;     | LOW      | N/A     | N/A    | Deferred until  |
|    | referenced in AGENTS.md   |          | (future)|        | first API       |
|    | but never created         |          |         |        | contract need   |
+----+---------------------------+----------+---------+--------+-----------------+
|G11 | 1 dangling shelf ref      | LOW      | S (30m) | Low    | Update shelf    |
|    | (ai-self-improvement      |          |         |        | path to archive |
|    | archived, shelf still     |          |         |        | path            |
|    | points to active path)    |          |         |        |                 |
+----+---------------------------+----------+---------+--------+-----------------+
|G12 | dia-071 empty scaffold    | LOW      | S (30m) | Low    | Delete empty    |
|    | (no proposal/design/      |          |         |        | scaffold or     |
|    | tasks)                    |          |         |        | complete it     |
+----+---------------------------+----------+---------+--------+-----------------+
```

### 8.2 Effort Summary

```
HIGH priority (G1-G3):   ~4h total, low risk, immediate shelf accuracy
MEDIUM priority (G4-G8): ~20h total, moderate risk, requires design
LOW priority (G9-G12):   ~3h total, low risk, cleanup
```

---

## 9. Agent-to-Artifact Permission Matrix

```
+------------------+------+------+------+------+------+------+------+------+
| Agent            | A1   | A2   | A3   | A6   | A7   | A8   | A13  | A16  |
|                  | CTXT | arch | .sdd | prop | des  | task | spec | arch |
+------------------+------+------+------+------+------+------+------+------+
| @openspec-plan   | read | read | read | WRITE| WRITE| WRITE| WRITE| --   |
| @coder           | read | read | read | read | read | read | read | read |
| @reviewer        | read | read | read | read | read | read | read | read |
| @architector     | read | WRITE| WRITE| read | read | read | read | --   |
| @analyzer        | read | read | read | read | read | read | read | read |
| @researcher      | read | read | read | read | read | read | read | read |
| @memory-manager  | --   | --   | --   | --   | --   | --   | --   | --   |
|                  |      |      |      |      |      |      | shelf only  |
+------------------+------+------+------+------+------+------+------+------+

  A1  = CONTEXT.md          A6  = proposal.md       A13 = openspec/specs/
  A2  = architecture.md     A7  = design.md         A16 = archive/
  A3  = .sdd/*/arch.md      A8  = tasks.md
```

---

## 10. Naming Conventions

### 10.1 Alignment with DIA-074

```
ARTIFACT                   CONVENTION                          EXAMPLE
--------                   ----------                          -------
openspec change dir        human-readable slug                 volta-to-mise
                           (DIA-074 aligned)                   dia-100-worktree-lifecycle
                           NOT bare DIA-NNN

archive dir                YYYY-MM-DD-<slug>                   2026-08-06-ai-self-
                                                                 improvement-...

.sdd module dir            <module-name>/ OR                   dia-redispatch-cycle/
                           NN-<topic>/ (system arch)           dev-infra/
                                                               01-system-overview/ (planned)

ticket file                DIA-NNN-<human-slug>.md             DIA-102-specification-
                                                               workflow.md

branch                     feature/DIA-NNN-<short-name>        feature/DIA-100-worktree

knowledge dir              <type><NNN>-<topic>                 ana017-spec-workflow-
                           (type: ana/res/tch)                 reference
```

### 10.2 Naming Rules Summary

```
RULE 1: openspec change names are human-readable slugs (DIA-074).
        Bare "DIA-NNN" names are deprecated.
RULE 2: Archive prefix is ISO date: YYYY-MM-DD-<slug>.
RULE 3: .sdd/ uses unnumbered names for dev-infra modules,
        numbered NN-<topic>/ for system-architecture modules.
RULE 4: Ticket filenames include human slug after DIA-NNN.
RULE 5: knowledge/ uses <type><NNN>-<topic> with both parts >=3 chars.
```

---

## 11. Synthesized Reference -- Complete Workflow

### 11.1 Feature Change Workflow (End-to-End)

```
STEP  ACTION                         WHO              ARTIFACTS CREATED
----  ------                         ---              -----------------
 1    Developer describes feature    Developer        --
 2    Socratic interview             @openspec-plan   interview.md (opt)
 3    Synthesize spec artifacts      @openspec-plan   proposal.md
                                                     design.md
                                                     tasks.md
                                                     .openspec.yaml
 4    openspec validate              @openspec-plan   (validation pass)
 5    Developer approves             Developer        --
 6    Check .sdd/ constraints        @coder           --
 7    Implement tasks (TDD)          @coder           code + tests
 8    Two-axis review                @reviewer        review findings
 9    Fix + re-review loop           @coder/@rev.     fixes
10    Update tasks.md status         @coder           tasks.md (done)
11    Sync delta specs               @openspec-plan   openspec/specs/
12    openspec archive               automated        archive/YYYY-MM-DD-
                                                       <name>/
13    Close DIA ticket               orchestrator     ticket -> CLOSED
14    Register in shelf              memory-manager   shelf.specs entry
```

### 11.2 Architecture Decision Workflow

```
STEP  ACTION                         WHO              ARTIFACTS CREATED
----  ------                         ---              -----------------
 1    Architecture need identified   Developer/       --
                                     @architector
 2    Create .sdd/<module>/          @architector     architecture.md
    architecture.md                                   with ADRs
 3    Update .sdd/README.md index    @architector     README.md update
 4    Register in shelf              memory-manager   shelf.architectures
 5    Reference from feature specs   @openspec-plan   design.md Approach
                                     (later)          section
```

---

## 12. Recommendations for DIA-102 Fix Section

The orchestrator should record the following in the DIA-102 ticket fix section:

### 12.1 Immediate (HIGH priority, ~4h)

```
R1: Register all 10 unregistered openspec changes in shelf.specs.
    Status: match each to its proposal.md or actual implementation state.

R2: Fix dangling shelf ref: update ai-self-improvement-auditor-and-cleanup
    path from openspec/changes/ai-self-improvement-auditor-and-cleanup/
    to openspec/changes/archive/2026-08-06-ai-self-improvement-auditor-
    and-cleanup/

R3: Reconcile 4 status mismatches between shelf and proposal.md.

R4: Register 2 .sdd/ documents in shelf.architectures array.
```

### 12.2 Short-Term (MEDIUM priority, ~20h)

```
R5: Add status + source_ticket + implemented_at fields to .openspec.yaml
    schema. Backfill existing 15 changes.

R6: Run sync-specs for all implemented changes to populate openspec/specs/.

R7: Define commit->spec linkage convention (task footers with commit hash).

R8: Define "find spec for DIA-NNN" discovery script or convention.
    Candidate: grep openspec/changes/ for source_ticket in .openspec.yaml.

R9: Populate CONTEXT.md via domain-grilling skill sessions.
```

### 12.3 Long-Term (LOW priority, ~3h)

```
R10: Define .sdd/ ADR deprecation header convention.
R11: Clean up dia-071 empty scaffold.
R12: Create .tss/ when first API contract need arises (deferred).
```

### 12.4 Section-10 Routing Note

```
R5 (.openspec.yaml schema extension) touches openspec/config.yaml
   indirectly -- this is an OpenSpec convention change, NOT an AI-tooling
   config change. It does NOT require section-10 routing.

R8 (discovery script) touches scripts/ -- if a new script is created,
    it follows the dev-infra workflow (section 2.4), not section 10.

None of R1-R12 require section-10 AI-devtools routing.
```

---

## 13. Sources

| Source | Path | Used For |
|--------|------|----------|
| ana004 | knowledge/ana004-spec-authoring-philosophy/ | Interview-first philosophy, bypass paths |
| res001 | knowledge/res001-openspec-sdd-reconciliation/ | Three-layer model, OpenSpec concepts |
| ana010 | knowledge/ana010-artifacts-folder-audit/ | 10 unregistered changes, 4 status mismatches, dangling refs |
| DIA-102 | docs/dev-infra-audit/tickets/DIA-102-*.md | Ticket requirements |
| openspec/config.yaml | openspec/config.yaml | Current project rules |
| .sdd/README.md | .sdd/README.md | SDD conventions and index |
| .sdd/dev-infra/architecture.md | .sdd/dev-infra/architecture.md | 8-ADR example (traceability table) |
| .sdd/dia-redispatch-cycle/ | .sdd/dia-redispatch-cycle/architecture.md | 5-ADR example (ADR format) |
| architecture.md | architecture.md (root) | System architecture authority |
| AGENTS.md | AGENTS.md (root) | Workflow chain sections 2.2/2.3 |
| CONTEXT.md | CONTEXT.md (root) | Domain glossary (L0) |
| _TEMPLATE.md | docs/dev-infra-audit/tickets/_TEMPLATE.md | Ticket naming conventions |
| openspec/templates/ | openspec/templates/HANDOFF.md, T5-row.md | Template conventions |
| 15 active changes | openspec/changes/*/ | .openspec.yaml metadata patterns |
| 2 archived changes | openspec/changes/archive/*/ | Archive naming convention |

---

## 14. Teaching Notes

**Core mental model:** The spec workflow is a three-layer cake.
- **L0 (CONTEXT.md)** = the vocabulary layer (what do we call things)
- **L1 (.sdd/)** = the architecture layer (what are the boundaries and why)
- **L3 (openspec/)** = the change layer (what specifically are we building now)

Each layer answers a different question. Confusion arises when agents try
to make architecture decisions in design.md (L3 stepping on L1) or when
feature specs try to define domain vocabulary (L3 stepping on L0).

**Subgoal labeling for the gaps:**
1. **Visibility** (G1-G3, G5, G7, G11) -- register what exists so agents
   can find it. Zero new content, just accurate indexes.
2. **Traceability** (G4, G8) -- connect specs to commits and tickets so
   future sessions can reconstruct why code exists.
3. **Completeness** (G6, G2) -- fill in the empty shelves (specs/, CONTEXT.md)
   so the three-layer model is actually populated.
4. **Lifecycle** (G9, G10, G12) -- define what happens when specs age out.

**Assumption challenged:** "The workflow is broken." It is not broken --
it WORKS for the changes that are tracked. The problem is the 60% of
changes (10/15 active) that are invisible to the discovery system. Fix
the indexes, not the workflow.
