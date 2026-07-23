---
type: schema
schema_id: io.nats.jetstream.api.v1.consumer_getnext_request
source: https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_getnext_request.json
---

# ConsumerGetnextRequest

> The pull-consumer NEXT body. Published (PUB with a reply inbox) to `$JS.API.CONSUMER.MSG.NEXT.<stream>.<consumer>`. The server delivers matching stream messages to the reply inbox until the batch, byte, or expiry limit is reached. This is a request body on the wire, not a client-library object.

**Required fields:** none. All fields optional.
**Used by:** [[05 JetStream Consuming]]

## Fields
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `batch` | `int64` | No | — | How many messages the server should deliver to the requestor. Min `0`, max `256`. Original ADR-13 field. |
| `expires` | `int64 (ns)` | No | `0` | A duration from now (nanoseconds) when the pull should expire; `0` for no expiry. Min `0`. Original ADR-13 field. |
| `no_wait` | `bool` | No | — | When true, a response with a `404` status header is returned immediately when no messages are available (instead of waiting). Original ADR-13 field. |
| `max_bytes` | `int64` | No | — | Send at most this many bytes to the requestor, further limited by the consumer's configured `max_bytes`. Min `0`. Later addition (post ADR-13). |
| `idle_heartbeat` | `int64 (ns)` | No | — | When not `0`, idle heartbeats (empty message, `100` status header) are sent on this interval so the client can detect a stalled pull. Min `0`. Later addition (post ADR-13). |
| `group` | `string` | No | — | The consumer (priority) group to pull from. Priority-group extension (NATS 2.11+). |
| `min_pending` | `int64` | No | — | Minimum number of messages the server should have in the consumer's pending queue before serving this pull. Min `0`. Priority-group extension. |
| `min_ack_pending` | `int64` | No | — | Minimum number of messages the server should have in the consumer's ack-pending queue before serving this pull. Min `0`. Priority-group extension. |
| `id` | `string` | No | — | When pulling from a Pinned Client consumer, the unique client ID. Priority-group extension. |
| `priority` | `int64` | No | — | The priority of the pull request. Min `0`, max `9`. Priority-group extension. |

## Constraints & validation
- The schema defines **no** `required` fields; an empty `{}` is a valid (but useless) request.
- **Original ADR-13 fields:** `batch`, `expires`, `no_wait`. These are the classic pull-subscribe controls.
- **Later additions:** `max_bytes` and `idle_heartbeat` were added after the original design to support byte-bounded fetches and stall detection.
- **Priority-group extension fields** (`group`, `min_pending`, `min_ack_pending`, `id`, `priority`) apply only to consumers configured with priority groups / a pinned-client policy (NATS 2.11+); leave them unset for ordinary pulls.
- `batch` is capped at `256`; `priority` is bounded `0`–`9`. `expires`, `idle_heartbeat`, `max_bytes`, `min_pending`, `min_ack_pending` are non-negative.
- **Recommended usage:** always set `expires` (e.g. a few seconds shorter than the client request timeout) so the pull terminates cleanly, and set `idle_heartbeat` (typically `expires`/2 or less) on long pulls so a dead connection is detected. Combine `batch` with `max_bytes` to bound both count and payload. See [[05 JetStream Consuming]].

## Example JSON
```json
{
  "batch": 100,
  "max_bytes": 1048576,
  "expires": 5000000000,
  "idle_heartbeat": 2500000000,
  "no_wait": false
}
```

## Referenced by
[[05 JetStream Consuming]] · [[Schema Catalog]] · [[JetStream JSON Schemas]]

## Sources
- [consumer_getnext_request.json](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_getnext_request.json)
- [ADR-13: Pull Subscribe Improvements](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-13.md)
- [JetStream — Pull Consumers (docs.nats.io)](https://docs.nats.io/nats-concepts/jetstream/consumers)

#reference #schema
