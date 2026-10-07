# Capability-Based Authorization for Multi-Agent Systems

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 16
phase-a-failures: 2
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

## Executive Summary

Capability-based authorization eliminates the chicken-and-egg problem in multi-agent workflows by replacing identity-centric access control with unforgeable, transferable tokens that carry their own authority. Instead of asking "who are you?" (which requires a pre-existing identity system), a capability system asks "what are you holding?" (which requires only a cryptographically signed token). This conspect synthesizes 14 sources across academic papers, production codebases, and foundational references to identify patterns applicable to the poetry-platform's delegation-observer system.

**Key finding:** The project's existing HMAC-signed delegation events and session handoff JSON already implement a de facto capability system. Formalizing this as capability tokens with TTL, scope attenuation, and revocation is the natural next step -- not a rewrite, but a tightening of what already exists.

---

## 1. Capability-Based Security Fundamentals

### 1.1 Core Concept

A capability is a **communicable, unforgeable token of authority** that references an object along with an associated set of access rights ("Capability-Based Security," Wikipedia). Possession of the capability is sufficient proof of authorization -- no additional ACL lookup is needed (Dennis and Van Horn 1966; Levy 1984).

The critical distinction from traditional access control:

| Dimension | ACL-Based (Zanzibar) | Capability-Based |
|---|---|---|
| Authority source | Central policy server | Token itself |
| Verification | Lookup at access time | Cryptographic check |
| Delegation | Requires server round-trip | Token transfer |
| Offline operation | Impossible | Native |
| Circular dependency | Yes (auth needs auth) | No |

### 1.2 Object-Capability Model

The object-capability model (Dennis and Van Horn 1966) reduces all authorization to two rules:

1. Object A can send a message to B only if A holds a reference to B.
2. Object A can obtain a reference to C only if A receives a message containing a reference to C.

This creates a **connectivity-based authority graph** where "only connectivity begets connectivity" (Wikipedia, Object-capability model). Attenuation -- creating a restricted proxy from an existing capability -- is the primary mechanism for least-privilege delegation.

### 1.3 Why This Solves the Chicken-and-Egg Problem

In multi-agent systems, the traditional authorization flow has a circular dependency: Agent A needs to authorize Agent B, but the authorization mechanism itself requires Agent A to already be authorized. Capability tokens break this cycle because:

- The **initial capability** can be minted by any trusted entity (the developer, the orchestrator)
- Delegation chains are **cryptographically self-verifying** -- each delegation is signed by the delegator
- No central authorization server is consulted during delegation

The blockchain trust taxonomy paper (arXiv 2608.04626) identifies this as "authorization and delegation trust" -- one of five trust dimensions in agent networks, where "the trust boundary expands from individual execution to cross-agent, cross-platform, and cross-organizational interaction."

---

## 2. UCAN: Decentralized Capability Tokens

### 2.1 Specification

UCAN (User Controlled Authorization Network) is a trustless, local-first authorization protocol that provides:

- **Cryptographic signing** -- every authorization is verifiable without contacting the issuer (ucan.xyz)
- **Delegation chains** -- capabilities can be chained and combined while maintaining security guarantees
- **Attenuation** -- delegate specific capabilities with custom constraints, time limits, and precise scope control
- **Revocation** -- built-in revocation mechanisms and blacklisting support
- **Offline operation** -- no central server required for permission verification

### 2.2 Implementation: @ucanto/core

The `@ucanto/core` library (npm, v10.4.6) provides the canonical UCAN implementation with:

- JWT-compatible token format with IPLD encoding
- Capability-based invocation model
- Delegation and revocation primitives
- Principal-based verification (no centralized identity provider)

### 2.3 Production Reference: w3up Revocation

The w3up codebase (`w3up-ucan-revocation.js`) demonstrates real-world UCAN revocation:

```javascript
// Revocation authority flows both directions in the delegation chain
const scope = {
  [delegation.issuer.did()]: delegation,
  [delegation.audience.did()]: delegation,
}

// All principals upstream are also authorized to revoke delegations downstream
for (const proof of proofs) {
  const parent = toRevocationQuery(proof)
  Object.assign(query, parent)
  Object.assign(scope, parent[proof.delegation.cid.toString()])
}
```

Key design choice: revocation authority is bidirectional -- both issuer and audience of a delegation can revoke it, and all upstream principals can revoke downstream delegations.

---

## 3. Stamp/Endorsement Patterns in Multi-Agent Systems

### 3.1 TopoClaw: Cross-Context Authority Governance

TopoClaw (arXiv 2605.15556) introduces the most relevant multi-agent authorization model:

- **Cross-device action placement** -- decoupling intent from actuation, routing actions across device clusters based on hardware affordances
- **Cross-user identity attribution** -- agents as "Digital Twins" that coordinate while preserving provenance and role-aware permissions
- **Cross-context authority governance** -- pairing broad capability with distributed, context-aware policy enforcement across physical and social trust boundaries

The critical insight: authorization must be **topology-aware** -- the same capability means different things in different contexts.

### 3.2 ColluSkill: Composition Attacks

ColluSkill (arXiv 2608.09732) demonstrates that capability authorization must account for **cross-skill composition attacks** -- multiple locally plausible capabilities that collectively form a harmful workflow. The defense (ChainGuard) reconstructs cross-skill dependencies and capability compositions to identify risks at the workflow level.

**Implication for poetry-platform:** Capability tokens should carry not just individual permissions but also composition metadata -- which other capabilities are expected to be present.

---

## 4. Bootstrap Authorization: Authorizing the First Authorization

### 4.1 The Bootstrap Problem

Every authorization system faces the question: who authorizes the first capability? The sources reveal four solutions:

| Bootstrap Mechanism | Example | Trade-off |
|---|---|---|
| **Trusted minter** | OpenClaw server mints tokens | Single point of trust |
| **Cryptographic derivation** | UCAN root key signs first delegation | Key management burden |
| **Policy declaration** | ToolGuardian ASP pre-admission vetting | Policy complexity |
| **Social topology** | TopoClaw role-based initial grants | Context dependency |

### 4.2 Recommended Bootstrap for Poetry-Platform

The **trusted minter** pattern (OpenClaw) is the pragmatic choice:

1. The orchestrator session mints a root capability for each agent at dispatch time
2. The root capability carries the agent's permitted scope (tools, files, network)
3. The agent can attenuate but never escalate its capability
4. The orchestrator retains revocation authority

This mirrors the existing pattern where `log_decision(handoff)` already creates a signed authority artifact at session boundaries.

---

## 5. Key-Based Access Control Patterns

### 5.1 HMAC Capability Tokens (OpenClaw, Unsloth)

The simplest capability pattern -- a server-side secret signs a capability token:

```typescript
// OpenClaw: mint opaque capability token
export function mintPluginNodeCapabilityToken(): string {
  return randomBytes(18).toString("base64url");
}
```

```python
# Unsloth: HMAC-signed preview ref capability
def sign_preview_ref(ref: str) -> str:
    mac = hmac.new(
        get_or_create_preview_link_secret(),
        _canonical_payload(ref),
        hashlib.sha256,
    ).digest()
    return base64.urlsafe_b64encode(mac).rstrip(b"=").decode("ascii")
```

Properties:
- Stateless verification (no database lookup)
- Constant-time comparison prevents timing attacks
- Secret rotation revokes all tokens at once
- TTL provides automatic expiration

### 5.2 Capability Token Verification (QM)

The QM server demonstrates audience-based capability authorization:

```typescript
// Capability tokens carry audience claims for route-level authorization
if (capability.aud !== requiredAud) {
  sendJson(res, 403, {
    error: "forbidden",
    message: `this route requires a capability token with audience "${requiredAud}"`,
  });
}
```

Key design: different routes require different audience claims, enabling fine-grained capability scoping without a central policy server.

### 5.3 AgentRiskBOM: Capability Opacity

AgentRiskBOM (arXiv 2606.21877) addresses "capability opacity" -- the absence of a structured account of what a deployed agent can access, remember, change, delegate, and prove afterward. Their JSON-schema artifact adds fields for:

- Autonomy level
- Tool permissions
- Memory scope
- Credential scope
- Approval gates
- Audit signals
- Inter-agent communication
- External action capability

**Implication:** Capability tokens should be machine-readable and auditable, not just opaque blobs.

---

## 6. Event-Driven Authorization Integration

### 6.1 Alignment with Delegation-Observer

The existing delegation-observer system already captures:

- Delegation events (`registry.jsonl`)
- Semantic events (`messages.jsonl`)
- Decision logging (`log_decision`)

Capability tokens integrate naturally:

1. **Mint** -- orchestrator mints capability at delegation time
2. **Attach** -- capability token accompanies the task dispatch
3. **Verify** -- worker verifies capability before action
4. **Log** -- capability use logged to `messages.jsonl`
5. **Revoke** -- orchestrator can revoke via registry update

### 6.2 ToolGuardian: Declarative Policy Layer

ToolGuardian (arXiv 2607.21835) proposes Answer Set Programming (ASP) for declarative capability policy:

- Pre-admission vetting converts evidence into structured facts
- Runtime authorization reasons over capabilities, effects, task context, and composition
- ASP achieves deny-class F1 of 0.86 on 16 MCP-style tools

**Relevance:** For poetry-platform, a simpler declarative approach (YAML capability definitions + HMAC tokens) captures most of the benefit without ASP complexity.

---

## 7. Pattern Catalog

### Pattern 1: HMAC Stateless Capability
- **Mechanism:** Server signs `capabilityID + scope + TTL` with shared secret
- **Pros:** Zero state, constant-time verify, instant revocation via secret rotation
- **Cons:** No delegation chains, no per-agent revocation, secret must be shared
- **Example:** Unsloth preview tokens, OpenClaw node capabilities

### Pattern 2: Signed Delegation Chain (UCAN)
- **Mechanism:** JWT/IPLD tokens with issuer signature + delegation proofs
- **Pros:** Decentralized verification, delegation chains, per-capability revocation
- **Cons:** Complex implementation, JWT size overhead, key management
- **Example:** w3up UCAN revocation, @ucanto/core

### Pattern 3: Capability-in-URL
- **Mechanism:** Capability token embedded in URL path or query parameter
- **Pros:** Simple integration, works with HTTP without headers
- **Cons:** Logged in access logs, bookmarkable (may leak), limited scope
- **Example:** OpenClaw `/__openclaw__/cap/{token}` path prefix

### Pattern 4: Capability-in-Header
- **Mechanism:** Capability token passed in HTTP header (e.g., `X-Capability`)
- **Pros:** Not logged, can be scoped per-request, standard HTTP pattern
- **Cons:** Requires header manipulation, not cacheable
- **Example:** QM server `CAPABILITY_HEADER`

### Pattern 5: Audience-Scoped Capability
- **Mechanism:** Capability token carries `aud` claim restricting which routes/services it authorizes
- **Pros:** Fine-grained without multiple tokens, self-describing
- **Cons:** Requires route-level audience mapping
- **Example:** QM server `CONTROL_PLANE_AUD` pattern

### Pattern 6: Capability Attenuation
- **Mechanism:** Parent capability creates child with restricted scope
- **Pros:** Least privilege, delegation without escalation
- **Cons:** Requires chain verification, state management
- **Example:** UCAN delegation, object-capability proxy pattern

### Pattern 7: Capability Revocation List
- **Mechanism:** Central registry of revoked capability IDs checked at verification
- **Pros:** Immediate revocation, auditable
- **Cons:** Requires online check, scalability concern
- **Example:** w3up revocation storage

### Pattern 8: TTL-Based Auto-Expiry
- **Mechanism:** Capabilities carry expiration timestamp, rejected after expiry
- **Pros:** No explicit revocation needed, bounded lifetime
- **Cons:** Clock skew, can't revoke early, requires time sync
- **Example:** OpenClaw 10-minute default TTL

### Pattern 9: Composition-Aware Capability
- **Mechanism:** Capability metadata includes expected companion capabilities
- **Pros:** Detects cross-skill composition attacks
- **Cons:** Complex metadata, harder to mint
- **Example:** ColluSkill/ChainGuard pattern

### Pattern 10: Declarative Policy Capability
- **Mechanism:** ASP/OWL/Rego policy defines capability rules, tokens carry claims
- **Pros:** Auditable reasoning, composable policies
- **Cons:** Policy engine overhead, learning curve
- **Example:** ToolGuardian ASP layer

---

## 8. Comparison Matrix

| Pattern | Audit Trail | Circular-Dep Elimination | Integration Effort | Revocation | Delegation |
|---|---|---|---|---|---|
| HMAC Stateless | Log token ID | Yes | Low | Secret rotation only | No |
| Signed Delegation Chain | Full chain | Yes | High | Per-capability | Yes |
| Capability-in-URL | URL logged | Yes | Low | TTL only | No |
| Capability-in-Header | Event log | Yes | Low | TTL only | No |
| Audience-Scoped | Per-route log | Yes | Medium | TTL + audience | No |
| Capability Attenuation | Chain log | Yes | Medium | Per-chain | Yes |
| Revocation List | Revocation log | Yes | Medium | Immediate | No |
| TTL Auto-Expiry | Implicit | Yes | Low | Automatic | No |
| Composition-Aware | Dependency log | Yes | High | Per-chain | Yes |
| Declarative Policy | Policy log | Yes | High | Per-rule | Yes |

---

## 9. Recommendation for Poetry-Platform

### Primary: HMAC Stateless Capability (Pattern 1) + TTL Auto-Expiry (Pattern 8)

**Rationale:** The project already implements this pattern in spirit:

- `log_decision` produces signed JSON artifacts (de facto capability tokens)
- Session handoff JSON carries authority metadata
- `registry.jsonl` provides audit trail

Formalizing this adds:

1. **Explicit capability tokens** -- HMAC-signed `capabilityID + agent + scope + TTL`
2. **Scope attenuation** -- orchestrator mints with `tools: ["read", "edit"]`, agent can't escalate
3. **TTL enforcement** -- tokens expire, forcing re-authorization
4. **Revocation via secret rotation** -- instant mass revocation if compromised

### Secondary: Audience-Scoped Capability (Pattern 5)

Add audience claims to route the same token to different authorization paths. This is low-effort since QM already demonstrates the pattern.

### Avoid: Signed Delegation Chain (UCAN)

UCAN is over-engineered for this use case. The poetry-platform is a single-system deployment, not a decentralized network. HMAC + TTL provides the same security properties with 10x less complexity.

### Avoid: Declarative Policy (ASP)

ToolGuardian's ASP layer is research-grade. The YAML config approach already used for agent permissions is sufficient.

---

## 10. Implementation Sketch

### 10.1 Capability Token Structure

```typescript
interface CapabilityToken {
  id: string;           // randomBytes(18).toString("base64url")
  agent: string;        // internal agent name (e.g., "coder")
  scope: {
    tools: string[];    // permitted tools (e.g., ["edit", "bash"])
    paths: string[];    // permitted paths (e.g., ["knowledge/*"])
    route: string;      // audience scope (e.g., "implementation")
  };
  issuedAt: number;     // Date.now()
  expiresAt: number;    // issuedAt + TTL_MS
  issuer: string;       // "orchestrator" or session ID
  signature: string;    // HMAC-SHA256 canonical payload
}
```

### 10.2 Integration Points

```
Orchestrator Session
  |
  |-- log_decision(handoff)  -->  mints CapabilityToken
  |                                |
  |                                v
  |                          registry.jsonl  (stores token ID + metadata)
  |
  |-- dispatch(@coder)      -->  attaches CapabilityToken to task
  |                                |
  |                                v
  |                          @coder verifies token before action
  |                          @coder logs use to messages.jsonl
  |
  |-- revoke(capabilityID)  -->  marks token revoked in registry
                                 agents verify before each action
```

### 10.3 Minimal Changes Required

1. **New:** `capability-token.ts` -- mint, verify, revoke (HMAC + TTL)
2. **Modify:** `log_decision` -- accept and store capability metadata
3. **Modify:** task dispatch -- attach capability token to worker context
4. **Modify:** worker action hooks -- verify capability before edit/bash
5. **No change:** `registry.jsonl` schema (add `capability_id` field)
6. **No change:** `messages.jsonl` schema (capability use logged as event)

Total estimated scope: ~200 lines of TypeScript, zero new dependencies.

---

## Works Cited

"Capability-Based Security." *Wikipedia*, Wikimedia Foundation, en.wikipedia.org/wiki/Capability-based_security. Accessed 20 Aug. 2026.

Dennis, Jack B., and Earl C. Van Horn. "Programming Semantics for Multiprogrammed Computations." *Communications of the ACM*, vol. 9, no. 3, 1966, pp. 143-155.

Karmaker Shanto, Subangkar. "Securing Agentic AI: From Per-Action Checks to Trajectory Assurance." *arXiv preprint* arXiv:2608.01558, 3 Aug. 2026. arXiv.org.

Levy, Henry M. *Capability-Based Computer Systems*. Digital Equipment Corporation, 1984.

"Object-capability Model." *Wikipedia*, Wikimedia Foundation, en.wikipedia.org/wiki/Object-capability-model. Accessed 20 Aug. 2026.

OpenClaw Contributors. "Plugin Node Capability." *GitHub*, github.com/openclaw/openclaw, src/gateway/plugin-node-capability.ts. Accessed 20 Aug. 2026.

QM Contributors. "Capability Token Server." *GitHub*, github.com/yc-software/qm, src/api/server.ts. Accessed 20 Aug. 2026.

"Securing Agentic AI." See Karmaker Shanto above.

*TopoClaw: A Human-Centric and Topology-Aware Agent Operating System*. arXiv:2605.15556, 15 May 2026. arXiv.org.

*UCAN: Trustless, Decentralized Authorization*. ucan.xyz. Accessed 20 Aug. 2026.

Unsloth AI Contributors. "Preview Token." *GitHub*, github.com/unslothai/unsloth, studio/backend/utils/preview_token.py. Accessed 20 Aug. 2026.

*W3up UCAN Revocation*. *GitHub*, github.com/storacha/w3up, packages/upload-api/src/utils/revocation.js. Accessed 20 Aug. 2026.

@ucanto/core. *npm*, www.npmjs.com/package/@ucanto/core. Accessed 20 Aug. 2026.

"Blockchain Empowered Trustworthy Agent Networks: Foundations, Taxonomy, and Future Directions." *arXiv preprint* arXiv:2608.04626, 5 Aug. 2026. arXiv.org.

"AgentRiskBOM: A Risk-Scoping Security Bill of Materials for Agentic AI Systems." *arXiv preprint* arXiv:2606.21877, 20 Jun. 2026. arXiv.org.

"ToolGuardian: Declarative Security for AI Agent-Tool Interactions." *arXiv preprint* arXiv:2607.21835, 23 Jul. 2026. arXiv.org.

"ColluSkill: Adversarial Cross-Skill Composition for Evading Agent Skill Scanners." *arXiv preprint* arXiv:2608.09732, 10 Aug. 2026. arXiv.org.

@iamsrivastavabhi. "Google Zanzibar: Consistent, Globally Distributed, and Fine-Grained Access Control." *Google Research*, research.google/pubs/pub48190/. Accessed 20 Aug. 2026.

---

## Unarchived/Excluded

| Source | Reason |
|---|---|
| https://www.hcaptcha.com/what-is-authorization | trafilatura returned empty content (JS-gated page) |
| https://web3.storage/docs/concepts/capabilities/ | trafilatura returned 0 bytes (JS SPA page, needs crwl) |
