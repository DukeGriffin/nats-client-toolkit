---
type: reference
source: https://docs.nats.io/reference/reference-protocols/nats_api_reference
---

# JetStream Wire API

> **What this note is for** · the *subjects* JetStream admin calls ride on, the shared *response envelope*, and a one-line purpose per operation · **not** here: full field tables (canonical: [[StreamConfig]] / [[ConsumerConfig]] / [[Schema Catalog]]) · operation→schema-file manifest (see [[JetStream JSON Schemas]]) · the LabVIEW module scope (see [[03 JetStream Management API]])

New to NATS? Start with [[NATS in 5 Minutes]]; unfamiliar terms are in the [[Glossary]].

## Concepts

- **Stream** — a durable, append-only log of messages captured from a set of matching subjects. It persists messages independently of who is (or isn't) listening.
- **Consumer** — a named, server-side read cursor over one stream. *Durable* consumers survive disconnects; *ephemeral* ones vanish when their subscription ends. *Pull* consumers fetch batches on demand; *push* consumers have the server deliver to a subject you subscribe to.
- **JetStream** — the persistence layer on top of Core NATS. It is exposed as ordinary JSON request/reply over Core NATS subjects (the `$JS.API.*` admin subjects below) — no new wire protocol.
- **Domain** — an isolated JetStream instance (e.g. a leaf node / edge site). It changes the admin subject prefix from `$JS.API` to `$JS.{domain}.API`; everything else is identical (see [[#Domain prefixing]]).

## Core mechanism
- JetStream-enabled `nats-server`s expose a set of services over **Core NATS** — same TCP/pub-sub wire protocol nats.lv already implements, just structured JSON request/reply on specific subjects.
- Admin subjects: `$JS.API.STREAM.*`, `$JS.API.CONSUMER.*` (e.g. `$JS.API.STREAM.LIST`, `$JS.API.STREAM.INFO.<stream>`).
- Domain-scoped deployments: subject prefix becomes `$JS.{domain}.API` instead of `$JS.API`. Relevant for leaf nodes / multi-tenant deployments — see [[02 Authentication]] open question on domain support.
- Subjects ending in `T` (e.g. `JSApiConsumerCreateT`) are **format strings** needing stream/consumer names interpolated in.

## Request/response conventions
- Admin APIs respond with standardized JSON, including a `type` field (e.g. `io.nats.jetstream.api.v1.stream_info_response`) identifying the response schema.
- Non-admin APIs (e.g. adding a message to a stream) respond with `+OK` or `-ERR` with an optional reason.
- Errors: JSON Schema repo at `nats-io/jsm.go/schemas` (upstream Go project — reference only, not something to depend on directly from LabVIEW, but useful for confirming field names/types).

## Admin subject reference

Every admin call is a Core NATS request/reply: publish the JSON request body (or empty for the info/delete-style calls) to the subject with a reply inbox, and parse the JSON response. `%s` / `<...>` tokens are interpolated (stream name, consumer name). All subjects below are prefixed with `$JS.API.` (or `$JS.{domain}.API.` — see [[#Domain prefixing]]).

Source: [ADR-1](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-1.md) (JetStream JSON API design) and the [Wire API reference](https://docs.nats.io/reference/reference-protocols/nats_api_reference). Payload struct names are as used in `jsm.go`.

Each row's **What it does** is a one-liner. The operation→schema-file manifest is in [[JetStream JSON Schemas]]; per-field type docs (every field with type / required / default) are in [[Schema Catalog]] and the individual type pages ([[StreamConfig]], [[ConsumerConfig]], [[StreamInfo]], …).

### Account / info
| Subject | What it does | Request body | Response `type` |
|---|---|---|---|
| `$JS.API.INFO` | Report JetStream account usage/limits; also confirms JetStream is enabled. | none (empty / `{}`) | `io.nats.jetstream.api.v1.account_info_response` |

### Stream CRUD
| Subject | What it does | Request body | Response `type` |
|---|---|---|---|
| `$JS.API.STREAM.CREATE.<name>` | Create a new stream (errors if it exists). | `StreamConfig` (required) | `...stream_create_response` → [[StreamInfo]] |
| `$JS.API.STREAM.UPDATE.<name>` | Change an existing stream's config (some fields immutable). | `StreamConfig` (required) | `...stream_update_response` → [[StreamInfo]] |
| `$JS.API.STREAM.INFO.<name>` | Read a stream's config + runtime state. | none (optional `JSApiStreamInfoRequest` for subject/paging detail) | `...stream_info_response` → [[StreamInfo]] |
| `$JS.API.STREAM.DELETE.<name>` | Delete the stream and all its messages (irreversible). | none | `...stream_delete_response` |
| `$JS.API.STREAM.LIST` | Page through full configs+state of all streams. | `JSApiStreamListRequest` (paging: `offset`) | `...stream_list_response` (full configs) |
| `$JS.API.STREAM.NAMES` | Page through stream names only; `subject` filter finds the owning stream. | `JSApiStreamNamesRequest` (paging, optional `subject` filter) | `...stream_names_response` (names only) |
| `$JS.API.STREAM.PURGE.<name>` | Delete messages (by subject / up-to-seq / keep-N) without deleting the stream. | optional `JSApiStreamPurgeRequest` (`filter`, `seq`, `keep`) | `...stream_purge_response` |
| `$JS.API.STREAM.MSG.GET.<name>` | Read one stored message by seq or last-by-subject, no consumer. | `JSApiMsgGetRequest` (`seq` or `last_by_subj`) | `...stream_msg_get_response` |
| `$JS.API.STREAM.MSG.DELETE.<name>` | Delete/erase one stored message by sequence. | `JSApiMsgDeleteRequest` (`seq`, optional `no_erase`) | `...stream_msg_delete_response` |

The CREATE / UPDATE / INFO response body **is** a [[StreamInfo]] (`config` echoing what the server stored + runtime `state`) wrapped in the standard envelope — same payload for all three, so decode it once and reuse

### Consumer CRUD
| Subject | What it does | Request body | Response `type` |
|---|---|---|---|
| `$JS.API.CONSUMER.CREATE.<stream>` | Create a consumer (durable/ephemeral, push/pull per config). | `ConsumerConfig` wrapped in `{stream_name, config}` | `...consumer_create_response` → [[ConsumerInfo]] |
| `$JS.API.CONSUMER.DURABLE.CREATE.<stream>.<consumer>` | Legacy durable-only create path. | `ConsumerConfig` wrapped (legacy durable-only path) | `...consumer_create_response` → [[ConsumerInfo]] |
| `$JS.API.CONSUMER.INFO.<stream>.<consumer>` | Read a consumer's config + state (delivered/ack sequences, pending). | none | `...consumer_info_response` → [[ConsumerInfo]] |
| `$JS.API.CONSUMER.DELETE.<stream>.<consumer>` | Delete the consumer and its durable state. | none | `...consumer_delete_response` |
| `$JS.API.CONSUMER.LIST.<stream>` | Page through full consumer configs+state on a stream. | `JSApiConsumerListRequest` (paging) | `...consumer_list_response` (full configs) |
| `$JS.API.CONSUMER.NAMES.<stream>` | Page through consumer names only on a stream. | `JSApiConsumerNamesRequest` (paging) | `...consumer_names_response` (names only) |
| `$JS.API.CONSUMER.MSG.NEXT.<stream>.<consumer>` | Pull the next batch of messages for a pull consumer (delivered to the reply inbox). | numeric batch **or** JSON pull request (`batch`, `expires`, `max_bytes`, `no_wait`) | streamed messages, not an envelope — see [[05 JetStream Consuming]] |

The CREATE / INFO response body **is** a [[ConsumerInfo]] (`config` + runtime `state`) wrapped in the standard envelope

Notes:
- `CONSUMER.CREATE.<stream>` is the modern path used by current clients for both durable and ephemeral consumers (durability is decided by whether `durable_name`/`name` is set in the config). Newer servers also accept a filtered variant `$JS.API.CONSUMER.CREATE.<stream>.<consumer>.<filter>`. The `CONSUMER.DURABLE.CREATE` subject is the older, durable-only form kept for compatibility — this affects the helper-VI decision in [[03 JetStream Management API]].
- Additional non-CRUD subjects exist (`STREAM.SNAPSHOT/RESTORE`, `STREAM.PEER.REMOVE`, `*.LEADER.STEPDOWN`, `CONSUMER.PAUSE`) — out of scope for the management module but documented in ADR-1.

## Standardized response envelope

Every admin response is JSON carrying a `type` field. Type values live in the `io.nats.jetstream.api.v1.*` namespace and name the schema (see tables above). Success and error share one envelope; **presence of the `error` object is the discriminator** (ADR-1):

```json
{
  "type": "io.nats.jetstream.api.v1.stream_info_response",
  "error": {
    "code": 404,
    "err_code": 10059,
    "description": "stream not found"
  }
}
```

Error object shape (ADR-1):
| Field | Type | Meaning |
|---|---|---|
| `code` | integer | HTTP-style class (e.g. 400, 404, 500). |
| `err_code` | integer | Unique NATS-specific error identifier (stable across versions; use this, not the string, for programmatic branching). |
| `description` | string | Human-readable message. |

- List/names responses are paged and add `total`, `offset`, `limit`.
- Parsing rule for the toolkit:
  1. **Before parsing JSON, check for no-responders.** An empty reply carrying header `Nats-Status: 503` (or a request timeout with no reply at all) means *no service answered* — JetStream not enabled on the account, or the subject was wrong. Treat as a transport-level "retry / check config" condition, **not** a JetStream `error` object (there is no JSON body to parse).
  2. Otherwise decode the JSON, read `type`, then check for `error`. If present → typed JetStream error (see [[ApiError]] for the object shape); if absent → decode the success payload for that `type`.

## Worked example: create a stream → confirm it worked

A full round-trip using only Core NATS request/reply. Also collected in the [[Cookbook]].

**1. Create.** PUBlish the [[StreamConfig]] as the request body to `$JS.API.STREAM.CREATE.ORDERS`, with a reply inbox subscribed:

```json
{
  "name": "ORDERS",
  "subjects": ["orders.>"],
  "retention": "limits",
  "max_consumers": -1,
  "max_msgs": -1,
  "max_bytes": -1,
  "max_age": 0,
  "storage": "file",
  "num_replicas": 3
}
```

**2. Read the reply.** The server answers on the reply inbox with a `stream_create_response` — which **is** a [[StreamInfo]] (envelope + `config` + `state`):

```json
{
  "type": "io.nats.jetstream.api.v1.stream_info_response",
  "config": {
    "name": "ORDERS",
    "subjects": ["orders.>"],
    "retention": "limits",
    "max_consumers": -1,
    "max_msgs": -1,
    "max_bytes": -1,
    "max_age": 0,
    "storage": "file",
    "num_replicas": 3
  },
  "state": {
    "messages": 0,
    "bytes": 0,
    "first_seq": 0,
    "last_seq": 0,
    "consumer_count": 0
  },
  "created": "2026-07-23T10:15:00Z"
}
```

**3. Confirm success.** Apply the parsing rule above: no `Nats-Status: 503` (a service answered), and **no `error` object** in the body → success. The returned `config` echoes what the server actually stored (defaults filled in), and `state` shows the fresh stream (`messages: 0`). If instead an `error` object is present, branch on its `err_code` (see [[ApiError]]).

**4. (Optional) Re-check later.** Send an empty request to `$JS.API.STREAM.INFO.ORDERS`; the reply is another [[StreamInfo]] with the current `state` (e.g. `messages` climbing as `orders.*` are published).

## Config bodies (field detail elsewhere)

The two big request bodies are documented field-by-field on their canonical type pages — not duplicated here:

- **StreamConfig** — body for `STREAM.CREATE` / `STREAM.UPDATE`. Every field, enum, default, and constraint: [[StreamConfig]] (incl. the stream-name-rule reconciliation).
- **ConsumerConfig** — body for `CONSUMER.CREATE`, wrapped as `{ "stream_name": "...", "config": { …ConsumerConfig… } }`. Every field, enum, default: [[ConsumerConfig]].

Note on the stream-name rule (two layers, not a contradiction): the JSON-schema pattern is `^[^.*>]*$` with **no length limit** at the API layer, while [ADR-6](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-6.md)'s "≤255 chars, no `/` `\`" is the server-side *naming* rule enforced on top — full write-up on [[StreamConfig]]

## Domain prefixing

- Default admin prefix is `$JS.API.*`. In a JetStream **domain** deployment (leaf nodes, isolated JetStream per site), the prefix becomes `$JS.{domain}.API.*` — every admin subject above is rewritten with the domain token inserted.
- One helper that builds the API prefix (`$JS.API` vs `$JS.<domain>.API`) once, feeding all subject-construction VIs, is the clean design — see the domain `#question` in [[03 JetStream Management API]] and the related note in [[02 Authentication]].
- Caveat (already noted below): flow-control subjects `$JS.FC.<stream>.>` are **not** domain-prefixed, a documented server limitation for identically-named streams across domains.

## Publishing to streams
- Plain `Publish()` to a subject captured by a stream = unacknowledged delivery.
- `Request()` to that subject = server replies once the message is stored (the ack).
- `Nats-Msg-Id` header → dedup (server-tracked, default 2-minute window, configurable via `--dupe-window`, but large windows are discouraged).
- Streams can disable acks entirely via `NoAck: true` in their config.

## Consumers
- Durable consumers persist across disconnects; ephemeral consumers exist only while a subscription is active on their delivery subject (auto-removed after a short grace period).
- Pull consumers: explicit fetch requests (`CONSUMER.MSG.NEXT`).
- Push consumers: server delivers to a subject you subscribe to; flow control via `$JS.FC.<stream>.>` (not domain-prefixed — a documented limitation for identically-named streams across domains).
- Ack policies (`ack_policy`): `none` / `all` / `explicit`. Per-message ack tokens (bytes PUBlished to the message's reply subject): `+ACK` / `-NAK` / `+WPI` / `+TERM` / `+NXT` — see [[05 JetStream Consuming]] for the full protocol.

## Advisories / events
- Published to `$JS.EVENT.ADVISORY.>` — could feed [[09 Monitoring and Admin]] if built out later.

## Sources
- [NATS JetStream API reference](https://docs.nats.io/reference/reference-protocols/nats_api_reference)
- [ADR-1 — JetStream JSON API Design](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-1.md)
- [ADR-6 — Stream/consumer naming rules](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-6.md)
- [ADR-9 — JetStream consumer configuration](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-9.md)
- [ADR-15 (NATS architecture & design)](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-15.md)
- [ADR-17 (NATS architecture & design)](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-17.md)
- [jsm.go JetStream API v1 schemas](https://github.com/nats-io/jsm.go/tree/main/schemas/jetstream/api/v1)

#reference
