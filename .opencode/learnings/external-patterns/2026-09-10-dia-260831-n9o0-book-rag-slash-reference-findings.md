# book-rag slash-reference findings - DIA-260831-n9o0 (2026-09-10)

Ticket: DIA-260831-n9o0
Date: 2026-09-10
Gate: ai-specialist, AGENTS.md section 2.5 step 1, docs only, no config edit.
Source: ai-specialist lane ses_f75443a3fffeiEzMRmZV76q6OO
Scope: read-only verification. Single learnings file. No edits to skills, configs, tickets, changelog, memory-shelf.

## Finding

`.opencode/skills/book-rag/SKILL.md` lines 41-42 say:

"Prefer the `@rag` opencode command (registered in opencode.json) instead
of calling the script directly."

That reference is wrong on both counts: the sigil and the registry.

## Ground truth (verified read-only)

1. The correct invocation is the slash command `/rag`, defined by the
   file-based command `.opencode/commands/rag.md` (frontmatter
   description + `agent: coder`, `$ARGUMENTS` routing rules, script call
   `python3 .opencode/scripts/query_rag.py "$ARGUMENTS"`).
2. The `opencode.jsonc` inline `command` object has only four keys:
   `tdd-cycle`, `test-package`, `arch-check`, `code-ownership`. There is
   no `rag` key, so nothing named `@rag` or `/rag` is registered inline.
   `/rag` resolves via the file-based command path, not the inline block.
3. There is no `@rag` mention-syntax command in this repo. `@` addresses
   agents; `/` invokes commands. `@rag` is not a defined agent either.

## Best-practice pointer

Official OpenCode docs confirm slash invocation for commands:
URL: https://opencode.ai/docs/commands/

File-based commands under the commands directory resolve as `/name`;
inline `command` objects in the config are the only registry that could
back a "registered in opencode.json(c)" claim, and `rag` is absent there.

## Approved correction (for coder lane, NOT applied here)

In `.opencode/skills/book-rag/SKILL.md` lines 41-43, replace:

"Prefer the `@rag` opencode command (registered in opencode.json) instead
of calling the script directly. Use direct bash calls only when the command
is unavailable or you need flags like `--list` / `--books` / `--stats`."

with:

"Prefer the `/rag` slash command (`.opencode/commands/rag.md`) instead
of calling the script directly. Use direct bash calls only when the command
is unavailable or you need flags like `--list` / `--books` / `--stats`."

Scope guard: this correction touches SKILL.md only. It MUST NOT touch
DIA-260827-8la4, DIA-260827-ft3z, or DIA-260909-csds, and MUST NOT edit
configs, tickets, changelog, or memory-shelf.

## Outcome

REGISTERED 2026-09-10. Awaiting coder fix lane + ai-auditor review per
AGENTS.md section 2.5 steps 4-6. No code changed in this step.
