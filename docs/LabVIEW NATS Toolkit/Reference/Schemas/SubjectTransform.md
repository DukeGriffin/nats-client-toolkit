---
type: schema
source: https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_configuration.json
---

# SubjectTransform

> A subject rewrite rule that maps a matching source subject to a destination subject. It rides on the wire inline inside a [[StreamConfig]] payload — as the top-level `subject_transform` field and as each entry of a [[StreamSource]] `subject_transforms` array — on `$JS.API.STREAM.CREATE.*` / `UPDATE.*` frames.

**Required fields:** `src`, `dest`. All others optional.
**Used by:** [[03 JetStream Management API]], [[JetStream JSON Schemas]] · **Nested in:** [[StreamConfig]], [[StreamSource]]

## Fields
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `src` | `string` | **Yes** | — | The subject transform source (the matching pattern). |
| `dest` | `string` | **Yes** | — | The subject transform destination (the rewritten subject). |

## Constraints & validation
- Both `src` and `dest` are required by the schema.
- The schema itself imposes no pattern on these strings; NATS subject-mapping semantics (wildcard tokens `*`/`>` in `src`, positional references such as `{{wildcard(1)}}` in `dest`) are enforced by the server.

## Example JSON
```json
{
  "src": "orders.*.received",
  "dest": "orders.received.{{wildcard(1)}}"
}
```

## Referenced by
[[StreamConfig]] · [[StreamSource]] · [[03 JetStream Management API]] · [[Schema Catalog]] · [[JetStream JSON Schemas]]

## Sources
- [stream_configuration.json (jsm.go)](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_configuration.json)

#reference #schema
