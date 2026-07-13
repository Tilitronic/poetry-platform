---
name: git-diff
description: Inject current Git status and uncommitted/staged diff context into the conversation. Trigger via #diff or #git tags.
compatibility: opencode
metadata:
  audience: developers
  workflow: context-awareness
---

## What I Do

- Intercept user queries that reference recent changes, broken code, or explicitly use the `#diff` or `#git` tags.
- Execute a local script to retrieve the exact `git status` and `git diff HEAD` from the developer's workspace.
- Provide the LLM with the exact lines of code added, modified, or deleted, allowing for hyper-accurate debugging and code reviews.

## Core Execution Requirements

1. **Trigger Condition:** Activate when the user asks questions like "what did I just change?", "why is my code failing now?", or explicitly uses `#diff` / `#git`.

2. **Execute the context utility via bash:**
   ```bash
   python3 .opencode/scripts/get_git_context.py
   ```

3. **Parse the Output:** The script will return a formatted string containing:
   - Current Git branch.
   - List of modified/staged files.
   - The actual diff (lines with `+` and `-`).

4. **Contextual Grounding:** Treat the output of this script as the absolute current state of the user's project. Base your debugging, refactoring, or review suggestions strictly on these diffs.

## Notes

- If the diff is excessively large (e.g., > 1000 lines), the script is configured to return only the summary (`git diff --stat`) to avoid context overflow.
- Do not hallucinate file names; only reference files explicitly mentioned in the script's output.
