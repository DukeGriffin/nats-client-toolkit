---
type: schema
schema_id: io.nats.jetstream.api.v1.account_info_response
source: https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/account_info_response.json
---

# AccountInfo

> The reply to `$JS.API.INFO` — the account's JetStream usage and limits. A client PUBlishes an empty request to `$JS.API.INFO` and the server replies on the message's reply subject with this JSON payload. It is a wire payload on a Core NATS frame, not a client object. The schema is a `oneOf`: either a success body (usage + limits + api) or an [[ApiError]] error body; both carry the `type` hint.

**Required fields:** `type`; on the success body also `memory`, `storage`, `streams`, `consumers`, `limits`, `api`. All others optional.
**Used by:** [[09 Monitoring and Admin]], [[JetStream JSON Schemas]]

## Fields
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `type` | `string` | **Yes** | — | Schema identifier, constant `io.nats.jetstream.api.v1.account_info_response`. See [[ApiError]]. |
| `memory` | `uint64` | **Yes** | — | Memory storage, in bytes, currently used for stream message storage. |
| `storage` | `uint64` | **Yes** | — | File storage, in bytes, currently used for stream message storage. |
| `reserved_memory` | `uint64` | No | — | Bytes reserved for memory usage by this account. |
| `reserved_storage` | `uint64` | No | — | Bytes reserved for disk usage by this account. |
| `streams` | `int64` | **Yes** | — | Number of active streams in the account. |
| `consumers` | `int64` | **Yes** | — | Number of active consumers in the account. |
| `domain` | `string` | No | — | The JetStream domain this account is in. |
| `limits` | `object` | **Yes** | — | Account-level resource limits. Sub-fields below. |
| `api` | `object` | **Yes** | — | API request counters for the account. Sub-fields below. |
| `tiers` | `map<string,object>` | No | — | Per-tier usage and limits, keyed by tier name (e.g. `R1`, `R3`). Each value mirrors the top-level usage fields plus a nested `limits` object. Sub-fields below. |
| `error` | `object → [[ApiError]]` | No | — | Present only on failure (error body of the `oneOf`). Its presence is the success/error discriminator. |

### `limits` (object) — required: `max_memory`, `max_storage`, `max_streams`, `max_consumers`
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `max_memory` | `int64` | **Yes** | — | Maximum memory storage (bytes) for stream messages. `-1` for unlimited. Min `-1`. |
| `max_storage` | `int64` | **Yes** | — | Maximum file storage (bytes) for stream messages. `-1` for unlimited. Min `-1`. |
| `max_streams` | `int64` | **Yes** | — | Maximum number of streams per account. `-1` for unlimited. Min `-1`. |
| `max_consumers` | `int64` | **Yes** | — | Maximum number of consumers per account. `-1` for unlimited. Min `-1`. |
| `max_bytes_required` | `bool` | No | `false` | When true, every stream in the account must set `max_bytes`. |
| `max_ack_pending` | `int64` | No | — | Maximum outstanding ACKs any consumer may have. `-1` for unlimited. Min `-1`. |
| `memory_max_stream_bytes` | `int64` | No | — | Maximum size of a single memory-storage stream. `-1` for unlimited. Min `-1`. |
| `storage_max_stream_bytes` | `int64` | No | — | Maximum size of a single file-storage stream. `-1` for unlimited. Min `-1`. |

### `api` (object) — required: `total`, `errors`
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `total` | `uint64` | **Yes** | — | Total number of JetStream API requests received for this account. |
| `errors` | `uint64` | **Yes** | — | Number of those API requests that resulted in an error. |
| `level` | `int` | No | — | The API level the server supports. |
| `inflight` | `uint64` | No | — | Number of API requests currently in flight (pending). |

### `tiers` (map value object)
Each entry is keyed by tier name and repeats the account-usage shape: `memory`, `storage`, `reserved_memory`, `reserved_storage`, `streams`, `consumers`, an `api` object, and a nested `limits` object with the same sub-fields as the top-level `limits` table above. Tiers appear when the account spans multiple replication tiers (e.g. `R1` for single-replica, `R3` for three-replica); the top-level totals are the account-wide aggregate.

## Constraints & validation / Notes
- The schema is a **`oneOf`**: exactly one of the success body or the error body. Discriminate as with any response — the presence of `error` means failure; see [[ApiError]].
- All byte/usage counters (`memory`, `storage`, `reserved_*`, `api.total`, `api.errors`, `api.inflight`) are unsigned 64-bit, min `0`. `streams` and `consumers` are signed 64-bit, min `0`.
- Every `limits` value uses `-1` to mean "unlimited"; `0` is a real limit of zero, not unlimited.
- `tiers` is optional and may be absent on servers/accounts without tiering. When present, prefer per-tier limits over the top-level `limits` for capacity decisions on a specific tier.

## Example JSON
Success:
```json
{
  "type": "io.nats.jetstream.api.v1.account_info_response",
  "memory": 0,
  "storage": 4194304,
  "streams": 3,
  "consumers": 5,
  "domain": "hub",
  "limits": {
    "max_memory": -1,
    "max_storage": 10737418240,
    "max_streams": 50,
    "max_consumers": -1
  },
  "api": {
    "total": 1287,
    "errors": 4
  },
  "tiers": {
    "R3": {
      "memory": 0,
      "storage": 4194304,
      "streams": 3,
      "consumers": 5,
      "limits": {
        "max_memory": -1,
        "max_storage": 10737418240,
        "max_streams": 50,
        "max_consumers": -1
      }
    }
  }
}
```

Error (missing JetStream on the account):
```json
{
  "type": "io.nats.jetstream.api.v1.account_info_response",
  "error": {
    "code": 503,
    "err_code": 10039,
    "description": "JetStream not enabled for account"
  }
}
```

## Nested types
- `limits`, `api`, and each `tiers` value are inline objects (documented above), not separate schema files.
- `error` → [[ApiError]]

## Referenced by
[[ApiError]] · [[09 Monitoring and Admin]] · [[Schema Catalog]] · [[JetStream JSON Schemas]]

## Sources
- [account_info_response.json](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/account_info_response.json)
- [ADR-1: JetStream JSON API Design](https://raw.githubusercontent.com/nats-io/nats-architecture-and-design/main/adr/ADR-1.md)
- [server/errors.json (canonical err_code list)](https://raw.githubusercontent.com/nats-io/nats-server/main/server/errors.json)

#reference #schema
