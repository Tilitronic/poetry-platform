# Pending-gate-clear gate findings (DIA-260825-fjnc, ai-specialist section-2.5 gate)

Source: ai-specialist gate review ses_fc4f236baffe3XR66NGzPXk7vK, 2026-08-26.

1. DIA-260819-qibv: persistence-pending.json was renamed to conspect-pending.json; old file is a legacy orphan - clearing tooling must handle both names during transition.
2. DIA-135 D4 / DIA-057 / DIA-058: pending flags are verification gates - any clearing mechanism must ENCODE the same artifact verification (sources/ + conspect file + memory-shelf entry), never bypass it.
3. Ponytail ladder (DIA-183): standalone script beats plugin hook here - delegation-observer.ts is hot (modified by parallel observer-fix session); plugin event-hook auto-clear also weakens gate verification (BLOCK verdict for candidates B and C).
4. Permission model (DIA-126a): orchestrator bash deny - script runs via coder dispatch or developer.
5. Flag semantics ground truth: delegation-observer.ts writes conspect-pending.json (researcher PERSISTENCE_RECOMMENDED) and analysis-pending.json (conspecter completion); orchestrator prompt rules consume them; nothing clears them mechanically today.

Outcome: applied (2026-08-26, review cycle 2/2).
