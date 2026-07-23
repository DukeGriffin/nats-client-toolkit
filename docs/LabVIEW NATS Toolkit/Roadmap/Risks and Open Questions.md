---
type: roadmap
---

# Risks & Open Questions

Rolling list — pulls in every `#question` tagged item from module notes plus cross-cutting concerns. Update as decisions are made; move resolved items into the relevant module's "Notes / decisions log" with a `#decision` tag.

> Status after the reference build-out (2026-07-23): the wire-level detail for every module is now documented in the module/reference notes, so most items below are no longer "unknowns" — they're **decisions to make** (options are laid out in the linked notes) or **spikes to run** (small things to verify against a live server or reference client before hard-coding). Grouped accordingly.

---

## Decisions to make (options documented — pick before the dependent module is built)

### Async delivery model — THE key cross-cutting decision
LabVIEW's dataflow/event paradigm vs. typical client-library callback/async-iterator models. One consistent pattern must be chosen because **push consumers ([[05 JetStream Consuming]]), KV watch ([[06 Key-Value Store]]), and Object Store watch/list ([[07 Object Store]]) all reuse it**, and async publish ack-correlation ([[04 JetStream Publishing]]) is coupled to it. Options A/B/C (Queue refnum + Notifier / Notifier-only / User Events) with trade-offs are written up in [[05 JetStream Consuming]]. Decide before building any of those. `#question`

### Error / result convention
Two distinct error shapes must be unified into one LabVIEW convention: Core NATS `-ERR` (string) vs. JetStream typed JSON `error {code, err_code, description}` (`err_code` is the stable programmatic id). Options A/B/C (standard LV error cluster + NATS code sub-field / dedicated NATS result cluster / hybrid) are in [[01 Request-Reply Helper]] and [[03 JetStream Management API]]. **Every module above module 1 inherits this** — decide before building CRUD VIs. `#question`
- Sub-question: should "no responders (503)" and "timeout" be the *same* error to callers or distinct outcomes? They mean different things and downstream retry logic may care ([[01 Request-Reply Helper]]).

### Subject prefix / domain support
`$JS.{domain}.API` vs `$JS.API`. Build a single API-prefix helper from the start (Option A, recommended for low cost) or bolt on later (Option B)? Affects every subject-construction VI in [[03 JetStream Management API]] and everything above. Note the documented caveat that `$JS.FC.*` flow-control subjects are **not** domain-prefixed. `#question`

### Ed25519 for NKey/JWT auth (the one genuine wire-level gap)
LabVIEW has no native Ed25519 primitive, needed to sign the server's connect-time nonce ([[02 Authentication]]). The signing sequence, NKey/creds formats, and three implementation paths — (a) .NET interop (BouncyCastle/NSec; `System.Security.Cryptography` added Ed25519 only in .NET 8+), (b) Call Library Function Node to a small native DLL (libsodium/monocypher), (c) pure-LabVIEW (high risk) — with pros/cons and a spike plan are now written up in [[02 Authentication]]. Decision left open. `#question`
- **Prior question, still worth confirming first:** do the target deployments even need NKey/JWT, or is TLS + token/user-pass sufficient? Answer this before sinking time into the Ed25519 spike. `#question`

### Async publish policy details ([[04 JetStream Publishing]])
- Ack-correlation model: per-publish inbox vs. shared inbox + token map; bounded (back-pressure) vs. unbounded in-flight window. Coupled to the async-delivery-model decision above. `#question`
- Adopt ADR-22 publish-retry-on-503 defaults (≈250 ms backoff, N attempts) for sync publish? Dedup window makes retries idempotent; the retry count/deadline is a toolkit policy choice. `#question`

### JSON handling at scale
LabVIEW's native JSON VIs (or a chosen JSON library) must comfortably round-trip the nested JetStream schemas. The heaviest real schemas are now documented (StreamConfig / ConsumerConfig ~30 fields each in [[JetStream Wire API]]) — **validate the JSON approach against a real `stream_info_response` before committing across the whole toolkit.** `#question`

---

## Spikes to run (verify against a live server or reference client before hard-coding)

### nats.lv READ semantics + demultiplexing — highest-impact unknown
`NATS SUB.vi` only registers a subscription; messages arrive by polling `NATS READ.vi`, which returns **one frame at a time off the shared socket for all subscriptions plus control frames — there is no queue/event/callback and no demux**. Consequences to confirm and design around (see [[Foundation - nats.lv]]):
- Does `READ` block until a full frame arrives, or return empty on timeout?
- Does auto-`PONG` fire inside `READ` (i.e. keep-alive only works while something is actively polling)?
- **Message routing by sid/subject is the toolkit's responsibility.** This lands in [[01 Request-Reply Helper]] (match a reply to its inbox) and is entangled with the async-delivery-model decision. Confirm READ's behavior before choosing that model.

### Exact nats.lv VI I/O ([[Foundation - nats.lv]])
`.vi` files are binary; several inputs/outputs are inferred from names, not the README: CONNECT auth/verbose inputs, PUB/HPUB reply-to and header encoding, `Publish (Polymorphic)` instance set, and the `nats message.ctl` / `nats connection.ctl` field layouts (does the connection carry last-INFO / a subscription table?). Confirm by opening the VIs in LabVIEW.

### Push-consumer flow control ([[05 JetStream Consuming]])
Is flow control (`$JS.FC.<stream>.>` + `100 FlowControl Request` replies) required for a v1 push consumer, or can push start without it (accepting stall risk under load) and add it later? Also confirm the non-domain-prefixed `$JS.FC` limitation before relying on push+FC across a domain boundary.

### JetStream 409 reason strings ([[05 JetStream Consuming]])
The pull-request `409` status reason strings ("Exceeded MaxWaiting", "Consumer Deleted", …) are server-version-dependent; don't hard-code an exhaustive set — match on code + treat reasons as informational.

---

## Resolved / decided

### ~~Chunk size vs max_payload~~ — RESOLVED
ADR-20 fixes the default Object Store chunk size at **128 KiB (131 072 bytes)**, deliberately below the default 1 MB `max_payload`; tunable per object via `options.max_chunk_size` but must stay under the negotiated server `max_payload`. See [[07 Object Store]]. #decision (from spec, not a toolkit choice)

### ~~KV/Object rollup config field & Object name/digest encoding~~ — RESOLVED
Confirmed against the jsm.go schema + nats.go source: the stream rollup config field is **`allow_rollup_hdrs`** (the ADRs' `rollup_hdrs` is outdated shorthand); the Object Store meta rollup uses the message header **`Nats-Rollup: sub`**; and the Object **name subject-token and digest value** use base64 URL-safe **with** padding (Go `base64.URLEncoding`) — e.g. digest `SHA-256=<base64url>`. (Contrast: the auth `sig` uses **no**-padding base64url.) See [[06 Key-Value Store]] · [[07 Object Store]] · [[ObjectInfo]]. #decision

---

## Out-of-scope (documented so they aren't mistaken for unknowns)
- Newer/edge StreamConfig fields (`placement`, `allow_atomic`, `allow_batched`, `allow_msg_counter`, `subject_delete_marker_ttl`, …) and ConsumerConfig fields (`pause_until`, `priority_*`, internal `direct`/`sourcing`) — treat as pass-through; don't model until a use case appears ([[JetStream Wire API]]).
- Batch-publish / counter PubAck fields (`batch`, `count`, `val`; ADR-49/50) — out of scope ([[04 JetStream Publishing]]).
- Services `SCHEMA` verb — dropped from current ADR-32; revisit only if needed ([[08 Services Framework]]).
- `$SYS.>` system-account monitoring — lowest priority; `/varz` + `$JS.EVENT.ADVISORY.>` likely suffice ([[09 Monitoring and Admin]]).

#roadmap
