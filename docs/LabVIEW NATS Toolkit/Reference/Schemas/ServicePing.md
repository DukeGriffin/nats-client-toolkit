---
type: schema
schema_id: io.nats.micro.v1.ping_response
source: https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/micro/v1/ping_response.json
---

# ServicePing

> The JSON payload a NATS micro service publishes to the reply subject of a `$SRV.PING` request. It is the lightweight identity heartbeat used to discover live service instances. Rides on a Core NATS MSG frame delivered to the request's reply inbox.

**Required fields:** `type`, `name`, `id`, `version` (from `required`). All others optional.
**Used by:** [[08 Services Framework]]

## Fields
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `type` | `string` | **Yes** | — | Envelope discriminator, constant `io.nats.micro.v1.ping_response`. |
| `name` | `string` | **Yes** | — | The kind of the service. Shared by all services that have the same name. Pattern `^[a-zA-Z0-9_-]+$`. |
| `id` | `string` | **Yes** | — | A unique ID for this instance of the service. |
| `version` | `string` | **Yes** | — | The version of the service (semantic-version format, e.g. `1.0.0`). |
| `metadata` | `map<string,string>` | No | — | Additional metadata for the service. May be `null`. |

## Endpoints sub-object (for Info/Stats)
Not applicable — the `$SRV.PING` response carries only identity fields and declares no `endpoints[]`. See [[ServiceInfo]] and [[ServiceStats]] for the endpoint sub-object.

## Example JSON
```json
{
  "type": "io.nats.micro.v1.ping_response",
  "name": "calculator",
  "id": "kExStFHqQ8w3vJ1nT2aBcd",
  "version": "1.2.0",
  "metadata": {
    "owner": "platform-team"
  }
}
```

## Referenced by
[[08 Services Framework]] · [[Schema Catalog]]

## Sources
- [ping_response.json (jsm.go micro)](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/micro/v1/ping_response.json)

#reference #schema
