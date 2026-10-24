# Observer vision routing: capability mismatch, modality probe, Option C

Date: 2026-10-06
Ticket: DIA-260929-nc6w 'Observer lane routed to text-only model (vision capability gap)'
Status: IMPLEMENTED - Option C accepted by developer, re-route applied to
slim.jsonc:143-150 (primary opencode-go/qwen3.8-flash, fallback
opencode-go/kimi-k2.7-code); `make test-config` passed; Phase-6 audit
returned advisory PASS; doc drift (F8/F9/F11) closed 2026-10-06.

## 1. Defect class: prompt capability vs routed model

A lane whose prompt REQUIRES a capability was routed to a model that lacks
it. The @observer native prompt declares the requirement explicitly:
`.opencode/oh-my-opencode-slim/src/agents/observer.ts:41` - "Requires a
vision-capable model." The ACTIVE preset mimo-balanced
(`.opencode/oh-my-opencode-slim.jsonc:3`) DEFECT (as found): it routed
observer to [opencode-go/mimo-v2.6-flash, opencode-go/deepseek-v4-flash]
(slim.jsonc:143-150), both text/volume models. CURRENT (fixed
2026-10-06): slim.jsonc:143-150 routes observer to
[opencode-go/qwen3.8-flash, opencode-go/kimi-k2.7-code].

Precedent: DIA-260824-1c3e (CHANGELOG.md:887; learnings
2026-08-25-dia260824-1c3e-oxalpha-mapping.md) already recorded the lesson:
"model-ID verification != capability verification; modality claims need
their own diagnostic before lanes with hard modality requirements adopt a
model." The same drift recurred, so the lesson had no enforcement point.

## 2. Gate research findings (section-2.5 @ai-specialist gate)

- Vision-capable Go-native candidates were enumerated for the observer lane.
- openai/gpt-5.6-luna rejected for mimo-balanced: it would violate the
  DIA-260916-7jek "no openai/* hits" invariant (slim.jsonc:14 composition
  comment), plus a Go-gateway transport caveat.
- Developer decision: primary opencode-go/qwen3.8-flash, fallback
  opencode-go/kimi-k2.7-code.

## 3. Modality diagnostic (capability evidence, not ID evidence)

- qwen3.8-flash: VISION_CONFIRMED via models.dev + QwenCloud + qwen-code,
  but the docs describe text+image only, no PDF.
- kimi-k2.7-code: VISION_CONFIRMED (ai-assist-sources.yaml:236, "multimodal
  primary").
- Failover risk: model-array fallback fires on model ERRORS, not on silent
  modality misclassification (2026-09-20-...8la4...md:34-39 - retry_on_empty
  is council-only; fallback chains cover provider/model errors). Therefore
  the PRIMARY must be validated by probe, not assumed; a wrong-but-working
  primary never triggers failover.

## 4. Live probe: exact-match design

- Bold PNG containing token X7-Q42-LM -> qwen3.8-flash replied EXACTLY
  "X7-Q42-LM" 6/6.
- No-image negative control: 0/2 (no hallucinated token).
- Image prompts billed 142-178 prompt tokens vs 76 with no image, proving
  the image parts were actually transmitted (not silently dropped).
- Thin-font PNG was OCR-fragile (X7-O42-LM / Q-O confusion): a legibility
  limitation, not a mechanism failure. Probe tokens must be bold/high
  contrast.

## 5. PDF finding (corrects the docs)

The Go gateway ACCEPTED a PDF as an OpenAI `file` part (HTTP 200) and the
model read the contained string exactly (390 tokens). Conclusion: PDF is
converted to vision input upstream; the documented "no PDF" limit is NOT
enforced by the gateway. Stuffing PDF bytes into `image_url` returns 400
"image format is illegal". Practical rule: send PDFs as a `file` part;
never stuff PDF bytes into `image_url`.

## 6. Observability lesson (probe validity + dispatch accounting)

- `opencode run` uses the default `build` agent, which HAS tools and read
  the attached image from disk - so CLI-based negative controls are invalid
  (the model can "answer" by reading the file, not by seeing the image).
  Modality probes must run through a tool-free path: a direct
  chat/completions request with a single user message.
- The session registry cannot count per-agent dispatches (every
  session_spawn row has agent=None), so dispatch-based justification for an
  agent's use is unreliable. Prefer probe-based evidence over registry
  dispatch counts.

## 7. Outcome (developer decision)

Option C accepted - keep @observer, re-route it:
- observer primary -> opencode-go/qwen3.8-flash
- observer fallback -> opencode-go/kimi-k2.7-code
- Doc drift (all closed 2026-10-06): slim.jsonc:14 composition comment now
  names observer's opencode-go/qwen3.8-flash route with
  opencode-go/kimi-k2.7-code fallback; observer already removed from the
  mimo-v2.5 / mimo-v2.6-flash lane arrays
  (knowledge/model-registry.yaml:35,47) and added to the qwen3.8-flash
  lane entry (line 99).

## 8. Sources

- Gate lane: section-2.5 @ai-specialist research (read-only) + live probe
- Disposition report:
  knowledge/ana-261006-jd0s-observer-agent-disposition/ana-261006-jd0s-observer-agent-disposition-report.md
- Config refs: slim.jsonc:3, slim.jsonc:14, slim.jsonc:143-150,
  src/agents/observer.ts:41 (`.opencode/oh-my-opencode-slim/` prefix),
  knowledge/model-registry.yaml:35,47, ai-assist-sources.yaml:236
- Precedent: CHANGELOG.md:887 (DIA-260824-1c3e),
  learnings/2026-08-25-dia260824-1c3e-oxalpha-mapping.md,
  learnings/2026-09-20-dia-260827-8la4-preset-stability-zdr-routing.md:34-39
