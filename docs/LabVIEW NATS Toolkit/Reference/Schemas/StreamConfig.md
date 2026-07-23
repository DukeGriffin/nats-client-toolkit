---
type: schema
schema_id: io.nats.jetstream.api.v1.stream_configuration
source: https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_configuration.json
---

# StreamConfig

> The full configuration of a JetStream stream. This JSON object is the request body PUBlished to `$JS.API.STREAM.CREATE.<name>` and `$JS.API.STREAM.UPDATE.<name>`, and is echoed back inside the `config` field of the response and of [[StreamInfo]].

**Required fields:** `retention`, `max_consumers`, `max_msgs`, `max_bytes`, `max_age`, `storage`, `num_replicas`. All others optional.
**Used by:** [[03 JetStream Management API]], [[JetStream JSON Schemas]]

## Fields
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `name` | `string` | No | — | A unique name for the Stream, empty for Stream Templates. Pattern `^[^.*>]*$`. |
| `description` | `string` | No | — | A short description of the purpose of this stream. Max length 4096. |
| `subjects` | `array of string` | No | — | A list of subjects to consume, supports wildcards. Must be empty when a mirror is configured. May be empty when sources are configured. |
| `subject_transform` | `object → [[SubjectTransform]]` | No | — | Subject transform to apply to matching messages. |
| `retention` | `string` | **Yes** | `limits` | How messages are retained; once exceeded old messages are removed. One of `limits`, `interest`, `workqueue`. |
| `max_consumers` | `int64` | **Yes** | `-1` | How many Consumers can be defined for a given Stream. `-1` for unlimited. Min `-1`. |
| `max_msgs` | `int64` | **Yes** | `-1` | How many messages may be in a Stream; oldest are removed if exceeded. `-1` for unlimited. Min `-1`. |
| `max_msgs_per_subject` | `int64` | No | `-1` | For wildcard streams, keep this many messages per unique subject — a per-subject retention limit. Min `-1`. |
| `max_bytes` | `int64` | **Yes** | `-1` | How big the Stream may be; when combined size exceeds this, old messages are removed. `-1` for unlimited. Min `-1`. |
| `max_age` | `int64 (ns)` | **Yes** | `0` | Maximum age of any message in the stream, in nanoseconds. `0` for unlimited. |
| `max_msg_size` | `int32` | No | `-1` | The largest message that will be accepted by the Stream. `-1` for unlimited. Min `-1`, max `2147483647`. |
| `storage` | `string` | **Yes** | `file` | The storage backend to use for the Stream. One of `file`, `memory`. |
| `compression` | `string` | No | `none` | Optional compression algorithm used for the Stream. One of `none`, `s2`. |
| `first_seq` | `uint64` | No | — | A custom sequence to use for the first message in the stream. |
| `num_replicas` | `int64` | **Yes** | `1` | How many replicas to keep for each message. Min `0`, max `5`. |
| `no_ack` | `bool` | No | `false` | Disables acknowledging messages that are received by the Stream. |
| `discard` | `string` | No | `old` | When a Stream reaches its limits either old messages are deleted or new ones are denied. One of `old`, `new`. |
| `duplicate_window` | `int64 (ns)` | No | `0` | The time window to track duplicate messages for, in nanoseconds. `0` for default. |
| `placement` | `object → [[Placement]]` | No | — | Placement directives to consider when placing replicas of this stream; random placement when unset. |
| `mirror` | `object → [[StreamSource]]` | No | — | Maintains a 1:1 mirror of another stream. When set, `subjects` and `sources` must be empty. |
| `sources` | `array of object → [[StreamSource]]` | No | — | List of Stream names to replicate into this Stream. |
| `sealed` | `bool` | No | `false` | Sealed streams do not allow messages to be deleted via limits or API; cannot be unsealed via configuration update. Can only be set on already-created streams via the Update API. |
| `deny_delete` | `bool` | No | `false` | Restricts the ability to delete messages from a stream via the API. Cannot be changed once set to true. |
| `deny_purge` | `bool` | No | `false` | Restricts the ability to purge messages from a stream via the API. Cannot be changed once set to true. |
| `allow_rollup_hdrs` | `bool` | No | `false` | Allows the use of the `Nats-Rollup` header to replace all contents of a stream, or subject in a stream, with a single new message. |
| `allow_direct` | `bool` | No | `false` | Allow higher performance, direct access to get individual messages. |
| `allow_atomic` | `bool` | No | `false` | Allow atomic batched publishes. |
| `allow_msg_counter` | `bool` | No | `false` | Configures a stream to be a counter and to reject all other messages. |
| `allow_msg_schedules` | `bool` | No | `false` | Allows the scheduling of messages. |
| `mirror_direct` | `bool` | No | `false` | Allow higher performance, direct access for mirrors as well. |
| `republish` | `object → [[Republish]]` | No | — | Rules for republishing messages from a stream with subject mapping onto new subjects for partitioning and more. |
| `discard_new_per_subject` | `bool` | No | `false` | When discard policy is `new` and max-messages-per-subject is set, applies the new behavior to every subject (max messages per subject rather than max number of subjects). |
| `metadata` | `map<string,string>` | No | — | Additional metadata for the Stream. |
| `consumer_limits` | `object → [[StreamConsumerLimits]]` | No | — | Limits of certain values that consumers can set; defaults for those who don't set these settings. |
| `allow_msg_ttl` | `bool` | No | `false` | Enables per-message TTL using headers. |
| `subject_delete_marker_ttl` | `int64 (ns)` | No | — | Enables and sets a duration for adding server markers for delete, purge and max-age limits. |
| `persist_mode` | `string` | No | `""` | Sets a specific persistence mode for writing to the Stream. One of `""`, `default`, `async`. |
| `allow_batched` | `bool` | No | `false` | Allows fast batch publishing into the Stream. |

## Enums
- **retention** — `limits`: retain by age/size/count limits; `interest`: retain a message only while a consumer has interest; `workqueue`: message is removed once acknowledged by a consumer.
- **storage** — `file`: on-disk storage; `memory`: in-memory storage (lost on restart).
- **compression** — `none`: no compression; `s2`: S2 block compression.
- **discard** — `old`: drop oldest messages when a limit is reached; `new`: reject new messages when a limit is reached.
- **persist_mode** — `""`: server default; `default`: default persistence mode; `async`: asynchronous writes.

## Constraints & validation
- `name` pattern `^[^.*>]*$` (no `.`, `*`, or `>` characters); may be empty for Stream Templates. **Two layers, not a contradiction:** this JSON-schema pattern has *no length limit* (the API layer), while [ADR-6](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-6.md)'s "≤255 chars, additionally no `/` or `\`" is the server-side *naming* rule enforced on top of it.
- `description` max length 4096.
- `max_consumers`, `max_msgs`, `max_msgs_per_subject`, `max_bytes` accept `-1` (unlimited) up to max int64; `max_msg_size` is int32 (`-1` up to `2147483647`).
- `max_age`, `duplicate_window`, `subject_delete_marker_ttl` are nanosecond durations, min `0`.
- `num_replicas` range `0`–`5`.
- `first_seq` is an unsigned 64-bit integer.
- **Mutually exclusive:** with a `mirror` configured, `subjects` and `sources` must be empty. `subjects` may be empty when `sources` are configured.
- `sealed`, `deny_delete`, and `deny_purge` are one-way switches once enabled; `sealed` can only be set via the Update API on an existing stream.
- `additionalProperties: false` — unknown keys are rejected by the schema.

## Example JSON
```json
{
  "name": "ORDERS",
  "description": "Customer order events",
  "subjects": ["orders.>"],
  "retention": "limits",
  "max_consumers": -1,
  "max_msgs": 1000000,
  "max_bytes": -1,
  "max_age": 604800000000000,
  "max_msgs_per_subject": -1,
  "max_msg_size": -1,
  "storage": "file",
  "compression": "s2",
  "num_replicas": 3,
  "discard": "old",
  "duplicate_window": 120000000000,
  "placement": { "cluster": "east", "tags": ["ssd"] },
  "allow_direct": true,
  "metadata": { "team": "fulfillment" }
}
```

## Nested types
- `subject_transform` → [[SubjectTransform]]
- `placement` → [[Placement]]
- `mirror` → [[StreamSource]]
- `sources` (each entry) → [[StreamSource]]
- `republish` → [[Republish]]
- `consumer_limits` → [[StreamConsumerLimits]]

## Referenced by
[[StreamInfo]] · [[03 JetStream Management API]] · [[Schema Catalog]] · [[JetStream JSON Schemas]]

## Sources
- [stream_configuration.json (jsm.go)](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_configuration.json)

#reference #schema
