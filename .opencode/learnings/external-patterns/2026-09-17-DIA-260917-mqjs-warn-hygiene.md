# DIA-260917-mqjs warn-hygiene findings (ai-specialist gate, AGENTS.md 2.5 step 1)

- Ticket: DIA-260917-mqjs (OPEN at verification time, 2026-09-17). Variant A approved: per-agent deny x4 + archive 13.
- Date: 2026-09-17.
- Gate deviation: the ai-specialist deny gate errored empty for the 3rd time overall; ai--1, ai--2, and ai--5 partials are preserved. The cod-26 recon answered all gate questions with line quotes and stands as gate-equivalent evidence.
- Recon summary:
  - Audit coverage is value-blind: allow would silence warnings just as much as deny; use deny only.
  - Global block lines ~24-118; per-agent maps exist for analyzer, reviewer, observer, conspecter.
  - No global top-level-deny precedent; note on non-inheritance of permission blocks.
  - Archive holds 18 files + README process; scanners exclude archive except blocker/show/update.
  - DIA-167..179: CLOSED x4, DONE x7, IMPLEMENTED x2, none OPEN.
  - Edges 169->167, 170->169 are safe; DONE/IMPLEMENTED statuses recorded as trigger extension.
- Plan: coder per-agent deny x4 (JSONC nested deny per map shape) + git mv 13 files to archive + README rows + rollup + test-config + auditor attempt + changelog + commit. Outcome field pending implementation.
