---
type: roadmap
---

# Build Order

> New to NATS? Read [[NATS in 5 Minutes]] first. **Build-step numbers below are not module numbers** — each step names its module explicitly.

| Step | Module | Focus |
|---|---|---|
| 1 | [[01 Request-Reply Helper]] | Synchronous request/reply over PUB+SUB — unlocks everything above |
| 2 | [[03 JetStream Management API]] | Create/inspect streams & consumers |
| 3 | [[04 JetStream Publishing]] | Store messages in a stream (sync first, then async) |
| 4 | [[05 JetStream Consuming]] — phase 1 | Pull consumers |
| 5 | [[05 JetStream Consuming]] — phase 2 | Push consumers + flow control |
| 6 | [[06 Key-Value Store]] | High user-facing value; exercises the whole stack |
| 7 | [[07 Object Store]] | Chunked blob storage |
| 8 | [[02 Authentication]] | NKey/JWT (decoupled — can slot in anytime; front-load the Ed25519 spike if deployments will require it) |
| 9 | [[08 Services Framework]] / [[09 Monitoring and Admin]] | Stretch goals, as time allows |

(Steps 4 and 5 are two phases of the single module [[05 JetStream Consuming]].)

## Rationale
The order follows the dependency chain in [[Layering Overview]], then optimizes for an early demo:
- **Step 1 is first** because modules 3–7 are all JSON request/reply and therefore all sit on the request/reply helper — nothing above works until it does.
- **Management → Publish → Consume (2→3→4/5)** is the natural lifecycle: you must be able to *create* a stream before you can *write* to it, and write before you can *read* — and each is easier to test once the previous one works.
- **Sync before async** (within Publish) and **pull before push** (within Consume): the synchronous/pull paths are fully buildable today and need no concurrency-model decision, whereas async publish and push delivery both depend on the deferred async-delivery-model decision (see [[Risks and Open Questions]]). Do the unblocked half first.
- **KV (6) before Object Store (7)** and before auth: KV reaches a demonstrably useful, demo-able milestone fastest and validates the entire stack beneath it; Object Store reuses the same patterns.
- **Auth (8) is deferred** because it's the one module with an unresolved *external* dependency (Ed25519 — see [[Risks and Open Questions]]) and it's decoupled from the messaging stack, so it never blocks the work above. Front-load only the Ed25519 spike if you already know production needs NKey/JWT.

#roadmap
