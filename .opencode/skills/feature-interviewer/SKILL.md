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

## Activation Triggers — and When to Skip

**Activate** when the request describes new behavior whose shape isn't
already obvious from an existing pattern: a new public API, a new
package/crate/module, a new cross-package data flow, or anything the
developer frames with "build", "design", "add a feature for".

**Skip the full interview** (go straight to `tdd-craftsman`, RED phase)
when the request is:

- A bugfix or regression (no new specification needed — the bug itself
  _is_ the spec).
- A small addition that mirrors an existing pattern 1:1 in the same
  package (e.g., "add a `median()` function next to the existing
  `mean()`/`stddev()` in this module" — the conventions, error handling,
  and test shape are already established by the sibling code).
- Explicitly marked trivial by the developer ("quick one", "small thing").

**Compressed interview (3 questions, not the full set):** when the
feature is real but clearly scoped — single function, single package, no
cross-language boundary, no new persisted state. Ask only Q1 (Scope),
Q2 (Edge cases), Q7 (Acceptance criteria) and skip straight to Phase 3.

When in doubt about which mode applies, ask the developer directly:
_"Is this a small, contained addition, or does it touch multiple
packages / introduce new state? I'll adjust how many questions I ask
accordingly."_

## Workflow

```
DEVELOPER: "Build feature X"

       │
       ▼
┌─────────────────────────────┐
│  PHASE 0: Triviality Check  │
│  - Full / Compressed / Skip │
└─────────────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│  PHASE 1: Context Scan      │
│  - Read architecture docs   │
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

Before asking questions, silently scan for context to ground the interview:

1. **Architecture docs** — look for `architecture.md`, `ARCHITECTURE.md`,
   or a package-local `README.md`/`docs/` describing data flow and
   constraints. Check both the repo root and the specific package
   (`packages/<name>/`, `crates/<name>/`) the feature will live in.
2. **Existing tests** in the affected package(s) — understand current
   behavior under test, and the test idiom already in use (Vitest /
   pytest / `cargo test` / GoogleTest — see `tdd-craftsman`'s per-language
   tooling table).
3. **Existing interfaces/types** in the affected package(s) — the public
   API surface, type definitions, or header files that define the
   contract this feature must fit.
4. **The package's toolchain file** (`package.json`, `pyproject.toml`,
   `Cargo.toml`, `CMakeLists.txt`) — identifies which language/ecosystem
   this feature lives in, which determines which conditional questions
   in Phase 2 apply.

**If no architecture doc exists for this package:** don't block on it.
Note its absence in the eventual spec ("no architecture doc found for
this package — constraints below are inferred from existing code") and
proceed. Optionally ask the developer once: _"I didn't find an
architecture doc for this package — is there a design doc elsewhere, or
should I work from the existing code patterns?"_

## Phase 2 — Structured Interview

Ask questions **one at a time**. Wait for the developer's answer before asking the next.

**Mode (set by Phase 0):**

- **Full** — ask all Core questions (Q1–Q7), then whichever Conditional
  group matches the package's language/domain.
- **Compressed** — ask only Q1, Q2, Q7.

If the developer doesn't know an answer (e.g. "I'm not sure about
performance targets"), don't stall — propose a reasonable default based
on the Context Scan and ask them to confirm or correct it, then move on.

### Core questions (always ask, in Full mode):

**Q1 — Scope**

> "What exactly should this feature do? What is explicitly in scope, and what is out of scope for this iteration?"

**Q2 — Boundary conditions**

> "What are the edge cases? Consider: empty input, maximum/extreme values, concurrent access, missing data, unexpected types."

**Q3 — Performance constraints**

> "Are there any latency targets, memory/allocation budgets, or hot-path requirements? Which code path handles the typical case, and does correctness depend on a specific numerical/memory layout?"
>
> _(The answer here determines whether `tdd-craftsman`'s section 3a —
> property-based tests, benchmark gates, memory-safety checks — applies
> to this feature. Carry the answer into the spec's Performance Targets
> section verbatim; don't paraphrase away specifics like "must stay
> F-contiguous" or "called across the Python/Rust FFI boundary".)_

**Q4 — Integration points**

> "Which existing modules/packages does this touch? What's the data flow — who calls whom, and across what boundary (in-process, FFI, IPC, network)?"

**Q5 — Error states**

> "What failure modes exist? For each, how should the system respond — silently handle, warn, raise/throw, panic, or recover?"

**Q6 — Observability**

> "Do we need logging, metrics, tracing, or telemetry for this feature? Any debug hooks?"

**Q7 — Acceptance criteria**

> "How will we know this is done and correct? What test scenarios must pass? What benchmarks, if any, must be met?"

### Conditional questions — pick the group matching the package's stack

Identified from the toolchain file found in Phase 1. Ask only the group(s)
that apply; most features trigger zero or one group.

**If the package touches persisted state (any language):**

**Q8 — Data persistence**

> "Does this change a data schema, file format, or serialization contract? Does it need a migration path for existing data?"

**If the package crosses a language/process boundary (FFI, IPC, subprocess):**

**Q9 — Boundary contract**

> "What's the exact contract at this boundary — call convention, data layout, ownership transfer (who frees/drops what), and error propagation across the boundary?"

**If the package has a UI-visible surface (web frontend only):**

**Q10 — Visual output**

> "Does this affect rendering, layout, or an existing UI component? Any accessibility or responsive-layout constraints?"

**If the package implements a numerical/scientific algorithm:**

**Q11 — Numerical correctness**

> "Are there mathematical invariants this must preserve (idempotence, conservation, monotonicity)? What's the acceptable numerical tolerance, and is there a reference implementation or paper to validate against?"

## Phase 3 — Spec Summary

After all questions are answered, produce a structured spec in this format:

```markdown
## Feature Specification: [name]

Date: [ISO date] | Package(s): [package/crate/module path] | Language: [TS/Python/Rust/C++]

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
2. Max/extreme values → [behavior]
3. [Other] → [behavior]

### Performance & Numerical Targets

- Typical-case path: [target latency or allocation budget, or "none specified"]
- Hot path optimization needed: [yes/no — which tactic from tdd-craftsman §3]
- Numerical invariants to preserve: [none / list — feeds tdd-craftsman §3a]
- Memory layout constraints: [none / row-major, F-contiguous, SIMD alignment, etc.]
- Cross-language boundary involved: [no / yes — specify which languages and direction]

### Integration

- Affected packages: [...]
- Data flow: [caller → callee → response]
- Boundary type: [in-process / FFI / IPC / network / none]

### Error Handling

| Failure mode | Response |
| ------------ | -------- |
| ...          | ...      |

### Acceptance Criteria (Tests)

- [ ] Happy path test: ...
- [ ] Edge case: ...
- [ ] Error case: ...
- [ ] Property-based test needed: [yes/no — if yes, what invariant]
- [ ] Benchmark gate needed: [yes/no — if yes, target]

### Architecture Compliance

- Existing patterns followed: [reference the sibling code/module this matches]
- New persisted state or schema change: [yes/no]
- Architecture doc found: [yes — path / no — inferred from existing code]
```

Then ask: _"Does this specification look correct? Please confirm so I can proceed with the TDD cycle."_

### Handoff to `tdd-craftsman`

Only after explicit confirmation, hand off the full spec (not just a
summary) to the `tdd-craftsman` skill. The handoff specifically carries:

- **Language/package** → selects the per-language tooling row in
  `tdd-craftsman`'s tables (Vitest/pytest/cargo test/GoogleTest).
- **"Numerical invariants to preserve" / "Memory layout constraints" /
  "Cross-language boundary involved"** → if any of these are non-empty,
  `tdd-craftsman` §3a (property-based tests, benchmark regression gates,
  memory-safety/ASan gate) is in scope for this cycle, not optional.
- **Edge Cases and Error Handling table** → become the RED-phase test
  list directly; `tdd-craftsman` should not need to re-derive them.
- **"Existing patterns followed"** → grounds the Ownership Protocol's
  rationale-comment requirement (the GREEN commit can cite _why this
  matches/diverges from_ the referenced pattern).

If the spec is silent on performance/numerical fields (developer had no
constraints to give), `tdd-craftsman` defaults to plain unit tests only —
§3a does not activate speculatively.
