---
type: schema
source: https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_info_response.json
---

# SequenceInfo

> A small pair object that tracks a position across both the consumer and the stream. It is not a top-level API payload — it appears embedded as the `delivered` and `ack_floor` fields of a [[ConsumerInfo]] response on the wire.

**Required fields:** `consumer_seq`, `stream_seq`. All others optional.
**Used by:** [[05 JetStream Consuming]], [[JetStream JSON Schemas]] · **Nested in:** [[ConsumerInfo]] (as `delivered` and `ack_floor`)

## Fields
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `consumer_seq` | `uint64` | **Yes** | — | The sequence number of the consumer. Min `0`. |
| `stream_seq` | `uint64` | **Yes** | — | The sequence number of the stream. Min `0`. |
| `last_active` | `string` (date-time) | No | — | The last time a message was delivered (for `delivered`) or acknowledged (for `ack_floor`). RFC3339, typically UTC. |

## Constraints & validation
- `consumer_seq` and `stream_seq` are unsigned 64-bit integers (min `0`).
- `last_active` is an RFC3339 timestamp (typically UTC).
- `additionalProperties: false` — unknown keys are rejected by the schema.
- The same object shape is used for both `delivered` (last message delivered) and `ack_floor` (highest contiguous acknowledged message) in [[ConsumerInfo]].

## Example JSON
```json
{
  "consumer_seq": 128,
  "stream_seq": 4096,
  "last_active": "2026-07-23T12:05:01Z"
}
```

## Referenced by
[[ConsumerInfo]] · [[05 JetStream Consuming]] · [[Schema Catalog]] · [[JetStream JSON Schemas]]

## Sources
- [consumer_info_response.json](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_info_response.json)

#reference #schema
