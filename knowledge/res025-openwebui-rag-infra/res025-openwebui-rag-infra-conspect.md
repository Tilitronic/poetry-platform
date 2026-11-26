# OpenWebUI RAG Infrastructure Investigation (DIA-089 Phase A)

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 8
phase-a-failures: 0
shelf-registration: .opencode/memory-shelf.yaml (shelf.conspects)
-->

- RES ID: res025 (verified free; res024-model-variant-fetch-tools is the last registered)
- Topic: book-rag / OpenWebUI hybrid RAG infrastructure investigation
- Ticket: DIA-089 (Phase A, investigation; Phase B/C blocked on developer)
- Researcher lane: res-5 (session ses_0032ead09ffeb7cwbfzAHgmBQO)
- Developer decision 2026-08-13: KEEP - persist
- Access date for web-fresh sources: 2026-08-13 (OpenWebUI v0.11.0, changelog head [0.11.0] - 2026-07-27)

---

## 1. Decision context

DIA-089 (OPEN, severity Medium, filed 2026-08-10) requested the book_rag
skill be added and connected to OpenWebUI for hybrid RAG over local
engineering textbooks. The skill registration check PASSED 2026-08-11
(SKILL.md exists, frontmatter valid, present in OMO per-agent skill arrays
and the runtime available-skills registry). OpenWebUI connectivity was
FAIL (environment): server not running, three env vars unset, script
default data-dir resolves wrong on Linux (APPDATA empty). The ticket was
scope-restructured into Phase A (investigation) / Phase B (MVP) / Phase C
(retrieval quality) with an explicit dependency note: do NOT start Phase B
until Phase A investigation is closed. This conspect closes Phase A.

Developer decision 2026-08-13: KEEP - persist the investigation as a
research conspect (res025). Phase B/C remain blocked on developer
environment setup (start the server, set OPENWEBUI_URL and
OPENWEBUI_DATA_DIR to the WSL path, or set OPENWEBUI_API_KEY).

---

## 2. Inventory

Local ground truth (read directly on disk, not archived - see Section 8):

| # | Component | Path | Exists? | Claimed-but-absent | Status |
|---|-----------|------|---------|--------------------|--------|
| 1 | Skill definition | .opencode/skills/book-rag/SKILL.md | YES (371 lines) | - | Registered in 10 agent skill arrays in oh-my-opencode-slim.jsonc (L35, 126, 141, 216, 271, 297, 331, 438, 492, 514); frontmatter name book-rag, compatibility opencode |
| 2 | KB metadata cache | .opencode/skills/book-rag/knowledge-bases.yaml | YES (51 lines) | - | STALE: cached_at 2026-07-13T10:33:23+00:00 (31 days old at 2026-08-13, TTL is 3600s = 1h); 12 KB UUIDs listed (visualization, analytical, js, teaching, statistics and algebra, dsboinf, ml, datamanagement, python, rust, csc, ppartreception) |
| 3 | Bridge script | .opencode/scripts/query_rag.py | YES (1328 lines, 48 KB) | - | Hybrid BM25+vector+rerank pipeline; dynamic KB discovery; no hardcoded UUIDs |
| 4 | Test suite | .opencode/scripts/test_query_rag.py | YES (512 lines, 22 KB) | - | Network-mocked (patch.object(m, "requests")); 26+ test cases across 7 classes |
| 5 | Web-search sibling | .opencode/scripts/query_web.py | YES (10,342 bytes) | - | Same OPENWEBUI_URL/API_KEY env contract; test_query_web.py sibling (22 KB) |
| 6 | Command doc | .opencode/commands/rag.md | YES (68 lines) | - | DOC DRIFT: present in .opencode/commands/ but NOT in opencode.jsonc "command" block (L615-636 registers only tdd-cycle, test-package, arch-check, code-ownership); SKILL.md L41-43 claims "@rag opencode command (registered in opencode.json)" |
| 7 | Global skill copy | ~/.config/opencode/skills/book-rag | NO | The skill's RAG_CACHE_DIR default (~/.config/opencode/skills/book-rag, query_rag.py L109-115) implies a global install | ABSENT - contradicts the memory-shelf deletion claim at memory-shelf.yaml L473-492 (ai-self-improvement change says delete 5 byte-exact duplicate skills from .opencode/skills/ including book-rag; CHANGELOG L103 documents the reverse: 4 GLOBAL copies deleted, project copies kept). CONFIG DRIFT between memory-shelf description and the actual applied change |
| 8 | Env vars | OPENWEBUI_URL / OPENWEBUI_API_KEY / OPENWEBUI_DATA_DIR | - | - | UNSET in runtime (ticket verification FAIL 2026-08-11); script defaults: URL http://localhost:8080, API_KEY empty, DATA_DIR %APPDATA%/open-webui/data (APPDATA empty on Linux -> resolves to /open-webui/data, wrong) |
| 9 | Server | localhost:8080 (script default) | - | - | NOT RUNNING (ticket ss scan 2026-08-11: nothing on 8080/3000/8000/Ollama 11434) |
| 10 | Real data dir | /mnt/c/Users/qualt/AppData/Roaming/open-webui/data/.key | YES (128 bytes) | - | Real WSL->Windows OpenWebUI data dir exists; .key present (JWT signing secret); webui.db 54 MB, vector_db/, uploads/, cache/ present. Existence-only verified - the secret VALUE was not read or copied into this conspect |

Stray archival artifacts (from this run's first -o attempt, content
redundant with the clean captures): sources/retrieval-router.md/ and
sources/changelog.md/ directories holding trafilatura output-dir writes.
The retrieval.py source (2,862 lines) and changelog-nav captures inside
them duplicate retrieval-router-src.md / changelog-blob.md.

---

## 3. Architecture: intended RAG data flow

The intended OPT-IN flow (from SKILL.md + commands/rag.md + query_rag.py):

1. User writes a query containing #rag or #tag syntax (e.g. "#csc OOP
   polymorphism"). The skill is OPT-IN only - a plain question must NOT
   trigger it (SKILL.md L12-27).
2. Agent follows the Redesign -> Route -> Execute workflow (SKILL.md
   L47-113): rewrite the raw question into keyword-dense search queries,
   route to one or more KBs semantically, run the search per KB.
3. Execution invokes the command (commands/rag.md) which calls
   query_rag.py; direct script calls are the fallback.
4. query_rag.py pipeline (query_hybrid_rag, L854-1033):
   - Parse #tag anywhere in the query via re.search(r"#(\w+)") - mid-sentence
     tags work, "C#" is never a tag (L880, L35-37).
   - Resolve the tag to a ChromaDB collection UUID via
     _resolve_knowledge_base_smart (L554-587): exact match, then difflib
     fuzzy match (cutoff 0.5), then explicit error path.
   - KB discovery is two-tier (L497-551): Tier 1 GET /api/v1/knowledge/
     (Bearer auth), Tier 2 local webui.db SQLite read (SELECT id, name
     FROM knowledge). Result cached to knowledge-bases.yaml with 1h TTL
     (L236-263) and degraded-mode stale-cache fallback (L330-339).
   - Auth (L829-847): OPENWEBUI_API_KEY env var first; else JWT minted
     from the server's .key file (L772-826, PyJWT optional, 1h admin
     token); else first-run auto-setup writes an API key into webui.db
     and sets a user env var via PowerShell (L616-765).
   - POST /api/v1/retrieval/query/collection with payload {query,
     collection_names, k (default RAG_TOP_K=6, server default 3), hybrid
     (default true client-side)} (L937-954).
   - Parse response {documents, metadatas} as list-of-lists, take the
     first collection's results (L982-987).
   - Format output as "=== RETRIEVED KNOWLEDGE (#tag) ===" with per-chunk
     [n] From: <source> [score=...] lines; emit [WARNING] line when the
     top relevance score is below 0.30 (L1010-1031).
5. Agent synthesizes across KBs and cites source book names; scores
   below 0.30 are flagged for verification (SKILL.md L206-250).

Server-side (verified in archived retrieval.py router): the
/query/collection endpoint (L2583-2635) requires get_verified_user,
validates collection access (_validate_collection_access, L2500), then
either runs hybrid search (query_collection_with_hybrid_search with
BM25 weight and CrossEncoder reranking) when config.ENABLE_RAG_HYBRID_SEARCH
is on and form_data.hybrid is not explicitly False, or plain vector
search otherwise. Note: server-side hybrid default is False
(env-configuration L3336); the script sends hybrid=true explicitly, which
the router honors only when the server config also enables hybrid search.

---

## 4. Gap analysis

| # | Gap | Owner | Action | Effort |
|---|-----|-------|--------|--------|
| 1 | Server not running (nothing on 8080/3000/8000/11434) | DEVELOPER | Start OpenWebUI server (Windows-side install per data dir) | Developer env setup |
| 2 | Env vars unset: OPENWEBUI_URL / OPENWEBUI_API_KEY / OPENWEBUI_DATA_DIR | DEVELOPER | Set OPENWEBUI_URL to the server URL; set OPENWEBUI_DATA_DIR to /mnt/c/Users/qualt/AppData/Roaming/open-webui/data (WSL path) OR set OPENWEBUI_API_KEY | Developer env setup |
| 3 | STALE API-key claim: SKILL.md L354 states "OPENWEBUI_API_KEY is set as a user env var" - FALSE in this runtime | LANE (doc) | Correct SKILL.md L354-355 to state the var is unset by default and JWT auto-mint/.key fallback is the local path | Doc fix (~1 line) |
| 4 | KB cache stale (cached_at 2026-07-13, 12 UUIDs; 1h TTL) | LANE (refresh) | Run query_rag.py --list --refresh once the server is up; verify UUIDs still match the Windows webui.db | 1 command once server up |
| 5 | Config drift: memory-shelf.yaml L473-492 claims project skill copies deleted; actual change (CHANGELOG L103) deleted GLOBAL copies, project copies kept; global book-rag ABSENT (consistent with the applied change, inconsistent with the shelf description) | LANE (doc) | Update the ai-self-improvement-and-cleanup shelf description to reflect the applied direction (global deleted, project kept) | Doc fix |
| 6 | @rag command doc drift: commands/rag.md not in opencode.jsonc "command" block | LANE (doc) | Either register "rag" in opencode.jsonc command block or correct SKILL.md L41 claim (OpenCode auto-discovers .opencode/commands/*.md - verify which mechanism is live) | Investigate + doc fix |
| 7 | Hybrid/rerank configuration (server-side defaults: ENABLE_RAG_HYBRID_SEARCH False, RAG_TOP_K 3, RAG_RELEVANCE_THRESHOLD 0.0; client sends hybrid=true, k=6) | DEVELOPER / LANE (confirm) | Decide server config: enable hybrid, set embedding/reranking models, confirm script k=6 vs server TOP_K=3 behavior | Confirm at B3 |
| 8 | Textbook ingestion into KBs (Phase B) | DEVELOPER (with lane help) | Ingest engineering textbooks into the 12 KBs (or new KBs); verify per-book status "completed" | Phase B |
| 9 | Missing .sdd/ design authority for the book-rag/OpenWebUI integration (no SDD/TSS governs the RAG bridge; DIA-019/DIA-084 touched paths without a design doc) | LANE (flag) | Flag as design-authority gap per project AGENTS.md section 3; propose an .sdd/ entry or OpenSpec change when Phase B starts | Flag only now |

---

## 5. Phase B/C verification plan (ready to run once developer env is up)

Precondition: server running, OPENWEBUI_URL set (and OPENWEBUI_DATA_DIR or
OPENWEBUI_API_KEY set).

B0 - Server health: curl -s -o /dev/null -w "%{http_code}" $OPENWEBUI_URL/api/health -> expect 200.

B1 - KB discovery: python3 .opencode/scripts/query_rag.py --list --refresh
    -> fresh tags, no "cache expired" warning, KB count matches the
    Windows webui.db knowledge table.

B2 - Knowledge API auth: curl -H "Authorization: Bearer <key>" 
    $OPENWEBUI_URL/api/v1/knowledge/ -> 200 JSON list (or 401 to confirm
    auth is enforced; then fix auth path).

B3 - Retrieval config: GET $OPENWEBUI_URL/api/v1/retrieval/config ->
    confirm ENABLE_RAG_HYBRID_SEARCH, RAG_EMBEDDING_MODEL,
    RAG_RERANKING_MODEL, TOP_K, RELEVANCE_THRESHOLD.

B4 - Raw retrieval: POST /api/v1/retrieval/query/collection with
    {query, collection_names:[<uuid>], k:6, hybrid:true} -> expect
    {documents, metadatas} list-of-lists with per-chunk score.

C1 - End-to-end tagged query: query_rag.py "#csc OOP polymorphism" ->
    cited chunks with top score >= 0.30 (no [WARNING]).

C2 - Book inventory: query_rag.py --books-all -> all textbooks with
    status "completed" (the [x] status icon) in the file table.

C3 - Routing: query_rag.py --route "gradient descent optimization" and
    #rag auto-route; weak-match guard (AUTO_ROUTE_THRESHOLD 0.30) falls
    back to global search, not a hard failure.

C4 - Test suite: pytest test_query_rag.py -q -> exit 0 (network-mocked,
    runs without a live server).

C5 - Quality acceptance (Phase C): precision of returned chunks against
    known queries and citation traceability - every answer traces to a
    specific source chunk (book/page/section metadata).

---

## 6. Web-fresh contract (OpenWebUI v0.11.0, accessed 2026-08-13)

All claims below are confirmed in the archived sources (see Section 8 for
exact mapping).

- Hybrid search: ENABLE_RAG_HYBRID_SEARCH (bool, default False) enables
  BM25 + vector retrieval with optional CrossEncoder reranking; applies
  to both the standard RAG pipeline and native knowledge tools.
  RAG_HYBRID_BM25_WEIGHT (float, default 0.5; 1 = keyword-only, 0 =
  vector-only). ENABLE_RAG_HYBRID_SEARCH_ENRICHED_TEXTS (bool, default
  False) enriches indexed text with filenames/titles/sections for better
  keyword recall. SENTENCE_TRANSFORMERS_CROSS_ENCODER_SIGMOID_ACTIVATION_FUNCTION
  (default True) keeps rerank scores in 0-1 so the relevance threshold
  works.
- BREAKING CHANGE: RAG_TEXT_SPLITTER=markdown_header option REMOVED.
  Markdown header splitting is now a preprocessing step controlled by
  ENABLE_MARKDOWN_HEADER_TEXT_SPLITTER (bool, default True). Migration:
  switch to character|token and keep the new var enabled. RAG_TEXT_SPLITTER
  options now: character (default, RecursiveCharacterTextSplitter) / token.
- Chunking: CHUNK_SIZE default 1000, CHUNK_OVERLAP default 100,
  CHUNK_MIN_SIZE_TARGET default 0 (0 disables merging; docs recommend
  e.g. 1000 for a 2000 chunk size, which can cut chunk counts by over
  90%); merging is forward-only, no cross-document merging, O(n) single
  pass, metadata inherited from the first chunk.
- Embedding: RAG_EMBEDDING_MODEL default
  sentence-transformers/all-MiniLM-L6-v2; changing the embedding model
  REQUIRES re-indexing all knowledge-base documents (embeddings from
  different models live in incompatible vector spaces); re-index deletes
  the collection, re-chunks, re-embeds; standalone chat files are NOT
  covered by re-indexing.
- Reranking: RAG_RERANKING_ENGINE (empty = local Sentence-Transformer
  CrossEncoder; "external" = external API via RAG_EXTERNAL_RERANKER_URL),
  RAG_RERANKING_MODEL, RAG_RERANKING_BATCH_SIZE (default 32).
- Retrieval params: RAG_TOP_K default 3 (server), RAG_TOP_K_RERANKER
  default 3, RAG_RELEVANCE_THRESHOLD default 0.0. Client-side query_rag.py
  sends k=6 by default (RAG_TOP_K env in the script, L141).
- Config precedence: ENABLE_PERSISTENT_CONFIG (bool, default True) - DB
  (Admin UI) values take precedence over env vars; set False to force env
  vars, with the caveat that UI changes then do not persist across
  restarts.
- Deprecations: WEBUI_JWT_SECRET_KEY is the legacy alias for
  WEBUI_SECRET_KEY (deprecated). WEBUI_SECRET_KEY is now a hard
  requirement for unsupported (direct uvicorn) startup. DATA_DIR is the
  documented base data directory; no explicit DATA_DIR deprecation marker
  was found in the archived env docs - flag as researcher claim not fully
  confirmable (see Section 8, claim G).
- Auth: Bearer tokens; both API keys (sk- prefix) and JWT tokens are
  accepted (the web UI uses JWTs internally for the same endpoints);
  custom header x-api-key (default) via CUSTOM_API_KEY_HEADER for
  reverse-proxy setups.
- File ingestion: POST /api/v1/files/ with process=true (default) extracts
  content and computes embeddings; uploads are processed ASYNCHRONOUSLY by
  default, so you MUST poll GET /api/v1/files/{id}/process/status until
  "completed" before adding the file to a knowledge base
  (POST /api/v1/knowledge/{id}/file/add) - adding a still-processing file
  returns 400 (empty content). SSE stream variant supported.
- Retrieval endpoints (retrieval.py router): GET /embedding, POST
  /embedding/update, GET /config, POST /config/update, POST /process/file,
  /process/text, /process/youtube, /process/web, /process/web/search,
  /process/files/batch, POST /query/doc, POST /query/collection, POST
  /delete, /reset/db, /reset/uploads. /query/collection accepts
  {collection_names, query, k, k_reranker, r, hybrid, hybrid_bm25_weight,
  enable_enriched_texts} and validates collection access per user.
- ENABLE_KB_EXEC (bool, default False): optional shell-style knowledge
  access tool (ls/tree/cat/head/tail/sed/grep/find/wc/stat with pipes),
  native-mode only, replaces per-purpose file tools; caps via
  KB_EXEC_MAX_OUTPUT_CHARS (30000), KB_EXEC_MAX_GREP_FILES (200),
  KNOWLEDGE_GREP_MAX_MATCHES (50).
- OPENWEBUI_DATA_DIR is a SCRIPT-INVENTED var (query_rag.py L134-138) -
  NOT a server env var. The server uses DATA_DIR (default ./data). This
  mismatch is a root cause of the broken default on Linux (APPDATA empty).

---

## 7. Sources

Archived external sources (all accessed 2026-08-13; stored in
knowledge/res025-openwebui-rag-infra/sources/):

1. Open WebUI Documentation. "Retrieval Augmented Generation (RAG)."
   Open WebUI Docs, 13 Aug. 2026,
   https://docs.openwebui.com/features/chat-conversations/rag/.
   Archived: rag-features.md (290 lines).
2. Open WebUI Documentation. "API Endpoints." Open WebUI Docs, 13 Aug.
   2026, https://docs.openwebui.com/reference/api-endpoints. Archived:
   api-endpoints.md (486 lines).
3. Open WebUI Documentation. "Environment Variable Configuration." Open
   WebUI Docs, 13 Aug. 2026,
   https://docs.openwebui.com/reference/env-configuration. Archived:
   env-configuration.md (7,485 lines). Page header states it is current
   with release v0.11.0.
4. Open WebUI Documentation. "API Keys." Open WebUI Docs, 13 Aug. 2026,
   https://docs.openwebui.com/features/authentication-access/api-keys.
   Archived: api-keys.md (147 lines).
5. Open WebUI Documentation. "Reference." Open WebUI Docs, 13 Aug. 2026,
   https://docs.openwebui.com/reference/. Archived: reference-index.md
   (83 lines).
6. Open WebUI Documentation. "Open WebUI" (quick start), 13 Aug. 2026,
   https://docs.openwebui.com/. Archived: quick-start.md (101 lines).
7. open-webui/open-webui. "backend/open_webui/routers/retrieval.py" (main
   branch). GitHub, 13 Aug. 2026,
   https://raw.githubusercontent.com/open-webui/open-webui/main/backend/open_webui/routers/retrieval.py.
   Archived: retrieval-router-src.md (2,862 lines, full Python source).
8. open-webui/open-webui. "CHANGELOG.md" (main branch). GitHub, 13 Aug.
   2026, https://github.com/open-webui/open-webui/blob/main/CHANGELOG.md.
   The blob page is JS-rendered and yielded only the GitHub nav frame
   (changelog-blob.md, 190 lines); the authoritative content was archived
   from the raw file equivalent, https://raw.githubusercontent.com/
   open-webui/open-webui/main/CHANGELOG.md -> changelog-raw.md (5,271
   lines; head entry [0.11.0] - 2026-07-27).

Local ground-truth files (read directly, NOT archived per dispatch):
.opencode/skills/book-rag/SKILL.md, knowledge-bases.yaml,
.opencode/scripts/query_rag.py, test_query_rag.py, query_web.py,
.opencode/commands/rag.md, .opencode/opencode.jsonc (command block),
.opencode/oh-my-opencode-slim.jsonc (book-rag arrays),
docs/dev-infra-audit/tickets/DIA-089-book-rag-skill-openwebui.md,
.opencode/memory-shelf.yaml, .opencode/CHANGELOG.md,
.opencode/learnings/external-patterns/2026-08-11-skill-location-precedence-risk.md,
/mnt/c/Users/qualt/AppData/Roaming/open-webui/data/ (directory listing;
.key existence and size only - secret value never read).

---

## 8. Claim-to-source mapping

| Claim | Source of verification |
|-------|-----------------------|
| A. Hybrid BM25 + CrossEncoder rerank via ENABLE_RAG_HYBRID_SEARCH | Archived env-configuration.md L3333-3338, L3387-3392; rag-features.md "Enhanced RAG Pipeline" section; retrieval-router-src.md L2592-2617 (query_collection_with_hybrid_search wiring) |
| B. RAG_TEXT_SPLITTER=markdown_header removed; ENABLE_MARKDOWN_HEADER_TEXT_SPLITTER default True | Archived env-configuration.md L3499-3508 (explicit migration note) |
| C. CHUNK_SIZE 1000 / CHUNK_OVERLAP 100 / CHUNK_MIN_SIZE_TARGET 0 (docs recommend 1000 target) | Archived env-configuration.md L3460-3479; rag-features.md L63-151 (merging algorithm, >90% chunk reduction example) |
| D. Embedding-model change requires re-index; re-index deletes/re-chunks/re-embeds; chat files not covered | Archived rag-features.md L155-187 |
| E. TOP_K / RELEVANCE_THRESHOLD / HYBRID_BM25_WEIGHT / TOP_K_RERANKER config surface | Archived env-configuration.md L3312-3331, L3387-3392; retrieval-router-src.md L341-363 (config key map) |
| F. ENABLE_PERSISTENT_CONFIG=True default, DB overrides env | Archived env-configuration.md L559-566 |
| G. DATA_DIR / WEBUI_SECRET_KEY / WEBUI_JWT_SECRET_KEY "deprecated" | PARTIAL: WEBUI_JWT_SECRET_KEY deprecated (legacy alias) confirmed env-configuration.md L2114; WEBUI_SECRET_KEY is the current standard and now a hard requirement for direct-uvicorn startup (changelog-raw.md L691) - NOT deprecated; no explicit DATA_DIR deprecation marker found in the archive. Flag per DIA-072: the blanket "deprecated" phrasing is researcher-supplied-not-fully-archived; the accurate reading is "WEBUI_JWT_SECRET_KEY deprecated in favor of WEBUI_SECRET_KEY" |
| H. Bearer sk- + JWT + x-api-key auth | Archived api-endpoints.md L118, L174; api-keys.md L98, L131 |
| I. File ingestion process=true + wait completed before KB add (400 empty content) | Archived api-endpoints.md L301-345 (endpoint, status polling, 400-on-empty, SSE stream) |
| J. POST /api/v1/retrieval/query/collection endpoint + form schema + access validation | Archived retrieval-router-src.md L2574-2635 |
| K. RAG_EMBEDDING_MODEL / RAG_RERANKING_MODEL + engines | Archived env-configuration.md L3300-3310, L3705-3738 |
| L. KB discovery GET /api/v1/knowledge/ + SQLite webui.db fallback | Local file query_rag.py L344-386, L497-551 (script behavior; endpoint not documented in archived api-endpoints.md beyond /knowledge/{id}/file/add) |
| M. k:6 client default, hybrid:true client default, 20s timeout, [WARNING] < 0.30 | Local file query_rag.py L128-147, L1010-1018 |
| N. SKILL.md L354 API-key claim FALSE (env var unset) | Local file SKILL.md L354 + DIA-089 ticket verification FAIL (env unset, server down) |
| O. KB cache stale 2026-07-13, 12 UUIDs | Local file knowledge-bases.yaml (cached_at line 1, 12 kbs entries) |
| P. Skill registered in 10 agent skill arrays | Local file oh-my-opencode-slim.jsonc (book-rag at L35, 126, 141, 216, 271, 297, 331, 438, 492, 514) |
| Q. commands/rag.md NOT in opencode.jsonc command block | Local files: .opencode/commands/rag.md exists; opencode.jsonc L615-636 command block has no rag entry |
| R. Global book-rag copy ABSENT; memory-shelf deletion description contradicts applied change | Local files: ~/.config/opencode/skills/ listing (no book-rag); memory-shelf.yaml L473-492 vs CHANGELOG.md L103 (global deleted, project kept) |
| S. Real Windows data dir exists, .key 128 bytes | Local filesystem listing of /mnt/c/Users/qualt/AppData/Roaming/open-webui/data/ (existence + size only) |
| T. Server not running / env vars unset | DIA-089 ticket verification FAIL 2026-08-11 (ss scan + printenv); not re-probed in this conspecter run |
| U. OPENWEBUI_DATA_DIR is script-invented (not a server var) | Local file query_rag.py L134-138 vs archived env-configuration.md (DATA_DIR only, L920-924) |
| V. v0.11.0 current release, changelog head [0.11.0] - 2026-07-27 | Archived changelog-raw.md L8; env-configuration.md L7 (page current with v0.11.0) |

DIA-072 discipline notes: (1) the blob CHANGELOG URL itself yielded only
nav content; the full changelog was archived from the raw equivalent URL
and the substitution is documented (Section 7, source 8). (2) Claim G's
blanket "deprecated" phrasing for DATA_DIR/WEBUI_SECRET_KEY is recorded
as researcher-supplied with the accurate archive-supported reading. (3)
No .key secret value appears anywhere in this conspect.
