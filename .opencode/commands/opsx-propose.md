---
description: Propose a new change via interview-first spec authoring (Socratic interview → artifact synthesis → validate)
---

Propose a new change — interview-first, then synthesize.

I will NOT generate spec artifacts without first conducting a structured Socratic
interview (dispatched to @openspec-plan). The interview transcript is the sole
input for artifact synthesis.

---

**Store selection:** If the user names a store (a store is a standalone OpenSpec repo registered on this machine) or the work lives in one, run `openspec store list --json` to discover registered store ids, then pass `--store <id>` on the commands that read or write specs and changes (`new change`, `status`, `instructions`, `list`, `show`, `validate`, `archive`, `doctor`, `context`). Other commands do not take the flag. Hints printed by commands already carry the flag; keep it on follow-ups. Without a store, commands act on the nearest local `openspec/` root.

**Input**: The argument after `/opsx-propose` is the change name (kebab-case), OR a description of what the user wants to build.

**Steps**

1. **Interview (MANDATORY)** — dispatch @openspec-plan for the structured Socratic interview BEFORE any artifact work. Protocol: one question at a time, each with the model's recommended answer; look up facts in the codebase rather than asking the developer; depth mode Full (default) / Compressed (≤5 questions) / Skip (requires explicit developer opt-in with a stated reason). Research/analysis needs found during the interview → dispatch @researcher / @analyzer inline and feed results back. Practice-protected: the developer writes the substance; you structure, challenge, and synthesize but never draft on the developer's behalf. Output: the interview transcript in conversation.

2. **Synthesize artifacts from the interview transcript** — using the openspec CLI commands in dependency order:
   - `openspec new change "<name>"`
   - `openspec status --change "<name>" --json` (get the build order)
   - For each ready artifact: `openspec instructions <artifact-id> --change "<name>" --json`, then write the artifact to its `resolvedOutputPath` using the `template` — every claim/decision/edge case must trace to a specific interview exchange.

3. **Validate**
   ```bash
   openspec validate "<name>"
   ```

4. **Show final status**
   ```bash
   openspec status --change "<name>"
   ```

**Output**

After completing all artifacts, summarize:
- Change name and location
- List of artifacts created with brief descriptions
- Interview depth mode used
- What's ready: "All artifacts created! Ready for implementation."
- Prompt: "Run `/opsx-apply` or ask me to implement to start working on the tasks."

**Guardrails**
- Create ALL artifacts needed for implementation (as defined by schema's `apply.requires`)
- Always read dependency artifacts before creating a new one
- NEVER skip the interview — unclear context is MORE reason to interview, not less
- If a change with that name already exists, point to `/opsx-continue`
- Verify each artifact file exists after writing before proceeding to next
