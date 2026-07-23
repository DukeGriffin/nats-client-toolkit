---
type: schema
source: https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_configuration.json
---

# Placement

> Directives that constrain which cluster and servers host the replicas (and leader) of a stream. It rides on the wire inline as the `placement` field of a [[StreamConfig]] payload on `$JS.API.STREAM.CREATE.*` / `UPDATE.*` frames. When unset, placement is random.

**Required fields:** none. All others optional.
**Used by:** [[03 JetStream Management API]], [[JetStream JSON Schemas]] · **Nested in:** [[StreamConfig]]

## Fields
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `cluster` | `string` | No | — | The desired cluster name. |
| `tags` | `array of string` | No | — | Tags required on servers hosting this stream or leader. |
| `preferred` | `string` | No | — | A preferred server name to move the leader to. |

## Constraints & validation
- The `placement` object has no `required` array in the schema; every field is optional and the whole object may be omitted for random placement.

## Example JSON
```json
{
  "cluster": "east",
  "tags": ["ssd", "region:us-east-1"],
  "preferred": "node-3"
}
```

## Referenced by
[[StreamConfig]] · [[StreamInfo]] · [[03 JetStream Management API]] · [[Schema Catalog]] · [[JetStream JSON Schemas]]

## Sources
- [stream_configuration.json (jsm.go)](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_configuration.json)

#reference #schema
