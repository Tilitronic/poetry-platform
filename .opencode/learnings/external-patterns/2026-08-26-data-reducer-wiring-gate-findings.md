# Data-reducer wiring gate findings (DIA-260826-6mhy, ai-specialist section-2.5 gate)

Source: ai-specialist gate review ses_fc290aaf6ffedNZ0ZUYPe6SszM, 2026-08-26.

1. data-reducer skill threshold: ~100 KB / ~2000 lines; pre-flight wc -c, route through scripts/data-reduce.sh if over threshold. Output contract: compact result < ~5 KB + savings line to stderr (input N KB -> result M KB, saved P%, ~Q tokens, ~4 chars/token heuristic).
2. Skill applicability section lists coder / analyzer / code-navigator / researcher - NOT conspecter. DIA-195 names analyzer/conspecter but the skill was designed without conspecter in mind (scope tension).
3. Conspecter has bash: deny (opencode.jsonc line 547) - cannot run data-reduce.sh or any worker process. Conspecter wiring requires creating skills arrays in 5 presets + relaxing bash deny to scoped allow - a permission-surface change, deferred pending measurement data (DIA-260826-6mhy).
4. Analyzer skills arrays: data-reducer NOT present in any preset; needs adding to 8 arrays (5 base presets + 3 analyzer-escalated clones; no ninth array exists - the +1 was an arithmetic slip) in oh-my-opencode-slim.jsonc (lines 141, 299, 333, 523, 557, 753, 793, 996).
5. make test-config (16 validators) does NOT validate skills-array membership - partial wiring (8 of 9 presets) passes silently. Wiring ticket must include a one-off grep assertion for "data-reducer" across all analyzer skills arrays.
6. Wiring spec (analyzer-only, approved by developer 2026-08-26): add "data-reducer" to analyzer skills arrays in all presets + append one-line mandate to analyzer orchestratorPrompt: raw input over ~100 KB or ~2000 lines MUST be reduced via the data-reducer skill before reading into context. No changes to opencode.jsonc permissions. No changes to conspecter.

Outcome: applied (2026-08-26, ai-auditor review APPROVE, changelog entry added)
