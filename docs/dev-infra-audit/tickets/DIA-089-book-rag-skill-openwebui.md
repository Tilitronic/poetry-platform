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

## Scope restructure: multi-phase (batch brief 2026-08-11)

This is a small RAG build, not a simple recovery - scope it with phases:

Phase A (investigation, do FIRST before any implementation):

- [ ] Inspect existing RAG infrastructure (book-rag skill is present at
      .opencode/skills/book-rag/ AND global - verify what exists and avoid
      duplicating).
- [ ] Inspect current OpenWebUI configuration.
- [ ] Define intended architecture: ingestion, chunking, embeddings,
      retrieval, metadata, citation/source tracking, querying.
- [ ] Document dependencies and interfaces with the existing agent
      workflow.

Phase B (MVP implementation, depends on Phase A):

- [ ] Book ingestion + chunking pipeline.
- [ ] Embedding generation and storage.
- [ ] Basic retrieval (query to relevant chunks).
- [ ] Minimal citation/source tracking (which book/page/section a chunk
      came from).

Phase C (retrieval quality + integration, depends on Phase B functional):

- [ ] Connect to OpenWebUI where appropriate.
- [ ] Acceptance tests for retrieval quality (precision of returned chunks
      against known queries).
- [ ] Acceptance tests for citation/source traceability (every answer
      traces to a specific source chunk).

Dependency note: do NOT start Phase B until Phase A investigation is
closed. Status stays OPEN with phases noted.
