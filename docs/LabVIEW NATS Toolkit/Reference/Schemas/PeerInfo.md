---
type: schema
source: https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_info_response.json
---

# PeerInfo

> One entry of the `cluster.replicas` array inside a [[StreamInfo]] response. Each entry describes a single peer (non-leader member) of the stream's RAFT group and rides on the same Core NATS MSG reply frame as its parent. All fields are server-set / read-only.

**Required fields:** `name`, `current`, `active`. All others optional.
**Used by:** [[03 JetStream Management API]] · **Nested in:** [[ClusterInfo]] (via [[StreamInfo]])

## Fields
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `name` | `string` | **Yes** | — | The server name of the peer. Server-set / read-only. |
| `current` | `bool` | **Yes** | `false` | Indicates the server is up to date and synchronised. Server-set / read-only. |
| `active` | `int64 (ns)` | **Yes** | — | Nanoseconds since this peer was last seen. Server-set / read-only. |
| `offline` | `bool` | No | `false` | Indicates the node is considered offline by the group. Server-set / read-only. |
| `lag` | `uint64` | No | — | How many uncommitted operations this peer is behind the leader. Server-set / read-only. |
| `peer` | `string` | No | — | The unique ID for the peer. Server-set / read-only. |

## Constraints & validation
- `active` is a duration in nanoseconds, minimum `0`, signed 64-bit (max `9223372036854775807`).
- `lag` is an unsigned 64-bit integer, minimum `0` (max `18446744073709551615`).
- Every field is server-populated and read-only.
- A healthy peer typically shows `current: true`, `offline: false`, and `lag: 0`.

## Example JSON
```json
{
  "name": "n2-east",
  "current": true,
  "active": 812000,
  "offline": false,
  "lag": 0,
  "peer": "S1Nunr6R"
}
```

## Referenced by
[[ClusterInfo]] · [[StreamInfo]] · [[Schema Catalog]] · [[JetStream JSON Schemas]] · [[03 JetStream Management API]]

## Sources
- [stream_info_response.json](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_info_response.json)

#reference #schema
