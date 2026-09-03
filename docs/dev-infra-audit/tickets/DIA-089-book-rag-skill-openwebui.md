# DIA-089 — add the book_rag skill and connect it to OpenWebUI (hybrid RAG over local engineering textbooks)

<!-- UPDATE 2026-08-13 (PHASE A COMPLETE - res-5 + res025): Phase A investigation + architecture definition delivered by researcher lane res-5 (ses_0032ead09ffeb7cwbfzAHgmBQO); persisted as conspect res025 (knowledge/res025-openwebui-rag-infra/, 8/8 sources archived, 328 lines, shelf.conspects). INVENTORY: book-rag SKILL.md exists + registered in 10 agent skill arrays; backing scripts query_rag.py (1328 lines) + test_query_rag.py (500 lines, network-mocked) + query_web.py + commands/rag.md all EXIST and are sound; knowledge-bases.yaml STALE (cached_at 2026-07-13, 12 KB UUIDs); global skill copy ABSENT (memory-shelf deletion claim = config drift); OPENWEBUI_URL/OPENWEBUI_API_KEY/OPENWEBUI_DATA_DIR all UNSET; server NOT running; real WSL->Windows data dir exists (/mnt/c/Users/qualt/AppData/Roaming/open-webui/data/.key). STALE-CLAIM CONFIRMED: SKILL.md line 354 states OPENWEBUI_API_KEY is set - FALSE. ARCHITECTURE: OPT-IN #rag/#tag -> SKILL.md -> commands/rag.md -> query_rag.py (parse #tag, KB UUID via Tier1 GET /api/v1/knowledge/ or Tier2 webui.db, auth via API key or .key JWT, POST /api/v1/retrieval/query/collection {query, collection_names, k:6, hybrid:true}, BM25+vector+CrossEncoder, cited chunks + [WARNING] when top < 0.30). GAPS: developer-blocked (server start + 3 env vars) vs lane-owned (SKILL.md stale claims, KB cache refresh, memory-shelf drift reconcile, @rag doc drift). WEB-FRESH (v0.11.0, 2026-08-13): hybrid BM25+CrossEncoder via ENABLE_RAG_HYBRID_SEARCH; breaking change RAG_TEXT_SPLITTER=markdown_header REMOVED -> ENABLE_MARKDOWN_HEADER_TEXT_SPLITTER; embedding-model change requires re-index; OPENWEBUI_DATA_DIR is script-invented not a server var; Bearer sk- + JWT + x-api-key auth; file ingestion POST /api/v1/files/ process=true + wait completed before KB add. PHASE B/C VERIFICATION PLAN READY (exact curl calls + expected shapes in res025 section 5) - run once developer starts server + sets env. Developer KEEP decision 2026-08-13 (binary per DIA-135). Phases B/C remain BLOCKED on developer env setup. -->

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
- [x] Phase A investigation complete (res-5 2026-08-13): inventory, architecture, gap analysis, Phase B/C verification plan - persisted res025
- [ ] Phase B: OpenWebUI endpoint config verification - BLOCKED on developer (start server + set OPENWEBUI_URL/API_KEY/DATA_DIR)
- [ ] Phase C: retrieval test - BLOCKED on developer (Phase B precondition)

## Fix

§10-routed if registration touches .opencode/ config.

> To be filled at fix time.

Phase A COMPLETE 2026-08-13 (res-5/res025): inventory + architecture + gaps + Phase B/C verification plan delivered and persisted. Phases B/C blocked on developer env setup (server start + 3 env vars per res025 section 4). Lane-owned post-B/C items: fix SKILL.md stale API-key claim, refresh stale KB cache, reconcile memory-shelf/global-copy drift.

## Lane-owned Fixes

- **SKILL.md stale API-key claim (2026-08-17):** Fixed line 354. Old text stated
  `OPENWEBUI_API_KEY is set as a user env var` — false. Updated to list both auth
  methods (API key, JWT auto-minting) and note the API key is NOT currently configured
  and must be set by the developer.
- **Phase B/C still blocked:** OpenWebUI server + env vars (OPENWEBUI_URL,
  OPENWEBUI_API_KEY, OPENWEBUI_DATA_DIR) remain developer-blocked.

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
