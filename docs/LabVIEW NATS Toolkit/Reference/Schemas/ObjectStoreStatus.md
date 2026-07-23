---
type: schema
source: https://raw.githubusercontent.com/nats-io/nats-architecture-and-design/main/adr/ADR-20.md
---

# ObjectStoreStatus

> The status of an Object Store bucket, returned by `Status()`. Object Store has **no jsm.go JSON schema file** — status is **not a wire message**. The client assembles it from the backing stream's [[StreamInfo]] (`$JS.API.STREAM.INFO.OBJ_<bucket>`): size from stream state, the rest from the stream's [[StreamConfig]] (ADR-20 `ObjectStoreStatus` interface). See [[07 Object Store]].

**Required fields:** none formally specified (ADR-defined interface, not a JSON schema). Every accessor is always populated by the client — see Wire source column.
**Used by:** [[07 Object Store]]

## Fields
| Field (Go accessor / conceptual) | Type | Required | Wire source / Default | Description |
|---|---|---|---|---|
| `Bucket` | `string` | see notes | Stream name minus `OBJ_` prefix | Bucket name. |
| `Description` | `string` | see notes | [[StreamConfig]] `description` | Human description of the bucket. |
| `TTL` | `int64 (ns)` | see notes | [[StreamConfig]] `max_age` | Per-bucket object age limit (`0` = keep forever). |
| `Storage` | `string` | see notes | [[StreamConfig]] `storage` | Storage backend (`file` / `memory`). |
| `Replicas` | `int64` | see notes | [[StreamConfig]] `num_replicas` | Replication factor. |
| `Sealed` | `bool` | see notes | [[StreamConfig]] `sealed` | Whether the backing stream is sealed (no further writes/deletes). |
| `Size` | `uint64` | see notes | Stream state `bytes` | Total size of the store on disk/in memory. |
| `BackingStore` | `string` | see notes | Constant | Backend type — always **`JetStream`** for this implementation. |
| `Metadata` | `map<string,string>` | see notes | [[StreamConfig]] `metadata` | User metadata attached to the bucket. |
| `IsCompressed` | `bool` | No | [[StreamConfig]] `compression != none` | Whether the backing stream uses S2 compression (rev 3). |

## Backing stream mapping
Bucket `X` is one stream `OBJ_X` carrying both chunk and meta subjects — see [[07 Object Store]]:

| Component | Template |
|---|---|
| Stream name | `OBJ_<bucket>` |
| Chunk stream subject | `$O.<bucket>.C.>` |
| Meta stream subject | `$O.<bucket>.M.>` |
| Chunk message subject | `$O.<bucket>.C.<object-nuid>` |
| Meta message subject | `$O.<bucket>.M.<name-encoded>` |

Stream invariants: `allow_rollup_hdrs: true` (per-subject rollup for meta), `allow_direct: true` (direct-get meta), `discard: "new"`, `retention: "limits"`.

## Constraints & validation / Notes
- ADR-20 defines `ObjectStoreStatus` as an interface, not a JSON schema — there is no formal `required` array, hence "see notes". In practice the client populates every field.
- `BackingStore` is a constant string (`JetStream`); the backing also lets the client expose the full underlying [[StreamInfo]].
- `IsCompressed` reflects the stream's `compression` field (`s2` when the bucket enabled compression; NATS Server ≥ 2.10).
- `Size` is total stored bytes (chunks + meta), not a count of objects.

## Example JSON
`ObjectStoreStatus` is a client-assembled cluster, not a wire payload. Illustrative shape (for documentation only):
```json
{
  "bucket": "MY-STORE",
  "description": "asset store",
  "ttl": 0,
  "storage": "file",
  "replicas": 3,
  "sealed": false,
  "size": 1048576,
  "backing_store": "JetStream",
  "is_compressed": true,
  "metadata": { "owner": "infra" }
}
```

## Referenced by
[[07 Object Store]] · [[StreamConfig]] · [[StreamInfo]] · [[Schema Catalog]] · [[JetStream JSON Schemas]]

## Sources
- [ADR-20 — JetStream based Object Stores](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-20.md)
- [NATS docs — Object Store concept](https://docs.nats.io/nats-concepts/jetstream/obj_store)
- [NATS docs — Developing with Object Store](https://docs.nats.io/using-nats/developer/develop_jetstream/object)

#reference #schema
