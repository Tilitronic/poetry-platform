---
name: book-rag
description: >-
  OPT-IN ONLY. Query local engineering textbooks via OpenWebUI hybrid RAG.
  Only activates when user explicitly uses #rag or #tag syntax.
compatibility: opencode
metadata:
  audience: developers
  workflow: knowledge-retrieval
---

## Activation Rule — CRITICAL

**This skill is OPT-IN only.** Do NOT invoke it unless the user explicitly
uses one of these trigger patterns:

| Trigger                        | Example                                          |
|--------------------------------|--------------------------------------------------|
| `#rag` keyword                 | `"#rag explain polymorphism"`                    |
| `#tag` (known KB)              | `"closures in JavaScript #js"`                   |
| Asking about books/KBs         | `"what books are in #csc?"`                      |
| `--list` / `--books` / `--stats` | `"list all knowledge bases"`                   |

A plain question like `"explain polymorphism"` or `"what is a monad"`
must **NOT** trigger this skill. Answer from your own knowledge or use
the native websearch capability.

---

## What This Skill Does (when explicitly invoked)

Extract domain context using OpenWebUI's hybrid BM25+vector search and
BGE-Reranker-v2-m3 cross-encoder. Supports two trigger modes:

- **`#tag`** — query a specific knowledge base directly
- **`#rag`** — auto-select relevant KB(s) based on topic analysis

The backing script (`.opencode/scripts/query_rag.py`) discovers
knowledge bases **dynamically at runtime** — no hardcoded UUIDs needed.

Prefer the `@rag` opencode command (registered in opencode.json) instead
of calling the script directly. Use direct bash calls only when the command
is unavailable or you need flags like `--list` / `--books` / `--stats`.

---

## Workflow: Redesign → Route → Execute

When the user asks a question with `#rag` or `#tag`, follow this
three-phase workflow:

### Phase 1: Redesign the query

Take the user's raw question and rewrite it into **effective search
queries** optimized for embedding-based retrieval:

**What to do:**
- Strip conversational filler ("how do I", "tell me about", "what is")
- Extract key technical terms and concepts
- Add synonyms and related terms
- Consider splitting complex questions into sub-queries

**Examples:**

| Raw question | Redesigned search query |
|---|---|
| "How do I handle errors in Rust?" | `Rust error handling Result Option unwrap error propagation patterns` |
| "Tell me about closures in JavaScript" | `JavaScript closures lexical scope capture variables callback` |
| "What's the difference between an interface and a type in TypeScript?" | `TypeScript interface vs type alias comparison differences usage` |

### Phase 2: Route to knowledge base(s)

Using the KB table below, decide which KB(s) to target:

- **Single topic** → one KB: *"gradient descent"* → `#ml`
- **Cross-cutting topic** → multiple KBs: *"visualize ML model performance"* → `#ml` + `#visualization`
- **Comparison** → both KBs: *"Python vs Rust concurrency"* → `#python` + `#rust`

When routing, use your semantic understanding — you can match concepts
that keyword matching would miss (e.g., "TypeScript" → `#js`,
"gradient descent" → `#ml`).

If unsure about available KBs, run `rag --list` first.

### Phase 3: Execute search(es)

For each selected KB:
1. **Scope the query** to the KB's domain — add context that helps
   retrieval focus on the right content
2. **Run** `rag #tag "scoped query"`
3. **Collect results** with source book titles and relevance scores

**Example (cross-KB):**

```
User: "Compare Python and Rust error handling patterns"

Phase 1 → redesigned queries:
  Query A: "Python exception handling try except best practices"
  Query B: "Rust error handling Result Option propagation patterns"

Phase 2 → routes:
  Query A → #python
  Query B → #rust

Phase 3 → execute:
  python3 .opencode/scripts/query_rag.py "#python Python exception handling try except best practices"
  python3 .opencode/scripts/query_rag.py "#rust Rust error handling Result Option propagation patterns"
```

Finally, **synthesize** results from all KBs — group related facts,
note contradictions, present a unified answer.

---

## Quick reference: `#tag` syntax

When the user includes an explicit `#tag` in their query (e.g.,
`"closures in JavaScript #js"`), skip Phases 1-2 and query that
KB directly. The `#tag` must be at the start of the query string
for the script to recognize it.

---

## KB Cache & Auto-Routing

The script maintains a persistent YAML cache of knowledge base metadata
at `knowledge-bases.yaml` in this skill folder.

- **Cache TTL:** 1 hour default (configurable via `RAG_CACHE_TTL` env var)
- **Cache indicator:** `--list` output shows `(cached, age: Xm)` or `(fresh)`
- **Force refresh:** `--refresh` to update after adding/renaming KBs in OpenWebUI
- **Degraded mode:** If OpenWebUI is unreachable, stale cache is used with a warning

```bash
rag --list --refresh         # Force refresh, then list
rag --refresh                # Refresh cache only
```

### Mode 3: Auto-routing with `--route`

When you're unsure which KB to query, let the script select the best match:

```bash
rag --route "gradient descent optimization"
# Output:
# #ml (score: 0.38) — machine learning
```

Routing uses keyword overlap scoring against KB descriptions. It's a fast
heuristic — if it returns no match, use `--list` to discover KBs manually
or fall back to global search (no #tag).

### Mode 4: Auto-routing via `#rag` keyword

When the user says `#rag <topic>`, the agent should:

1. Run `rag --route "<topic>"` to find matching KB(s)
2. If matches found → query each: `rag #tag "<query>"`
3. If no match → ask user: internet search or query all KBs?

This replaces manual KB analysis — it saves tokens and avoids stale
metadata in agent memory.

---

## Available Knowledge Bases

Knowledge bases are discovered **dynamically at runtime** from OpenWebUI
and cached locally. Run this for the current list:

```bash
python3 .opencode/scripts/query_rag.py --list
```

**Cache source** (not hardcoded — always verify with `--list`):

| Tag                    | Contents                                                |
|------------------------|---------------------------------------------------------|
| `#csc`                 | Core computer science and programming concepts          |
| `#js`                  | Core JS/TS language knowledge, core web programming     |
| `#python`              | Core Python language knowledge                          |
| `#rust`                | Core Rust programming language knowledge                |
| `#ml`                  | Machine learning textbooks                              |
| `#datamanagement`      | Databases, SQL                                          |
| `#dsboinf`             | Data science and bioinformatics                         |
| `#analytical`          | Core reasoning, analytical and sensemaking frameworks   |
| `#visualization`       | Core data and analysis visualization knowledge          |
| `#teaching`            | Best teaching approaches                                |
| `#statistics and algebra` | Core statistics and algebra                          |
| `#ppartreception`      | Psychophysiology of art perception                     |

> ⚠ **These may be stale** — KBs can be added/renamed in OpenWebUI at any
> time. Always prefer `--list` for ground truth.

### Listing books within a KB

```bash
python3 .opencode/scripts/query_rag.py --books #csc      # books in one KB
python3 .opencode/scripts/query_rag.py --books-all         # books in ALL KBs
python3 .opencode/scripts/query_rag.py --stats             # file counts per KB
```

---

## Relevance Score Interpretation

Every chunk returned by the RAG query includes a `score` (0.0–1.0) from the
BGE-Reranker-v2-m3 cross-encoder. Use these guidelines:

| Score Range | Meaning                                      | How to Use                                    |
|-------------|----------------------------------------------|-----------------------------------------------|
| 0.70–1.00   | Strong semantic match                        | Safe to use as ground truth                   |
| 0.30–0.69   | Moderate match — related but partial         | Use with corroboration; may need synthesis    |
| 0.00–0.29   | Weak match — tangentially related or noise   | **Do not treat as factual.** Verify or re-query |

**The script emits a `[WARNING]` line when the top score is below 0.30.**
If you see this warning, consider:
- Broadening the query (fewer domain-specific terms)
- Checking a different KB
- Falling back to web search

---

## Response Synthesis & Citation Format

When returning RAG-grounded answers to the user:

1. **Cite the source book** for each claim. Use inline format:
   ```
   According to *Grokking Algorithms* (Aditya Bhargava): [explanation]
   ```
   or for multi-source:
   ```
   - Closures capture their enclosing scope (*Effective TypeScript*, Vanderkam)
   - This differs from simple function pointers (*Programming Rust*, Blandy)
   ```

2. **Synthesize across chunks** — don't just dump 6 raw chunks.
   Group related facts, note contradictions, and summarize.

3. **Flag low-confidence results.** If the top score was < 0.30, preface with:
   ```
   [Note: these results have low relevance scores; verify before relying on them.]
   ```

4. **Handle multiple KB queries.** When the `#rag` flow queries 2+ KBs,
   combine results and deduplicate overlapping information. If KBs disagree,
   present both perspectives with their sources.

---

## Error Handling & Troubleshooting

| Script Output                                    | Likely Cause                      | Agent Action                                    |
|--------------------------------------------------|-----------------------------------|-------------------------------------------------|
| `Failed to connect to OpenWebUI at ...`         | Server is down or wrong URL       | Tell user: "OpenWebUI is not running. Start it or check OPENWEBUI_URL." |
| `OpenWebUI did not respond within 20s`          | Server overloaded or hung         | Retry once. If persists: "RAG is unavailable, use web search." |
| `Error: Unknown knowledge base '#foo'.`         | Typo in tag name                  | Run `--list` to show valid tags, suggest a correction. |
| `No relevant results met threshold`             | Query too narrow                  | Broaden the query or switch to global search. |
| `RAG search completed, no results`              | Topic not in any KB               | Use web search instead.                         |
| `[WARNING] Top relevance score is below 0.3`   | Weak semantic match               | See score interpretation table above.           |

---

## Decision Tree for Agents

```
User query received with #rag or #tag
│
├─ Contains explicit #tag at START?
│   ├─ YES → run: rag "#tag <query>" directly
│   └─ NO  → proceed to workflow below
│
├─ #rag workflow:
│   │
│   ├─ Phase 1 — REDESIGN
│   │   Rewrite user's question into effective search query(ies):
│   │   - Strip conversational filler
│   │   - Extract key technical terms
│   │   - Split into sub-queries for different angles
│   │
│   ├─ Phase 2 — ROUTE
│   │   Pick KB(s) using semantic understanding:
│   │   - Confident? → use that KB
│   │   - Spans topics? → use multiple KBs
│   │   - Unsure? → rag --list first
│   │   - No match? → ask user: internet or query all KBs?
│   │
│   ├─ Phase 3 — EXECUTE
│   │   For each KB:
│   │     1. Scope query to KB's domain
│   │     2. Run: rag #tag "<scoped query>"
│   │     3. Collect results with sources + scores
│   │
│   └─ SYNTHESIZE
│       Combine results across KBs, cite sources, note contradictions.
│
└─ All RAG search goes through OpenWebUI's BM25+vector+reranker.
    Nothing runs client-side.
```

---

## Core Execution Requirements

1. **Opt-in only.** Never invoke unless the user explicitly used `#rag`,
   `#tag`, or asked about available KBs / books.

2. **Always redesign the query** before searching. Raw user questions
   ("how do I handle errors in Rust?") perform worse than keyword-dense
   queries ("Rust error handling Result Option propagation patterns")
   for embedding-based retrieval. Don't skip this step.

3. **Route semantically, not by keyword matching.** You have semantic
   understanding — use it. "TypeScript" → `#js`, "gradient descent" →
   `#ml`, "ggplot" → `#visualization`. The `--route` flag is available
   but your own understanding is more reliable.

4. **Multi-KB when needed.** If the question spans domains, run separate
   scoped queries per KB rather than a global search. Global search
   should be a last resort.

5. **Scope each query to its KB.** For a `#python` query about web
   frameworks, include "Python" in the query terms; for `#csc` about
   the same concept, use general CS terms. The extra context helps the
   retriever focus.

6. **Synthesize across KBs.** When you queried multiple KBs, combine
   results, deduplicate, note contradictions, and cite sources.

7. **Cite source book names** in your response (see response synthesis
   section). Use inline format:
   ```
   According to *99 Bottles of OOP* (Metz): [explanation]
   ```

8. **Respect relevance scores.** Scores below 0.30 are weak — verify
   before citing. The script emits a `[WARNING]` line when the top
   score is below 0.3.

---

## Platform & Auth Notes

- **Any OS — use repo-root-relative path:** Always run from the repo root:
  ```bash
  python3 .opencode/scripts/query_rag.py "#csc OOP"
  ```
- **Linux / macOS:** Use `python3` and the relative path from the skill base:
  ```bash
  python3 ../../scripts/query_rag.py "#csc OOP"
  ```
- **Authentication:** The script supports two auth methods:
  1. **API key:** Set `OPENWEBUI_API_KEY` env var (not currently configured — developer must set this).
  2. **JWT auto-minting:** Reads OpenWebUI's `.key` file to forge an admin token (requires PyJWT).
  > ⚠ **Security:** JWT auto-minting reads the OpenWebUI signing key and
  > forges an admin token. Never use on multi-user or internet-exposed instances.

---

## New in This Version

| Feature                     | Description                                       |
|-----------------------------|---------------------------------------------------|
| `--books-all`               | List books across ALL knowledge bases at once     |
| `--stats`                   | Compact file-count summary per KB                 |
| Score warnings              | `[WARNING]` line when relevance < 0.30            |
| Tag-at-start enforcement    | `#tag` must be at beginning of query string       |
| No silent global fallback   | Unknown tag → explicit error (not auto-global)    |
| `--books` SQLite fallback   | Works even when KB files API endpoint is missing  |
| Reduced timeout             | Default 20s (down from 60s)                       |
