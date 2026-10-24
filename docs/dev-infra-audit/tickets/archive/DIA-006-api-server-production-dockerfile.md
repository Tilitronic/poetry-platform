# DIA-006 — api-server has no production Dockerfile

---

id: DIA-006
title: "api-server has no production Dockerfile — evaluate need"
area: docker
severity: Major
status: CLOSED
blocked_by: []
discovered:
source: inventory
date: 2026-08-02
created: 2026-08-02
updated: 2026-08-03

---

## Description

`apps/api-server` is covered only by the shared dev image (`Dockerfile.dev`,
`docker-compose.yml` dev service). There is no production container for the API
server. Since the repository has no CI (section 12) and the deploy story is
undocumented, the need is unproven — but a production image gap blocks any future
deployment path and keeps the project dev-only. Evaluate: does the project need a
production api-server image now, or should this be explicitly deferred/documented?

## Verification

1. Confirm `apps/api-server/` contains no Dockerfile.
2. Check `docker-compose.yml` and `Makefile` for any non-dev service/target.

## Fix

> **Deferred (owner decision, 2026-08-03)** — whether to build an api-server
> production Dockerfile. No CI/deploy story exists and the production-image need is
> unproven, so this is explicitly deferred rather than left open pending a product
> decision. Revisit when a deployment story is planned. **Non-blocking for the
> clean cycle** (dev image + compose cover all automated gates).

## Re-verify

> To be filled at re-verify time.

## Disposition

CLOSED 2026-08-03 (owner directive, campaign closeout). DEFERRED disposition
retained: owner decision 2026-08-03 — no CI/deploy story; production-image need
unproven. Revisit when deployment is planned. Archived per archive policy.
