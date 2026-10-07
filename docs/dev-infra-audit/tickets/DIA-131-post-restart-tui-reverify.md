# DIA-131 - post-restart TUI re-verify of user-level inline-override fix (DIA-130 review finding F3)

<!-- Filed 2026-08-13 from the DIA-130 review (rev-1). The DIA-130 fix removed
     3 inline "prompt" keys from the user-level OMO config and relocated the
     content into the user-level prompt files (coder.md, analyzer.md). The
     byte-exact relocation and dedupe are independently verified (F1/F2), but
     the VISUAL TUI check requires an OpenCode restart - the DIA-128 close-out
      gap pattern (log-grep does not cover the TUI "Loading plugins..."
      notification emission path). This ticket tracks the post-restart visual
      re-verification.

     UPDATE 2026-08-13 (RESTART-VERIFY PASS + CLOSED): all 5 verification
     items PASS. Lane evidence (cod-2 restart-verify lane, ~16:42 local):
     (1) post-restart process PID 3570407 started 16:40:23 local, after the
     config edit at 16:11; (2) ZERO inline-override warnings in post-restart
     plugin logs oh-my-opencode-slim.20260813T144026/27/29.log; (3) user-level
     config clean - no inline prompt key in any coder/analyzer block (all 3
     presets opencode-go/cebula/free + root agents); (4) coder.md (4085B) +
     analyzer.md (12631B) present with byte-exact relocated DIA-130 content.
     Item 5 (TUI screenshot) recorded as PASS via developer attestation in
     session on 2026-08-13: the TUI "Loading plugins..." area rendered ZERO
     inline-override warnings and no duplication ("terminal ui loaded clean,
     nothing to show you. Look like we fixed correctly."); a screenshot was
     moot because nothing anomalous was shown. Ticket flipped CLOSED
     2026-08-13. -->

---

id: DIA-131
title: "post-restart TUI re-verify of user-level inline-override fix (DIA-130 review finding F3)"
area: opencode-config
severity: Major
status: CLOSED
blocked_by: [DIA-130] # created after DIA-130 fix; needs an OpenCode restart
discovered: 2026-08-13
source: review-finding
date: 2026-08-13
created: 2026-08-13
updated: 2026-08-13

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_0047feea7ffe0tIShzm60jMooi" # base coder verification lane that closed F1/F2
lane_id: "base-coder"
agent: "coder"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-131-post-restart-tui-reverify.md", "docs/dev-infra-audit/tickets/README.md"]
artifacts: []
evidence: ["DIA-130 review finding F3 (rev-1)", "DIA-130 Fix section (byte-exact F1/F2 verification, 2026-08-13)", "DIA-128 close-out gap pattern (log grep missed the TUI emission path)"]

---

## Description

The DIA-130 fix (2026-08-13) deleted the 3 user-level inline "prompt" keys
(coder preset opencode-go line 77, coder preset cebula line 197, analyzer
root agents block line 411) from
`~/.config/opencode/oh-my-opencode-slim.jsonc` and relocated their content
verbatim into the user-level prompt files
(`~/.config/opencode/oh-my-opencode-slim/coder.md`,
`~/.config/opencode/oh-my-opencode-slim/analyzer.md`). The relocation was
independently verified byte-exact (DIA-130 Fix section, F1: 28199-byte
pre-fix reconstruction exact match; F2: coder presets byte-identical).

The remaining DIA-130 review finding (F3) is the VISUAL TUI re-verification:
the duplicated inline-override warnings in the opencode TUI "Loading
plugins..." notification area must be confirmed GONE after an OpenCode
restart. This check cannot run in the current session (the running opencode
process loaded the OLD user-level config at startup); it requires a restart
of opencode itself. This is the same close-out gap that bit DIA-128 - its
zero-occurrence log grep did not cover the TUI emission path, so a log-only
check is NOT sufficient evidence here.

## Verification

How to prove the fix (post-restart, visual):

1. Restart opencode (fresh process loads the fixed user-level config).
2. During startup, watch the "Loading plugins..." notification area in the
   TUI for the OMO 2.2.13 inline-override warnings:
   - `[oh-my-opencode] Agent 'coder': inline prompt overrides prompt file
(coder.md). Remove the inline prompt to use the file.`
   - `[oh-my-opencode] Agent 'analyzer': inline prompt overrides prompt file
(analyzer.md). Remove the inline prompt to use the file.`
   - Expected: ZERO occurrences (pre-fix: 4 lines - 2x coder, 2x analyzer).
   - Capture a screenshot or TUI notification capture as evidence (the DIA-130
     evidence screenshot pattern).
3. Confirm the agents resolve the prompt files at the user level:
   - coder.md and analyzer.md contain their "## DIA-130 relocated inline
     prompt" sections (already verified byte-exact - F1).
   - No inline "prompt" key remains in
     `~/.config/opencode/oh-my-opencode-slim.jsonc`
     (`grep -n '"prompt"'` -> only ai-specialist + 4 council keys remain,
     which are out of scope).
4. Optional duplication check (H3 from DIA-130): confirm the warnings no
   longer fire at all (duplication moot once zero).

## Fix

> To be filled at fix time.

## Re-verify

RESTART-VERIFY PASS (2026-08-13). Ticket flipped CLOSED.

### Evidence

1. **Post-restart process (item 1):** PID 3570407 started 16:40:23 local,
   AFTER the user-level config edit at 16:11 - the running process loaded the
   fixed (post-edit) config.
2. **ZERO inline-override warnings in post-restart plugin logs (item 2):**
   `oh-my-opencode-slim.20260813T144026.log`,
   `oh-my-opencode-slim.20260813T144027.log`,
   `oh-my-opencode-slim.20260813T144029.log` - no "inline prompt overrides
   prompt file" occurrence in any of them (the pre-fix count was 4 lines:
   2x coder, 2x analyzer).
3. **User-level config clean (item 3):**
   `~/.config/opencode/oh-my-opencode-slim.jsonc` has no inline `"prompt"`
   key in any coder/analyzer block - all 3 presets (opencode-go/cebula/free)
   and the root agents block. Only ai-specialist + 4 council keys remain,
   which are out of scope (DIA-130 fix scope).
4. **Prompt files active with relocated content (item 4):**
   `~/.config/opencode/oh-my-opencode-slim/coder.md` (4085 bytes) and
   `analyzer.md` (12631 bytes) present, containing the byte-exact relocated
   DIA-130 content (F1/F2 verified in DIA-130).
5. **TUI clean - developer-attested (item 5):** developer verbally attested
   in session on 2026-08-13 that the TUI "Loading plugins..." area rendered
   ZERO inline-override warnings and no duplication - "terminal ui loaded
   clean, nothing to show you. Look like we fixed correctly." A screenshot
   was moot because nothing anomalous was shown. Recorded as the item-5 PASS
   evidence (developer-attested, supersedes the screenshot requirement).

### Resolution

Status CLOSED 2026-08-13. All 5 items PASS (4 lane-evidence items + 1
developer-attested TUI observation). The DIA-130 F3 visual re-verification
gap is closed: post-restart process loads the fixed user-level config, zero
inline-override warnings fire in the TUI, and the user-level prompt files
carry the relocated prompts. Residual risk unchanged: a future OMO upgrade
or config edit re-adding inline prompts would re-trigger the warning; the
dual-runtime regression note headers in both user-level prompt files guard
against this.
