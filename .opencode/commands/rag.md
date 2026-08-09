---
description: >-
  Query local textbooks via OpenWebUI RAG. You (the agent) redesign the
  query for effective retrieval, pick the right KB, and run the search.
  The user shouldn't need to remember #tag names. Supports flags:
  --list, --route, --refresh, --books, --stats.
agent: coder
---

# RAG query

**Your job: redesign → route → run. Don't just pass through the query.**

## Available knowledge bases

| Tag | Contents |
|-----|----------|
| `#csc` | Core CS: OOP, algorithms, data structures, programming concepts |
| `#js` | JavaScript, TypeScript, web development, Node, React |
| `#python` | Python language, libraries, idioms |
| `#rust` | Rust language, borrow checker, systems programming |
| `#ml` | Machine learning, AI, neural networks, statistics |
| `#datamanagement` | Databases, SQL, data modeling |
| `#dsboinf` | Data science, bioinformatics |
| `#analytical` | Reasoning, analytical frameworks, sensemaking |
| `#visualization` | Data viz: D3, ggplot, charts, plotting |
| `#teaching` | Pedagogy, mental models, learning theory |
| `#statistics and algebra` | Statistics, linear algebra, probability |
| `#ppartreception` | Psychophysiology of art perception |

## Routing rules

- If `$ARGUMENTS` starts with `--`: pass through as-is (flag).
- If `$ARGUMENTS` starts with `#`: pass through as-is (user chose KB).
- **Otherwise**: follow the workflow below.

## Workflow

### 1. Redesign the query
Rewrite the user's question into a keyword-dense search query:
- Strip conversational filler ("how do I", "tell me about", "what is")
- Extract key technical terms and concepts
- Add synonyms for better retrieval

### 2. Route to KB(s)
Pick the best KB using semantic understanding. Use multiple KBs for
cross-cutting topics. Example: "visualize ML model performance" →
query `#ml` for ML content + `#visualization` for visualization techniques.

### 3. Execute and synthesize
Run `python3 .../query_rag.py "#tag <redesigned query>"` for each KB.
If multiple KBs, synthesize results. Cite source books.

## Script call

```bash
python3 .opencode/scripts/query_rag.py "$ARGUMENTS"
```

## Examples

| User types | You redesign to | Route | You run |
|---|---|---|---|
| `rag TypeScript generics` | `"TypeScript generics constraints extends"` | `#js` | `python3 .../query_rag.py "#js TypeScript generics constraints extends"` |
| `rag how to handle errors in Rust` | `"Rust error handling Result Option propagation"` | `#rust` | `python3 .../query_rag.py "#rust Rust error handling Result Option propagation"` |
| `rag compare Python and Rust concurrency` | `"Python async await concurrency"` + `"Rust async tokio concurrency"` | `#python` + `#rust` | Run both queries, synthesize |
| `rag --list` | — | — | `python3 .../query_rag.py --list` |
| `rag #rust lifetimes` | (user chose) | `#rust` | `python3 .../query_rag.py "#rust lifetimes"` |
