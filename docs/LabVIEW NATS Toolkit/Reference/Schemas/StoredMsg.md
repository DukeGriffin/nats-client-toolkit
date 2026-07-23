---
type: schema
schema_id: io.nats.jetstream.api.v1.stream_msg_get_response
source: https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_msg_get_response.json
---

# StoredMsg

> The `message` object returned on the reply subject of a `$JS.API.STREAM.MSG.GET.<name>` request — a single stored message read back out of a stream by sequence or last-by-subject. It rides on a Core NATS MSG frame delivered to the request's reply inbox. The payload and headers are **base64-encoded strings** on the wire. All fields are server-set / read-only.

**Required fields:** `subject`, `seq`, `time` (within the `message` object). All others optional.
**Used by:** [[03 JetStream Management API]] · **Nested in:** the `stream_msg_get_response` envelope

## Fields
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `subject` | `string` | **Yes** | — | The subject the message was originally received on (min length 1). Server-set / read-only. |
| `seq` | `uint64` | **Yes** | — | The sequence number of the message in the stream. Server-set / read-only. |
| `time` | `string` | **Yes** | — | RFC3339 timestamp when the message was received (typically UTC). Server-set / read-only. |
| `data` | `bytes (base64 string)` | No | — | The message body, base64-encoded. Decode to recover the raw payload bytes. Server-set / read-only. |
| `hdrs` | `bytes (base64 string)` | No | — | The message headers, base64-encoded. Decode to recover the raw NATS header block. Server-set / read-only. |

## Constraints & validation
- The response schema is a `oneOf`: **either** an object carrying this `message` object **or** an error object carrying a single `error` field — see [[ApiError]] for the shared error object and standard response envelope. The envelope also carries `type` = `io.nats.jetstream.api.v1.stream_msg_get_response`.
- The `message` object sets `additionalProperties: false` — no fields beyond those listed appear.
- **`data` and `hdrs` are base64-encoded strings on the wire.** A LabVIEW client must base64-decode them to obtain the raw payload/header bytes. `data` has min length 0 (an empty body encodes to an empty string).
- `hdrs`, once decoded, is the raw NATS message header block (the same `NATS/1.0`-style header bytes used on the wire), not pre-parsed key/value pairs.
- `seq` is an unsigned 64-bit integer (min `0`, max `18446744073709551615`).
- This response is the standard (non-direct) `STREAM.MSG.GET` shape. Direct-get responses (when the stream has `allow_direct`) instead return the message as raw MSG data + headers rather than this JSON object.

## Example JSON
```json
{
  "type": "io.nats.jetstream.api.v1.stream_msg_get_response",
  "message": {
    "subject": "orders.us.new",
    "seq": 42,
    "time": "2026-07-23T12:19:58Z",
    "hdrs": "TkFUUy8xLjANCk5hdHMtTXNnLUlkOiBhYmMtMTIzDQoNCg==",
    "data": "eyJvcmRlciI6IDEwMDF9"
  }
}
```

## Nested types
- `error` (error branch) → [[ApiError]]

## Referenced by
[[Schema Catalog]] · [[JetStream JSON Schemas]] · [[03 JetStream Management API]] · [[StreamMsgGetRequest]]

## Sources
- [stream_msg_get_response.json](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_msg_get_response.json)

#reference #schema
