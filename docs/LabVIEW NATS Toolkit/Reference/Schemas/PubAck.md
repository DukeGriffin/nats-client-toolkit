---
type: schema
schema_id: io.nats.jetstream.api.v1.pub_ack_response
source: https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/pub_ack_response.json
---

# PubAck

> The reply a JetStream server sends when a message is published into a stream. When a stream is listening on a subject, a plain Core NATS `PUB` becomes a request/reply: the server answers on the message's reply subject with this JSON payload. It is a wire payload on a Core NATS frame, not a client object — the same bytes arrive whether the publisher used a helper library or a raw `PUB`/`SUB`.

**Required fields:** `stream`. All others optional.
**Used by:** [[04 JetStream Publishing]], [[JetStream JSON Schemas]]

## Fields
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `stream` | `string` | **Yes** | — | The name of the stream that received the message. Min length 1. Present on both success and error replies. |
| `seq` | `uint64` | No | — | On success, the sequence the message is stored at within the stream. Absent on error. Unsigned 64-bit, min `0`. |
| `duplicate` | `bool` | No | `false` | `true` when the message was recognised as a duplicate via the `Nats-Msg-Id` header and duplicate-tracking window, and therefore was not stored again. |
| `domain` | `string` | No | — | If the stream's server is configured for a JetStream domain, the name of that domain. |
| `batch` | `string` | No | — | When doing Atomic Batch Publishes, the Batch ID being committed. |
| `count` | `int` | No | — | When doing Atomic Batch Publishes, how many messages were in the batch. |
| `val` | `string` | No | — | The current value of the counter, on counter-enabled streams. |
| `error` | `object → [[ApiError]]` | No | — | Present only on failure. Its presence is the success/error discriminator (see below). Fields: `code`, `err_code`, `description`. |

## Constraints & validation / Notes
- **Success vs. error discrimination.** The reply is a success acknowledgement if and only if the `error` object is **absent**. A successful PubAck carries `stream` + `seq` (and possibly `duplicate`/`domain`); a failed one carries `stream` + `error`. Decoders must check for `error` before trusting `seq`. See [[ApiError]] for the shared error object.
- **`error.code` range** is `300`–`699` (HTTP-like) per the schema; only `code` is required inside the error object. See [[ApiError]] for `err_code` (the stable programmatic identifier) and `description`.
- **`duplicate: true`** is a *success* outcome, not an error — the message was intentionally suppressed by duplicate tracking. `seq` refers to the already-stored original.
- **503 "no responders" (leader not ready).** This is distinct from an `error` PubAck. If no server is currently subscribed to the stream's subject — e.g. the stream's Raft leader has not been elected yet, JetStream is still starting, or the account/stream does not exist — Core NATS returns a **503 no-responders** status message: an *empty-payload* reply carrying a `Nats-Status: 503` header, **not** a PubAck JSON body. Publishers must treat a 503 no-responders as "not delivered / retry", separate from a well-formed PubAck whose `error` object describes a rejection (e.g. maximum-messages reached). If the request instead simply times out with no reply, the outcome is unknown and the publish should be retried (idempotently, using `Nats-Msg-Id`).
- `additionalProperties: false` — unknown keys are rejected by the schema.

## Example JSON
Success:
```json
{
  "stream": "ORDERS",
  "seq": 148
}
```

Duplicate (suppressed by `Nats-Msg-Id` tracking — still a success):
```json
{
  "stream": "ORDERS",
  "seq": 148,
  "duplicate": true
}
```

Error (rejected by the stream — note the `error` object and no `seq`):
```json
{
  "stream": "ORDERS",
  "error": {
    "code": 400,
    "err_code": 10054,
    "description": "message size exceeds maximum allowed"
  }
}
```

## Referenced by
[[ApiError]] · [[04 JetStream Publishing]] · [[Schema Catalog]] · [[JetStream JSON Schemas]]

## Sources
- [pub_ack_response.json](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/pub_ack_response.json)
- [ADR-1: JetStream JSON API Design](https://raw.githubusercontent.com/nats-io/nats-architecture-and-design/main/adr/ADR-1.md)
- [server/errors.json (canonical err_code list)](https://raw.githubusercontent.com/nats-io/nats-server/main/server/errors.json)

#reference #schema
