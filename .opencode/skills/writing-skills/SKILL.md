---
name: writing-skills
description: Use when creating new skills, editing existing skills, or verifying skills work before deployment
---

# Writing Skills

## Overview

**Writing skills IS Test-Driven Development applied to process documentation.**

You write test cases (pressure scenarios with subagents), watch them fail (baseline behavior), write the skill (documentation), watch tests pass (agents comply), and refactor (close loopholes).

**Core principle:** If you didn't watch an agent fail without the skill, you don't know if the skill teaches the right thing.

## When to Create a Skill

**Create when:**
- Technique wasn't intuitively obvious
- You'd reference this again across projects
- Pattern applies broadly

**Don't create for:**
- One-off solutions
- Standard practices well-documented elsewhere
- Project-specific conventions

## SKILL.md Structure

**Frontmatter (YAML):**
```yaml
---
name: Skill-Name-With-Hyphens
description: Use when [specific triggering conditions]
---
```

**Required fields:** `name` and `description`

**Description rules:**
- Start with "Use when..."
- Describe triggering conditions, NOT workflow
- Third person

## The Iron Law

```
NO SKILL WITHOUT A FAILING TEST FIRST
```

## RED-GREEN-REFACTOR for Skills

### RED: Write Failing Test (Baseline)
Run pressure scenario WITHOUT the skill. Document exact behavior.

### GREEN: Write Minimal Skill
Write skill addressing those specific rationalizations.

### REFACTOR: Close Loopholes
Agent found new rationalization? Add explicit counter. Re-test.

## Skill Creation Checklist

**RED Phase:**
- [ ] Create pressure scenarios
- [ ] Run WITHOUT skill - document baseline
- [ ] Identify patterns in rationalizations

**GREEN Phase:**
- [ ] YAML frontmatter with name and description
- [ ] Description starts with "Use when..."
- [ ] Address specific baseline failures
- [ ] Code inline OR link to separate file
- [ ] Run WITH skill - verify compliance

**REFACTOR Phase:**
- [ ] Identify NEW rationalizations
- [ ] Add explicit counters
- [ ] Re-test until bulletproof

**Deployment:**
- [ ] Commit skill to git
