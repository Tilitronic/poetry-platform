---
ownership:
  substance: developer
  structure: AI
  interview_depth: compressed
  interview_reason: 'DIA-104 cross-boundary/cross-cutting/hard-to-reverse triggers; developer pre-resolved scope decisions 1-3 as the authoritative compressed grill.'
campaign_ticket: DIA-260929-sjwm
---

## 1. Docker live-surface removal (dev-infra class, one context window)

- [ ] 1.1 Blocking edges: none. Remove every live snip reference from
      `Dockerfile.dev`: delete the install block (lines 128-135), delete
      `ARG SNIP_VERSION=0.22.0` (line 36), drop `snip` from the header comment
      (line 5), and reword the comparison comments (lines 44, 92, 141, 170, 290) to name only the surviving pattern (uv/tini/node) so no `snip` token
      remains. Touch nothing else in the file. **Acceptance:** `grep -in snip
  Dockerfile.dev` returns zero matches; `docker compose config --quiet`
      still exits 0; no `SNIP_VERSION`, `SNIP_ARCH`, or `edouard-claude/snip`
      token remains. **Blocks:** 3.1, 5.1.

## 2. OpenCode config live-surface removal (section 2.5 class, one context window)

- [ ] 2.1 Blocking edges: none. Dispatch `@ai-specialist` (read-only) as the
      AGENTS.md section 2.5 gate for the `.opencode/*` config portion:
      confirm no hidden dependency loads snip, confirm the four deny rules are
      dormant, and register findings in
      `.opencode/learnings/external-patterns/`. Present findings to the
      developer for the section 2.5 review/decide step. **Acceptance:** the
      gate finding is recorded and the developer approves the config edit
      before any `@coder` config dispatch. **Blocks:** 2.2, 5.2.
- [ ] 2.2 Blocking edges: 2.1. Dispatch `@coder` to remove the live config
      surface: the `snip` / `snip *` deny rules from the `coder` permission
      block (opencode.jsonc lines 329-330) and from `coder-escalated` (lines
      435-436); the DORMANT comment block lines 317-322 (including the
      "do NOT remove these rules" line); and the
      `bash: snip / snip * (deny)` line 34 of
      `.opencode/agents/coder-escalated.md`. Keep `doom_loop: deny` and all
      other rules. Do NOT touch the project plugin array (lines 749-760, which
      already has no snip entry). **Acceptance:** `grep -in snip` over
      `.opencode/opencode.jsonc` and `.opencode/agents/coder-escalated.md`
      returns zero matches; JSONC remains valid; `git diff` is limited to these
      two files plus the ticket/artifact bookkeeping. **Blocks:** 3.1, 5.1.

## 3. Live documentation/inventory sync (one context window)

- [ ] 3.1 Blocking edges: 1.1, 2.2. Update `docs/dev-infra-audit/inventory.md`
      line 51 so the pinned-ARG list no longer names `snip 0.22.0`. Record the
      disposition of `docs/dev-infra-audit-plan.md` line 47: preserve it as
      historical record (the C5 checklist is complete `[x]`). Do not rewrite
      any historical analysis, research conspect, memory file, CHANGELOG, or
      CLOSED ticket doc. **Acceptance:** `docs/dev-infra-audit/inventory.md`
      contains no `snip` live-pin claim; `git diff` shows no change to any
      preserved historical path (`.opencode/CHANGELOG.*`,
      `knowledge/archive/**`, `.opencode/memory/lessons.md`,
      `.opencode/memory/failures.md`, `docs/dev-infra-audit/tickets/*`).
      **Blocks:** 5.1.

## 4. Out-of-repo user-global cleanup (delegated external_directory lane)

- [ ] 4.1 Blocking edges: none. Dispatch a delegated lane holding
      `external_directory` permission. It MUST first RE-CONFIRM the actual
      user-global OpenCode config path on the current machine (the prior path
      `/home/mimic/.config/opencode/opencode.jsonc` is a recorded observation
      only, per developer decision 1); capture the pre-edit content as a
      restore artifact; then remove only the `opencode-snip@latest` entry from
      the plugin array. Abort if no `opencode.jsonc` plugin array is found at
      the confirmed path. **Acceptance:** re-confirmed path + pre-edit backup
      recorded in session evidence; the plugin array no longer contains
      `opencode-snip`; no other key is edited. **Blocks:** 4.2, 5.1.
- [ ] 4.2 Blocking edges: 4.1. Inspect and report the orphaned user-home
      `~/.config/snip/` config and the `snip` binary on PATH; remove them only
      if the developer explicitly approves (back up first if removing).
      Perform a restart smoke and confirm the
      `[snip] snip binary not found in PATH - plugin disabled` warning no
      longer appears. **Acceptance:** orphan paths reported with a
      keep/remove decision; restart smoke shows no `[snip]` warning.
      **Blocks:** 5.1.

## 5. Validation, review, registration (one context window)

- [ ] 5.1 Blocking edges: 1.1, 2.2, 3.1, 4.1. Run the gates:
      `make test-config` (exit 0), `make test-infra` (exit 0; image builds,
      smoke passes, `command -v snip` fails inside the container), and
      `openspec validate dia-260929-sjwm-remove-live-snip-traces` (exit 0).
      Run the repo-wide live-token scan and classify every remaining `snip`
      hit as live / historical / false-positive by path. **Acceptance:**
      all three commands exit 0; zero live hits remain; every remaining hit is
      a preserved historical path or a documented `snippet`/`Snippets` false
      positive. **Blocks:** 5.2.
- [ ] 5.2 Blocking edges: 5.1. Dispatch `@ai-auditor` for the independent
      config review (AGENTS.md section 2.5) and `@reviewer` for the dev-infra
      portion (section 2.4). Provide the diff, the gate evidence, and the scan
      classification. **Acceptance:** no Critical findings; reviewers confirm
      the diff scope matches design.md; no historical path was modified.
      **Blocks:** 5.3.
- [ ] 5.3 Blocking edges: 5.2. Register the change: append the CHANGELOG entry
      via `scripts/changelog-add --ticket DIA-260929-sjwm` (then validate and
      render), dispatch `@memory-manager` for any lesson, and update the
      DIA-260929-sjwm ticket (Description/Verification/Fix) plus its
      gate_state/gate_triggers/gate_waivers frontmatter. **Acceptance:** one
      schema-valid CHANGELOG entry; ticket carries gate_state=grilled,
      gate_triggers=[cross-boundary, cross-cutting, hard-to-reverse],
      gate_waivers=[]. **Blocks:** none.
