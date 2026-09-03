# Human-Readable Session Identifiers for OpenCode

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 10
phase-a-failures: 1
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

## Problem Statement

OpenCode session identifiers use hex short-id suffixes (e.g., `session-a3f2`). These are opaque and hard to distinguish in terminal titles, session lists, and handoff logs. The goal is a human-readable label that is memorable, pronounceable, and collision-resistant at the scale OpenCode operates (tens to low hundreds of concurrent sessions).

## Candidates Evaluated

### 1. Docker Name Generator (adjective_surname)

**Source:** [docker-names-generator.md] (GitHub: moby/moby, Apache-2.0, frozen)

Docker assigns container names using `<adjective>_<surname>` from curated lists: ~100 adjectives (admiring, focused, zen) and ~350 notable scientists/hackers (turing, lovelace, knuth). The combination space is 100 x 350 = ~35,000 unique names. A birthday-problem analysis shows ~1.4% collision probability at 1,000 concurrent sessions (docker-names-generator.md, "Combinations"). The list is frozen -- no new entries accepted -- which is a strength for stability but means the namespace is fixed permanently.

**Strengths:** Proven at Docker scale, memorable ("focused_turing"), pronounceable, collision-free below ~500 sessions for practical purposes.
**Weaknesses:** Fixed namespace, no seed support, Go implementation (not directly consumable from Node.js/TypeScript), underscore separator is less conventional than hyphen for URL/terminal use.

### 2. unique-names-generator (npm)

**Source:** [github-andreasonny83-unique-names-generator.md], [npm-unique-names-generator.md], [unique-names-generator.json]

MIT-licensed, zero dependencies, 686 GitHub stars, 490K weekly downloads, 14,080 dependents (unique-names-generator.json, "stats"). The package provides built-in dictionaries: adjectives (1,400+), animals (350+), colors (50+), countries (250+), names (4,900+), languages, starWars (80+), plus a NumberDictionary for numeric suffixes (github-andreasonny83-unique-names-generator.md, "Dictionaries Available"). Total combinations exceed 50,000,000 out of the box (npm-unique-names-generator.md, "Key Stats").

The critical feature for session IDs is **deterministic seed support**: passing the same seed always produces the same name (github-andreasonny83-unique-names-generator.md, "Key Features"). This enables reproducible session labels from session UUIDs without storing the label separately. Configuration supports separator, length (2-3 words), and style (lowerCase/upperCase/capital) (npm-unique-names-generator.md, "Features").

```typescript
import { uniqueNamesGenerator, Config, adjectives, animals } from 'unique-names-generator';

const config: Config = {
  dictionaries: [adjectives, animals],
  separator: '-',
  length: 2,
  seed: sessionId,  // deterministic from session UUID
};
const label = uniqueNamesGenerator(config); // "continuous-gray-dragonfly"
```

**Strengths:** Mature, zero deps, TypeScript built-in, seed for determinism, configurable, 50M+ namespace.
**Weaknesses:** Last published 2022-02-16 (npm-unique-names-generator.md, "Last publish"), though the API is stable and feature-complete.

### 3. humanhash (JS port and Python original)

**Source:** [github-SEBv15-humanhash.md], [github-zacharyvoase-humanhash.md], [humanhash.json]

The Python original (zacharyvoase/humanhash, 868 stars) compresses any input digest to 4 bytes (default), then maps each byte to a word from a predefined wordlist (github-zacharyvoase-humanhash.md, "How It Works"). The JS port (SEBv15/humanhash, 5 stars, 7 commits) mirrors this algorithm. Uniqueness is ~1 in 4.3 billion (2^32) -- adequate for display but not for persistent identification (humanhash.json, "features.uniqueness").

**Strengths:** Deterministic, well-known algorithm, works on any input digest.
**Weaknesses:** The JS port depends on `uuid` (^3.3.2) and has only 5 stars / 7 commits (humanhash.json, "stats"), making it a maintenance risk. Uniqueness is hard-capped at 2^32. Output words are from a fixed wordlist (NATO phonetic-style), producing labels like "three-georgia-xray-jig" that are less memorable than Docker-style names.

### 4. moniker

**Source:** [moniker.json]

Very old package (created 2011), minimal documentation, 80 dependents, unknown license, no repository metadata (moniker.json). Generates random names but with no seed support, no TypeScript, and no active maintenance.

**Verdict:** Disqualified -- unmaintained, no seed, no TS support.

### 5. didyoumean

**Source:** [didyoumean.json]

Levenshtein distance matching engine, not an ID generator (didyoumean.json, "readme_summary"). Could serve as a complementary utility for fuzzy-matching session names when a user mistypes, but does not solve the naming problem itself.

**Verdict:** Not a candidate for session ID generation; tangentially useful for session lookup UX.

### 6. random-word-slugs

**Source:** [random-word-slugs.json]

Generates kebab-case slugs from categorized word lists (adjective + noun), 30M+ default combinations, configurable word count, multiple formats (random-word-slugs.json, "features"). Zero dependencies, TypeScript support, MIT licensed.

**Strengths:** Good combination space, category-aware (adjective + noun produces readable labels).
**Weaknesses:** No seed/determinism support (random-word-slugs.json, "features" -- no seed option listed). Lower adoption (33 dependents vs. 14K for unique-names-generator).

**Verdict:** Plausible alternative but lacks determinism, which is important for reproducible session labels.

## Comparative Analysis

| Criterion | Docker-style | unique-names-generator | humanhash | random-word-slugs |
|---|---|---|---|---|
| Combination space | 35K | 50M+ | 4.3B | 30M+ |
| Deterministic seed | No | Yes | Yes (from digest) | No |
| Zero dependencies | N/A (Go) | Yes | No (uuid) | Yes |
| TypeScript support | No | Yes | No | Yes |
| Maintenance | Frozen (stable) | Stable (2022) | Low (5 stars) | Active (33 deps) |
| Memorability | High | High | Medium | High |
| Separator options | Underscore only | Configurable | Hyphen | Configurable |

## EBDV: Decision Variants

### Variant A -- unique-names-generator with seed (Recommended)

Use `unique-names-generator` with `[adjectives, animals]` dictionaries, hyphen separator, length 2, and `seed: sessionId` (UUID-derived numeric). Deterministic: same session always gets the same label. 50M+ namespace is far beyond OpenCode's scale. Zero deps, TypeScript native.

**Evidence:** 686 stars, 490K weekly downloads, 14K dependents (unique-names-generator.json). Seed support confirmed in README and API docs (github-andreasonny83-unique-names-generator.md, "Key Features"; npm-unique-names-generator.md, "Features").

**Effort:** Low -- single npm install, ~15 lines of wrapper code.
**Risk:** Last published 2022, but API is stable and feature-complete.

### Variant B -- Docker-style adjective_surname (inline)

Implement Docker's algorithm directly: two hardcoded arrays (~100 adjectives, ~350 surnames), seeded PRNG for determinism. ~35K namespace is adequate for OpenCode's scale. No dependency, full control.

**Evidence:** Algorithm documented in docker-names-generator.md with exact word lists. Collision at 1,000 sessions is ~1.4% (birthday problem analysis).

**Effort:** Medium -- ~50 lines including the word arrays. Must maintain the lists manually.
**Risk:** Smaller namespace (35K vs. 50M), no ecosystem/community, frozen lists.

### Variant C -- humanhash (deterministic digest mapping)

Use humanhash to map session UUIDs to 4-word labels. Unlimited input space, deterministic.

**Evidence:** Algorithm documented in github-zacharyvoase-humanhash.md (868 stars on Python original). JS port at 5 stars (github-SEBv15-humanhash.md).

**Effort:** Low -- single dependency.
**Risk:** JS port depends on `uuid`, only 5 stars, 7 commits. Fixed wordlist produces less memorable names ("three-georgia-xray-jig").

### Variant D -- random-word-slugs (no seed)

Use random-word-slugs for 3-word category-aware labels.

**Evidence:** 30M+ combinations, zero deps (random-word-slugs.json).

**Effort:** Low.
**Risk:** No determinism -- same session could get different labels across restarts unless the label is stored separately.

### Variant E -- Abort (status quo)

Keep hex short-id suffixes. No change.

**Evidence:** Current system works; hex IDs are unambiguous.
**Risk:** Continues to produce opaque labels that are hard to distinguish in session lists and terminal titles.

## Recommendation

**Variant A: unique-names-generator with seed.** Because it provides the best combination of determinism (seed from session UUID), combination space (50M+), zero dependencies, TypeScript support, and ecosystem maturity (14K dependents, 490K weekly downloads). The seed means no additional storage is needed -- the label is always derivable from the session ID. The wrapper is trivial (~15 lines). Variant B (inline Docker-style) is the fallback if dependency addition is undesirable, but the smaller namespace and manual list maintenance make it strictly worse.

## Unarchived/Excluded Sources

| Source | Reason |
|---|---|
| https://www.npmjs.com/package/random-word-slugs | HTTP 403 Forbidden -- all fetch methods exhausted. Registry JSON (`random-word-slugs.json`) captured the data instead. |

## Works Cited

- "docker-names-generator." GitHub: moby/moby, `internal/namesgenerator/names-generator.go`. Apache-2.0. Web.
- "unique-names-generator." npm registry, v4.7.1, 2022. Web.
- "unique-names-generator." GitHub: andreasonny83/unique-names-generator. MIT. Web.
- "humanhash." npm registry, v1.0.4. Web.
- "humanhash." GitHub: SEBv15/humanhash. Unlicense. Web.
- "humanhash." GitHub: zacharyvoase/humanhash. Unlicense. Web.
- "moniker." npm registry, v0.1.2, 2011. Web.
- "didyoumean." npm registry, v1.2.2. Web.
- "random-word-slugs." npm registry, v0.1.7. Web.
