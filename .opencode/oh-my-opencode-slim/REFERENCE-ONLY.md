# REFERENCE-ONLY -- live prompt-override layer

This directory is ONLY the live OMO prompt-override dir plus curated knowledge.
The upstream source snapshot (src/, dist/, companion/, docs/, build scaffolding)
was removed on 2026-10-22 (DIA-261022-5n2v) because it was 8 releases behind the
runtime. The running plugin is npm `oh-my-opencode-slim@2.2.19`, pinned in
`.opencode/opencode.jsonc` (tui.json aligned to the same pin). Prompt discovery
is by filename convention at (1) <project>/<preset>/, (2) <project>/,
(3) user config dirs -- a miss silently falls back to the built-in prompt.
To consult upstream source use the npm cache package or the clonedeps skill,
never a vendored copy.
