---
type: schema
source: https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_configuration.json
---

# StreamConsumerLimits

> Stream-level ceilings and defaults for values that consumers of the stream can set. It rides on the wire inline as the `consumer_limits` field of a [[StreamConfig]] payload on `$JS.API.STREAM.CREATE.*` / `UPDATE.*` frames.

**Required fields:** none. All others optional.
**Used by:** [[03 JetStream Management API]], [[JetStream JSON Schemas]] · **Nested in:** [[StreamConfig]]

## Fields
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `inactive_threshold` | `int64 (ns)` | No | — | Maximum value for `inactive_threshold` for consumers of this stream. Acts as a default when consumers do not set this value. Min `0`. |
| `max_ack_pending` | `int64` | No | — | Maximum value for `max_ack_pending` for consumers of this stream. Acts as a default when consumers do not set this value. |

## Constraints & validation
- The `consumer_limits` object has no `required` array; both fields are optional and the whole object may be omitted.
- `inactive_threshold` is a nanosecond duration, minimum `0`, up to max int64.
- `max_ack_pending` is a signed 64-bit integer (range `-9223372036854775808` to `9223372036854775807`).
- Values set here bound and default the corresponding fields on each [[ConsumerConfig]] for consumers of this stream.

## Example JSON
```json
{
  "inactive_threshold": 300000000000,
  "max_ack_pending": 1000
}
```

## Referenced by
[[StreamConfig]] · [[ConsumerConfig]] · [[StreamInfo]] · [[03 JetStream Management API]] · [[Schema Catalog]] · [[JetStream JSON Schemas]]

## Sources
- [stream_configuration.json (jsm.go)](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_configuration.json)

#reference #schema
