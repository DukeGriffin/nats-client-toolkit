---
type: schema
source: https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_configuration.json
---

# Republish

> Rules for re-emitting messages that enter a stream onto new subjects, with subject mapping for partitioning and fan-out. It rides on the wire inline as the `republish` field of a [[StreamConfig]] payload on `$JS.API.STREAM.CREATE.*` / `UPDATE.*` frames.

**Required fields:** `dest`. All others optional.
**Used by:** [[03 JetStream Management API]], [[JetStream JSON Schemas]] · **Nested in:** [[StreamConfig]]

## Fields
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `src` | `string` | No | — | The source subject to republish. |
| `dest` | `string` | **Yes** | — | The destination to publish to. |
| `headers_only` | `bool` | No | `false` | Only send message headers, no bodies. |

## Constraints & validation
- Only `dest` is required. When `src` is omitted, all messages entering the stream are candidates for republishing.
- The schema imposes no pattern on `src`/`dest`; subject-mapping wildcard/reference semantics are enforced by the server.

## Example JSON
```json
{
  "src": "orders.>",
  "dest": "events.orders.>",
  "headers_only": false
}
```

## Referenced by
[[StreamConfig]] · [[StreamInfo]] · [[03 JetStream Management API]] · [[Schema Catalog]] · [[JetStream JSON Schemas]]

## Sources
- [stream_configuration.json (jsm.go)](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_configuration.json)

#reference #schema
