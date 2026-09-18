# Model availability verification - pricing pages vs actual subscription (2026-08-12)

- **Date:** 2026-08-12
- **Source:** DIA-108 audit research phase (ai-specialist lane, web-fresh; 7 sources archived at knowledge/res013-opencode-model-pricing-audit/); developer disposition during DIA-108 review.
- **Status:** REJECTED - the recommended config change was rejected by the developer; the finding is persisted as a quality lesson. Ticket DIA-108 remains OPEN (see ticket for remaining work).
- **Outcome note:** no config change applied. DIA-108 ticket updated 2026-08-12 with research outcome + disposition; conspect res013 records the availability caveat.

## Pattern

An AI specialist recommended a Copilot model (Claude Sonnet 5) based on the public pricing page without verifying it exists in the developer's actual Copilot Pro subscription model list. The developer rejected the change because Claude Sonnet 5 is NOT in the subscription's model list. The recommendation was withdrawn.

## Rule

For ANY model recommendation, validate availability against the ACTUAL subscription/plan model list (not just pricing pages) BEFORE proposing config changes. Pricing-page availability does NOT imply subscription availability. Sources consulted must distinguish "listed on public pricing page" from "available in this subscription tier/plan".

## Outcome

- Recommendation: designer claude-sonnet-4.5 -> claude-sonnet-5. DISPOSITION: REJECTED by developer.
- DIA-108 updated 2026-08-12: Fix section now records research outcome, disposition, and remaining work (ai-assist-sources.yaml refresh, R5 MiMo evaluation, optional Kimi K3 escalation adoption).
- Conspect res013 (knowledge/res013-opencode-model-pricing-audit/) records the availability caveat.
- No config change applied (DIA-108 fix lane).

## Reusable lesson

Before recommending any model change, check the model against the user's ACTUAL subscription/plan model list, not merely against public pricing/benchmark pages. When a pricing page lists a model, explicitly verify it is included in the relevant paid plan before proposing a config change; otherwise the recommendation is withdrawn by the developer and the research effort produces no applied value.

## Tags

DIA-108, model-availability, subscription-validation, pricing-pages, copilot-pro, claude-sonnet-5, ai-specialist, research-quality, model-recommendation
