# Observer Plugin Path Resolution Defect (DIA-260821-5r03)

- Source: ai-specialist read-only runtime audit (DIA-260821-5r03)
- Date: 2026-08-21
- Ticket: DIA-260821-5r03
- Scope: OpenCode config plugin loading (AGENTS.md section 2.5)
- Status: finding registered pre-implementation; no config change applied yet

## Verified facts (runtime audit)

1. **No duplicate observer loads.** The read-only runtime audit found that the
   observer plugins are loaded exactly ONCE. The earlier hypothesis of
   duplicate loads is NOT confirmed by the audit.

2. **Actual defect: dead nested plugin paths.** `.opencode/opencode.jsonc`
   (lines 603-604) declares two explicit local plugin paths:

   ```
   "./.opencode/plugins/delegation-observer.ts",
   "./.opencode/plugins/needs-input-observer.ts"
   ```

   These paths are resolved RELATIVE TO the config file's own directory
   (`.opencode/`), so they expand to the dead nested locations
   `.opencode/.opencode/plugins/delegation-observer.ts` and
   `.opencode/.opencode/plugins/needs-input-observer.ts`. Those nested paths
   do not exist. Meanwhile OpenCode auto-discovery loads the real files at
   `.opencode/plugins/...` (relative to project root) exactly once. The
   explicit entries therefore point at dead targets while auto-discovery
   supplies the working load.

3. **Prescribed remediation.**
   - Change the two explicit entries to `./plugins/...` (relative to the
     config dir `.opencode/`, yielding the live `.opencode/plugins/...`).
   - Add fail-hard validation for local-file-plugin path resolution: a
     declared local plugin path that does not resolve to an existing file
     must hard-fail startup instead of silently resolving to nothing.

## Historical hypotheses (NOT confirmation)

The following earlier analyses hypothesized a DIFFERENT root cause
(duplicate observer loads). They are recorded here only as historical
context for the audit; the runtime audit did NOT confirm them:

- ana019: hypothesized duplicate observer loads
- ana026: hypothesized duplicate observer loads
- ana032: hypothesized duplicate observer loads

These remain unverified hypotheses. The verified defect is the dead nested
path resolution described above, not duplication.

## Why this matters

Silent dead plugin paths mask configuration drift: the config appears to
explicitly load observers, but the explicit entries are inert while
auto-discovery does the real work. Fail-hard path validation would surface
such drift at startup rather than leaving a misleading config.

## Verification (this learning file only)

- Defect verified by reading `.opencode/opencode.jsonc` lines 603-604
  (dead nested `.opencode/.opencode/plugins/...` expansion).
- No config, ticket, OpenSpec artifact, or memory-shelf file was modified.
- Runtime-audit "no duplicate loads" conclusion taken from DIA-260821-5r03
  (read-only, pre-implementation registration).
