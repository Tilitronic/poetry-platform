<!--
  DIA-128 dual-runtime prompt-precedence regression note (2026-08-13).
  Project-level prompt override (append file); loaded by OMO prompt-file
  search-order step 2 (project root directory), see
  docs/project-local-customization.md.

  DUAL-RUNTIME NOTE (revised DIA-260831-h3i4): the project runtime wires
  npm oh-my-opencode-slim@2.2.19 from the .opencode/opencode.jsonc plugin
  array (tui.json aligned to the same pin), which reads prompt overrides
  from this directory at runtime - so this FILE wins (the vendored checkout
  itself stays REFERENCE-ONLY, see REFERENCE-ONLY.md). The inline analyzer prompt was
  removed from oh-my-opencode-slim.jsonc (content relocated here) so BOTH
  runtimes now resolve consistently and no override warning fires.

  ON ANY OMO UPGRADE: re-verify prompt precedence semantics (inline vs file)
  and keep the warning-free invariant - never re-add an inline prompt beside
  this file unless the upgraded runtime semantics are confirmed.
-->

## OWNERSHIP TRACKING

Alongside the existing metrics (retry counts, token cost, failure patterns), track for each session touching a practice-protected zone: who authored the artifact (person vs agent) and how much of it. If authored by the agent despite the zone being protected, flag this explicitly in analysis-report.md as its own finding.

