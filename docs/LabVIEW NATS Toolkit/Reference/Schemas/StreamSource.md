---
type: schema
source: https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_configuration.json
---

# StreamSource

> Defines another stream to replicate messages from. The identical object shape is used two ways inside a [[StreamConfig]] payload: as the single `mirror` object (a 1:1 mirror) and as each entry of the `sources` array. It rides on the wire inline on `$JS.API.STREAM.CREATE.*` / `UPDATE.*` frames.

**Required fields:** `name`. All others optional.
**Used by:** [[03 JetStream Management API]], [[JetStream JSON Schemas]] · **Nested in:** [[StreamConfig]] (`mirror`, `sources`)

## Fields
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `name` | `string` | **Yes** | — | Stream name to replicate from. Pattern `^[^.*>]+$`, min length 1. |
| `opt_start_seq` | `uint64` | No | — | Sequence to start replicating from. |
| `opt_start_time` | `string` | No | — | Time stamp to start replicating from. RFC3339 date-time (typically UTC). |
| `filter_subject` | `string` | No | — | Replicate only a subset of messages based on this filter. |
| `subject_transforms` | `array of object → [[SubjectTransform]]` | No | — | The subject filtering sources and associated destination transforms. May be `null`. |
| `consumer` | `object` | No | — | Consumer information for durable sourcing (`name`, `deliver_subject`). See below. |
| `external` | `object` | No | — | Configuration referencing a stream source in another account or JetStream domain (`api`, `deliver`). See below. |

### Nested `consumer` object
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `name` | `string` | **Yes** | — | Consumer name. Pattern `^[^.*>]+$`, min length 1. |
| `deliver_subject` | `string` | **Yes** | — | The subject to deliver messages to. |

### Nested `external` object
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `api` | `string` | **Yes** | — | The subject prefix that imports the other account/domain `$JS.API.CONSUMER.>` subjects. |
| `deliver` | `string` | No | — | The delivery subject to use for the push consumer. |

## Constraints & validation
- `name` (and nested `consumer.name`) pattern `^[^.*>]+$` — at least one character, none of `.`, `*`, or `>`.
- `opt_start_seq` is an unsigned 64-bit integer; `opt_start_time` is an RFC3339 timestamp. These are alternative start points.
- `subject_transforms` is typed `["array","null"]` in the schema, so an explicit `null` is valid.
- The nested `consumer` object requires both `name` and `deliver_subject`; the nested `external` object requires `api`.
- When used as `mirror`, the parent [[StreamConfig]] `subjects` and `sources` must be empty.
- #question The task brief listed a `domain` field for this object, but this schema version defines no `domain` property on `mirror`/`sources` entries — cross-domain sourcing is expressed via the `external.api` prefix instead. Documented as-is from the schema; `domain` is not invented here.

## Example JSON
```json
{
  "name": "ORDERS",
  "opt_start_seq": 1024,
  "filter_subject": "orders.us.>",
  "subject_transforms": [
    { "src": "orders.us.>", "dest": "mirror.orders.us.>" }
  ],
  "external": {
    "api": "$JS.acct-b.API",
    "deliver": "deliver.orders"
  }
}
```

## Nested types
- `subject_transforms` (each entry) → [[SubjectTransform]]
- `consumer` → inline object (name, deliver_subject)
- `external` → inline object (api, deliver)

## Referenced by
[[StreamConfig]] · [[StreamInfo]] · [[03 JetStream Management API]] · [[Schema Catalog]] · [[JetStream JSON Schemas]]

## Sources
- [stream_configuration.json (jsm.go)](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_configuration.json)

#reference #schema
