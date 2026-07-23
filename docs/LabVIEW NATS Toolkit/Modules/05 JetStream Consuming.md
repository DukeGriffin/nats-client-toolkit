---
type: module
status: planned
---

# 05 — JetStream Consuming

> **Buildability:** Pull consumers are fully buildable from this note today; only the *async push delivery* mechanism awaits the deferred async-primitive decision. The open `#question`s below scope that one mechanism — they do not block the module. New to NATS? Start with [[NATS in 5 Minutes]] and the [[Glossary]].

## Scope
- **Pull consumers**: explicit `CONSUMER.MSG.NEXT` requests. Simpler model — good first target within this module.
- **Push consumers**: server streams messages to a delivery subject you subscribe to; needs flow-control subject handling (`$JS.FC.<stream>.>`) so the consumer doesn't stall under high load.
- **Ack policies** (consumer-config `ack_policy` — see [[ConsumerConfig]]): `none` / `all` / `explicit` · sets *how many* acks the server requires · one setting per consumer.
- **Per-message ack tokens** (the bytes you PUB to a delivered message's reply subject): `+ACK` / `-NAK` / `+WPI` / `+TERM` / `+NXT` · one token per message · detailed in [[#Acknowledgement protocol]].
- **Consumer lifecycle**: ephemeral (exists only while a subscription is active on its delivery subject, auto-removed after a grace period) vs. durable (persists across disconnects).

**Pull vs push — which to pick:** choose **pull** when the LabVIEW loop should control its own pace / you want built-in backpressure (the loop asks for the next batch only when ready). Choose **push** for low-latency fan-out and queue-group load balancing across multiple subscribers.

## Depends on
- [[01 Request-Reply Helper]]
- [[03 JetStream Management API]] (consumer create/info)

## Used by
- [[06 Key-Value Store]] (watch = a push consumer under the hood)
- [[07 Object Store]] (reuses the same push-consumer patterns)

## Docs
- `using-nats/developer/develop_jetstream/model_deep_dive` — best conceptual walkthrough of ack modes and ephemeral vs. durable
- `using-nats/developer/develop_jetstream/consumers`

## Open questions
- #question Async consumer delivery model for push consumers — LabVIEW's dataflow/event paradigm vs. typical client-library callback/async-iterator models. Candidates: queue refnum + notifier, or user events. **Decide before building KV watch or Object Store**, since both reuse this pattern — see [[Risks and Open Questions]].
- #question Flow control: is it required for v1, or can push consumers start without it (accepting stall risk under high load) and add it later?

## Notes / decisions log
-

---

# Wire-protocol reference

> Verified against: NATS docs `develop_jetstream/model_deep_dive`, `develop_jetstream/consumers`; JetStream Wire API Reference (`reference/reference-protocols/nats_api_reference`); ADR-9 (JetStream Consumer Idle Heartbeats), ADR-13 (Pull Subscribe internals); ack byte constants confirmed against `nats.go/jetstream/message.go`. See [[JetStream Wire API]] for shared subject/header conventions.
>
> Note on ADR numbering: the consumer *config* / pull mechanics live in **ADR-13**, and idle-heartbeat behaviour in **ADR-9** — ADR-9 is *not* the general consumer-config ADR.

## Pull consumers — create the consumer first

MSG.NEXT only works against a consumer that already exists, so **create it before you pull**. Create (or idempotently re-assert) the consumer by PUBlishing a request body to:

```
$JS.API.CONSUMER.CREATE.<stream>              # server picks/uses the name in the config
$JS.API.CONSUMER.CREATE.<stream>.<consumer>   # name pinned in the subject
```

The request body is `{"stream_name":"<stream>","config":{…}}` where `config` is a [[ConsumerConfig]]. Minimal pull config:

```json
{
  "durable_name": "order-workers",
  "ack_policy": "explicit"
}
```

- `durable_name` — makes it durable (survives disconnects) and is the `<consumer>` you address in MSG.NEXT.
- `ack_policy: explicit` — the **only** policy valid for pull consumers.
- **No `deliver_subject`** — its *absence* is what makes the consumer pull rather than push (see [[ConsumerConfig]]).

The full create/response mechanics (`$JS.API.*` request framing, error shape, [[ConsumerInfo]] reply) live in [[03 JetStream Management API]] — link there, don't rebuild it here. Once the consumer exists, pull with MSG.NEXT below.

## Pull consumers — the NEXT request

A pull consumer delivers nothing until the client asks. The client publishes a **pull-next request** to:

```
$JS.API.CONSUMER.MSG.NEXT.<stream>.<consumer>
```

with a **reply inbox** as the NATS reply subject. **The JSON request body below is the PUB payload** — you `PUB $JS.API.CONSUMER.MSG.NEXT.<stream>.<consumer> <inbox> <len>` and the `{"batch":…}` JSON is the message body; the `<inbox>` reply subject is where replies land. The server delivers up to `batch` messages to that inbox, then (optionally) a status message. (ADR-13; JetStream Wire API Reference.) This is a normal Core-NATS publish with reply, so it reuses [[01 Request-Reply Helper]] except that **one request yields many replies** — the helper must not close the inbox after the first message.

### Pull-next request body (JSON)

| Field | Type | Meaning |
|-------|------|---------|
| `batch` | int | Max messages to deliver for this request (min 1). |
| `expires` | int (ns) | How long the server parks this request as a "waiting pull" before returning `408`. Set to *slightly less* than the client-side timeout (docs suggest client timeout minus a small buffer). `<= 0` = no expiry (not recommended). |
| `max_bytes` | int (bytes) | Cap on total bytes delivered; the request ends when `batch` **or** `max_bytes` is hit first (nats-server 2.9+). |
| `no_wait` | bool | Return immediately: if messages are available send up to `batch`, otherwise send `404 No Messages` rather than parking the request. |
| `idle_heartbeat` | int (ns) | During a long (`expires`) pull, if idle this long the server emits a `100 Idle Heartbeat` so the client can tell the request is still alive (ADR-9). |

Only `batch`, `expires`, `no_wait` are in the original ADR-13; `max_bytes` and `idle_heartbeat` were added by later server versions (docs `nats-concepts/jetstream/consumers`).

### Reply flow

1. Zero or more **data messages** arrive on the inbox. Each carries a `$JS.ACK.…` reply subject (see grammar below).
2. Optionally a **status message** terminates the batch. Status messages carry **no reply subject** and convey the outcome in headers (a `NATS/1.0 <code> <description>` status line), so the client distinguishes "message" from "status" by presence of headers / absence of a reply subject.

**Batch-completion logic** (when to stop reading the inbox for one request):

- The batch is **done** when you have received `batch` **data** messages, **or** a `404` / `408` status message arrives.
- A `100` idle-heartbeat status message means "still alive, keep waiting" — it must **not** be counted toward `batch` and does not end the request.
- Count only *data* messages (those with a `$JS.ACK.…` reply subject) toward `batch`; never count status messages. This is the key correctness rule for a LabVIEW pull loop: a naive "count every reply" will end the batch early on the first heartbeat.

### Status messages (headers, not payload)

| Code | Description | When |
|------|-------------|------|
| `100` | `Idle Heartbeat` / `FlowControl Request` | Keepalive during a long pull, or push-consumer flow control. |
| `404` | `No Messages` | `no_wait` request with nothing pending. |
| `408` | `Request Timeout` | `expires` elapsed before `batch` filled. |
| `409` | e.g. `Exceeded MaxWaiting`, `Exceeded MaxRequestBatch`, `Exceeded MaxRequestExpires`, `Exceeded MaxRequestMaxBytes`, `Message Size Exceeds MaxBytes`, `Consumer Deleted`, `Consumer is push based`, `Server Shutdown`, `Leadership Change` | Request violates a consumer limit, or the consumer/server state changed. |

(Codes 404/408/100 from ADR-13 + ADR-9; 409 reason strings confirmed against nats-server behaviour and client reports — treat the exact 409 reason text as server-version-dependent.)

Recommended client pattern (ADR-13): optionally a `no_wait` probe, then a "long pull" with `expires` set to the client timeout minus a small buffer.

## Acknowledgement protocol

Acks are sent by **publishing a payload to the received message's reply subject** (`$JS.ACK.…`). The literal bytes (confirmed in `nats.go/jetstream/message.go` and `model_deep_dive`):

| Intent | Literal payload | Notes |
|--------|-----------------|-------|
| Ack (AckAck) | `+ACK` | Positive ack. An empty/`nil` body is also treated as an ack. |
| Negative ack (AckNak) | `-NAK` | Redeliver. Delayed redelivery: `-NAK {"delay": <ns>}` (JSON body appended after a space; `<ns>` = delay in nanoseconds). |
| In progress (AckProgress) | `+WPI` | "Work in progress" — resets/extends the redelivery timer by another `ack_wait`; does **not** acknowledge. |
| Terminate (AckTerm) | `+TERM` | Stop redelivery without marking success. With reason: `+TERM <reason>` (free-text reason appended after a space). |
| Ack + next (AckNext) | `+NXT` | Ack this message **and** request the next — pull-mode only. |

`+ACK` can be sent fire-and-forget, or as a request/reply ("AckSync") when you need server confirmation the ack landed — that path reuses [[01 Request-Reply Helper]].

### AckPolicy interplay (consumer config `ack_policy`)

| `ack_policy` | Behaviour |
|--------------|-----------|
| `none` | Server treats every message as delivered/acked immediately; sending acks is meaningless. No redelivery. |
| `all` | Acking sequence *N* implicitly acks all messages `1..N` — good for batch processing, lower ack overhead. |
| `explicit` | Every message must be acked individually. **Only** mode allowed for pull consumers. |

### Redelivery / backpressure config

- `ack_wait` (ns) — how long the server waits for an ack before redelivering. `+WPI` extends it.
- `max_deliver` — maximum delivery attempts; once exhausted the server stops redelivering (and can emit a `max deliveries` advisory). `-1` = unlimited.
- `max_ack_pending` — cap on **unacknowledged in-flight** messages. When reached the server stops delivering until acks catch up. This is the primary backpressure lever and matters a lot for LabVIEW, where ack publishing may lag behind a slow consumer loop.

## `$JS.ACK` reply-subject grammar

Every delivered JetStream message carries a structured reply subject encoding its stream metadata. The client parses it to know the sequence and redelivery count — no extra round-trip needed.

**Standard (v1, 9 tokens):**

```
$JS.ACK.<stream>.<consumer>.<delivered>.<stream_seq>.<consumer_seq>.<timestamp>.<pending>
```

| Token | Meaning |
|-------|---------|
| `$JS` / `ACK` | Fixed prefix (2 tokens). |
| `<stream>` | Stream name. |
| `<consumer>` | Consumer name. |
| `<delivered>` | Delivery count for this message (1 = first delivery; >1 = redelivery). |
| `<stream_seq>` | Message's sequence in the stream. |
| `<consumer_seq>` | Message's sequence for this consumer. |
| `<timestamp>` | Delivery timestamp (ns since epoch). |
| `<pending>` | Messages remaining to be delivered (num pending). |

**Domain-prefixed (v2, 12 tokens):** when a JetStream domain / account hashing is in play, two tokens are inserted after the prefix and a trailing random token is appended:

```
$JS.ACK.<domain>.<account_hash>.<stream>.<consumer>.<delivered>.<stream_seq>.<consumer_seq>.<timestamp>.<pending>.<random>
```

Clients disambiguate by **token count**: split on `.` → 9 tokens = v1, 12 tokens = v2 (domain at index 2, account hash at index 3, trailing token ignored). The LabVIEW parser must handle both counts. (JetStream Wire API Reference; token layout confirmed against `nats.go` metadata parsing.)

## Worked example — pull consumer, end to end

Real frames for one full cycle against stream `ORDERS`, durable pull consumer `order-workers` (`\r\n` shown as `␍␊`). Also collected in [[Cookbook]].

```
# 1 · Create the pull consumer (request/reply — see [[01 Request-Reply Helper]], [[03 JetStream Management API]])
C→S  SUB _INBOX.create 1␍␊
C→S  PUB $JS.API.CONSUMER.CREATE.ORDERS.order-workers _INBOX.create 90␍␊
     {"stream_name":"ORDERS","config":{"durable_name":"order-workers","ack_policy":"explicit"}}␍␊
S→C  MSG _INBOX.create 1 <n>␍␊
     {"type":"io.nats.jetstream.api.v1.consumer_create_response", …}␍␊     # body is a ConsumerInfo — see [[ConsumerInfo]]

# 2 · Ask for a batch of 2 · the JSON below IS the PUB payload · reply inbox = where messages land
C→S  SUB _INBOX.pull 2␍␊
C→S  PUB $JS.API.CONSUMER.MSG.NEXT.ORDERS.order-workers _INBOX.pull 32␍␊
     {"batch":2,"expires":5000000000}␍␊

# 3 · Two data messages arrive on the inbox · each carries a $JS.ACK.… reply subject
S→C  MSG orders.new 2 $JS.ACK.ORDERS.order-workers.1.42.1.1737550000000000000.1 27␍␊
     {"id":1001,"item":"widget"}␍␊
S→C  MSG orders.new 2 $JS.ACK.ORDERS.order-workers.1.43.2.1737550000000000000.0 27␍␊
     {"id":1002,"item":"gadget"}␍␊

# 4 · Ack each message by PUBlishing +ACK to ITS reply subject
C→S  PUB $JS.ACK.ORDERS.order-workers.1.42.1.1737550000000000000.1 4␍␊+ACK␍␊
C→S  PUB $JS.ACK.ORDERS.order-workers.1.43.2.1737550000000000000.0 4␍␊+ACK␍␊

# Batch complete: 2 data messages received = requested `batch`. Loop to step 2 for the next batch.
# (A 100 heartbeat here would NOT count; a 404/408 status frame would end the batch early.)
```

Reply-subject tokens decode via [[#`$JS.ACK` reply-subject grammar]]: e.g. `…1.42.1.…1` = delivered 1× · `stream_seq` 42 · `consumer_seq` 1 · 1 pending; the second message shows `stream_seq` 43 · `consumer_seq` 2 · 0 pending (last of the batch).

## Push consumers

A consumer becomes **push** when its config sets `deliver_subject`. The server publishes matching messages to that subject; the client simply **subscribes** to it (Core-NATS SUB). Adding a `deliver_group` (queue group) load-balances across subscribers. Acks work exactly as above (publish to the message's `$JS.ACK` reply subject).

### Flow control + idle heartbeats

Set `flow_control: true` together with `idle_heartbeat` (ns) on the consumer. The server interleaves **flow-control control messages** on:

```
$JS.FC.<stream>.>
```

A FC message arrives with a reply subject and header `NATS/1.0 100 FlowControl Request`; the client **must reply** to it (empty payload) to signal it has drained the buffered window and can accept more — failing to do so stalls delivery. Idle heartbeats (`100 Idle Heartbeat`, carrying `Nats-Last-Consumer` and `Nats-Last-Stream` headers, ADR-9) let the client detect a silent disconnect.

- #question **Non-domain-prefixed FC limitation** — the `$JS.FC` flow-control subject is published on the stream's account/domain and is *not* rewritten with the JetStream domain prefix that a leaf-node client uses for the `$JS.API` surface. For push consumers on a stream inside a JetStream **domain** (leaf nodes), the FC reply subject may therefore be unreachable, so flow-controlled push consumers across a domain boundary are a known problem area. **Verify the exact current behaviour** against the docs/ADR before relying on push+FC across domains — this is another reason pull may be the safer v1 target. See [[Risks and Open Questions]].

## "Ordered consumer" — the wire recipe behind KV/Object watch & reads

Client libraries expose an *ordered consumer* / `OrderedConsumer` type; **it is not a wire construct** — it is a client-side pattern that [[06 Key-Value Store]] (watch, history, keys) and [[07 Object Store]] (chunk reads, watch, list) all lean on, so the toolkit must build it once from the frames in [[Layering Overview]]. The recipe:

1. **Create an ephemeral push consumer** via `$JS.API.CONSUMER.CREATE.<stream>` (no `durable_name`) with a config tuned for single-reader, no-ack, gap-detectable delivery:
   - `deliver_subject` = a fresh inbox we `SUB` to (push).
   - `ack_policy: "none"` — **we never publish acks** for an ordered consumer.
   - `max_deliver: 1`, `replay_policy: "instant"`, `mem_storage: true`, `num_replicas: 1`.
   - `flow_control: true` + `idle_heartbeat: <ns>` — so we get `100` control frames (reply to FC as above) and can detect a silent stall.
   - `deliver_policy` per use case: `all` (history), `last_per_subject` (watch initial values), or `by_start_sequence` + `opt_start_seq` (resume).
2. **`SUB` to the deliver subject** and read `MSG`/`HMSG` frames off the poll loop like any other subscription.
3. **Track the consumer sequence** from each message's `$JS.ACK.…` reply subject (the `<consumer_seq>` token). Because there are no acks and `max_deliver: 1`, the server sends each message exactly once in order.
4. **Gap detection = the whole point:** watch the two sequence tokens for *different* jobs — detect gaps on `<consumer_seq>` (the per-consumer counter, which increments by exactly 1 per delivered message so a skip is unambiguous), but resume via `opt_start_seq` using `<stream_seq>` (because `opt_start_seq` addresses a position in the *stream*, not the consumer). So: if the received `<consumer_seq>` skips (e.g. we fell behind and the server's delivery outran us, or the connection blipped), tear down and **recreate** the consumer with `deliver_policy: by_start_sequence`, `opt_start_seq` = last-good `<stream_seq>` + 1, and resume. This self-heals ordered delivery without ack bookkeeping.

So wherever these notes say "ordered consumer," read it as *"the CONSUMER.CREATE config above + a SUB + sequence-gap watch,"* all expressed in `PUB`/`SUB`/`MSG` frames — no library type involved. For a first cut, a plainer ephemeral consumer (even a pull consumer draining to completion) is a valid simpler substitute; the ordered-consumer machinery is the optimization for long-lived watches.

## LabVIEW async delivery model — needs a shared pattern

Push delivery, pull idle-heartbeat handling, KV `watch`, and Object Store all share the same shape: **an async stream of server-initiated messages** arriving on a subscription, decoupled from the caller's request. LabVIEW has no callbacks/async-iterators, so we need one house pattern reused by this module, [[06 Key-Value Store]] and [[07 Object Store]].

- #question **Which async delivery primitive?** Options and trade-offs (DECISION deferred to the user — see [[Risks and Open Questions]]):

| Option | How | Pros | Cons |
|--------|-----|------|------|
| **A. Subscriber loop → Queue refnum** | One loop owns the SUB and enqueues parsed messages; a consumer loop dequeues, processes, and acks. | Natural producer/consumer; lossless buffering; backpressure maps to `max_ack_pending`; easy to bound. | Two loops + lifecycle/teardown to manage; queue refnum plumbing through the API. |
| **B. Notifier** | Subscriber posts the latest message to a Notifier the caller waits on. | Simplest; good for "latest value" (e.g. KV latest). | Lossy — misses intervening messages; wrong for durable/at-least-once consuming. |
| **C. User Events** | Subscriber fires a User Event; caller handles it in an Event Structure. | Integrates with UI event loop; multiple registrants; idiomatic for GUIs. | Event queue is unbounded (memory risk under load); harder to apply consumer-side backpressure; couples toolkit to Event Structure usage. |

Leaning (not a decision): **A (Queue + a control Notifier for shutdown)** as the general-purpose consuming primitive, with B reserved for KV latest-value reads. Confirm before building KV watch, since both reuse it. Cross-link [[Risks and Open Questions]].

## Sources
- [Develop JetStream — Model deep dive](https://docs.nats.io/using-nats/developer/develop_jetstream/model_deep_dive)
- [Develop JetStream — Consumers](https://docs.nats.io/using-nats/developer/develop_jetstream/consumers)
- [Consumers (NATS concepts)](https://docs.nats.io/nats-concepts/jetstream/consumers)
- [NATS JetStream API reference](https://docs.nats.io/reference/reference-protocols/nats_api_reference)
- [ADR-9 — JetStream consumer idle heartbeats](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-9.md)
- [ADR-13 — JetStream pull subscribe internals](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-13.md)
- [nats.go reference client](https://github.com/nats-io/nats.go)
