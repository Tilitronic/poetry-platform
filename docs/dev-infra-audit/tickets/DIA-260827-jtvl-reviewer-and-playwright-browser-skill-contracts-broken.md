# DIA-260827-jtvl - Reviewer and playwright-browser skill contracts broken

---

id: DIA-260827-jtvl
title: "Reviewer and playwright-browser skill contracts broken"
area: opencode-config
severity: High
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260827-wfcx
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: test-lane
date: 2026-08-27
created: 2026-08-27
updated: 2026-08-27

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence:

- DIA-260827-wfcx

---

## Description

Reaudit (DIA-260827-wfcx, 2026-08-31; S-H7/S-H8/S-M1) confirms three broken contracts: (1) promo gives reviewer book-rag (oh-my-opencode-slim.jsonc:1237-1241) while reviewer bash is denied (opencode.jsonc:292-297) and the skill requires script/command execution (book-rag/SKILL.md:38-43,172-174) - the mandatory grounding contract is impossible. (2) teaching requires Python RAG (teaching/SKILL.md:38-47) and describes writes (:123-134) but is assigned to architector/openspec-plan/ai-specialist/ai-auditor, which deny bash/edit or allow only openspec \*. (3) playwright-browser/SKILL.md:34-36,58-72 recommends 'playwright-cli', which does not exist in the container; npx --no-install @playwright/cli fails, though the fallback 'playwright cli' works. Impact: reviewer cannot perform mandatory grounding and may fabricate it; teaching's mandatory Step 0 is impossible and its persistence contradicts lane ownership; playwright primary recipes fail on the first command. Correct fix: remove mandatory RAG or provide a dedicated read-only retrieval tool; split teaching's read-only pedagogy from persistence or grant a narrow RAG tool only to eligible roles; standardize all playwright examples on the actually provisioned CLI.

## Verification

reviewer can perform grounding via a read-only retrieval tool without bash; teaching runs Step 0 on eligible roles only; playwright examples run on the first command in the container.

## Fix

For book-rag and teaching: remove the mandatory RAG/persistence that needs bash, or provide a dedicated read-only retrieval tool and a narrow RAG tool only for roles that allow it. For playwright: standardize every example on the provisioned CLI (e.g. 'playwright cli' / 'npx playwright cli') rather than the nonexistent 'playwright-cli'.

## Re-verify

> To be filled at re-verify time.
