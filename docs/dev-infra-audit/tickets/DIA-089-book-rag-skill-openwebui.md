# DIA-089 — add the book_rag skill and connect it to OpenWebUI (hybrid RAG over local engineering textbooks)

<!-- Filed by the docs lane (code-executor re-route) 2026-08-10. -->

---

id: DIA-089
title: "add the book_rag skill and connect it to OpenWebUI (hybrid RAG over local engineering textbooks)"
area: skills
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-10
source: inventory
date: 2026-08-10
created: 2026-08-10
updated: 2026-08-11

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_0133de7fdffeKc3ClhE6fqFy0X"
lane_id: "docs"
agent: "code-executor"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-089-book-rag-skill-openwebui.md"]
artifacts: []
evidence: []

---

## Description

Add the book_rag skill and connect it to OpenWebUI (hybrid RAG over local
engineering textbooks). Verify the skill's SKILL.md exists (listed at
.opencode/skills/book-rag/SKILL.md — confirm registration), configure the
OpenWebUI endpoint, and test retrieval.

## Verification

- [x] Confirm .opencode/skills/book-rag/SKILL.md exists and is registered. (PASS 2026-08-11)
- [ ] Configure the OpenWebUI endpoint (hybrid RAG over local engineering textbooks). (BLOCKED on developer 2026-08-11)
- [ ] Run a retrieval test against a local textbook and confirm relevant results. (BLOCKED on developer 2026-08-11)

## Fix

§10-routed if registration touches .opencode/ config.

> To be filled at fix time.

## Re-verify

**Session-6 verification (2026-08-11, wrap-up lane, campaign
c-20260809-residual-closure).** Status stays OPEN; OpenWebUI connection blocked
on developer action.

- PASS - .opencode/skills/book-rag/SKILL.md exists, frontmatter valid
  (name: book-rag, compatibility: opencode), registered + active (present in
  OMO per-agent skill arrays + runtime available-skills registry).
- FAIL (environment) - OpenWebUI connection NOT functional:
  - Server not running: nothing listening on localhost:8080, ports 3000/8000,
    or Ollama 11434 (ss scan 2026-08-11).
  - Env vars UNSET: OPENWEBUI_URL / OPENWEBUI_API_KEY / OPENWEBUI_DATA_DIR
    (printenv exit 1).
  - Script default OPENWEBUI_DATA_DIR resolves wrong on Linux (APPDATA empty).
  - Real key present at
    /mnt/c/Users/qualt/AppData/Roaming/open-webui/data/.key (128 bytes).
- STALE CLAIM - SKILL.md line 354 states 'OPENWEBUI_API_KEY is set as a user
  env var'; NOT true in this runtime (unset).

Pending developer action: start the OpenWebUI server, set OPENWEBUI_URL, and
set OPENWEBUI_DATA_DIR to the WSL path
(/mnt/c/Users/qualt/AppData/Roaming/open-webui/data) or set
OPENWEBUI_API_KEY; then re-run the retrieval test (Verification item 3).
