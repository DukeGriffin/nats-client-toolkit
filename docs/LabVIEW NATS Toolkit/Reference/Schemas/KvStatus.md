---
type: schema
source: https://raw.githubusercontent.com/nats-io/nats-architecture-and-design/main/adr/ADR-8.md
---

# KvStatus

> The status of a Key-Value bucket, returned by `Status()`. KV has **no jsm.go JSON schema file** — status is **not a wire message**. The client assembles it from the backing stream's [[StreamInfo]] (`$JS.API.STREAM.INFO.KV_<bucket>`): message/byte counts come from stream state, `History`/`TTL`/`LimitMarkerTTL`/compression from the stream's [[StreamConfig]] (ADR-8 `Status` interface). See [[06 Key-Value Store]].

**Required fields:** none formally specified (ADR-defined `Status` interface, not a JSON schema). Every accessor is always populated by the client — see Wire source column.
**Used by:** [[06 Key-Value Store]]

## Fields
| Field (Go accessor / conceptual) | Type | Required | Wire source / Default | Description |
|---|---|---|---|---|
| `Bucket` | `string` | see notes | Stream name minus `KV_` prefix | Bucket name. |
| `Values` | `uint64` | see notes | Stream state `messages` | Total messages in the bucket, including history revisions and markers. |
| `History` | `int64` | see notes | [[StreamConfig]] `max_msgs_per_subject` | Configured historical revisions kept per key. |
| `TTL` | `int64 (ns)` | see notes | [[StreamConfig]] `max_age` | Per-bucket message age limit (`0` = keep forever). |
| `LimitMarkerTTL` | `int64 (ns)` | see notes | [[StreamConfig]] `subject_delete_marker_ttl`; `0` = markers unsupported | TTL for server-generated delete/purge/max-age markers. |
| `IsCompressed` | `bool` | see notes | [[StreamConfig]] `compression != none` | Whether the backing stream uses S2 compression. |
| `BackingStore` | `string` | see notes | Constant | Backend type — always **`JetStream`** for this implementation. |
| `Bytes` | `uint64` | see notes | Stream state `bytes` | Total size of the bucket on disk/in memory. |
| `Metadata` | `map<string,string>` | see notes | [[StreamConfig]] `metadata` | User metadata attached to the bucket. |

## Constraints & validation / Notes
- ADR-8 defines `Status` as an interface, not a JSON schema — there is no formal `required` array, hence "see notes" above. In practice the client populates every field.
- `LimitMarkerTTL` = `0` signals that delete/purge/max-age markers are **not** supported by this bucket (requires `allow_msg_ttl` + server API level 1+ / 2.11+).
- `BackingStore` is a constant string (`JetStream`) identifying the implementation; the JetStream backing also lets the client expose the full underlying [[StreamInfo]] for detailed state.
- `Values` counts every stored message (all revisions and markers), not the number of distinct live keys.

## Example JSON
`KvStatus` is a client-assembled cluster, not a wire payload. Illustrative shape (for documentation only):
```json
{
  "bucket": "CONFIGURATION",
  "values": 128,
  "history": 5,
  "ttl": 0,
  "limit_marker_ttl": 900000000000,
  "is_compressed": true,
  "backing_store": "JetStream",
  "bytes": 40960,
  "metadata": { "encoding": "base64" }
}
```

## Referenced by
[[06 Key-Value Store]] · [[StreamConfig]] · [[StreamInfo]] · [[Schema Catalog]] · [[JetStream JSON Schemas]]

## Sources
- [ADR-8 — JetStream based Key-Value Stores](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-8.md)
- [NATS docs — Key/Value Store concept](https://docs.nats.io/nats-concepts/jetstream/key-value-store)
- [NATS docs — Developing with KV](https://docs.nats.io/using-nats/developer/develop_jetstream/kv)

#reference #schema
