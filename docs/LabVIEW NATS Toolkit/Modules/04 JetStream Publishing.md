---
type: module
status: planned
---

# 04 — JetStream Publishing

## Scope
- **Sync publish**: Request (not plain Publish) → server replies with an ack containing stream name + sequence number.
- **Async publish**: fire multiple requests without blocking on each ack; needs a pending-ack tracking structure (correlate outstanding requests to their eventual replies).
- **Headers**:
  - `Nats-Msg-Id` — dedup (server tracks within a configurable window, default 2 min)
  - `Nats-Expected-*` — optimistic concurrency (expected last sequence, expected stream, etc.)

## Depends on
- [[01 Request-Reply Helper]] (sync + async variants)
- [[03 JetStream Management API]] (shared error/response conventions)

## Docs
- `using-nats/developer/develop_jetstream/publish`
- `nats-concepts/jetstream/headers`

## Sync publish mechanism

JetStream publishing is **not** a distinct wire verb — it is a Core NATS `Request()` to a subject that some stream is configured to capture. The server (the stream leader) consumes the message and replies on the request inbox with a JSON **PubAck**. See [[01 Request-Reply Helper]] for the Request/inbox mechanics and [[JetStream Wire API]] for how this differs from the `$JS.API.*` management RPCs.

- **Plain message** → `PUB <subject> <inbox> <len>` (see [[Core NATS Protocol]]).
- **With publish headers** → `HPUB <subject> <inbox> <hdr_len> <tot_len>` — the `Nats-*` expectation/dedup headers ride here. Requires HPUB support in [[Foundation - nats.lv]] and the `NATS/1.0` header framing documented in [[Core NATS Protocol]].
- The server replies on `<inbox>` with a PubAck payload (a plain `MSG`, JSON body). A missing stream / not-ready leader surfaces as a **503 "no responders"** status reply, not a PubAck (see the retry note below). Source: `using-nats/developer/develop_jetstream/publish`.

### PubAck field table

Authoritative schema: `io.nats.jetstream.api.v1.pub_ack_response` (jsm.go `schemas/jetstream/api/v1/pub_ack_response.json`); also `reference/reference-protocols/nats_api_reference`.

| Field | Type | Meaning |
|-------|------|---------|
| `stream` | string (**required**, minLen 1) | Name of the stream that stored the message. |
| `seq` | uint64 | On success, the stream sequence the message was stored at. |
| `duplicate` | bool (default `false`) | `true` when the message was **not** stored because its `Nats-Msg-Id` matched an entry already in the duplicate-tracking window. |
| `domain` | string | Present when the accepting stream lives in a JetStream server configured with a domain. |
| `error` | object | Present only on failure (see error case below). Presence of `error` (vs. `stream`) is how a client distinguishes reject from success. |

Advanced / feature-gated fields also defined in the schema (out of scope for the first cut, listed so they are not mistaken for unknowns): `batch` + `count` (Atomic Batch Publishing, ADR-50), `val` (counter-enabled streams, ADR-49).

**Error object** (`error` present ⇒ publish was rejected, message not stored):

| Field | Type | Meaning |
|-------|------|---------|
| `code` | integer (300–699) | HTTP-like coarse error code. |
| `err_code` | integer (0–65535) | NATS-specific error code, unique per error kind (see [[03 JetStream Management API]] shared error conventions and ADR-7 "NATS Server Error Codes"). |
| `description` | string | Human-friendly description. |

### Example PubAcks

Success:
```json
{"stream":"ORDERS","seq":42,"domain":"hub"}
```

Duplicate (message suppressed by dedup window — note `seq` may be absent/0, `duplicate:true`):
```json
{"stream":"ORDERS","seq":42,"duplicate":true}
```

Rejected (e.g. failed expectation — wrong last sequence):
```json
{"stream":"ORDERS","error":{"code":400,"err_code":10071,"description":"wrong last sequence: 41"}}
```

### Worked example — publish with ack

One synchronous JetStream publish to stream `ORDERS`, carrying a dedup id, plus the PubAck reply (`\r\n` shown as `␍␊`). Also collected in [[Cookbook]].

```
# 1 · Publish via HPUB (carries the Nats-Msg-Id header) with a reply inbox · hdr=37 bytes, total=64 bytes
C→S  SUB _INBOX.y 1␍␊
C→S  HPUB ORDERS _INBOX.y 37 64␍␊
     NATS/1.0␍␊
     Nats-Msg-Id: order-1001␍␊
     ␍␊
     {"id":1001,"item":"widget"}␍␊

# 2 · Server stores it and replies on the inbox with a PubAck (a plain MSG, JSON body)
S→C  MSG _INBOX.y 1 43␍␊
     {"stream":"ORDERS","seq":42,"domain":"hub"}␍␊
```

Interpreting the reply (fields defined in [[PubAck]] — link, don't duplicate):

- `seq` present and **no** `error` → stored successfully at stream sequence 42. Success.
- Re-publishing the **same** `Nats-Msg-Id` inside the stream's duplicate window returns `{"stream":"ORDERS","seq":42,"duplicate":true}` (45 bytes) → treat as a **successful, idempotent** outcome, *not* an error (nothing was stored again). This is what makes the ADR-22 retry loop safe.
- An `error` object **instead of** `seq` → rejected, message not stored (see the rejected PubAck above).

## Publish headers

Set on the outgoing `HPUB`. Exact spelling matters — the server matches these case-sensitively, and per ADR-4 ("NATS Message Headers") NATS is **case-preserving**, so the toolkit must emit them verbatim. Header wire format (`NATS/1.0␍␊Key: Value␍␊␍␊`) is in [[Core NATS Protocol]]; HPUB framing support is a [[Foundation - nats.lv]] requirement. Source: `nats-concepts/jetstream/headers`.

| Header | Enforces | Server behavior on failure |
|--------|----------|----------------------------|
| `Nats-Msg-Id` | Client-defined unique message ID; server applies **de-duplication** within the stream's `Duplicate Window`. | Not an error — a duplicate is *accepted silently* and the PubAck comes back with `duplicate:true`. |
| `Nats-Expected-Stream` | Message must be landing on this exact stream name. | Publish **rejected** with a PubAck `error` if the capturing stream differs. |
| `Nats-Expected-Last-Sequence` | Optimistic concurrency at **stream** level: the stream's current last sequence must equal this value. | Rejected with `error` (`"wrong last sequence"`) if it does not match. |
| `Nats-Expected-Last-Subject-Sequence` | Optimistic concurrency at **subject** level: the last sequence *for this subject* must equal this value. | Rejected with `error` if it does not match. |
| `Nats-Expected-Last-Msg-Id` | Optimistic concurrency: the last stored message's `Nats-Msg-Id` must equal this value. | Rejected with `error` if it does not match. |

(The headers doc also lists `Nats-Expected-Last-Subject-Sequence-Subject`, `Nats-Rollup`, `Nats-TTL` — related but outside this module's publish-path scope; `Nats-TTL` is covered by ADR-43.)

## Deduplication window

- Deduplication is per-stream, keyed on `Nats-Msg-Id`, scoped to a rolling **`duplicate_window`** configured on the stream (see [[03 JetStream Management API]] stream config). Default window is **2 minutes** (`120s`).
- If a message with a `Nats-Msg-Id` seen within the window is republished, the server does **not** store it again and returns a PubAck with `duplicate:true` (the `seq` reflects that no new storage occurred). Callers must treat `duplicate:true` as a *successful, idempotent* outcome, not an error.
- This is the mechanism that makes the ADR-22 publish-retry loop safe: a retried publish that actually succeeded the first time comes back `duplicate:true` rather than double-storing.

## High-rate data: frame as blocks, not per-sample #decision
NATS never splits or merges payloads — **one `PUB` = one stored message = one delivered message**, and the payload is opaque bytes. So the *granularity* subscribers read is fixed at publish time; JetStream's pull `batch=N` fetches N **messages**, not "N data points" (see [[05 JetStream Consuming]]).

For high-rate acquisition (e.g. a DAQ at 10 kHz × 8 channels) do **not** publish one sample per message — that is 10,000 msg/s and a punishing per-message parse load on the LabVIEW read loop. Instead **publish a block per time window**: e.g. every 10 ms send one message carrying 100 samples × 8 channels. Same data, but ~100 msg/s of larger payloads, and a subscriber pulling `batch=10` gets 10 blocks = 8,000 points in 10 parses. Message framing is the single biggest throughput lever.

- **Encoding:** payload is opaque → use a compact **binary** encoding for a block (flattened array / typed record), not JSON — smaller and far cheaper to (de)serialize at rate. A 100×8 `float64` block is ~6.4 KB, well under `max_payload` (1 MB default; see [[Core NATS Protocol]]).
- **Ordering/identity:** JetStream stamps each message with a stream sequence and preserves order, so blocks stay in acquisition order and can be resumed from a known sequence.
- **Benchmark early:** the single-connection read loop's throughput at your real message rate/size is the thing to verify before committing the concurrency design — this is the `NATS READ.vi` semantics spike in [[Risks and Open Questions]]. Keep the read loop lean (read → route → enqueue) and fan processing out to worker loops (see the connection model in [[Library and Project Structure]]).

## Async publishing

The goal: keep many publishes **in flight** without blocking on each PubAck, correlating each reply to its originating publish. This is fundamentally the **async variant of Request/Reply** — it cannot be built until that exists. **Depends on** the async request variant in [[01 Request-Reply Helper]], and it is gated by the async-delivery-model decision tracked in [[Risks and Open Questions]] (the same reactor/notifier choice also drives async consumer delivery in [[05 JetStream Consuming]]).

Design options (not yet chosen — see #question below):
- **Correlation strategy**
  - *Per-publish inbox*: each publish gets its own unique reply inbox; the reply subject alone identifies the publish. Simple correlation, more subscriptions/inbox churn.
  - *Shared inbox + token*: one subscription on a wildcard inbox (e.g. `_INBOX.<base>.*`), a per-publish token in the last subject segment (or a `Nats-Msg-Id`/correlation token) maps the reply back to the pending publish. Fewer subscriptions, needs a token→pending map.
- **In-flight window**: a bounded max number of outstanding publishes (back-pressure) vs. unbounded with a "flush/wait-for-all" barrier (like Go's `PublishAsyncComplete`). Bounding protects memory and bounds recovery work on error.
- **Pending-ack structure**: a map/queue of outstanding publishes → their inbox/token, drained by a background reply handler that resolves each entry (success/duplicate/error) and enforces a **client-side per-request publish timeout** (how long we wait for a PubAck before giving up/retrying). Note this is *not* the consumer `ack_wait` setting from [[05 JetStream Consuming]] — that governs message redelivery on the consume side and has nothing to do with the publish path.

## Open questions
- #question Async publish tracking structure — queue of pending inbox subjects + a background handler, or notifier-per-request? Decide once, reuse pattern for async consumer delivery too (see [[05 JetStream Consuming]]).
- #question Async ack-correlation model — **per-publish inbox** vs. **shared inbox + token map** — plus whether the in-flight window is **bounded** (back-pressure) or unbounded-with-barrier. Leave as a question; it is coupled to the async-delivery-model decision in [[Risks and Open Questions]] and must stay consistent with [[01 Request-Reply Helper]] and [[05 JetStream Consuming]]. (`#question`, not `#decision`.)
- #question Adopt the ADR-22 publish-retry-on-503 behavior (default 250 ms backoff, N attempts) for sync publish? Dedup window makes retries idempotent, but the retry count/deadline defaults are a toolkit policy choice.

## Notes / decisions log
-

## Sources
- [Develop JetStream — Publishing](https://docs.nats.io/using-nats/developer/develop_jetstream/publish)
- [JetStream headers (NATS concepts)](https://docs.nats.io/nats-concepts/jetstream/headers)
- [NATS JetStream API reference](https://docs.nats.io/reference/reference-protocols/nats_api_reference)
- [pub_ack_response.json (jsm.go)](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/pub_ack_response.json)
- [ADR-4 — NATS Message Headers](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-4.md)
- [ADR-7 — NATS Server Error Codes](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-7.md)
- [ADR-22 — JetStream publish retries](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-22.md)
- [ADR-43 — per-message TTL](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-43.md)
- [ADR-49 — counter-enabled streams](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-49.md)
- [ADR-50 — Atomic Batch Publishing](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-50.md)
