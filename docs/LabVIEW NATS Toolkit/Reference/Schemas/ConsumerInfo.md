---
type: schema
schema_id: io.nats.jetstream.api.v1.consumer_info_response
source: https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_info_response.json
---

# ConsumerInfo

> The response payload returned by the JetStream `$JS.API.CONSUMER.INFO.<stream>.<consumer>` and `$JS.API.CONSUMER.CREATE`/`DURABLE.CREATE` APIs. It arrives as a JSON body on a Core NATS reply message and describes the current state of a single consumer.

**Required fields:** `type`; and (on success) `stream_name`, `name`, `created`, `delivered`, `ack_floor`, `num_ack_pending`, `num_redelivered`, `num_waiting`, `num_pending`. All others optional.
**Used by:** [[05 JetStream Consuming]], [[03 JetStream Management API]], [[JetStream JSON Schemas]]

## Response envelope
This payload is a `oneOf`: **either** a success object (fields below) **or** an error envelope `{ "error": { "code", "description", "err_code } }`. Every response also carries a top-level `type` field with the constant `io.nats.jetstream.api.v1.consumer_info_response`. See the shared error shape → [[ApiError]]. Always check for the `error` member before reading success fields.

## Fields
| Field (JSON key)  | Type                        | Required | Default | Description                                                                                                |
| ----------------- | --------------------------- | -------- | ------- | ---------------------------------------------------------------------------------------------------------- |
| `type`            | `string` (const)            | **Yes**  | —       | Always `io.nats.jetstream.api.v1.consumer_info_response`.                                                  |
| `stream_name`     | `string`                    | **Yes**  | —       | The stream the consumer belongs to.                                                                        |
| `name`            | `string`                    | **Yes**  | —       | A unique name for the consumer, either machine generated or the durable name.                              |
| `created`         | `string` (date-time)        | **Yes**  | —       | The time the consumer was created. RFC3339, typically UTC.                                                 |
| `config`          | object → [[ConsumerConfig]] | No       | —       | The full configuration the consumer was created with.                                                      |
| `delivered`       | object → [[SequenceInfo]]   | **Yes**  | —       | The last message delivered from this consumer (consumer/stream sequence pair).                             |
| `ack_floor`       | object → [[SequenceInfo]]   | **Yes**  | —       | The highest contiguous acknowledged message (consumer/stream sequence pair).                               |
| `num_ack_pending` | `int64`                     | **Yes**  | —       | The number of messages pending acknowledgement. Min `0`.                                                   |
| `num_redelivered` | `int64`                     | **Yes**  | —       | The number of redeliveries that have been performed. Min `0`.                                              |
| `num_waiting`     | `int64`                     | **Yes**  | —       | The number of pull requests waiting for messages. Min `0`.                                                 |
| `num_pending`     | `uint64`                    | **Yes**  | —       | The number of messages left unconsumed in this consumer. Min `0`.                                          |
| `cluster`         | object → [[ClusterInfo]]    | No       | —       | RAFT cluster placement/leadership information for the consumer.                                            |
| `push_bound`      | `bool`                      | No       | —       | Indicates if any client is connected and receiving messages from a push consumer.                          |
| `ts`              | `string` (date-time)        | No       | —       | The server time the consumer info was created. RFC3339.                                                    |
| `paused`          | `bool`                      | No       | —       | Indicates if the consumer is currently in a paused state.                                                  |
| `pause_remaining` | `int64 (ns)`                | No       | —       | When paused, the time remaining until unpause, in nanoseconds. Min `0`.                                    |
| `priority_groups` | `array of object`           | No       | —       | The state of Priority Groups. Each entry: `{ group (required), pinned_client_id, pinned_ts }`.             |
| `error`           | object → [[ApiError]]       | No       | —       | Present instead of the success fields when the request failed. Contains `code`, `description`, `err_code`. |

## Constraints & validation
- The payload is a `oneOf`: success object **or** `{ "error": ... }` — never both.
- `num_ack_pending`, `num_redelivered`, `num_waiting` are int64 (min `0`); `num_pending` is an unsigned 64-bit integer (min `0`).
- `pause_remaining` and (within `cluster.replicas[].active`) are int64 nanosecond durations.
- `created`, `ts`, and other time fields are RFC3339 strings (typically UTC).
- Each `priority_groups` entry requires `group`.

## Example JSON
```json
{
  "type": "io.nats.jetstream.api.v1.consumer_info_response",
  "stream_name": "ORDERS",
  "name": "order-workers",
  "created": "2026-07-23T12:00:00Z",
  "config": {
    "name": "order-workers",
    "deliver_policy": "all",
    "ack_policy": "explicit",
    "ack_wait": 30000000000,
    "max_deliver": 5,
    "filter_subject": "orders.new",
    "replay_policy": "instant",
    "max_ack_pending": 1000
  },
  "delivered": { "consumer_seq": 128, "stream_seq": 4096, "last_active": "2026-07-23T12:05:01Z" },
  "ack_floor": { "consumer_seq": 120, "stream_seq": 4080, "last_active": "2026-07-23T12:05:00Z" },
  "num_ack_pending": 8,
  "num_redelivered": 2,
  "num_waiting": 3,
  "num_pending": 512,
  "cluster": { "name": "east", "leader": "n1-east" },
  "push_bound": false,
  "ts": "2026-07-23T12:05:02Z"
}
```

## Nested types
- `config` → [[ConsumerConfig]]
- `delivered` → [[SequenceInfo]]
- `ack_floor` → [[SequenceInfo]]
- `cluster` → [[ClusterInfo]]
- `error` → [[ApiError]]

## Referenced by
[[ConsumerConfig]] · [[SequenceInfo]] · [[05 JetStream Consuming]] · [[03 JetStream Management API]] · [[Schema Catalog]] · [[JetStream JSON Schemas]]

## Sources
- [consumer_info_response.json](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_info_response.json)

#reference #schema
