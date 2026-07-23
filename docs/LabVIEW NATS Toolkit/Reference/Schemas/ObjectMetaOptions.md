---
type: schema
source: https://raw.githubusercontent.com/nats-io/nats-architecture-and-design/main/adr/ADR-20.md
---

# ObjectMetaOptions

> The `options` sub-object of [[ObjectInfo]]/`ObjectMeta`. Object Store has **no jsm.go JSON schema file** — this is a Go struct (ADR-20) serialized inline as `options` inside the meta message payload on `$O.<bucket>.M.<name-encoded>`. It carries the per-object chunk-size override and, for link objects, the `link` target. See [[07 Object Store]].

**Required fields:** none (ADR-defined struct, not a JSON schema; the whole `options` object is `omitempty`, and both members are `omitempty`). See notes.
**Used by:** [[07 Object Store]] · **Nested in:** [[ObjectInfo]]

## Fields
| Field (JSON key / conceptual) | Type | Required | Wire source / Default | Description |
|---|---|---|---|---|
| `max_chunk_size` | `uint32` | No | `omitempty`; default **128 KiB (131 072 bytes)** when absent | Per-object override of the default chunk size. |
| `link` | `object` → `{ bucket, name }` | No | `omitempty`; present only on link objects | Link target. See link semantics below. |

## `link` object
| Field (JSON key) | Type | Required | Wire source / Default | Description |
|---|---|---|---|---|
| `bucket` | `string` | see notes | — | Target object store (bucket) name. Always set on a link. |
| `name` | `string` | No | `omitempty` | Target object name. Present ⇒ object link; **omitted ⇒ bucket link**. |

## Constraints & validation / Notes
- ADR-20 defines these as Go structs (`ObjectMetaOptions`, `ObjectLink`), not a JSON schema — no formal `required` array. Within a `link`, `bucket` is required by semantics (a link must target a store); `name` is `omitempty`.
- **Object link vs bucket link:**
  - **Object link** — both `link.bucket` and `link.name` set: points at a specific object in another (or the same) bucket. Created via `AddLink(name, obj)`.
  - **Bucket link** — only `link.bucket` set, `link.name` omitted: points at a whole store (directory-style). Created via `AddBucketLink(name, bucket)`.
- Link objects are stored as normal meta messages with `options.link` populated and **carry no chunks** (no `$O.<bucket>.C.<nuid>` data).
- Link rules (ADR-20): cannot link to a deleted object, cannot link to another link. Overwriting an existing link or bucket-link with the same name is allowed; overwriting a live regular object with a link is an error.
- **`max_chunk_size`** must stay below the connection's negotiated `max_payload` (default 1 MB) — the message is chunk payload plus subject/header overhead, so leave headroom. See [[07 Object Store]] and [[Core NATS Protocol]].
- ADR-20 notes links are "under discussion whether they are necessary" — treat as an optional/lower-priority feature.

## Example JSON
Object link with a custom chunk size (the `options` object as it appears inside [[ObjectInfo]]):
```json
{
  "link": { "bucket": "link-to-bucket", "name": "link-to-name" },
  "max_chunk_size": 8196
}
```
Bucket link (`name` omitted ⇒ directory-style link to a whole store):
```json
{
  "link": { "bucket": "other-store" }
}
```

## Referenced by
[[ObjectInfo]] · [[07 Object Store]] · [[StreamConfig]] · [[Schema Catalog]] · [[JetStream JSON Schemas]]

## Sources
- [ADR-20 — JetStream based Object Stores](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-20.md)
- [NATS docs — Object Store concept](https://docs.nats.io/nats-concepts/jetstream/obj_store)
- [NATS docs — Developing with Object Store](https://docs.nats.io/using-nats/developer/develop_jetstream/object)

#reference #schema
