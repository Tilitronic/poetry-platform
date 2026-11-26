# Skill command-reference validator findings - DIA-260831-n9o0

Date: 2026-10-13
Gate: inline read-only research, explicitly approved by developer because the ai-specialist lane is unavailable.
Ticket: DIA-260831-n9o0 'Book-rag skill references at-rag instead of rag'

## Findings

1. `.opencode/skills/book-rag/SKILL.md` already uses the correct `/rag` reference, and `.opencode/commands/rag.md` exists. The spelling correction is already present; the remaining ticket gap is automated validation of command references in skill bodies.
2. `.opencode/scripts/validate-skills.sh` already snapshots command names from both the inline `command` config and `.opencode/commands/*.md` filenames. It resolves frontmatter `commands:` declarations against this set, but does not currently inspect body references.
3. `scripts/__tests__/validate-skills.bats` already provides hermetic fixtures for skills, inline command manifests, and command-file stems through `SKILLS_ROOT`, `COMPAT_CONFIG_FILE`, and `COMPAT_COMMANDS_DIR`.
4. Existing skill references use inline-code slash forms such as `/rag` and `/opsx-apply`. A body check can therefore stay narrow: validate backticked slash-command tokens only and avoid interpreting ordinary paths such as `/tmp/path` as commands.

## Options

1. Recommended: extend `validate-skills.sh` to resolve backticked body command references against its existing command snapshot, and add hermetic Bats cases. Pros: one source of truth, existing gate wiring, no new validator or manifest. Cons: scope is intentionally limited to explicit inline-code command syntax. Effort: small. Routing: ordinary implementation; no policy/schema change.
2. Create a separate command-reference validator and add its own tests plus gate wiring. Pros: separate responsibility. Cons: duplicates skill traversal and command registry setup, adds another script and gate. Effort: medium. Routing: no clear benefit for this bounded rule.
3. Keep status quo and fix only individual typos. Pros: no code. Cons: future broken references remain undetected. Effort: none.

## Evidence

- Tier 1: `.opencode/scripts/validate-skills.sh` command snapshot and compat resolution; `scripts/__tests__/validate-skills.bats` fixture seams and unknown-command tests; `.opencode/skills/book-rag/SKILL.md`; `.opencode/commands/rag.md`.
- Tier 1: prior specialist finding `.opencode/learnings/external-patterns/2026-09-10-dia-260831-n9o0-book-rag-slash-reference-findings.md` confirms `/rag` is a file-based OpenCode command and records the original typo correction.
- Tier 2: the prior finding cites `https://opencode.ai/docs/commands/`; a fresh fetch on 2026-10-13 returned HTTP 404, so no new external claim is based on it.
- [INFERENCE] Reusing the current command snapshot and validating only backticked slash tokens is the smallest reliable extension because it reuses the exact registry already used for frontmatter command references while avoiding filesystem-path false positives.

## RED test scope

- A backticked command present in the fixture registry passes.
- A backticked unknown command fails with a deterministic message naming the skill and missing command.
- A backticked filesystem path with a slash after its first segment is ignored.

No implementation changes were made during this gate.
