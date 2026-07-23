---
type: schema
source: https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_info_response.json
---

# StreamState

> The `state` object embedded in a [[StreamInfo]] response. It describes the current runtime state of a stream (message counts, byte size, sequence/time bounds, consumer count) and rides on the same Core NATS MSG reply frame as its parent. All fields are server-set / read-only.

**Required fields:** `messages`, `bytes`, `first_seq`, `last_seq`, `consumer_count`. All others optional.
**Used by:** [[03 JetStream Management API]] · **Nested in:** [[StreamInfo]]

## Fields
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `messages` | `uint64` | **Yes** | — | Number of messages stored in the stream. Server-set / read-only. |
| `bytes` | `uint64` | **Yes** | — | Combined size of all messages in the stream. Server-set / read-only. |
| `first_seq` | `uint64` | **Yes** | — | Sequence number of the first message in the stream. Server-set / read-only. |
| `first_ts` | `string` | No | — | RFC3339 timestamp of the first message in the stream. Server-set / read-only. |
| `last_seq` | `uint64` | **Yes** | — | Sequence number of the last message in the stream. Server-set / read-only. |
| `last_ts` | `string` | No | — | RFC3339 timestamp of the last message in the stream. Server-set / read-only. |
| `consumer_count` | `int64` | **Yes** | — | Number of consumers attached to the stream. Server-set / read-only. |
| `num_subjects` | `int64` | No | — | Number of unique subjects held in the stream. Server-set / read-only. |
| `num_deleted` | `int64` | No | — | Number of deleted messages. Server-set / read-only. |
| `deleted` | `array of uint64` | No | — | Sequence IDs of messages deleted via the Message Delete API or removed out of order by interest-based streams. Returned only when explicitly requested. Server-set / read-only. |
| `subjects` | `object` (map `string → uint64`) | No | — | Per-subject message counts; present only when a `subjects_filter` was set on the request. Server-set / read-only. |
| `lost` | `object` | No | — | Records messages that were damaged and unrecoverable. Contains `msgs` (`array of uint64` or null — the lost message sequences) and `bytes` (`uint64` — bytes lost). Server-set / read-only. |

## Constraints & validation
- `additionalProperties: false` — no fields beyond those listed appear in this object.
- All numeric counts have minimum `0`. `messages`, `bytes`, `first_seq`, `last_seq`, `deleted[]`, `subjects` values, and `lost.msgs[]`/`lost.bytes` are unsigned 64-bit (max `18446744073709551615`). `consumer_count`, `num_subjects`, `num_deleted` are dynamic-width signed integers (max `9223372036854775807`).
- Every field is server-populated and read-only.
- `deleted` and `subjects` are typically omitted unless the INFO request opted in (deleted-details / subjects filter). `first_ts`/`last_ts` may be absent on an empty stream.
- `lost.msgs` may be JSON `null` rather than an array.

## Example JSON
```json
{
  "messages": 128,
  "bytes": 40960,
  "first_seq": 1,
  "first_ts": "2026-07-23T10:15:00Z",
  "last_seq": 128,
  "last_ts": "2026-07-23T12:20:11Z",
  "consumer_count": 2,
  "num_subjects": 7,
  "num_deleted": 0
}
```

## Nested types
- `lost` → inline object (`msgs`, `bytes`); no separate schema page.
- `subjects` → inline map of subject to count; no separate schema page.

## Referenced by
[[StreamInfo]] · [[Schema Catalog]] · [[JetStream JSON Schemas]] · [[03 JetStream Management API]]

## Sources
- [stream_info_response.json](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_info_response.json)

#reference #schema
