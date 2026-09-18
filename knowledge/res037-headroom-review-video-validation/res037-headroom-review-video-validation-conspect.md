# Headroom Review and Video Validation - Conspect (res037)

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 6
phase-a-failures: 6
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

Conspect for DIA-260821-8kpc (opencode-config, Medium, OPEN). Pure-synthesis
authoring: every claim below is grounded only in the locally archived sources
under `knowledge/res037-headroom-review-video-validation/sources/` plus the
reused res036 archive (read, not re-fetched). No network fetch was performed.
This conspect validates a community review of Headroom and checks whether two
YouTube videos confirm or contradict the project's prior finding (res036 /
DIA-183): Headroom's cache-preserving mode was project-measured to DRIFT the
frozen prefix on the opencode-go/DeepSeek path, so it is NOT a cache-friendlier
DCP replacement.

## 1. Research question and scope

- **Primary question**: Is the community review of Headroom largely valid, and
  do the two named YouTube videos (DIY Smart Code "I Tested Headroom: 96% Log
  Compression?"; AI Coding Daily "I Tried Headroom: Did It ACTUALLY Save
  Tokens?") confirm or contradict the res036 cache-drift finding?
- **Boundary**: The review's sub-claims are validated against Headroom's own
  vendor documentation (README, Limitations wiki) and the res036 cache-drift
  finding. The videos' spoken content could NOT be archived (see section 4 and
  Unarchived/Excluded), so their engagement with the cache axis is inferred
  from titles and channel topics only.
- **Decision under test**: whether to keep Headroom OFF as a cache-friendlier
  DCP replacement.

## 2. The community review is largely valid (5 of 6 sub-claims accurate)

Five of the review's sub-claims are confirmed by Headroom's own vendor
documentation:

1. **Reversible CCR (accurate).** Headroom's README states "Reversible (CCR) -
   originals are cached for retrieval on demand" and lists CCR as "reversible
   compression; LLM retrieves originals on demand" (source 3, lines 57, 373).
   The review's reversible-compression claim holds.
2. **<300-token auto-skip (accurate).** The Headroom Limitations doc confirms
   an auto-skip threshold: below 300 tokens the compression overhead exceeds the
   savings, so small payloads are passed through (source 6; manifest source 12).
   The review's "<300-token auto-skip" claim holds.
3. **Cross-agent memory (accurate).** The README advertises "Cross-agent memory
   - shared store across Claude, Codex, Gemini, Grok, auto-dedup" (source 3,
   line 54). The review's cross-agent-memory claim holds.
4. **Worth-it framing (accurate).** The README's value proposition - "compress
   everything your AI agent reads ... before it reaches the LLM. Same answers,
   fraction of the tokens" and "run AI coding agents daily and want savings
   without changing your code" (source 3, lines 41, 337) - supports the
   review's "worth it for heavy agent users" framing.
5. **Setup-friction framing (accurate).** The OpenCode integration docs show
   real setup friction: `headroom wrap opencode` starts a local proxy, writes a
   provider block, injects MCP tools, and requires `headroom unwrap` to revert
   (source 4, lines 6-33, 140). The review's "there is meaningful setup
   friction" framing holds.

## 3. The one material flaw: the 60-95% figure is a JSON-data benchmark, not coding-agent savings

The review's 60-95% token-savings figure is the single material inaccuracy.
Headroom's own README draws the distinction explicitly in one line:

> "60-95% fewer tokens (for JSON data), 15-20% fewer tokens (for coding
> agents)" (source 3, line 11).

The 60-95% range is Headroom's benchmark for JSON data workloads (the
"Proof" table shows 47-92% savings on code-search / SRE / triage / exploration
tasks, source 3, lines 139-144). For coding agents specifically, Headroom
states 15-20% - roughly 3x to 6x lower than the 60-95% headline. A review that
presents 60-95% as general coding-agent savings therefore overstates the
relevant number by a wide margin. This is a scope error in the review, not a
fabrication: the figure is Headroom's own, just misapplied to the wrong
workload class.

## 4. The two YouTube videos engage the TOKEN axis only - they neither confirm nor contradict the cache-drift finding

Both videos were characterized from their YouTube oEmbed records (title +
channel), which are the only archived artifacts; transcripts and descriptions
could not be captured (see Unarchived/Excluded, DIA-072):

- **Video 1** - "I Tested Headroom: 96% Log Compression?" by DIY Smart Code
  (source 1, `watch?v=7PMvZQjuuFk`). Title centers on log/token compression
  percentage.
- **Video 2** - "I Tried Headroom: Did It ACTUALLY Save Tokens?" by AI Coding
  Daily (source 2, `watch?v=IbBuU1s3ycs`). Title centers on whether tokens were
  actually saved.

Both titles address the **token-compression / token-savings axis** of Headroom.
Neither title references cache hits, KV-prefix preservation, or prefix-cache
drift. Because the transcripts could not be archived, we cannot directly verify
whether the spoken content touches the cache axis, but the available evidence
(titles + channel topics) indicates they stay on the token axis.

The res036 cache-drift finding is about a **different axis** - the provider
prefix-cache behavior of Headroom's cache-preserving mode on the
opencode-go/DeepSeek path. res036 (source 5, section 4) records the DIA-183 B1
spike: Headroom cache mode forwarded a compressed live-zone message at 202,503
bytes in turn N and the same logical message at 218,109 bytes (client-original)
in turn N+1, a byte divergence reproduced 3x, with a clean passthrough control.
That is a cache-axis measurement, independent of any token-savings claim.

**Conclusion on the videos**: they engage the token-compression axis only and
therefore neither confirm nor contradict the cache-drift finding. Their
existence does not weaken the res036 conclusion.

## 5. The decision to keep Headroom OFF as a cache-friendlier DCP replacement remains valid

- The review is 5/6 accurate, but its one flaw (60-95% misapplied to coding
  agents) is about token savings, not cache behavior - it does not touch the
  cache-drift evidence.
- The two videos address token compression only and do not engage the cache
  axis, so they add no evidence for or against the drift finding.
- The decisive evidence remains the res036 / DIA-183 B1 spike: Headroom's
  cache-preserving mode was project-measured to DRIFT the frozen prefix
  (202,503 -> 218,109 bytes, 3x) on the opencode-go/DeepSeek path, with the
  project's 50x cache-miss multiplier making the net cost effect strongly
  negative (source 5, sections 4 and 6).
- Therefore the prior verdict stands: Headroom is NOT a cache-friendlier DCP
  replacement on this project's opencode-go/DeepSeek path, and it should remain
  OFF. The ponytail ruleset (already active in the plugin array) remains the
  zero-cache-interaction alternative for token discipline.

## 6. Unarchived / Excluded sources

The following were provisioned in Phase A but NOT archived. Per the researcher's
manifest they are excluded from citation in the body (DIA-072 - all methods
attempted exactly once, no retry):

1. `youtube.com/api/timedtext?lang=en&v=7PMvZQjuuFk&kind=asr` - EMPTY response
   (legacy timedtext ASR endpoint returned no captions). [manifest source 3]
2. `youtube.com/api/timedtext?lang=en&v=IbBuU1s3ycs&kind=asr` - EMPTY response.
   [manifest source 4]
3. `yt-transcript.vercel.app/api/transcript?videoId=7PMvZQjuuFk` - HTTP
   "Payment required / DEPLOYMENT_DISABLED" (third-party service down).
   [manifest source 5]
4. `yt-transcript.vercel.app/api/transcript?videoId=IbBuU1s3ycs` - same,
   deployment disabled. [manifest source 6]
5. `trafilatura -u youtube.com/watch?v=7PMvZQjuuFk` (Tier 1) - no output;
   YouTube watch pages are JS-rendered. [manifest source 7]
6. `webfetch youtube.com/watch?v=7PMvZQjuuFk` (Tier 2) - returned only the
   YouTube consent/footer wall; no metadata/transcript. [manifest source 8]

Consequence: the videos' spoken content and descriptions could not be directly
verified. The characterization in section 4 rests on the archived oEmbed
title/channel records plus the DIA-072 exhaustion note
(`sources/transcript-NOT-ARCHIVED.md`), not on transcript text.

## 7. Works cited (MLA)

1. DIY Smart Code. "I Tested Headroom: 96% Log Compression?" YouTube,
   www.youtube.com/watch?v=7PMvZQjuuFk. Accessed 21 Aug. 2026. [archived:
   sources/video1-oembed.json]
2. AI Coding Daily. "I Tried Headroom: Did It ACTUALLY Save Tokens?" YouTube,
   www.youtube.com/watch?v=IbBuU1s3ycs. Accessed 21 Aug. 2026. [archived:
   sources/video2-oembed.json]
3. headroomlabs-ai. "headroom - README." GitHub, 2026,
   github.com/headroomlabs-ai/headroom. Accessed 21 Aug. 2026. [archived:
   knowledge/res036-dcp-vs-headroom/sources/headroom-readme.md]
4. headroomlabs-ai. "OpenCode Integration." Headroom docs, 2026,
   raw.githubusercontent.com/headroomlabs-ai/headroom/main/docs/content/docs/opencode.mdx.
   Accessed 21 Aug. 2026. [archived:
   knowledge/res036-dcp-vs-headroom/sources/headroom-opencode-docs.md]
5. poetry-platform. "DCP vs Headroom - Conspect (res036)." Project-internal
   conspect, 2026,
   knowledge/res036-dcp-vs-headroom/res036-dcp-vs-headroom-conspect.md.
   Accessed 21 Aug. 2026.
6. headroomlabs-ai. "Limitations." Headroom wiki / docs (websearch snippet,
   not fully archived), docs.headroomlabs.ai/docs/limitations, 2026. Accessed
   21 Aug. 2026. [supporting source; reliability Med; confirms <300-token
   auto-skip and system-prompt cache-preservation claims]

## 8. Claim-to-source mapping (key claims)

- "Review 5/6 accurate: reversible CCR" -> source 3 (README lines 57, 373) [cite 3]
- "Review 5/6 accurate: <300-token auto-skip" -> source 6 Limitations doc [cite 6]
- "Review 5/6 accurate: cross-agent memory" -> source 3 (README line 54) [cite 3]
- "Review 5/6 accurate: worth-it framing" -> source 3 (README lines 41, 337) [cite 3]
- "Review 5/6 accurate: setup-friction framing" -> source 4 (wrap/unwrap docs) [cite 4]
- "Flaw: 60-95% is JSON-data benchmark, not coding-agent savings (Headroom states 15-20% for coding agents)" -> source 3 (README line 11) [cite 3]
- "Video 1 is a token-compression review" -> source 1 oEmbed title [cite 1]
- "Video 2 is a token-savings review" -> source 2 oEmbed title [cite 2]
- "Videos engage token axis only; neither confirm nor contradict cache-drift finding" -> sources 1-2 (titles) + source 5 (cache-drift finding, sections 4, 6) [cite 1-2, 5]
- "Cache-drift finding: 202,503 -> 218,109 bytes, 3x, on opencode-go/DeepSeek; Headroom NOT a cache-friendlier DCP replacement; keep OFF" -> source 5 (res036 sections 4, 6) [cite 5]
- "Transcripts/descriptions not archived (DIA-072)" -> Unarchived/Excluded items 1-6 + sources/transcript-NOT-ARCHIVED.md
