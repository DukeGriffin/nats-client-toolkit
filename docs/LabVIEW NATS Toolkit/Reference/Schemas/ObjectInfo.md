---
type: schema
source: https://raw.githubusercontent.com/nats-io/nats-architecture-and-design/main/adr/ADR-20.md
---

# ObjectInfo

> Metadata for a stored object. Object Store has **no jsm.go JSON schema file** — it is a convention over JetStream (ADR-20). `ObjectInfo` = `ObjectMeta` (serialized inline) + instance fields, and **is** a real wire payload: it is the body of the meta message PUBlished to `$O.<bucket>.M.<name-encoded>` (with a rollup header so it supersedes prior meta for that name). See [[07 Object Store]].

**Required fields:** none formally specified (ADR-defined struct, not a JSON schema). By struct semantics `name`, `bucket`, `nuid`, `size`, `chunks`, `digest` are always present on a real (non-link) object; link/tombstone objects omit `nuid`/`size`/`chunks`/`digest`. See notes.
**Used by:** [[07 Object Store]]

## Fields
| Field (JSON key / conceptual) | Type | Required | Wire source / Default | Description |
|---|---|---|---|---|
| `name` | `string` | see notes | ObjectMeta; base64url-encoded (with padding) into the meta subject | Object name (unrestricted). |
| `description` | `string` | No | ObjectMeta; `omitempty` | Human description. |
| `headers` | `map<string,[]string>` | No | ObjectMeta; `omitempty` | NATS-style multi-value headers. |
| `metadata` | `map<string,string>` | No | ObjectMeta; `omitempty` (rev 2) | User key-value metadata. |
| `options` | `object → [[ObjectMetaOptions]]` | No | ObjectMeta; `omitempty` | `link` + `max_chunk_size`. |
| `bucket` | `string` | see notes | ObjectInfo | Owning bucket name. |
| `nuid` | `string` | see notes | ObjectInfo | Object instance id; ties this meta to its `$O.<bucket>.C.<nuid>` chunks. |
| `size` | `uint64` | see notes | ObjectInfo | Total object size in bytes. |
| `chunks` | `uint32` | see notes | ObjectInfo | Total number of chunk messages. |
| `digest` | `string` | see notes | ObjectInfo; `omitempty` | `SHA-256=<value>` (see Constraints). |
| `mtime` | `int64 (ns)` / timestamp | see notes | **Never stored**; client fills from the meta message's server timestamp on read, current UTC on write | Modification time. |
| `deleted` | `bool` | No | ObjectInfo; `omitempty` | `true` = tombstone (object logically deleted). |

## Constraints & validation / Notes
- ADR-20 defines Go structs (`ObjectMeta` embedded in `ObjectInfo`), not a JSON schema — there is no formal `required` array, hence "see notes". Struct semantics: a live regular object always carries `name`, `bucket`, `nuid`, `size`, `chunks`, `digest`; link objects and tombstones omit the chunk-related fields.
- **`mtime` is never persisted.** It is `omitempty`-free in the struct but populated by the client from the message time on read and from current UTC on write — do not rely on reading it back from stored JSON.
- **Digest format:** `<algorithm>=<value>`, algorithm token uppercase **`SHA-256`** (only supported algorithm, RFC-6234 uppercase form), e.g. `SHA-256=IdgP4UYMGt47rgecOqFoLrd24AXukHf5-SVzqQ5Psg8=`. The `<value>` is the SHA-256 digest encoded as **base64 URL-safe WITH padding** (Go `base64.URLEncoding`) — note the `-`/`_` alphabet and trailing `=` padding — so the token stays subject-legal. Confirmed against `nats.go`. See [[07 Object Store]].
- **Name encoding:** the object `name` is encoded with **base64 URL-safe WITH padding** (Go `base64.URLEncoding`) to form `<name-encoded>` for the meta subject `$O.<bucket>.M.<name-encoded>` — URL-safe so it avoids `/` and `+` and stays subject-legal. Confirmed against `nats.go`. See [[07 Object Store]].
- **Rollup on Put:** the meta message is published with the rollup header **`Nats-Rollup: sub`** so it replaces prior meta for the same name (the backing stream has `allow_rollup_hdrs: true`). Confirmed against `nats.go`. See [[04 JetStream Publishing]].
- Chunk size for the object's chunks defaults to **128 KiB (131 072 bytes)**, overridable via `options.max_chunk_size` — see [[ObjectMetaOptions]].

## Example JSON
The meta message payload (based on the ADR-20 example; `metadata` is shown as the `map<string,string>` the toolkit serializes, matching the field table above):
```json
{
  "name": "object-name",
  "description": "object-desc",
  "metadata": {"owner": "infra"},
  "headers": { "key1": ["foo"], "key2": ["bar", "baz"] },
  "options": {
    "link": { "bucket": "link-to-bucket", "name": "link-to-name" },
    "max_chunk_size": 8196
  },
  "bucket": "object-bucket",
  "nuid": "CkuyLEX4z2hbyjj1aWCfiH",
  "size": 344000,
  "chunks": 42,
  "digest": "SHA-256=abcdefghijklmnopqrstuvwxyz=",
  "deleted": true
}
```

## Nested types
- `options` → [[ObjectMetaOptions]] (which carries `link` → `{ bucket, name }`)

## Referenced by
[[07 Object Store]] · [[ObjectMetaOptions]] · [[StreamConfig]] · [[Schema Catalog]] · [[JetStream JSON Schemas]]

## Sources
- [ADR-20 — JetStream based Object Stores](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-20.md)
- [NATS docs — Object Store concept](https://docs.nats.io/nats-concepts/jetstream/obj_store)
- [NATS docs — Developing with Object Store](https://docs.nats.io/using-nats/developer/develop_jetstream/object)

#reference #schema
