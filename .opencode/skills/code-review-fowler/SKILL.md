---
name: code-review-fowler
description: Use when reviewing code against the Fowler code-smell baseline — the twelve labelled heuristics the @reviewer applies on the Standards axis of the two-axis review.
compatibility: opencode
metadata:
  audience: reviewers
  workflow: code-review
  forkedFrom: mattpocock/skills
---

<!-- Forked from mattpocock/skills (MIT License, https://github.com/mattpocock/skills). Original Copyright (c) Matt Pocock. -->

# Code Review — Fowler Smell Baseline

The twelve Fowler code smells from Martin Fowler's *Refactoring*, each with a one-line description and its canonical refactoring direction. Applied as **labelled heuristics, never hard violations** — a documented repo standard overrides the baseline, and anything tooling (lint/typecheck) already enforces is skipped.

| Smell | What it looks like | Fix direction |
| ----- | ------------------ | ------------- |
| Mysterious Name | name doesn't reveal intent | rename |
| Duplicated Code | same logic in multiple places | extract shared shape |
| Feature Envy | method reaches into another object's data | move to the data |
| Data Clumps | same fields travel together | bundle into one type |
| Primitive Obsession | primitive standing in for domain concept | give it a type |
| Repeated Switches | same cascade on same type recurs | polymorphism or shared map |
| Shotgun Surgery | one change forces scattered edits | gather into one module |
| Divergent Change | one module edited for unrelated reasons | split by reason |
| Speculative Generality | abstraction for needs the spec doesn't have | delete |
| Message Chains | long a.b().c().d() navigation | hide behind one method |
| Middle Man | mostly delegates onward | cut it, call the target |
| Refused Bequest | subclass ignores most of what it inherits | drop inheritance |

## Usage

When a finding maps to one of these smells, label it with the smell name and cite the fix direction. Distinguish hard violations (documented-standard breaches) from judgement calls (baseline smells). The @reviewer's `orchestratorPrompt` references this skill for the full baseline; the names-only list stays in the prompt to respect its character budget.
