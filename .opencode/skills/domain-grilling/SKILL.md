---
name: domain-grilling
description: Use when the user wants to design a feature, pin down domain terminology, or stress-test a plan — a relentless one-question-at-a-time Socratic interview that sharpens the domain model and captures ADRs as decisions crystallise.
compatibility: opencode
metadata:
  audience: developers
  workflow: design-and-domain-modeling
  forkedFrom: mattpocock/skills
---

<!-- Forked from mattpocock/skills (MIT License, https://github.com/mattpocock/skills). Original Copyright (c) Matt Pocock. -->
<!-- Adapted for poetry-platform: merged the upstream grill-with-docs, grilling, and domain-modeling skills into one three-phase skill. ADR output is redirected from docs/adr/ to .sdd/<module>/architecture.md per project conventions; practice-protected and OpenSpec integration rules added. -->

# Domain Grilling

Interview the user relentlessly about a plan, decision, or idea until we reach a shared understanding, while actively building and sharpening the project's domain model. Three phases, in order: **Grilling** (the interview), **Domain Modeling** (sharpening language and maintaining CONTEXT.md), and **ADR Capture** (recording decisions worth recording).

## Phase 1 — Grilling (the interview)

<!-- FIRST-QUESTION -->
- Example question: Which existing behavior changes, and for whom?
- What is the primary hypothesis this feature/design validates, and how will you know if it is falsified?
- Walk down each branch of the decision tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.
- Ask the questions **one at a time**, waiting for feedback on each question before continuing. Asking multiple questions at once is bewildering.
- If a *fact* can be found by exploring the environment (filesystem, tools, etc.), look it up rather than asking. The *decisions*, though, are the user's — put each one to them and wait for their answer.
- Do not act on anything until the user confirms we have reached a shared understanding.

## Phase 2 — Domain Modeling

Actively build and sharpen the project's domain model as you design — challenging terms, inventing edge-case scenarios, and writing the glossary down the moment terms crystallise. (Merely *reading* `CONTEXT.md` for vocabulary is not this phase — this is for when you're changing the model, not just consuming it.)

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in `CONTEXT.md`, call it out immediately. "Your glossary defines 'cancellation' as X, but you seem to mean Y — which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term. "You're saying 'account' — do you mean the Customer or the User? Those are different things."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios. Invent scenarios that probe edge cases and force the user to be precise about the boundaries between concepts.

### Cross-reference with code

When the user states how something works, check whether the code agrees. If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible — which is right?"

### Update CONTEXT.md inline

When a term is resolved, update `CONTEXT.md` right there. Don't batch these up — capture them as they happen. `CONTEXT.md` should be totally devoid of implementation details. Do not treat it as a spec, a scratch pad, or a repository for implementation decisions. It is a glossary and nothing else.

### CONTEXT.md format

```md
# Domain Glossary

{One or two sentence description of what this context is and why it exists.}

| Term | Definition | Avoid using |
| ---- | ---------- | ----------- |
| {Term} | {one or two sentence definition} | {synonyms to avoid} |
```

Rules:

- **Be opinionated.** When multiple words exist for the same concept, pick the best one and list the others under "Avoid using".
- **Keep definitions tight.** One or two sentences max. Define what it IS, not what it does.
- **Only include terms specific to this project's context.** General programming concepts (timeouts, error types, utility patterns) don't belong even if the project uses them extensively. Before adding a term, ask: is this a concept unique to this context, or a general programming concept? Only the former belongs.
- **Group terms under subheadings** when natural clusters emerge. If all terms belong to a single cohesive area, a flat list is fine.

## Phase 3 — ADR Capture

Only offer to create an ADR when **all three** are true:

1. **Hard to reverse** — the cost of changing your mind later is meaningful
2. **Surprising without context** — a future reader will wonder "why did they do it this way?"
3. **The result of a real trade-off** — there were genuine alternatives and you picked one for specific reasons

If any of the three is missing, skip the ADR.

**Where ADRs live (project convention):** append ADR sections to `.sdd/<module>/architecture.md` — NOT `docs/adr/`. If the module has no `.sdd/` document yet, flag the gap and propose one to @architector rather than creating a parallel doc. Use our ADR format:

```md
## ADR: <Title>
- **Status:** Proposed | Accepted | Deprecated | Superseded
- **Context:** What problem are we solving? What constraints exist?
- **Decision:** What did we choose and why?
- **Consequences:** What becomes easier? Harder? What are the risks?
- **Alternatives Considered:** What else was evaluated? Why rejected?
```

## Practice-Protected Guard (MANDATORY)

This skill touches a practice-protected zone (see `.opencode/practice-protected.md` §1). You may challenge vocabulary and propose ADRs, but you MUST NOT write `proposal.md`/`design.md` substance without the user's explicit draft. You interview and structure; the user writes.

## OpenSpec Integration

If this session is part of an OpenSpec change, the interview transcript feeds @openspec-plan's artifact synthesis. Do not synthesize artifacts yourself.
