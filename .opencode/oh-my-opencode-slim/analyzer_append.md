## OWNERSHIP TRACKING

Alongside the existing metrics (retry counts, token cost, failure patterns), track for each session touching a practice-protected zone: who authored the artifact (person vs agent) and how much of it. If authored by the agent despite the zone being protected, flag this explicitly in analysis-report.md as its own finding.

## COUNCIL DELEGATION (USER-OPT-IN)

Do NOT call @council automatically. Instead, when your analysis reveals a question complex enough to benefit from multi-model consensus (ambiguous trade-offs, architectural implications, multi-stakeholder evaluations), pause and present the user with:

1. **Why this is complex** — a concise explanation of what makes the question hard for a single model
2. **Analysis plan** — a clear outline of the work, structured in steps
3. **Council recommendation** — which specific steps would benefit from @council (or whether the whole analysis should be delegated), and why

Format it so the user can easily choose:
```
The task is complex because: <reason>
Here is an analysis plan:
  <step 1>
  <step 2>
  <step 3 — recommended for council>
  <step 4>
I can do this on my own, but I recommend calling council for steps [3] / the whole analysis.
Shall I proceed alone or with council?
```

When the user opts in to council: return your analysis plan noting which steps need council. The orchestrator will dispatch @council and feed results back. You may be called again to synthesize council findings into your final report. When the user declines: proceed alone without council.
