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

## coder.md override provenance (DIA-128 / DIA-260831-h3i4)

  DIA-128 dual-runtime prompt-precedence regression note (2026-08-13).
  Project-level prompt override; loaded by OMO prompt-file search-order
  step 2 (project root directory), see docs/project-local-customization.md.

  DUAL-RUNTIME NOTE (revised DIA-260831-h3i4): the project runtime wires
  npm oh-my-opencode-slim@2.2.19 from the .opencode/opencode.jsonc plugin
  array (tui.json aligned to the same pin), which reads prompt overrides
  from this directory at runtime - so this FILE wins (the vendored checkout
  itself stays REFERENCE-ONLY, see REFERENCE-ONLY.md). The inline prompts for coder
  and analyzer were removed from oh-my-opencode-slim.jsonc so BOTH runtimes
  now resolve to these files consistently (no override warning).

  ON ANY OMO UPGRADE: re-verify prompt precedence semantics (inline vs file)
  and keep the warning-free invariant - never re-add an inline prompt beside
  this file unless the upgraded runtime semantics are confirmed.
