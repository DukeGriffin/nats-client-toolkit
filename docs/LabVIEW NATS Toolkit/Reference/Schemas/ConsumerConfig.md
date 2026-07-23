---
type: schema
schema_id: io.nats.jetstream.api.v1.consumer_configuration
source: https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_configuration.json
---

# ConsumerConfig

> The full configuration of a JetStream consumer. This JSON object rides inside the `config` field of the request body PUBlished to `$JS.API.CONSUMER.DURABLE.CREATE.<stream>.<consumer>` / `$JS.API.CONSUMER.CREATE.<stream>` and is echoed back inside the `config` field of the response and of [[ConsumerInfo]].

**Required fields:** none (the schema `required` array is empty). However the schema's `allOf`/`oneOf` makes `deliver_policy` effectively required, and requires `opt_start_seq` when `deliver_policy` = `by_start_sequence`, or `opt_start_time` when `deliver_policy` = `by_start_time`. All other fields optional.
**Used by:** [[05 JetStream Consuming]], [[03 JetStream Management API]], [[JetStream JSON Schemas]] · **Nested in:** [[ConsumerInfo]]

## Fields
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `durable_name` | `string` | No | — | A unique name for a durable consumer. Pattern `^[^.*>]+$`, min length 1. **Deprecated:** all consumers now have names picked by clients. |
| `name` | `string` | No | — | A unique name for a consumer. Pattern `^[^.*>]+$`, min length 1. |
| `description` | `string` | No | — | A short description of the purpose of this consumer. Max length 4096. |
| `deliver_policy` | `string` (enum) | No | `all` | The point in the stream from which to receive messages. One of `all`, `last`, `new`, `by_start_sequence`, `by_start_time`, `last_per_subject`. |
| `opt_start_seq` | `uint64` | No | — | Start sequence used with the `by_start_sequence` deliver policy. Min `0`. Required when `deliver_policy` = `by_start_sequence`. |
| `opt_start_time` | `string` (date-time) | No | — | Start time (RFC3339, typically UTC) used with the `by_start_time` deliver policy. Required when `deliver_policy` = `by_start_time`. |
| `deliver_subject` | `string` | No | — | The subject push consumers deliver messages to. **Its presence makes the consumer a push consumer; its absence makes it a pull consumer.** Min length 1. |
| `deliver_group` | `string` | No | — | The queue group name used to distribute messages among subscribers (push consumers). Min length 1. |
| `ack_policy` | `string` (enum) | No | `none` | The requirement of client acknowledgments. One of `none`, `all`, `explicit`, `flow_control`. |
| `ack_wait` | `int64 (ns)` | No | `30000000000` | How long (nanoseconds) to allow messages to remain un-acknowledged before attempting redelivery. Min `1`. Default is 30s. |
| `max_deliver` | `int64` | No | `-1` | The number of times a message will be delivered if not acknowledged in time. `-1` for unlimited. |
| `filter_subject` | `string` | No | — | Filter the stream by a single subject. Mutually exclusive with `filter_subjects`. |
| `filter_subjects` | `array of string` | No | — | Filter the stream by multiple subjects (each min length 1). Mutually exclusive with `filter_subject`. |
| `replay_policy` | `string` (enum) | No | `instant` | The rate at which messages are pushed to a client. One of `instant`, `original`. |
| `sample_freq` | `string` | No | — | Sets the percentage of acknowledgments that should be sampled for observability (e.g. `"50"` or `"50%"`). |
| `rate_limit_bps` | `uint64` | No | — | The rate at which messages are delivered to clients, in bits per second. Min `0`. |
| `max_ack_pending` | `int64` | No | `1000` | Maximum number of un-acknowledged messages that can be outstanding; once reached, delivery is suspended. |
| `idle_heartbeat` | `int64 (ns)` | No | — | If the consumer is idle for more than this many nanoseconds, an empty message with `Status` header `100` is sent to signal the consumer is still alive. Min `0`. |
| `flow_control` | `bool` | No | — | Push consumers: regularly sends an empty message with `Status` header `100` and a reply subject; consumers must reply to control delivery rate. |
| `max_waiting` | `int64` | No | `512` | The number of pull requests that can be outstanding on a pull consumer; pulls received after this is reached are ignored. Min `0`. |
| `headers_only` | `bool` | No | `false` | Delivers only the headers of messages, not bodies. Adds a `Nats-Msg-Size` header indicating the removed payload size. |
| `max_batch` | `int64` | No | `0` | The largest `batch` value that may be specified on a pull. Min `0`. |
| `max_expires` | `int64 (ns)` | No | `0` | The maximum `expires` value that may be set on a pull. Min `0`. |
| `max_bytes` | `int64` | No | `0` | The maximum `max_bytes` value that may be set on a pull. Min `0`. |
| `inactive_threshold` | `int64 (ns)` | No | `0` | Duration after which the server cleans up ephemeral consumers that have been inactive for that long. Min `0`. |
| `backoff` | `array of int64 (ns)` | No | — | List of durations (nanoseconds) representing a retry time scale for NaK'd messages. Each min `0`. |
| `num_replicas` | `int64` | No | — | When set, do not inherit the replica count from the stream but set it to this amount. Range `0`–`5`. |
| `mem_storage` | `bool` | No | `false` | Force the consumer state to be kept in memory rather than inherit the setting from the stream. |
| `metadata` | `map<string,string>` | No | — | Additional metadata for the consumer. |
| `pause_until` | `string` (date-time) | No | — | When creating a consumer, a time in the future acts as a deadline until which the consumer will be paused. RFC3339. |
| `priority_groups` | `array of string` | No | — | List of priority groups this consumer supports (each min length 1). |
| `priority_policy` | `string` (enum) | No | — | The priority policy the consumer is set to. One of `none`, `overflow`, `pinned_client`, `prioritized`. |
| `priority_timeout` | `int64 (ns)` | No | `0` | For `pinned_client` priority policy, how long before the client times out. Min `0`. |
| `direct` | `bool` | No | `false` | Internal use only — special consumer that does not touch the Raft layers. Not for general use by clients. |
| `sourcing` | `bool` | No | `false` | Internal use only — marks the consumer as one used by a stream to source data from another stream. Not for general use by clients. |

## Enums
- **deliver_policy** — `all`: deliver all messages from the start of the stream; `last`: start with the last message on the stream; `new`: deliver only messages arriving after the consumer is created; `by_start_sequence`: start at `opt_start_seq`; `by_start_time`: start at `opt_start_time`; `last_per_subject`: start with the last message for each filtered subject.
- **ack_policy** — `none`: no acknowledgment required (server assumes delivery is enough); `all`: acknowledging a message implicitly acks all prior ones; `explicit`: every message must be individually acknowledged; `flow_control`: a real value in the live schema enum, but a legacy/internal one (distinct from the separate `flow_control` boolean field) — **do not set it for normal consumers**; use `none`, `all`, or `explicit`.
- **replay_policy** — `instant`: deliver messages as fast as possible; `original`: deliver messages honoring the original inter-message timing recorded in the stream.
- **priority_policy** — `none`: no priority handling; `overflow`: deliver to overflow groups; `pinned_client`: pin delivery to a specific client; `prioritized`: prioritized delivery ordering.

## Push vs pull (ConsumerConfig only)
- **`deliver_subject` set ⇒ push consumer.** The server pushes messages to that subject; `deliver_group`, `flow_control`, and `idle_heartbeat` apply, and `rate_limit_bps` / `replay_policy` govern delivery pacing.
- **`deliver_subject` absent ⇒ pull consumer.** Clients fetch batches via `$JS.API.CONSUMER.MSG.NEXT.<stream>.<consumer>`; `max_waiting`, `max_batch`, `max_bytes`, and `max_expires` bound pull requests.
- **Ack policy:** pull consumers must use `ack_policy` = `explicit` (only explicit acks are valid for pull). Push consumers may use `none`, `all`, or `explicit`.
- **flow_control / idle_heartbeat** are push-only mechanisms: `flow_control` requires the client to reply to control-message probes, and `idle_heartbeat` emits `Status: 100` keep-alives; both are meaningless for pull consumers.

## Constraints & validation
- `durable_name` and `name` pattern `^[^.*>]+$` (no `.`, `*`, or `>`), min length 1. `durable_name` is deprecated.
- `description` max length 4096.
- All duration fields — `ack_wait`, `idle_heartbeat`, `max_expires`, `inactive_threshold`, `priority_timeout`, and each `backoff` element — are **int64 nanoseconds**.
- `opt_start_seq` and `rate_limit_bps` are unsigned 64-bit integers (min `0`).
- `num_replicas` range `0`–`5`.
- **Mutually exclusive:** `filter_subject` (single) vs `filter_subjects` (multiple) — set one or the other, not both.
- **Conditional required (oneOf):** `deliver_policy` = `by_start_sequence` requires `opt_start_seq`; `deliver_policy` = `by_start_time` requires `opt_start_time`.
- `direct` and `sourcing` are internal-only flags and should not be set by client code.
- The top-level `required` array is empty, so no field is unconditionally required by the base schema.

## Example JSON
```json
{
  "name": "order-workers",
  "description": "Pull consumer for order processing",
  "deliver_policy": "all",
  "ack_policy": "explicit",
  "ack_wait": 30000000000,
  "max_deliver": 5,
  "filter_subject": "orders.new",
  "replay_policy": "instant",
  "max_ack_pending": 1000,
  "max_waiting": 512,
  "max_batch": 100,
  "max_expires": 30000000000,
  "inactive_threshold": 300000000000,
  "backoff": [1000000000, 5000000000, 10000000000],
  "num_replicas": 3,
  "metadata": { "team": "fulfillment" }
}
```

## Referenced by
[[ConsumerInfo]] · [[05 JetStream Consuming]] · [[03 JetStream Management API]] · [[Schema Catalog]] · [[JetStream JSON Schemas]]

## Sources
- [consumer_configuration.json](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_configuration.json)

#reference #schema
