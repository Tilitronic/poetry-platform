# Reflect batch gate findings (DIA-260825-k8mc, ai-specialist section-2.5 gate)

Source: ai-specialist gate review ses_fc4f236baffe3XR66NGzPXk7vK, 2026-08-25.

1. DIA-194/DIA-196: YAML ledger (.opencode/CHANGELOG.yaml) is source of truth; derived MD regenerated via scripts/changelog-render. Any changelog tool must append to YAML then validate + render.
2. DIA-137: settled YAML stack is PyYAML (yq rejected). All YAML construction must use PyYAML, not bash string concatenation.
3. DIA-061: canonical handoff checksum pipeline is jq -c '.prognosis | to_entries | sort_by(.key) | from_entries' | tr -d '\n' | sha256sum. Any checksum tool must use this exact pipeline.
4. Ponytail ladder (DIA-183): before writing a new script, check if an existing script covers the need. scripts/validate-handoff.sh already performs checksum verification (lines 239-279) - a separate handoff-check script was rejected; extend validate-handoff.sh with a --checksum-only flag instead.
5. Permission model (DIA-126a): orchestrator has bash deny. Scripts needing bash must be run by coder (scripts/* allow) or the developer; document this in script headers.
6. changelog schema requires date, ticket, scope, files, summary, verification (scripts/schemas/changelog.schema.json); optional severity/status/area/route. Recommended defaults: date=today, files=[], verification=manual with warning.
7. lane-resume triage over registry.jsonl must use jq structured extraction (32k+ rows), not naive grep; keep under ~50 lines; git-log cross-check dropped as manual step.

Outcome: pending (fill after implementation).
