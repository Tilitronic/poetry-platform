# DIA-112 - section-10 ticket gate fires despite OPEN + indexed + referenced ticket (correlation bug)

<!-- Filed 2026-08-12. The section-10 ticket gate blocked the DIA-111 conspect
     dispatch 4 times (conspecter x3, coder x1) even though DIA-111 is OPEN,
     has a README index row, and the dispatch carried the "Ticket: DIA-111"
     prefix. Meanwhile ai--2 (same ticket, same prefix) and con-1 (conspecter,
     DIA-108, no prefix) passed. Root-cause hypothesis: the gate correlates via
     the registry row objective field, which is being reused (DIA-077
     description-reuse quirk) and references CLOSED tickets DIA-087/DIA-084. -->

---

id: DIA-112
title: "section-10 ticket gate fires despite OPEN + indexed + referenced ticket (correlation bug)"
area: opencode-config
severity: Major
status: CLOSED
blocked_by: []
discovered: 2026-08-12
source: fix-lane
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-12

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-112-ticket-gate-correlation-bug.md"]
artifacts: ["docs/dev-infra-audit/tickets/DIA-112-ticket-gate-correlation-bug.md#fix (document-only disposition)", ".opencode/learnings/external-patterns/2026-08-12-dia112-ticket-gate-frontmatter-parsing.md"]
evidence: ["ai--3 lane (2026-08-12): Phase 1 research report - confirmed root cause: DIA-111 frontmatter title+comment inside first --- block yields empty status, excluding ticket from OPEN set"]

---

## Description

The section-10 ticket gate (DIA-063) fires "No correlating DIA ticket found
for this section-10 work" even when a correlating ticket EXISTS and is OPEN.

Observed 2026-08-12 (session 12/13, branch omo-slim-changes):

- DIA-111 (model escalation routing for coder and analyzer agents) was created
  OPEN, added to the README index (cod-11), and referenced with the
  "Ticket: DIA-111 (docs/dev-infra-audit/tickets/DIA-111-coder-analyzer-model-
  escalation.md)" prefix.
- The res014 conspect dispatch (same research, same ticket) was blocked
  4 times: conspecter x3 (including once AFTER the README index row was
  added) and coder x1 (the developer-approved reroute).
- CONTROL dispatches that PASSED: ai--2 (ai-specialist, DIA-111 research,
  same prefix), con-1 (conspecter, DIA-108 conspect, no prefix), cod-2/3/5/9
  (coder, ticket creation).

Hypothesis (needs verification in fix): the gate correlates the dispatch to
a ticket via the REGISTRY ROW OBJECTIVE field, not the payload. The registry
rows for coder lanes are showing a stale reused objective "Restart-verify
DIA-087/084 config" (DIA-077 description-reuse quirk) - a reference to
CLOSED tickets DIA-087 and DIA-084. If the gate sees a dispatch whose
registry objective references CLOSED tickets, it fires "no correlating
ticket" even though the payload references an OPEN ticket (DIA-111).

## Verification

- [ ] Reproduce: dispatch @conspecter with "Ticket: DIA-111 (docs/...)" prefix
      and observe the gate firing (expected to reproduce per 2026-08-12).
- [ ] Inspect registry.jsonl: compare the objective field of a blocked
      dispatch vs the description actually passed in the task() call. Confirm
      objective reuse (stale "Restart-verify DIA-087/084 config").
- [ ] Confirm DIA-111 exists: docs/dev-infra-audit/tickets/DIA-111-coder-
      analyzer-model-escalation.md, status OPEN, README index row present.
- [ ] Confirm control dispatches passed (ai--2, con-1) with correct registry
      objectives.

## Fix

DOCUMENT-ONLY DISPOSITION (developer, 2026-08-12): no fix applied.

CONFIRMED ROOT CAUSE (ai-specialist Phase 1 research, 2026-08-12, delegation-observer.ts lines 839-992 gate, 468-513 correlation, 98-125 parseFrontmatterFields, 425-447 scanTickets):

- The gate extracts DIA-IDs from the dispatch text (description + prompt, line 866) via /DIA-\d+/gi and matches them against tickets scanned from the tickets directory with frontmatter `status` (line 922-928, evaluateTicketCorrelation 468-503).
- scanTickets (425-447) reads status via parseFrontmatterFields (98-125), which finds the FIRST `---` delimiter, parses until the NEXT `---`, and STOPS.
- DIA-111-coder-analyzer-model-escalation.md had its title + HTML comment INSIDE the first `---` block (between delimiter 1 and 2). parseFrontmatterFields therefore returned no fields; status parsed as empty (""); the ticket was excluded from the OPEN_TICKET_STATUSES set; evaluateTicketCorrelation Path 1 returned false for every dispatch referencing DIA-111.
- Result: 4 consecutive gate blocks for the res014 conspect dispatch (conspecter x3, coder x1) despite DIA-111 being OPEN + README-indexed + referenced with the "Ticket: DIA-111" prefix.

REFUTED HYPOTHESIS: the original DIA-112 hypothesis (registry-objective reuse / DIA-077 description-reuse quirk causing correlation failure) is INCORRECT. The gate reads the task() description+prompt directly, not registry objectives. DIA-077 is a cosmetic board-render issue only.

DESIGN NOTE (important): the parser is FAIL-CLOSED by design - a malformed ticket is treated as NOT-OPEN, which is the safe direction for a gate (a broken CLOSED ticket must never be treated as OPEN). Durable prevention = correct ticket structure + validation, NOT lenient parsing. This is why no parser change was made.

CONSEQUENCE: DIA-111's ticket file remains malformed (no fix applied). Any FUTURE dispatch referencing DIA-111 will STILL be gate-blocked until the ticket file is corrected (title/comment moved BEFORE the first ---) or a new ticket is used. res014 conspect remains DEFERRED.

## Re-verify

> To be filled at re-verify time.
