---
description: Continue authoring the remaining OpenSpec artifacts of an existing change (via the openspec-propose skill)
---

Continue an existing OpenSpec change — resume authoring the artifacts that are still pending.

This handles an existing change (same interview-first flow as /opsx-propose): do NOT run
`openspec new change` again. Pick up where the last session left off and drive the remaining
artifacts (proposal.md → design.md → tasks.md) to completion.

**Input**: The change name (kebab-case), e.g. `/opsx-continue add-user-auth`. If omitted, run
`openspec list --json` and ask the user which change to continue.

**Steps**

1. **Resume the change**
   ```bash
   openspec status --change "<name>" --json
   ```
   Parse the JSON to find:
   - `applyRequires`: artifact IDs still needed before implementation
   - `artifacts`: each artifact's status (`done` / `pending`) and dependencies
   - `planningHome`, `changeRoot`, `artifactPaths`, `actionContext`: path and scope context

2. **Load the openspec-propose skill** — follow its interview-first workflow. If the
   interview for this change has NOT yet been conducted (or was incomplete), dispatch
   @openspec-plan to complete the interview first; then synthesize the remaining
   artifacts from the combined transcript.

3. **Author the remaining artifacts in dependency order**

   Use the **TodoWrite tool** to track progress. For each artifact that is `ready`
   (dependencies satisfied, not yet `done`):
   ```bash
   openspec instructions <artifact-id> --change "<name>" --json
   ```
   - Read completed dependency files for context
   - Create the artifact using `template` and write to `resolvedOutputPath`
   - Apply `context` and `rules` as constraints — do NOT copy them into the file
   - Re-run `openspec status --change "<name>" --json` after each artifact
   - Stop when every artifact in `applyRequires` is `done`

4. **Validate before handoff**
   ```bash
   openspec validate <name>
   ```

5. **Show final status**
   ```bash
   openspec status --change "<name>"
   ```

**Output**

- Change name and which artifacts were completed this session
- What remains (if anything)
- When apply-ready: "All artifacts created! Ready for implementation." → prompt "Run `/opsx-apply` to start implementing."

**Guardrails**

- NEVER run `openspec new change` for an existing change — this is a continuation, not a creation
- Always read dependency artifacts before authoring the next one
- Practice-protected: the user writes the artifact substance; you interview, structure, and prompt
- If the change is already apply-ready, say so and point to `/opsx-apply` instead
