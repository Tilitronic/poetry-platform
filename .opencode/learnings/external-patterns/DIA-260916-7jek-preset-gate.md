# DIA-260916-7jek preset gate findings (ai-specialist gate, AGENTS.md 2.5 step 1)

- Ticket: DIA-260916-7jek (OPEN at verification time, 2026-09-16).
- Date: 2026-09-17.
- Context: muse-qwen-balanced RENAMED to promo. promo is the main preset; openai-first-cost-balanced is separate for openai subscription. Only those 2 presets exist.
- promo must be openai-free (developer ruling). Prior gate found exactly 1 openai/ hit in promo: L202 promo.code-navigator openai/gpt-5.6-luna. Classified as leftover, to be replaced with a non-openai route already used in promo.
- openai-first-cost-balanced is openai-only by design (17 hits, one per agent). Expected, no change.
- scripts/test-interview-enforcement.sh Check 1 hardcodes stale preset tuple (opencode-go/cebula/free) and throws KeyError: 'opencode-go' on current config. Both current presets carry '!openspec-propose', so check intent holds; only the tuple needs updating to (promo, openai-first-cost-balanced).

## Outcome (2026-09-17, close lane; auditor ai--2 PASS WITH NOTES, no blockers)

- promo.code-navigator Luna -> opencode/muse-spark-1.3-contributor-free (promo now 0 openai/ hits).
- openai-first-cost-balanced gained a byte-identical inline orchestrator prompt (routing fields unchanged); drift gate default retargeted to both presets with a generic byte-identity guard; drift bats converted 3->2 presets (16/16 pass).
- Stale L13-14 Luna-medium composition comment refreshed to describe current promo routes.
- Gates: validate-opencode-config 0, prompt-drift 0, make test-config 0, drift bats 16/16.
- Changelog: .opencode/CHANGELOG.yaml entry DIA-260916-7jek (+ rendered CHANGELOG.md, 151 entries).
- Lesson: preset renames orphan every hardcoded preset tuple (checker defaults, bats fixtures); grep for the old names across scripts/ + __tests__/ before closing a rename ticket.
