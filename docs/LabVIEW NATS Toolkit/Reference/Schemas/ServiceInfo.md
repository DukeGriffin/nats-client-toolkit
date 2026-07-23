---
type: schema
schema_id: io.nats.micro.v1.info_response
source: https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/micro/v1/info_response.json
---

# ServiceInfo

> The JSON payload a NATS micro service publishes to the reply subject of a `$SRV.INFO` request. It describes the service instance and its declared endpoints. Rides on a Core NATS MSG frame delivered to the request's reply inbox.

**Required fields:** `type`, `name`, `id`, `version`, `description` (from `required`). All others optional.
**Used by:** [[08 Services Framework]]

## Fields
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `type` | `string` | **Yes** | — | Envelope discriminator, constant `io.nats.micro.v1.info_response`. |
| `name` | `string` | **Yes** | — | The kind of the service. Shared by all services that have the same name. Pattern `^[a-zA-Z0-9_-]+$`. |
| `id` | `string` | **Yes** | — | A unique ID for this instance of the service. |
| `version` | `string` | **Yes** | — | The version of the service (semantic-version format, e.g. `1.0.0`). |
| `metadata` | `map<string,string>` | No | — | Additional metadata for the service. May be `null`. |
| `description` | `string` | **Yes** | — | The description of the service, supplied as configuration when the service was created. |
| `endpoints` | `array of object (see Endpoints sub-object below)` | No | — | List of declared endpoints. See the endpoints sub-object below. |

## Endpoints sub-object (for Info/Stats)
Each element of `endpoints[]` describes one declared endpoint. Within an element, `name` and `subject` are required.

| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `name` | `string` | **Yes** | — | The endpoint name. Pattern `^[a-zA-Z0-9_-]+$`. |
| `subject` | `string` | **Yes** | — | The subject the endpoint listens on. |
| `queue_group` | `string` | No | — | The queue group this endpoint listens on for requests. |
| `metadata` | `map<string,string>` | No | — | Additional metadata for the endpoint. May be `null`. |

## Example JSON
```json
{
  "type": "io.nats.micro.v1.info_response",
  "name": "calculator",
  "id": "kExStFHqQ8w3vJ1nT2aBcd",
  "version": "1.2.0",
  "description": "Arithmetic service",
  "metadata": {
    "owner": "platform-team"
  },
  "endpoints": [
    {
      "name": "add",
      "subject": "calc.add",
      "queue_group": "q",
      "metadata": {
        "description": "Adds two integers"
      }
    }
  ]
}
```

## Referenced by
[[08 Services Framework]] · [[Schema Catalog]]

## Sources
- [info_response.json (jsm.go micro)](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/micro/v1/info_response.json)

#reference #schema
