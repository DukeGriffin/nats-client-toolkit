---
type: schema
schema_id: io.nats.jetstream.api.v1.stream_info_response
source: https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_info_response.json
---

# StreamInfo

> The JSON payload returned on the reply subject of a `$JS.API.STREAM.INFO.<name>` request and of `$JS.API.STREAM.CREATE.<name>` / `$JS.API.STREAM.UPDATE.<name>`. It rides on a Core NATS MSG frame delivered to the request's reply inbox. All fields are server-set / read-only.

**Required fields:** `config`, `state`, `created` (on the success branch). All others optional.
**Used by:** [[03 JetStream Management API]] · **Nested in:** top-level response type (this is itself a top-level payload)

## Fields
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `type` | `string` | No | — | Envelope discriminator, constant `io.nats.jetstream.api.v1.stream_info_response`. Server-set / read-only. |
| `config` | `object → [[StreamConfig]]` | **Yes** | — | The active configuration for the stream. Server-set / read-only. |
| `state` | `object → [[StreamState]]` | **Yes** | — | Detail about the current state of the stream. Server-set / read-only. |
| `created` | `string` | **Yes** | — | RFC3339 timestamp when the stream was created. Server-set / read-only. |
| `ts` | `string` | No | — | RFC3339 server time when the info was generated. Server-set / read-only. |
| `cluster` | `object → [[ClusterInfo]]` | No | — | RAFT cluster placement/membership. Present only in clustered deployments. Server-set / read-only. |
| `mirror` | `object → [[StreamSource]]` | No | — | Runtime status of the upstream mirror (name, lag, active). Present only when the stream mirrors another. Server-set / read-only. |
| `sources` | `array of object → [[StreamSource]]` | No | — | Runtime status of each sourced stream (name, lag, active). Server-set / read-only. |
| `alternates` | `array of object` | No | — | Alternate locations (mirrors) to read the data from, sorted by priority; each has `name`, `cluster`, `domain`. Server-set / read-only. |
| `domain` | `string` | No | — | The JetStream domain the stream is in. Server-set / read-only. |
| `total` | `int64` | No | — | Paging total (envelope; unused for single INFO). See [[ListPaging]]. |
| `offset` | `int64` | No | — | Paging offset (envelope). See [[ListPaging]]. |
| `limit` | `int64` | No | — | Paging limit (envelope). See [[ListPaging]]. |

## Constraints & validation
- The schema is a `oneOf`: **either** the success object above **or** an error object carrying a single `error` field. On error only `type` + `error` are present — see [[ApiError]] for the shared error object and the standard response envelope shared by every `$JS.API.*` response.
- Every field here is server-populated and read-only; clients never send this payload.
- `config` is the same object accepted by CREATE/UPDATE; consult [[StreamConfig]] for its fields, enums, and defaults.
- `mirror` / `sources[]` entries reuse the [[StreamSource]] shape but in a runtime form (`name`, `lag`, `active` are required; `active` is `-1` when there has been no activity).
- `total`/`offset`/`limit` are part of the shared paging envelope and are typically absent on a single-stream INFO.

## Example JSON
```json
{
  "type": "io.nats.jetstream.api.v1.stream_info_response",
  "config": {
    "name": "ORDERS",
    "subjects": ["orders.>"],
    "retention": "limits",
    "max_consumers": -1,
    "max_msgs": -1,
    "max_bytes": -1,
    "max_age": 0,
    "storage": "file",
    "num_replicas": 3
  },
  "state": {
    "messages": 128,
    "bytes": 40960,
    "first_seq": 1,
    "first_ts": "2026-07-23T10:15:00Z",
    "last_seq": 128,
    "last_ts": "2026-07-23T12:20:11Z",
    "consumer_count": 2,
    "num_subjects": 7
  },
  "cluster": {
    "name": "east",
    "leader": "n1-east",
    "replicas": [
      { "name": "n2-east", "current": true, "active": 812000, "lag": 0 }
    ]
  },
  "created": "2026-07-20T08:00:00Z",
  "ts": "2026-07-23T12:20:12Z"
}
```

## Nested types
- `config` → [[StreamConfig]]
- `state` → [[StreamState]]
- `cluster` → [[ClusterInfo]] (whose `replicas[]` → [[PeerInfo]])
- `mirror`, `sources[]` → [[StreamSource]]
- `error` (error branch) → [[ApiError]]

## Referenced by
[[Schema Catalog]] · [[JetStream JSON Schemas]] · [[03 JetStream Management API]]

## Sources
- [stream_info_response.json](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_info_response.json)

#reference #schema
