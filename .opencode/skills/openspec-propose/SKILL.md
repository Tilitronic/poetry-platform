---
name: openspec-propose
description: Propose a new change via interview-first spec authoring — a structured Socratic interview precedes ALL artifact synthesis, and the interview transcript is the sole input for creating proposal, design, and tasks. Use when the user wants to build something and needs OpenSpec artifacts authored from an interview.
allowed-tools: Bash(openspec:*)
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "2.0"
  generatedBy: "1.6.0"
---

<!-- LOCAL OVERRIDE — vendored from openspec@1.6.0. Artifact content rules
(Testing Decisions, Seams, vertical-slice tasks) come from
openspec/config.yaml rules, injected into `openspec instructions`.
If `openspec update` regenerates this file, re-apply this banner. -->

Propose a new change — interview-first, then synthesize. I will NOT generate spec artifacts without first conducting a structured Socratic interview. The interview transcript is the sole input for artifact synthesis.

---

**Store selection:** If the user names a store (a store is a standalone OpenSpec repo registered on this machine) or the work lives in one, run `openspec store list --json` to discover registered store ids, then pass `--store <id>` on the commands that read or write specs and changes (`new change`, `status`, `instructions`, `list`, `show`, `validate`, `archive`, `doctor`, `context`). Other commands do not take the flag. Hints printed by commands already carry the flag; keep it on follow-ups. Without a store, commands act on the nearest local `openspec/` root.

**Input**: The user's request should include a change name (kebab-case) OR a description of what they want to build.

**Steps**

1. **Socratic Interview (MANDATORY — no skipping)**

   <!-- FIRST-QUESTION -->
   - Example question: What problem does this change solve for the user, and what would 'done' look like?
   - What is the primary hypothesis this feature/design validates, and how will you know if it is falsified?

   Dispatch **@openspec-plan** for the structured Socratic interview BEFORE any artifact work. The interview protocol:
   - One question at a time, each with the model's recommended answer ("My recommendation: [answer]. Agree, or what should change?")
   - Look up facts in the codebase rather than asking the developer — explore and report findings
   - Numerical-invariants battery when the feature involves phonetics / metrics / stress / scientific computation (IPA, stress, syllabification; meter, foot, caesura; intonation contours, tonal patterns; idempotence, conservation, monotonicity; numerical tolerance and reference implementation)
   - Depth mode selection: **Full** (default) / **Compressed** (≤5 questions) / **Skip** (requires explicit developer opt-in with a stated reason)
   - Research/analysis needs found during the interview → dispatch @researcher / @analyzer inline and feed results back
   - Practice-protected: the developer writes the substance; you structure, challenge, and synthesize but never draft on the developer's behalf.

   Output of this step: the interview transcript in conversation. Do NOT proceed to artifact synthesis without it.

2. **Artifact Synthesis (FROM INTERVIEW TRANSCRIPT ONLY)**

   - Create the change:
     ```bash
     openspec new change "<name>"
     ```
   - Get the artifact build order:
     ```bash
     openspec status --change "<name>" --json
     ```
   - For each ready artifact in dependency order:
     ```bash
     openspec instructions <artifact-id> --change "<name>" --json
     ```
     Read the `dependencies`, `template`, `resolvedOutputPath`, `context` and `rules` from the instructions JSON. Synthesize FROM THE INTERVIEW TRANSCRIPT — every claim, decision, and edge case must trace to a specific interview exchange. Write the artifact to its `resolvedOutputPath` using the `template` as the structure (apply `context`/`rules` as constraints — do NOT copy them into the file). Show brief progress: "Created <artifact-id>".

3. **Validate**
   ```bash
   openspec validate "<name>"
   ```

**Output**

After completing all artifacts, summarize:
- Change name and location
- List of artifacts created with brief descriptions
- Interview depth mode used
- What's ready: "All artifacts created! Ready for implementation."
- Prompt: "Run `/opsx-apply` or ask me to implement to start working on the tasks."

**Artifact Creation Guidelines**

- Follow the `instruction` field from `openspec instructions` for each artifact type
- The schema defines what each artifact should contain - follow it
- Read dependency artifacts for context before creating new ones
- Use `template` as the structure for your output file - fill in its sections
- **IMPORTANT**: `context` and `rules` are constraints for YOU, not content for the file
  - Do NOT copy `<context>`, `<rules>`, `<project_context>` blocks into the artifact
  - These guide what you write, but should never appear in the output

**Guardrails**
- Create ALL artifacts needed for implementation (as defined by schema's `apply.requires`)
- Always read dependency artifacts before creating a new one
- NEVER skip the interview — unclear context is MORE reason to interview, not less
- If a change with that name already exists, ask if user wants to continue it or create a new one
- Verify each artifact file exists after writing before proceeding to next
