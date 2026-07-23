---
type: schema
schema_id: io.nats.micro.v1.stats_response
source: https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/micro/v1/stats_response.json
---

# ServiceStats

> The JSON payload a NATS micro service publishes to the reply subject of a `$SRV.STATS` request. It reports runtime request/error counters and timing for the service instance and each of its endpoints. Rides on a Core NATS MSG frame delivered to the request's reply inbox.

**Required fields:** `type`, `name`, `id`, `version`, `started`, `endpoints` (from `required`). All others optional.
**Used by:** [[08 Services Framework]]

## Fields
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `type` | `string` | **Yes** | — | Envelope discriminator, constant `io.nats.micro.v1.stats_response`. |
| `name` | `string` | **Yes** | — | The kind of the service. Shared by all services that have the same name. Pattern `^[a-zA-Z0-9_-]+$`. |
| `id` | `string` | **Yes** | — | A unique ID for this instance of the service. |
| `version` | `string` | **Yes** | — | The version of the service (semantic-version format, e.g. `1.0.0`). |
| `started` | `string` | **Yes** | — | The time the service was started, in RFC3339 format (including timezone, typically UTC). |
| `metadata` | `map<string,string>` | No | — | Additional metadata for the service. May be `null`. |
| `endpoints` | `array of object (see Endpoints sub-object below)` | **Yes** | — | Statistics for each known endpoint. See the endpoints sub-object below. |

- All timing fields are **nanoseconds** (signed 64-bit integer durations).

## Endpoints sub-object (for Info/Stats)
Each element of `endpoints[]` reports statistics for one endpoint. Within an element, `name`, `subject`, `num_requests`, `num_errors`, `last_error`, `processing_time`, and `average_processing_time` are required; `queue_group` and `data` are optional.

| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `name` | `string` | **Yes** | — | The endpoint name. Pattern `^[a-zA-Z0-9_-]+$`. |
| `subject` | `string` | **Yes** | — | The subject the endpoint listens on. |
| `num_requests` | `int64` | **Yes** | — | The number of requests this endpoint received. |
| `num_errors` | `int64` | **Yes** | — | The number of errors this endpoint encountered. |
| `last_error` | `string` | **Yes** | — | The last error the service encountered. |
| `processing_time` | `int64 (ns)` | **Yes** | — | Total time, in nanoseconds, spent processing requests in the handler. |
| `average_processing_time` | `int64 (ns)` | **Yes** | — | The average time, in nanoseconds, spent processing requests. |
| `queue_group` | `string` | No | — | The queue group this endpoint listens on for requests. |
| `data` | `any` | No | — | Additional statistics the endpoint makes available. Schema declares no fixed type. #question |

## Example JSON
```json
{
  "type": "io.nats.micro.v1.stats_response",
  "name": "calculator",
  "id": "kExStFHqQ8w3vJ1nT2aBcd",
  "version": "1.2.0",
  "started": "2026-07-23T08:00:00Z",
  "metadata": {
    "owner": "platform-team"
  },
  "endpoints": [
    {
      "name": "add",
      "subject": "calc.add",
      "num_requests": 1024,
      "num_errors": 3,
      "last_error": "invalid operand",
      "processing_time": 512000000,
      "average_processing_time": 500000,
      "queue_group": "q",
      "data": {
        "cache_hits": 900
      }
    }
  ]
}
```

## Referenced by
[[08 Services Framework]] · [[Schema Catalog]]

## Sources
- [stats_response.json (jsm.go micro)](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/micro/v1/stats_response.json)

#reference #schema
