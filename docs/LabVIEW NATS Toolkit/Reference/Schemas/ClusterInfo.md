---
type: schema
source: https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_info_response.json
---

# ClusterInfo

> The `cluster` object embedded in a [[StreamInfo]] response. It describes the RAFT group that replicates the stream — its name, current leader, and peer members — and rides on the same Core NATS MSG reply frame as its parent. Present only in clustered deployments. All fields are server-set / read-only.

**Required fields:** none. All others optional.
**Used by:** [[03 JetStream Management API]] · **Nested in:** [[StreamInfo]]

## Fields
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `name` | `string` | No | — | The cluster name. Server-set / read-only. |
| `leader` | `string` | No | — | The server name of the RAFT leader. Server-set / read-only. |
| `replicas` | `array of object → [[PeerInfo]]` | No | — | The members of the RAFT cluster (excludes the leader). Server-set / read-only. |
| `leader_since` | `string` | No | — | RFC3339 time the current leader was elected; absent when this node is not the leader. Server-set / read-only. |
| `raft_group` | `string` | No | — | Name of the RAFT group managing the asset in clustered environments. Server-set / read-only. |
| `system_account` | `bool` | No | — | When true, replication traffic goes over the system account. Server-set / read-only. |
| `traffic_account` | `string` | No | — | The account the replication traffic goes over. Server-set / read-only. |

## Constraints & validation
- The schema declares no `required` array for this object, so every field may be absent.
- The whole `cluster` object is omitted for non-clustered (single-server) streams.
- Every field is server-populated and read-only.
- Each entry of `replicas` is a [[PeerInfo]] object.

## Example JSON
```json
{
  "name": "east",
  "leader": "n1-east",
  "replicas": [
    { "name": "n2-east", "current": true, "active": 812000, "offline": false, "lag": 0 },
    { "name": "n3-east", "current": true, "active": 913500, "offline": false, "lag": 0 }
  ],
  "raft_group": "S-R3F-ORDERS"
}
```

## Nested types
- `replicas[]` → [[PeerInfo]]

## Referenced by
[[StreamInfo]] · [[Schema Catalog]] · [[JetStream JSON Schemas]] · [[03 JetStream Management API]]

## Sources
- [stream_info_response.json](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_info_response.json)

#reference #schema
