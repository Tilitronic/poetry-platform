# OpenCode Configuration Review — 2026-07-12

**Sources consulted:**
- OpenCode `/docs/agents/` (fetched 2026-07-10)
- OpenCode `/docs/skills/` (fetched 2026-07-10)
- OpenCode `/docs/rules/` (fetched 2026-07-10)
- OpenCode `/changelog` (v1.17.0–v1.17.18)
- `agents.md/` homepage
- GitHub Copilot pricing (fetched fresh)
- `oh-my-opencode-slim/knowledge/opencode-best-practices.md` (curated mid-2026)
- `oh-my-opencode-slim/knowledge/ai-assist-sources.yaml`
- book-rag queries against #csc (Anthropic agent design blog posts not found in any RAG KB)

---

## 🔴 HIGH — Documented claims vs actual config mismatches

### Finding 1: Triple inconsistency on ai-assist-specialist's use of book-rag

| Source | Claim about book-rag |
|--------|----------------------|
| `AGENTS.md:112` | "Skills: teaching, book-rag" and "Tier 1 (stable Anthropic engineering blog → book-rag)" |
| `agents/ai-assist-specialist.md` frontmatter | `skills: [teaching, book-rag]` |
| `omo.jsonc` cebula preset:187-189 | `skills: ["teaching", "websearch"]` — **NO book-rag** |
| `omo.jsonc` specialist prompt:332 | "Does NOT use book-rag" |

**Reality:** The Anthropic blog articles ARE NOT indexed in any of the 12 RAG KBs. So even if book-rag were assigned, it wouldn't find them.

**Delta:** Three different claims about the same capability, all contradicting each other. The specialist uses `opencode-best-practices.md` (local file) and fresh web fetches instead.

**Options:**
1. Add the 10 Anthropic blog URLs to a new RAG KB (e.g., `anthropic-agent-design`), then consistently assign `book-rag` everywhere
2. Update all three files to say the specialist uses `opencode-best-practices.md + fresh web fetches` instead of book-rag
3. Remove book-rag from the markdown frontmatter and AGENTS.md, keeping only `teaching` + implicit web fetch ability

---

### Finding 2: AGENTS.md claims 3 telemetry plugins but only 1 is installed

**Best practice (AGENTS.md Section 5):** Lists `opencode-telemetry`, `opencode-token-monitor`, and `opencode-subagent-output` as "three passive plugins providing cross-session observability"

**Current config (`opencode.jsonc:139-146`):**
```json
"plugin": [
  "envsitter-guard",
  "opencode-subagent-output",
  "opencode-plugin-openspec",
  "opencode-snip",
  "opencode-dynamic-context-pruning",
  "oh-my-opencode-slim"
]
```

Only `opencode-subagent-output` is present. The other two are missing entirely.

**Options:**
1. Install the two missing plugins if they exist as installable packages
2. Remove them from AGENTS.md if they're aspirational or deprecated
3. Add a note that they're planned but not yet installed

---

### Finding 3: openspec-plan agent missing from opencode-go preset

**Best practice (AGENTS.md Section 4):** Spec-driven workflow chain: feature-interviewer → OpenSpec Architect → tdd-craftsman — relies on `openspec-plan` agent.

**Current config:**
- `cebula` preset: defines `openspec-plan` with `model: opencode-go/qwen3.7-plus` ✓
- `opencode-go` preset: **NO openspec-plan entry** ✗

**Delta:** Anyone using the `opencode-go` preset can't run the spec-driven workflow without switching presets. The orchestrator prompt lists this workflow as standard.

**Options:**
1. Add `openspec-plan` to the opencode-go preset (same model: `qwen3.7-plus`)
2. Document in AGENTS.md that the spec workflow requires the `cebula` preset

---

## 🟡 MEDIUM — Config quality and documentation gaps

### Finding 4: observer agent has zero documentation

**Current config:**
- Present in both `opencode-go` preset (model: `kimi-k2.6`, medium) and `cebula` preset (model: `gpt-5-mini`, low)
- No entry in AGENTS.md
- No markdown file in `agents/` directory
- No displayName rewiring in OMO config

**Delta:** Users of this system have no way to know what `observer` does or when to delegate to it.

**Options:**
1. Add a section to AGENTS.md documenting observer's purpose, delegation rules, and model rationale
2. Create `agents/observer.md` with frontmatter and instructions
3. Add displayName mapping (e.g., `"observer" -> "code_observer"`)

---

### Finding 5: gigabuild temperature (0.3) conflicts with deterministic refactoring role

**Best practice (OpenCode docs, Anthropic engineering):** For deterministic planning work (code generation, refactoring), temperature should be 0.0–0.2. Higher temperatures introduce unwanted randomness.

**Current config:**
- `agents/gigabuild.md`: `temperature: 0.3`, model: `qwen3.7-plus`
- `build` primary agent: `temperature: 0.1` — consistent with best practice
- gigabuild is described as "highly decoupled, modular code" — deterministic work

**Delta:** 0.3 vs recommended 0.0–0.2.

**Options:**
1. Lower to 0.1 (matches `build` agent for consistency)
2. Lower to 0.2 (slightly more variety but still deterministic enough)

---

### Finding 6: council has weak councillor adding cost without proportional value

**Current config (omo.jsonc:341-362):**
5 parallel councillors: deepseek, gemini-3-flash, gemini-2.5-pro, gpt-4o-mini, qwen-max

**Issue:** `gpt-4o-mini` is the weakest model in the council. No documented SWE-bench score in the model compendium. It adds:
- Additional token cost (5 parallel calls)
- Additional timeout/retry risk
- No uniquely valuable perspective (gemini-3-flash already covers "fast" slot)

**Options:**
1. Remove gpt-4o-mini from the default council preset (4 councillors is sufficient)
2. Replace with a model that provides a genuinely different perspective (e.g., a local Ollama model, or a different provider)
3. Keep but document that it's the cost-efficiency option

---

### Finding 7: gigaplan agent missing bash permission denial

**Best practice (OpenCode `/docs/agents/`):** Read-only agents should have both `edit: deny` AND `bash: deny` for defense-in-depth. Bash access could be used to exfiltrate data or modify files indirectly.

**Current config (`agents/gigaplan.md`):**
```yaml
permission:
  edit: deny
```
No `bash: deny` — bash defaults to whatever the global/default permission is.

**Delta:** A read-only architect agent could potentially run bash commands.

**Options:**
1. Add `bash: deny` to gigaplan.md
2. Or be explicit: `bash: ask` if there's a legitimate use case (e.g., running analysis tools)

---

### Finding 8: AGENTS.md is 282 lines vs recommended 20–50 lines

**Best practice (`opencode-best-practices.md`):** "Keep concise: Start 20-50 lines. Revisit weekly."

**Current config:** `AGENTS.md` is 282 lines — 5–14× the recommended length.

**Delta:** Longer files are less likely to be read fully, more likely to contain stale information (as confirmed by Findings 1–3).

**Options:**
1. Split into nested files: `AGENTS.md` (core standards, 20-50 lines) + references to sub-files for specific topics
2. Keep but add a "Last reviewed" date and weekly review mechanism
3. Remove agent documentation that lives in the config anyway (agent sections duplicate what's in `omo.jsonc` displayName prompts)

---

## 🟢 Minor observations

### Finding 9: `web: allow` permission may be legacy shorthand

`agents/ai-assist-specialist.md` uses `web: allow` but OpenCode docs (Jul 2026) document `webfetch` and `websearch` as separate permission keys. May be accepted as shorthand — worth verifying against latest schema.

### Finding 10: Council councillor naming mismatch

Council preset defines `"qwen-max": { "model": "opencode-go/qwen3.7-plus" }` — the key name says "qwen-max" but the model is `qwen3.7-plus`. Minor but confusing.

### Finding 11: gemini-2.5-pro missing `apply` role

Has only `chat` + `edit` roles, no `apply`. May be intentional (model doesn't support it), but worth documenting why if so.

### Finding 12: Inconsistent capitalization in AGENTS.md

AGENTS.md writes `@Designer` (capital D) while all other agent mentions use `snake_case` (`@code-navigator`, `@web_scout`, etc.). Inconsistent.

### Finding 13: No weekly review mechanism for AGENTS.md

Best practice recommends weekly review. No mechanism exists.

### Finding 14: All 12 skill directories present

book-rag, clonedeps, codemap, deepwork, git-diff, oh-my-opencode-slim, reflect, release-smoke-test, simplify, tdd-craftsman, teaching, worktrees — all present, no obvious gaps. ✓

### Finding 15: Plugin split is intentional and correct

6 plugins in `opencode.jsonc` (full surface), only OMO in `tui.json` (TUI surface). This is correct architecture. ✓

### Finding 16: free preset is well-structured

Complete fallback preset with sensible model downgrades for cost-limited scenarios. ✓

### Finding 17: Temperature settings are mostly correct

All agents within 0.1–0.3 range, which aligns with best practices. Only gigabuild (0.3) is borderline. ✓

### Finding 18: Permission scoping is generally correct

Read-only agents (council, councillor, gigaplan) have the right basic permissions. Only gigaplan missing `bash: deny` (Finding 7). ✓

### Finding 19: Council configuration is reasonable

Parallel mode, 300s timeout, 2 retries — all within sensible ranges. ✓

---

## Summary

| Severity | Count | Key items |
|----------|-------|-----------|
| 🔴 HIGH | 3 | book-rag inconsistency, missing telemetry plugins, missing openspec-plan |
| 🟡 MEDIUM | 5 | undocumented observer, gigabuild temperature, weak councillor, gigaplan bash, AGENTS.md length |
| 🟢 Minor | 7 | web shorthand, naming, roles, capitalization, review cadence |

The configuration is **well-structured overall** — model assignments follow guidelines, permissions are generally correct, and the skills/council/provider setups are sound. The most actionable items are resolving the three documentation-vs-config mismatches in Findings 1–3, which erode trust in AGENTS.md as an authoritative source.
