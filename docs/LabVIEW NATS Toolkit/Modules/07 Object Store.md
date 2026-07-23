---
type: module
status: planned
---

# 07 — Object Store

## Scope
- Also JetStream-backed: chunked messages + a metadata stream per bucket.
- Chunking/reassembly logic — LabVIEW byte array handling, not conceptually hard, just needs care around buffer sizing.
- Digest/checksum verification on reassembly.

## Depends on
- [[03 JetStream Management API]], [[04 JetStream Publishing]], [[05 JetStream Consuming]]
- Benefits from patterns established in [[06 Key-Value Store]] (do that module first)

## Docs
- `nats-concepts/jetstream/obj_store`
- `using-nats/developer/develop_jetstream/object`

## Open questions
- ~~#question Chunk size defaults/limits and how they interact with `max_payload`~~ **RESOLVED** — see [Chunk size vs. `max_payload`](#chunk-size-vs-max_payload-resolved) below. ADR-20 fixes the default chunk size at **128 KiB (128 × 1024 = 131 072 bytes)**, deliberately below the default 1 MB `max_payload` of [[Core NATS Protocol]]. Clients may tune chunk size per object via `options.max_chunk_size`, but must keep it under the negotiated server `max_payload`.
- ~~#question **Rollup header name/value.**~~ **RESOLVED** — the meta message is published with the header **`Nats-Rollup: sub`** (rollup on the message's own subject); confirmed against nats.go (`MsgRollup` / `MsgRollupSubject`). See [[04 JetStream Publishing]] and [[Glossary]].
- ~~#question **Object-name → subject-token encoding.**~~ **RESOLVED** — the object name is encoded with **base64 URL-safe, WITH padding** (Go `base64.URLEncoding`; alphabet `A–Z a–z 0–9 - _` plus `=` padding) to form `$O.<bucket>.M.<name-encoded>`; confirmed against nats.go. Note this is **different** from the auth `sig` in [[02 Authentication]], which is base64url **no-padding**.
- #question **Watch/List delivery model.** Watch/List run an ephemeral ordered consumer over the meta subject `$O.<bucket>.M.>`; this reuses the same async delivery-model decision still deferred in [[05 JetStream Consuming]], [[06 Key-Value Store]], and [[Risks and Open Questions]].

## Notes / decisions log
- #decision Meta rollup header is **`Nats-Rollup: sub`** (confirmed against nats.go `MsgRollup`/`MsgRollupSubject`) — needs `allow_rollup_hdrs: true` on the backing stream.
- #decision Object name → subject token uses **base64url WITH padding** (Go `base64.URLEncoding`); the `SHA-256=` **digest** value uses the same base64url-with-padding encoding of the raw 32-byte hash (confirmed against nats.go). Distinct from the auth `sig` (base64url no-padding).

---

# Reference (from ADR-20 + docs)

> Canonical source: **NATS ADR-20 "JetStream based Object Stores"** — `https://raw.githubusercontent.com/nats-io/nats-architecture-and-design/main/adr/ADR-20.md` (Status: Implemented; rev 3, 2024-02-05, adds compression).
> Concept/API docs: `https://docs.nats.io/nats-concepts/jetstream/obj_store` and `https://docs.nats.io/using-nats/developer/develop_jetstream/object`. The docs pages are thin; the ADR is authoritative for the wire/subject layout.
> The Object Store is a **convention over a JetStream stream** — no new wire protocol. Everything below is plain [[04 JetStream Publishing]] / [[05 JetStream Consuming]] against one stream per bucket, so it sits on top of what [[03 JetStream Management API]] already builds.

## Stream backing a bucket

A **bucket** — a named namespace of objects (see [[Glossary]]) — is backed by exactly one stream. Creating a bucket is a stream CREATE (`$JS.API.STREAM.CREATE.OBJ_<bucket>`) and deleting one is a stream DELETE (`$JS.API.STREAM.DELETE.OBJ_<bucket>`) — see [[03 JetStream Management API]]. All names are derived by template (ADR-20 §Naming, §Stream Config); `<bucket>` is restricted to `A-Z a-z 0-9 - _`:

| Component | Template | Example (bucket `MY-STORE`) |
| --- | --- | --- |
| Stream name | `OBJ_<bucket>` | `OBJ_MY-STORE` |
| Chunk stream subject | `$O.<bucket>.C.>` | `$O.MY-STORE.C.>` |
| Meta stream subject | `$O.<bucket>.M.>` | `$O.MY-STORE.M.>` |
| Chunk **message** subject | `$O.<bucket>.C.<object-nuid>` | `$O.MY-STORE.C.CkuyLEX4z2hbyjj1aWCfiH` |
| Meta **message** subject | `$O.<bucket>.M.<name-encoded>` | `$O.MY-STORE.M.<base64url(name)>` |

- `<object-nuid>` is a NUID assigned per stored object instance (not per name). Every chunk of one Put shares the same nuid; a re-Put of the same name gets a **new** nuid, and the meta rollup supersedes the old one.
- `<name-encoded>` is the object name encoded with **base64 URL-safe, WITH padding** (Go `base64.URLEncoding`; alphabet `A–Z a–z 0–9 - _` plus `=` padding), confirmed against nats.go. One meta subject per object name means "latest wins" via per-subject **rollup** — publishing the new meta with the `Nats-Rollup: sub` header tells the server to delete all prior meta on that subject and keep only this one (see [[Glossary]]).

### StreamConfig used (ADR-20 example, verbatim shape)

```json
{
  "name": "OBJ_MY-STORE",
  "description": "description",
  "metadata": [{"owner": "infra"}],
  "subjects": [
    "$O.MY-STORE.C.>",
    "$O.MY-STORE.M.>"
  ],
  "max_age": 0,
  "max_bytes": -1,
  "storage": "file",
  "num_replicas": 1,
  "allow_rollup_hdrs": true,
  "allow_direct": true,
  "discard": "new",
  "placement": { "cluster": "clstr", "tags": ["tag1", "tag2"] },
  "compression": "s2"
}
```

Load-bearing fields for the implementation:
- **`subjects`** — both the chunk and meta wildcard subjects on one stream.
- **`allow_rollup_hdrs: true`** — REQUIRED. Enables the per-subject **rollup** (via the `Nats-Rollup: sub` header) that lets a new meta message replace all prior meta for that name. (The `rollup_hdrs` spelling in older ADR samples is outdated shorthand; the server/schema field is `allow_rollup_hdrs` — confirmed against nats.go/schema. See [[StreamConfig]].)
- **`allow_direct: true`** — REQUIRED. Lets Get/GetInfo read the meta via direct-get instead of a consumer.
- **`discard: "new"`** — refuse writes over `max_bytes` rather than evicting old chunks.
- **`compression: "s2"`** — only when compression is requested (NATS Server ≥ 2.10). The `ObjectStoreConfig.Compression bool` maps to the string `"s2"`; OS does not expose raw stream internals.
- The `ObjectStoreConfig` → StreamConfig mapping mirrors [[06 Key-Value Store]]: `Bucket`→name template, `TTL`→`max_age`, `MaxBytes`→`max_bytes`, `Storage`→`storage`, `Replicas`→`num_replicas`, `Placement`→`placement`.

## ObjectMeta / ObjectInfo schema

`ObjectInfo` = `ObjectMeta` (serialized inline) + instance fields. This exact JSON is the payload of the meta message.

| Field | JSON key | Type | Source | Notes |
| --- | --- | --- | --- | --- |
| Name | `name` | string | ObjectMeta | required; object name (unrestricted, base64-encoded into the subject) |
| Description | `description` | string | ObjectMeta | optional |
| Headers | `headers` | map[string][]string | ObjectMeta | optional; NATS-style multi-value headers |
| Metadata | `metadata` | map[string]string | ObjectMeta | optional; user KV metadata (rev 2) |
| Options | `options` | object | ObjectMeta | optional; `link` + `max_chunk_size` (see below) |
| Bucket | `bucket` | string | ObjectInfo | owning bucket name |
| NUID | `nuid` | string | ObjectInfo | object instance id; ties meta to its `$O.X.C.<nuid>` chunks |
| Size | `size` | uint64 | ObjectInfo | total object size in bytes |
| Chunks | `chunks` | uint32 | ObjectInfo | total number of chunk messages |
| Digest | `digest` | string | ObjectInfo | `SHA-256=<base64url-value>` (see below) |
| ModTime | `mtime` | timestamp | ObjectInfo | **never stored**; client fills from server message time on read, from current UTC on write |
| Deleted | `deleted` | bool | ObjectInfo | optional; true = tombstone |

`options` sub-object:

| Field | JSON key | Type | Notes |
| --- | --- | --- | --- |
| Link | `link` | object | `{ "bucket": "<store>", "name": "<obj?>" }`. `name` omitted ⇒ link to whole bucket (directory-style). |
| Max chunk size | `max_chunk_size` | uint32 | per-object override of the 128 KiB default |

### Digest format (verified)

The **digest** is the `SHA-256` hash of the object's raw bytes, carried so a reader can verify integrity on reassembly (see [[Glossary]]). ADR-20: "Currently `SHA-256` is the only supported digest. Please use the uppercase form as in RFC-6234." Format is HTTP-style `<algorithm>=<value>`:

```
SHA-256=IdgP4UYMGt47rgecOqFoLrd24AXukHf5-SVzqQ5Psg8=
```

- Algorithm token is **uppercase `SHA-256`**.
- The value is **base64 URL-safe, WITH padding** (Go `base64.URLEncoding`) of the raw 32-byte hash — confirmed against nats.go. Note the URL-safe alphabet (`-`, `_`) and the trailing `=` padding. Encode and verify with base64url-with-padding.

### Example ObjectInfo (ADR-20, verbatim)

```json
{
  "name": "object-name",
  "description": "object-desc",
  "metadata": [{"owner": "infra"}],
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

## Put (store) algorithm

1. Reject if `ObjectMeta.options.link` is set — links go through AddLink / AddBucketLink, not Put.
2. Assign a fresh **`nuid`** for this object instance; all chunks publish to `$O.<bucket>.C.<nuid>`.
3. Choose chunk size = `options.max_chunk_size` if set, else the **128 KiB** default. This MUST be ≤ the server's `max_payload` (default 1 MB — see [[Core NATS Protocol]] for the CONNECT/INFO-negotiated limit; the message is the chunk payload plus subject/headers overhead, so leave headroom).
4. Stream the reader, cutting it into chunks. For each chunk: update a rolling **SHA-256** hash and publish the raw bytes to `$O.<bucket>.C.<nuid>`. Track running `size` and `chunks` count. Use [[04 JetStream Publishing]] acks; on a publish failure, purge `$O.<bucket>.C.<nuid>` and abort.
5. Finalize the digest as `SHA-256=<base64url-with-padding(hash)>` (Go `base64.URLEncoding` of the raw 32-byte hash); set `size`, `chunks`, `nuid`, `bucket`.
6. Publish the `ObjectInfo` JSON to the meta subject `$O.<bucket>.M.<name-encoded>` (name encoded base64url-with-padding) **with the rollup header `Nats-Rollup: sub`** so it supersedes any prior meta for that name (stream has `allow_rollup_hdrs: true`). Confirmed against nats.go (`MsgRollup`/`MsgRollupSubject`).
7. If a previous instance of this name existed, purge its now-orphaned chunk subject `$O.<bucket>.C.<old-nuid>`.
8. Set `mtime` to now (UTC) in the value returned to the caller; do not store it.

Chunking/reassembly is exactly the LabVIEW byte-array buffer work flagged in Scope above — assemble chunks into fixed-size buffers, watch for the final short chunk.

## Get algorithm

1. Read the current meta for the name from `$O.<bucket>.M.<name-encoded>` (direct-get, enabled by `allow_direct`). If absent or `deleted: true`, treat as not-found.
2. Read chunk messages from `$O.<bucket>.C.<nuid>` **in stream order** (an ordered consumer over that exact subject — [[05 JetStream Consuming]]).
3. Reassemble payloads, feeding each into a rolling SHA-256 and writing to the output stream/writer.
4. After the last chunk, compare the computed `SHA-256=<base64url>` against `digest`; mismatch ⇒ error (corrupt/incomplete object). Optionally cross-check byte count against `size` and message count against `chunks`.
5. Fill `mtime` from the meta message's server timestamp.

## Delete

- Mark the object deleted and remove its bytes: publish an updated meta with `deleted: true` (rolled up over `$O.<bucket>.M.<name-encoded>`), and **purge** the chunk subject `$O.<bucket>.C.<nuid>` from the stream.
- No-op if already deleted; error if the name never existed.
- After delete, Get/GetInfo/List treat the object as non-existent (deleted entries filtered by default).

## Watch / List

> `ObjectWatcher` and its options are **client-library labels**, not wire operations. "Ordered consumer" here = the wire recipe in [[05 JetStream Consuming]]; the options below map to consumer `deliver_policy` + client-side filtering of the delivered meta `MSG`/`HMSG` frames, not fields sent to the server by those names. `ObjectInfo` is the LabVIEW cluster we assemble from the meta message JSON.

- **List** = read the latest meta message for every `$O.<bucket>.M.>` subject, deserialize into the `ObjectInfo` cluster, and drop entries with `deleted: true` (convenience option to include them).
- **Watch** (subscribe to future — and optionally current — object changes; see [[Glossary]]) = an ordered consumer (see recipe in [[05 JetStream Consuming]]) over `$O.<bucket>.M.>` that delivers the latest info per object plus all future meta updates. The `ObjectWatcher` options `IncludeHistory` / `IgnoreDeletes` / `UpdatesOnly` are client-side behaviors (choose `deliver_policy` `all` vs `last_per_subject`; filter `deleted:true`; skip the initial snapshot) — implemented by us, not requested by name.
- This is the same async delivery-model pattern as KV watchers; the concrete LabVIEW delivery mechanism is deferred — see the Watch/List `#question` above, [[05 JetStream Consuming]], and [[Risks and Open Questions]].

## Links (object links / bucket links)

Links are stored as normal meta messages whose `options.link` is populated (and which carry no chunks).

- **AddLink(name, obj)** — meta with `link.bucket` + `link.name` pointing at another object. Errors: link to a deleted object; link to a link. Overwriting an existing link or bucket-link with the same name is allowed; overwriting a live regular object is an error.
- **AddBucketLink(name, bucket)** — meta with `link.bucket` set and `link.name` omitted ⇒ points at a whole store (directory-style). Same overwrite rules.
- ADR-20 notes links are "under discussion whether they are necessary" — treat as a lower-priority / optional feature for the toolkit.

## Chunk size vs. `max_payload` (resolved)

- Default chunk size is **128 KiB (131 072 bytes)**, fixed by ADR-20; overridable per object via `options.max_chunk_size`.
- The 128 KiB default sits well under the default **1 MB** `max_payload` on the connection (negotiated in the server `INFO` line — see [[Core NATS Protocol]]). `max_payload` is configurable server-side (up to 64 MB).
- Implementation rule: never emit a chunk whose full message (payload + subject + headers) exceeds the negotiated `max_payload`. Cap effective chunk size at `min(configured_chunk_size, max_payload − overhead)`. This resolves the "chunk size vs max_payload" item in [[Risks and Open Questions]].

## Worked example — store & fetch a 300 KB object

Bucket `ASSETS` ⇒ stream **`OBJ_ASSETS`** · chunk subjects `$O.ASSETS.C.>` · meta subjects `$O.ASSETS.M.>`. Store `sensor-calibration.bin` (307 200 bytes) as three 128 KiB chunks, then Get it back and verify the digest. Object instance nuid `CkuyLEX4z2hbyjj1aWCfiH`; the name token is base64url-**with-padding** of `sensor-calibration.bin` = `c2Vuc29yLWNhbGlicmF0aW9uLmJpbg==` (note the trailing `==`). `C→S`/`S→C` = client/server; `\r\n` shown as `␍␊`; byte counts are real. Also collected in [[Cookbook]].

```
# --- PUT: store the object ---
# 1 · Assign nuid CkuyLEX4z2hbyjj1aWCfiH · publish chunks to $O.ASSETS.C.<nuid> IN ORDER
#     128 KiB = 131072 bytes; 307200 = 131072 + 131072 + 45056 → 3 chunks
C→S  PUB $O.ASSETS.C.CkuyLEX4z2hbyjj1aWCfiH 131072␍␊<…131072 raw bytes…>␍␊
C→S  PUB $O.ASSETS.C.CkuyLEX4z2hbyjj1aWCfiH 131072␍␊<…131072 raw bytes…>␍␊
C→S  PUB $O.ASSETS.C.CkuyLEX4z2hbyjj1aWCfiH 45056␍␊<…45056 raw bytes…>␍␊
#     rolling SHA-256 over the raw bytes → digest SHA-256=EKYWmBP8wEELPXJXT_LdGZeTa5DbghQnE2MVlnz_K7k=

# 2 · Publish the meta to $O.ASSETS.M.<base64url(name)> WITH the rollup header (latest meta wins)
#     Nats-Rollup: sub deletes all prior meta for this name — needs allow_rollup_hdrs on the stream
#     HPUB header block: hdr_len 30, total 202 (header 30 + JSON 172)
C→S  SUB _INBOX.m 1␍␊
C→S  HPUB $O.ASSETS.M.c2Vuc29yLWNhbGlicmF0aW9uLmJpbg== _INBOX.m 30 202␍␊
     NATS/1.0␍␊Nats-Rollup: sub␍␊␍␊{"name":"sensor-calibration.bin","bucket":"ASSETS","nuid":"CkuyLEX4z2hbyjj1aWCfiH","size":307200,"chunks":3,"digest":"SHA-256=EKYWmBP8wEELPXJXT_LdGZeTa5DbghQnE2MVlnz_K7k="}␍␊
S→C  MSG _INBOX.m 1 <n>␍␊
     {"stream":"OBJ_ASSETS","seq":4}␍␊                                   # PubAck for the meta message

# --- GET: fetch & verify ---
# 3 · Read current meta via Direct GET (allow_direct) → gives nuid, size, chunks, digest
C→S  SUB _INBOX.g 2␍␊
C→S  PUB $JS.API.DIRECT.GET.OBJ_ASSETS.$O.ASSETS.M.c2Vuc29yLWNhbGlicmF0aW9uLmJpbg== _INBOX.g 0␍␊␍␊
S→C  HMSG _INBOX.g 2 <hdr> <tot>␍␊
     NATS/1.0␍␊Nats-Stream: OBJ_ASSETS␍␊…␍␊␍␊{"name":"sensor-calibration.bin","bucket":"ASSETS","nuid":"CkuyLEX4z2hbyjj1aWCfiH","size":307200,"chunks":3,"digest":"SHA-256=EKYWmBP8wEELPXJXT_LdGZeTa5DbghQnE2MVlnz_K7k="}␍␊

# 4 · Read the chunks IN STREAM ORDER — ordered consumer over $O.ASSETS.C.<nuid> (see [[05 JetStream Consuming]])
C→S  SUB _INBOX.c 3␍␊
C→S  SUB _INBOX.cc 4␍␊
C→S  PUB $JS.API.CONSUMER.CREATE.OBJ_ASSETS _INBOX.cc 191␍␊
     {"stream_name":"OBJ_ASSETS","config":{"filter_subject":"$O.ASSETS.C.CkuyLEX4z2hbyjj1aWCfiH","deliver_policy":"all","ack_policy":"none","deliver_subject":"_INBOX.c","replay_policy":"instant"}}␍␊
S→C  MSG _INBOX.cc 4 <n>␍␊                                              # ConsumerInfo reply — see [[ConsumerInfo]]
S→C  MSG _INBOX.c 3 131072␍␊<…chunk 1…>␍␊
S→C  MSG _INBOX.c 3 131072␍␊<…chunk 2…>␍␊
S→C  MSG _INBOX.c 3 45056␍␊<…chunk 3…>␍␊

# 5 · Feed each chunk into a rolling SHA-256; after chunk 3 compare against the meta digest
#     computed SHA-256=EKYWmBP8wEELPXJXT_LdGZeTa5DbghQnE2MVlnz_K7k=  ==  meta digest → OK
#     also cross-check bytes read = 307200 (size) and messages = 3 (chunks)
```

## Status / bucket lifecycle

- **Create bucket** — stream CREATE `$JS.API.STREAM.CREATE.OBJ_<bucket>` with the bucket [[StreamConfig]] (both `$O.<bucket>.C.>` and `$O.<bucket>.M.>` subjects on one stream) — see [[03 JetStream Management API]].
- **Delete bucket** — stream DELETE `$JS.API.STREAM.DELETE.OBJ_<bucket>` removes the stream and all chunks + meta.
- **Status** — there is no Object-Store-specific status wire message; the client assembles [[ObjectStoreStatus]] from the backing stream's [[StreamInfo]] via `$JS.API.STREAM.INFO.OBJ_<bucket>` (`Size` from stream state; `TTL`/`Storage`/`Replicas`/`Sealed`/`IsCompressed`/`Metadata` from [[StreamConfig]]). `Sealed` reflects the stream's `sealed` flag — a sealed bucket accepts no further writes or deletes. `BackingStore` is always `JetStream`.

## Related modules

- Depends on [[03 JetStream Management API]] (create/delete the `OBJ_<bucket>` stream), [[04 JetStream Publishing]] (chunk + meta writes, rollup header), [[05 JetStream Consuming]] (ordered chunk read, watch).
- Mirrors [[06 Key-Value Store]] (also a stream-backed convention with per-subject rollup and watchers) — do KV first.
- `max_payload` negotiation lives in [[Core NATS Protocol]].
- Field detail lives in [[ObjectInfo]], [[ObjectMetaOptions]], [[ObjectStoreStatus]], [[StreamConfig]]; new to NATS? see [[NATS in 5 Minutes]] and [[Glossary]].

## Sources
- [ADR-20 — JetStream based Object Stores](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-20.md)
- [Object Store (NATS concepts)](https://docs.nats.io/nats-concepts/jetstream/obj_store)
- [Develop JetStream — Object Store](https://docs.nats.io/using-nats/developer/develop_jetstream/object)
- [ADR-8 — JetStream based Key-Value Stores](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-8.md)
