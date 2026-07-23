---
type: schema
schema_id: io.nats.jetstream.api.v1.stream_msg_get_request
source: https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_msg_get_request.json
---

# StreamMsgGetRequest

> Request to retrieve a stored message from a stream. Published (PUB with a reply inbox) to `$JS.API.STREAM.MSG.GET.<stream>`. The reply carries a [[StoredMsg]] (wrapped in the standard response envelope). This is a request body on the wire, not a client-library object.

**Required fields:** none. All fields optional — but you must supply **exactly one** selection mode (see below).
**Used by:** [[03 JetStream Management API]]

## Fields
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `seq` | `uint64` | No | — | Stream sequence number of the message to retrieve. Cannot be combined with `last_by_subj`. |
| `last_by_subj` | `string` | No | — | Retrieve the last message on the given subject. Cannot be combined with `seq`. |
| `next_by_subj` | `string` | No | — | Combined with a sequence, get the next message on this subject at that sequence or higher. |
| `batch` | `int64` | No | — | Request a number of messages be delivered (batch/multi get). |
| `max_bytes` | `int64` | No | — | Restrict a batch get to at most this many cumulative bytes; defaults to the server `MAX_PENDING_SIZE`. |
| `start_time` | `string` | No | — | Start the batch at a point in time (RFC3339) rather than a sequence. |
| `multi_last` | `array of string` | No | — | Get the last message from each of the supplied subjects. |
| `up_to_seq` | `uint64` | No | — | Return messages up to this sequence (otherwise up to the stream's last sequence). |
| `up_to_time` | `string` | No | — | Only return messages up to this point in time (RFC3339). |

## Constraints & validation
- The schema defines **no** `required` fields, but a meaningful request must choose a single selection mode.
- **Mutually-exclusive selection modes (either/or):**
  - **By sequence** — set `seq` alone: returns exactly that message.
  - **Last by subject** — set `last_by_subj` alone: returns the last message on that subject.
  - **Next by subject** — set `next_by_subj` together with `seq` (the starting sequence): returns the first message on that subject at `seq` or higher.
- **`seq` and `last_by_subj` are explicitly mutually exclusive** — the schema descriptions on both state "cannot be combined". Sending both is invalid.
- `next_by_subj` is meaningful only in conjunction with a sequence (`seq`); on its own it starts from the beginning of the stream.
- **Batch / multi-get fields** (`batch`, `max_bytes`, `start_time`, `multi_last`, `up_to_seq`, `up_to_time`) form the newer batched-get variant. Use `batch` (with an optional `max_bytes` byte cap) to stream multiple messages; `multi_last` returns the last message per subject in the list; `start_time`, `up_to_seq`, and `up_to_time` bound the batch. This variant requires stream `allow_direct` / direct-get support on the server. #question exact server-side precedence when batch fields are combined with a single-message selector is not pinned down by the schema.

## Example JSON
```json
{
  "last_by_subj": "orders.us.east.42"
}
```

```json
{
  "seq": 100,
  "next_by_subj": "orders.us.east.*"
}
```

## Referenced by
[[StoredMsg]] · [[03 JetStream Management API]] · [[Schema Catalog]] · [[JetStream JSON Schemas]]

## Sources
- [stream_msg_get_request.json](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_msg_get_request.json)
- [JetStream — Direct Get / Message Get (docs.nats.io)](https://docs.nats.io/nats-concepts/jetstream/streams)

#reference #schema
