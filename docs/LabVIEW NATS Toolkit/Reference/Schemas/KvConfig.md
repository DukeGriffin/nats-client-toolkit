---
type: schema
source: https://raw.githubusercontent.com/nats-io/nats-architecture-and-design/main/adr/ADR-8.md
---

# KvConfig

> The configuration for a Key-Value bucket. KV has **no jsm.go JSON schema file** — it is a convention over JetStream (ADR-8). There is no wire message for a `KvConfig`: creating a bucket `X` is a stream CREATE of a [[StreamConfig]] named `KV_X` PUBlished to `$JS.API.STREAM.CREATE.KV_X`. The fields below are the client-facing bucket knobs (Go `KeyValueConfig`); each maps to a [[StreamConfig]] field on the wire. See [[06 Key-Value Store]].

**Required fields:** `Bucket` only (ADR semantics — a bucket must be named; there is no formal `required` array because KV is ADR-defined, not JSON-Schema). All others optional.
**Used by:** [[06 Key-Value Store]]

## Fields
| Field (conceptual / Go) | Type | Required | Wire source / Default | Description |
|---|---|---|---|---|
| `Bucket` | `string` | **Yes** (semantics) | → stream `name` = **`KV_<bucket>`**; subjects **`$KV.<bucket>.>`** | Bucket name. Determines the backing stream name and subject space. |
| `Description` | `string` | No | → `description` | Human description of the bucket. |
| `MaxValueSize` | `int32` | No | → `max_msg_size`; default `-1` (unlimited) | Largest single value accepted. |
| `History` | `int64` | No | → `max_msgs_per_subject`; default `1`, max `64` | Number of historical revisions kept per key. |
| `TTL` | `int64 (ns)` | No | → `max_age`; default `0` (keep forever) | Per-bucket message age limit. |
| `MaxBytes` | `int64` | No | → `max_bytes`; default `-1` (unlimited) | Overall bucket size limit. |
| `Storage` | `string` | No | → `storage`; default `file` | Storage backend. Always `file` for KV in practice. |
| `Replicas` | `int64` | No | → `num_replicas`; default `1` | Replication factor (1–5). |
| `Placement` | `object → [[Placement]]` | No | → `placement` | Cluster/tag placement passthrough. |
| `Republish` | `object → [[Republish]]` | No | → `republish` | Republish rules passthrough. |
| `Mirror` | `object → [[StreamSource]]` | No | → `mirror` | Mirror another bucket/stream (read-only replica). |
| `Sources` | `array of object → [[StreamSource]]` | No | → `sources` | Aggregate other buckets/streams. |
| `Compression` | `bool` | No | → `compression` = `s2` when true, else `none` | Enable S2 compression (server ≥ 2.10). |
| `Metadata` | `map<string,string>` | No | → `metadata` | User metadata passthrough. |
| `LimitMarkerTTL` | `int64 (ns)` | No | → `subject_delete_marker_ttl` (+ `allow_msg_ttl: true`); `0` = markers unsupported | Duration for server-generated delete/purge/max-age markers. Requires server API level 1+ (2.11+). |

## Invariants always set on the backing stream (not caller-supplied)
These are forced by the KV convention regardless of the caller's config — see [[06 Key-Value Store]]:
- `retention` = `limits`, `discard` = **`new`** (reject writes past limits).
- `deny_delete` = **`true`** (deletes are marker messages, never raw removal).
- `allow_direct` = **`true`** (fast GET path; ADR-8 rev 7 removed the ability to disable this).
- rollup headers **always enabled** (required for key purge — see below).
- `max_consumers` = `-1`.

## Constraints & validation / Notes
- KV is ADR-defined: there is no formal JSON `required` array. `Bucket` is required by semantics; all other fields are optional with server/library defaults.
- `History` range is `1`–`64` (min 1 applied if the caller omits it).
- `duplicate_window` when `TTL`/`max_age` is set: server derives it (`min(max_age, 2min)`); leave unset and let the server apply the logic.
- **Rollup field spelling:** the live NATS server [[StreamConfig]] field is **`allow_rollup_hdrs`** — that is the key the bucket-create payload must send. (The ADR-8 JSON sample and KV→stream mapping table use the shorthand `rollup_hdrs`; treat that as ADR shorthand for the same setting.) See [[06 Key-Value Store]].

## Example JSON
The `KvConfig` is not itself a wire object — this is the [[StreamConfig]] it produces for a bucket `CONFIGURATION` (based on the ADR-8 example, compression + limit markers; rollup shown with the live server field `allow_rollup_hdrs`):
```json
{
  "name": "KV_CONFIGURATION",
  "subjects": ["$KV.CONFIGURATION.>"],
  "retention": "limits",
  "max_consumers": -1,
  "max_msgs_per_subject": 5,
  "max_msgs": -1,
  "max_bytes": -1,
  "max_age": 0,
  "max_msg_size": -1,
  "storage": "file",
  "discard": "new",
  "num_replicas": 1,
  "allow_rollup_hdrs": true,
  "deny_delete": true,
  "allow_direct": true,
  "compression": "s2",
  "allow_msg_ttl": true,
  "subject_delete_marker_ttl": 900000000000,
  "placement": { "cluster": "clstr", "tags": ["tag1", "tag2"] },
  "republish": { "src": "repub.>", "dest": "dest.>", "headers_only": true },
  "metadata": { "encoding": "base64" }
}
```

## Referenced by
[[06 Key-Value Store]] · [[StreamConfig]] · [[Schema Catalog]] · [[JetStream JSON Schemas]]

## Sources
- [ADR-8 — JetStream based Key-Value Stores](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-8.md)
- [NATS docs — Key/Value Store concept](https://docs.nats.io/nats-concepts/jetstream/key-value-store)
- [NATS docs — Developing with KV](https://docs.nats.io/using-nats/developer/develop_jetstream/kv)

#reference #schema
