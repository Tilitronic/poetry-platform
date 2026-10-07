---
title: DIA-260929-sjwm config-portion gate - removing dormant snip deny rules
date: 2026-09-29
agent: ai-specialist
ticket: DIA-260929-sjwm
scope: .opencode/opencode.jsonc (coder + coder-escalated), .opencode/agents/coder-escalated.md
status: read-only gate research (findings routed via orchestrator)
---

Findings:
1. Removal is safe once the plugin declaration (out-of-repo) and the image binary are gone. Nothing in the config surface functionally assumes snip: project plugin array clean (opencode.jsonc:749-760), oh-my-opencode-slim.jsonc clean, commands/schemas clean, only coder-escalated.md:34 documents the deny.
2. Only real gate: coder/coder-escalated permission lockstep (jsonc-parse.js:62-98 via validate-opencode-config.sh:51, Makefile:256). It deep-compares both maps and is key-order sensitive, so the two snip pairs must be removed symmetrically and in place.
3. No validator/test asserts the rules, the DORMANT comment, or a snip token. All non-historical repo hits are false-positive prose ("snippet") except the in-scope live files.
4. The comment block opencode.jsonc:317-322 also carries the doom_loop: deny rationale; a naive delete of 317-322 would drop live-rule documentation. Reword to preserve it.
5. Residual snip references are historical (CHANGELOG, memory files, learnings, DIA-092, knowledge/archive, knowledge/ana reports, prior openspec changes) plus the live index .opencode/memory-shelf.yaml:52-64 which indexes preserved archive conspects and must be kept.
6. Best-practice basis for retiring a guard whose subject no longer exists: NIST SP 800-53 CM-7 Least Functionality (remove unused software/functions); OWASP Attack Surface Analysis (unused features increase surface); OpenCode permissions defaults (removed rule returns to inherited default, no unique hole). This reverses the DIA-092 council 5/5 dormancy premise because the priming source (the global plugin) is now being removed.
7. DIA-092 mechanical-lock risk: the deny rules AMPLIFIED the lock (deny fired on plugin-rewritten commands). Removing them removes that amplification; residual risk degrades to the DIA-075/078 loop class, partially covered by retained doom_loop: deny. Regression vector is the non-versioned global config only.

Outcome: Repo live-surface scan after the purge: 0 hits in Dockerfile.dev, .opencode/opencode.jsonc, .opencode/agents/coder-escalated.md, docs/dev-infra-audit/inventory.md; main-tree live-surface sweep 0 (only false positive: .opencode/agents/researcher.md:15 "code snippets"). make test-config exit 0, including ok: coder/coder-escalated permission lockstep (2 keys compared, task-related ignored) and the agent-name lockstep 27 passed / 0 failed. Deep key-order-sensitive validator standalone: node .opencode/scripts/lib/jsonc-parse.js --lockstep .opencode/opencode.jsonc exit 0. openspec validate dia-260929-sjwm-remove-live-snip-traces --strict exit 0. Independent review: ai-auditor config review verdict pass-with-findings; the follow-up fixes (this commit) address the accepted findings.
