---
description: Start a fresh OpenSpec change - routes into the interview-first /opsx-propose flow
---

Start a new OpenSpec change.

This is the entry point for brand-new work. It hands off to the **/opsx-propose** flow
(`/opsx-propose <name-or-description>`), which creates the change scaffold; all artifacts
are authored via the interview-first flow (Socratic interview → synthesis from transcript).

**Input**: Optional change name (kebab-case) or a description of what you want to build,
e.g. `/opsx-new add-user-auth` or `/opsx-new we need auth for the author studio`.

**Steps**

1. **Confirm the idea is ready to spec**
   - If the idea is still fuzzy, route through `/opsx-explore` first (thinking partner mode)
   - If it is concrete, proceed to the propose flow

2. **Route to the propose flow**
   - Run `/opsx-propose <name-or-description>` to create the change and author all artifacts

3. **After artifacts are done**
   - Run `openspec validate <name>` for structural validation
   - Prompt: "Run `/opsx-apply` to start implementing."

**Guardrails**

- This command only starts the flow — artifact authoring happens via /opsx-propose
- Use `/opsx-continue` instead if the change already exists and only some artifacts are done
- Practice-protected: you interview and structure; the user writes the artifact substance
