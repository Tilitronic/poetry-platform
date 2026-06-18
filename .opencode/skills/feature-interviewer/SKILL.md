---
name: feature-interviewer
description: Structured pre-build interview to gather full feature specifications before TDD begins. Asks one question at a time, documents edge cases, constraints, and acceptance criteria.
compatibility: opencode
metadata:
  audience: developers
  workflow: design
---

## What I Do

When a developer asks to build a **new feature** (not a refactor, bugfix, or trivial change), I conduct a structured interview to gather a comprehensive specification **before any code is written**. I ask questions one at a time, confirm understanding, and produce a finalized spec document that the TDD cycle then implements against.

## Workflow

```
DEVELOPER: "Build feature X"

       │
       ▼
┌─────────────────────────────┐
│  PHASE 1: Context Scan      │
│  - Read architecture.md     │
│  - Identify affected modules│
│  - Check existing patterns  │
└─────────────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│  PHASE 2: Structured        │
│  Interview (one Q at a time)│
└─────────────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│  PHASE 3: Spec Summary      │
│  + Developer Confirmation   │
└─────────────────────────────┘
       │
       ▼
   → Proceed to TDD (RED phase)
```

## Phase 1 — Context Scan

Before asking questions, silently read these files to ground the interview:

1. `architecture.md` — understand the system's data flow, component boundaries, and constraints
2. Any existing tests in the affected packages — understand current behavior under test
3. The existing interfaces/types in the affected packages — understand the contract surface

## Phase 2 — Structured Interview

Ask questions **one at a time**. Wait for the developer's answer before asking the next. Adapt the question set to the feature's nature.

### Core questions (always ask these):

**Q1 — Scope**
> "What exactly should this feature do? What is explicitly in scope, and what is out of scope for this iteration?"

**Q2 — Boundary conditions**
> "What are the edge cases? Consider: empty input, maximum values, concurrent access, missing data, unexpected types."

**Q3 — Performance constraints**
> "Are there any latency targets, memory limits, allocation budgets, or hot-path requirements? Which code path handles the 99% case?"

**Q4 — Integration points**
> "Which existing modules/packages does this touch? What's the data flow — who calls whom, and what's the message format?"

**Q5 — Error states**
> "What failure modes exist? For each, how should the system respond — silently handle, warn, throw, or recover?"

**Q6 — Observability**
> "Do we need logging, metrics, tracing, or telemetry for this feature? Any debug hooks?"

**Q7 — Acceptance criteria**
> "How will we know this is done and correct? What test scenarios must pass? What benchmarks must be met?"

### Conditional questions (ask if relevant):

**Q8 — Data persistence** (if the feature touches state)
> "Does this change the data contract schema? Does `contract_hash` / OCC need updating?"

**Q9 — Worker boundary** (if cross-worker)
> "Does this need a new MessageChannel message type? Will it run on W1, W2, or main thread?"

**Q10 — Visual output** (if UI-visible)
> "Does this affect the D3 visualizer, SSR template, or Vue components?"

## Phase 3 — Spec Summary

After all questions are answered, produce a structured spec in this format:

```markdown
## Feature Specification: [name]

### Scope
- In scope: ...
- Out of scope: ...

### Interface / Behavior
- [function/module] does [behavior]
- Input: [type, shape]
- Output: [type, shape]
- Side effects: [none / specific mutations]

### Edge Cases
1. Empty input → [behavior]
2. Max values → [behavior]
3. [Other] → [behavior]

### Performance Targets
- 99% path: [target ms or allocation budget]
- Hot path optimization: [allocation elimination / lazy / pre-compile]

### Integration
- Affected packages: [...]
- Data flow: [caller → callee → response]
- New/changed message types: [...]

### Error Handling
| Failure mode | Response |
|---|---|
| ... | ... |

### Acceptance Criteria (Tests)
- [ ] Happy path test: ...
- [ ] Edge case: ...
- [ ] Error case: ...

### Architecture Compliance
- SOLID principles: [which ones apply]
- OCC version check: [yes/no]
- Worker boundary: [main / W1 / W2]
```

Then ask: *"Does this specification look correct? Please confirm so I can proceed with the TDD cycle."*

Only after explicit confirmation, hand off to the TDD cycle (invoke `tdd-craftsman` skill).
