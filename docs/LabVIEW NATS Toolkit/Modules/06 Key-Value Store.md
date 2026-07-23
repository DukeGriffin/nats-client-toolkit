---
type: module
status: planned
---

# 06 — Key/Value Store

High user-facing value, good validation milestone for the whole stack before tackling Object Store or auth hardening.

## Scope
- Thin semantic layer on top of JetStream streams: one stream per bucket, subject = key.
- Put / get / delete / purge
- History (per-key revisions)
- Watch — subscribe to future (and optionally current) changes of a key or key-range; implemented as a push consumer reusing [[05 JetStream Consuming]] patterns · see [[Glossary]]
- TTL

## Depends on
- [[03 JetStream Management API]], [[04 JetStream Publishing]], [[05 JetStream Consuming]] — all need to be solid first, since KV is a materialized view over JetStream.

## Docs
- `nats-concepts/jetstream/key-value-store`
- `using-nats/developer/develop_jetstream/kv`

## Open questions
- #question Bucket-to-stream naming/subject mapping conventions — confirm against the `$KV.*` prefix behavior before building
- #question Watcher delivery model — the concrete LabVIEW async abstraction (callback vs. queue vs. event) for **watch** delivery is a deferred cross-cutting decision, shared with [[05 JetStream Consuming]] and [[07 Object Store]] · see [[Risks and Open Questions]]

## Notes / decisions log
- #decision Rollup config field is **`allow_rollup_hdrs`** (boolean), not the `rollup_hdrs` shorthand shown in the ADR-8 sample (confirmed against nats.go/schema) · bucket-create payloads set `allow_rollup_hdrs: true` · see [[StreamConfig]]

---

# Reference — JetStream mapping (implementation-ready)

> Canonical source: **NATS ADR-8 "JetStream based Key-Value Stores"** (Status: Implemented) — https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-8.md
> Supporting docs: `nats-concepts/jetstream/key-value-store`, `using-nats/developer/develop_jetstream/kv`.
> KV adds **no new wire protocol** — it is a set of conventions over JetStream streams and NATS headers. See [[JetStream Wire API]].

## Bucket ⇒ backing stream

A **bucket** — a named namespace of keys (see [[Glossary]]) — is materialized as a single JetStream stream. Creating a bucket is a stream CREATE (`$JS.API.STREAM.CREATE.KV_<bucket>`) — see [[03 JetStream Management API]].

| Bucket concept | Stream mapping |
|---|---|
| Bucket name `X` | Stream name **`KV_X`** |
| Bucket subject space | Subjects **`$KV.X.>`** |
| History (revisions per key) | `max_msgs_per_subject` (1–64; min 1 if caller omits) |
| Per-bucket TTL | `max_age` (nanoseconds; `0` = keep forever) |
| Max bucket size | `max_bytes` |
| Max value size | `max_msg_size` |

**StreamConfig used for a bucket** (ADR-8 example, `CONFIGURATION` bucket with compression + limit markers):

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

Invariants the toolkit must always set:
- `discard` = **`new`** (reject writes past limits rather than dropping oldest).
- **rollup** headers **always enabled** (`allow_rollup_hdrs: true`) — required for safe key purges (see Purge below). A **rollup** is publishing a message with the `Nats-Rollup: sub` header, which tells the server to delete all prior messages on that subject and keep only this one — this is how KV PURGE works · see [[Glossary]].
- `deny_delete` = **`true`** (KV never uses raw message-delete; deletes are marker messages).
- `allow_direct` = **`true`** (fast GET path; ADR-8 rev 7 removed support for disabling direct get).
- `storage` = `file`; `retention` = `limits`.
- `compression` = `s2` only if the bucket requested compression. `placement`, `republish`, `metadata` are optional passthroughs.

TTL / limit-marker details:
- Per-key/limit markers require NATS Server API level 1+ (2.11+) — assert via `$JS.API.INFO`, not the connected server version. When markers are requested set `allow_msg_ttl: true` and `subject_delete_marker_ttl` to a duration **> 1 second** (example uses `900000000000` ns = 15 min).
- `duplicate_window` when `max_age` is set: if `max_age` > 2 min ⇒ `duplicate_window` = 2 min; if `max_age` ≤ 2 min ⇒ `duplicate_window` = `max_age`. If left unset the **server** applies this logic (no client code needed) — prefer leaving it unset.

> The stream rollup config field is **`allow_rollup_hdrs`** (boolean) — the `rollup_hdrs` spelling in the ADR-8 sample is outdated shorthand (confirmed against nats.go/schema). Bucket-create payloads must use `allow_rollup_hdrs`; see the #decision in Notes / decisions log, [[StreamConfig]], and [[03 JetStream Management API]].

## Key ⇒ subject mapping

A KV key maps to `$KV.<bucket>.<key>` by appending the key to the subject prefix.

- Example: key `auth.username` in bucket `CONFIGURATION` ⇒ subject **`$KV.CONFIGURATION.auth.username`**.
- Keys are **`.`-delimited tokens** (they *are* NATS subject tokens), enabling wildcard watches (`auth.>`).
- Allowed key characters (concepts doc): `a-z` `A-Z` `0-9` `_` `-` `.` `=` `/`.

## Operations ⇒ JetStream

| KV op | JetStream mechanism | Headers |
|---|---|---|
| **PUT** | Publish (request) to `$KV.<bucket>.<key>` | — |
| **CREATE** (compare-to-null) | PUT that only succeeds if key is new | `Nats-Expected-Last-Subject-Sequence: 0` |
| **UPDATE / CAS** | PUT that only succeeds if latest revision matches | `Nats-Expected-Last-Subject-Sequence: <expected revision>` |
| **GET** (last value) | Direct: `$JS.API.DIRECT.GET.<stream>.<subject>`. Legacy: `stream_msg_get_request` (`$JS.API.STREAM.MSG.GET.<stream>`) with `last_by_subj: $KV.<bucket>.<key>` | — |
| **GetRevision** | `stream_msg_get_request` by stream sequence | — |
| **DELETE** | Publish a marker message (nil body) — history preserved | `KV-Operation: DEL` |
| **PURGE** | Publish a marker (nil body) + server-side rollup of prior revisions | `KV-Operation: PURGE`, `Nats-Rollup: sub` (+ optional `Nats-TTL: <dur>`) |

Notes:
- **CAS** = **compare-and-swap**: a conditional write that only succeeds if the key's current revision matches the one you expected (carried in `Nats-Expected-Last-Subject-Sequence`) · see [[Glossary]].
- **CREATE with `0`** — the `0` check is purge-aware (a purged subject accepts `0` again). On a CREATE failure that is *not* the first message, run the CAS retry:
  1. Load the current value for the key (GET / `GetRevision`).
  2. If it is a live value (`PUT`), the key genuinely exists → return "key exists"; do not retry.
  3. If it is a `DEL`/`PURGE` marker, the key is logically absent → retry as an **UPDATE** with `Nats-Expected-Last-Subject-Sequence` = the stream sequence of that delete marker.
  4. If that UPDATE fails again (someone wrote in between), reload and repeat from step 1.
- **GET path** — prefer **Direct GET** (`$JS.API.DIRECT.GET.<stream>.<subject>`); buckets always set `allow_direct: true`, so it is always available. The legacy `STREAM.MSG.GET` path is only for pre-2.9 servers.
- **Delete is a marker, not a real delete.** `deny_delete: true` blocks raw message removal; a delete is a new message carrying `KV-Operation: DEL` with an empty body. It preserves history and signals watchers/caches/gets. A GET landing on a `DEL`/`PURGE` marker returns *key-not-found*; watchers/history surface it as an `Entry` with the operation set.
- Any `KV-Operation` value other than unset means "deleted" — canonical values are **`DEL`** and **`PURGE`**.
- **PURGE** uses rollup (`Nats-Rollup: sub`): the server writes the purge marker then deletes all prior messages for that subject. Optional TTL'd purge adds `Nats-TTL` (e.g. `Nats-TTL: 1h`).

### Delete/limit markers (bucket with `allow_msg_ttl`)

Clients may receive server-generated markers carrying `Nats-Marker-Reason`:

| `Nats-Marker-Reason` value | Treat entry as |
|---|---|
| `MaxAge` | `PURGE` |
| `Purge`  | `PURGE` |
| `Remove` | `DEL`   |

## Entry structure (returned to the user)

Returned by `Get`, `GetRevision`, `History`, and watchers (ADR-8 `Entry` interface):

| Field | Meaning |
|---|---|
| `Bucket` | Bucket the data came from |
| `Key` | Key retrieved |
| `Value` | Value bytes |
| `Created` | Timestamp the message entered the bucket |
| `Revision` | Unique sequence for this value = **the stream sequence** |
| `Delta` | Distance from the latest value (0 = latest, 1 = one before, …) |
| `Operation` | Enum: `PUT`, `DEL`, or `PURGE` |

## WATCH / History / Keys / Status

> These are **client-side conveniences**, not wire operations. "Ordered Consumer" = the wire recipe in [[05 JetStream Consuming]] (ephemeral push consumer, `ack_policy: none`, gap-detect + recreate). The option names below (`IncludeHistory`, `IgnoreDeletes`, `MetaOnly`, `UpdatesOnly`) are how other client libraries *label* behaviors that we implement as consumer-config (`deliver_policy`, `headers_only`) plus client-side filtering of the delivered `MSG`/`HMSG` frames — they are not fields sent to the server by those names. The `Entry`/`Status` field names are the LabVIEW cluster we hand back, assembled from wire data (payload, `$JS.ACK` seq tokens, `KV-Operation` header, message timestamp).

- **WATCH** — ephemeral **Ordered Consumer** over `$KV.<bucket>.<key-or-wildcard>`, started with **`last_per_subject`**, delivering the latest value per matching key plus subsequent updates. Key spec may be a specific key, a wildcard (`auth.>`), or empty/`>` for the whole bucket. An **End Of Initial Data** signal is emitted the first time a delivered message has `Pending == 0` (and must still be emitted when the range is empty — check via `GetLastMsg()` or Pending+Delivered). Options: `IncludeHistory`, `IgnoreDeletes` (PUT only), `MetaOnly` (no values), `UpdatesOnly` (skip current/historical, emit EOID immediately). Default (no options): all `last_per_subject` values including DEL/PURGE.
  This reuses the async push/ordered-consumer delivery model shared with [[05 JetStream Consuming]] and [[07 Object Store]]. The concrete LabVIEW delivery-model abstraction for watchers is a deferred cross-cutting decision — see the watcher-delivery item in **Open questions** above, [[05 JetStream Consuming]], and [[Risks and Open Questions]].
- **History** — ephemeral **Ordered Consumer** filtered to the key subject with **`deliver_all`**, returning every revision; the current value is the message with `Pending == 0`. Max history depth is 64.
- **Keys** — a **headers-only** consumer set to deliver **last per subject**; parse each subject into a key, skipping `DEL`/`PURGE` operations. Supports the same key-spec filtering as Watch.
- **Status** — bucket-level info (ADR-8 `Status`): `Bucket`, `Values` (message count incl. history), `History` (configured per-key), `TTL`, `LimitMarkerTTL` (0 = markers unsupported), `IsCompressed`, `BackingStore` (returns **`JetStream`**), `Bytes`, `Metadata`. The JetStream implementation can expose the underlying `StreamInfo()` for full state.
- **Delete bucket** — remove the stream entirely (`$JS.API.STREAM.DELETE.KV_<bucket>`), see [[03 JetStream Management API]].

## Consistency note

ADR-8 states KV does **not** provide read-after-write consistency: reads go to any replica, including out-of-date ones. Relevant to CAS retry logic and to test expectations.

## Worked example — `CONFIG` bucket, end to end

Bucket `CONFIG` ⇒ stream **`KV_CONFIG`** · subject space **`$KV.CONFIG.>`**. Store key `auth.username` = `labview-01` with CREATE semantics, read it back via Direct GET, then watch `auth.>`. `C→S`/`S→C` = client/server; `\r\n` shown as `␍␊`; PUB/HPUB byte counts are real. Also collected in [[Cookbook]].

```
# 1 · Create the bucket = stream CREATE (see [[03 JetStream Management API]])
C→S  SUB _INBOX.b 1␍␊
C→S  PUB $JS.API.STREAM.CREATE.KV_CONFIG _INBOX.b 191␍␊
     {"name":"KV_CONFIG","subjects":["$KV.CONFIG.>"],"retention":"limits","max_msgs_per_subject":5,"discard":"new","storage":"file","allow_direct":true,"allow_rollup_hdrs":true,"deny_delete":true}␍␊
S→C  MSG _INBOX.b 1 <n>␍␊
     {"type":"io.nats.jetstream.api.v1.stream_create_response", …}␍␊     # body is a StreamInfo — see [[StreamInfo]]

# 2 · PUT auth.username = labview-01 with CREATE semantics (fails if the key already exists)
#     HPUB header block: hdr_len 52, total 62 (header 52 + payload 10). Nats-Expected-Last-Subject-Sequence: 0 = "must be new"
C→S  SUB _INBOX.p 2␍␊
C→S  HPUB $KV.CONFIG.auth.username _INBOX.p 52 62␍␊
     NATS/1.0␍␊Nats-Expected-Last-Subject-Sequence: 0␍␊␍␊labview-01␍␊
S→C  MSG _INBOX.p 2 30␍␊
     {"stream":"KV_CONFIG","seq":1}␍␊                                    # PubAck — revision = seq = 1

# 3 · GET (last value) via Direct GET — no consumer, served from any replica (allow_direct)
C→S  SUB _INBOX.g 3␍␊
C→S  PUB $JS.API.DIRECT.GET.KV_CONFIG.$KV.CONFIG.auth.username _INBOX.g 0␍␊␍␊
S→C  HMSG _INBOX.g 3 <hdr> <tot>␍␊
     NATS/1.0␍␊Nats-Stream: KV_CONFIG␍␊Nats-Subject: $KV.CONFIG.auth.username␍␊Nats-Sequence: 1␍␊␍␊labview-01␍␊

# 4 · WATCH auth.> = ephemeral ordered consumer over $KV.CONFIG.auth.> (see [[05 JetStream Consuming]])
#     last_per_subject delivers the latest value per matching key, then live updates
C→S  SUB _INBOX.w 4␍␊                                                    # delivery subject for the watch
C→S  SUB _INBOX.wc 5␍␊
C→S  PUB $JS.API.CONSUMER.CREATE.KV_CONFIG _INBOX.wc 186␍␊
     {"stream_name":"KV_CONFIG","config":{"filter_subject":"$KV.CONFIG.auth.>","deliver_policy":"last_per_subject","ack_policy":"none","deliver_subject":"_INBOX.w","replay_policy":"instant"}}␍␊
S→C  MSG _INBOX.wc 5 <n>␍␊                                               # ConsumerInfo reply — see [[ConsumerInfo]]
S→C  MSG _INBOX.w 4 10␍␊
     labview-01␍␊                                                        # first delivery: current value of auth.username
# subsequent PUTs / DEL / PURGE on $KV.CONFIG.auth.> now arrive on _INBOX.w as they happen
```

## Status / bucket lifecycle

- **Create bucket** — stream CREATE `$JS.API.STREAM.CREATE.KV_<bucket>` with the bucket [[StreamConfig]] (see [[03 JetStream Management API]]).
- **Delete bucket** — stream DELETE `$JS.API.STREAM.DELETE.KV_<bucket>` removes the stream and all keys.
- **Status** — there is no KV-specific status wire message; the client assembles [[KvStatus]] from the backing stream's [[StreamInfo]] via `$JS.API.STREAM.INFO.KV_<bucket>` (`Values`/`Bytes` from stream state; `History`/`TTL`/`LimitMarkerTTL`/`IsCompressed` from [[StreamConfig]]). `BackingStore` is always `JetStream`.

## Related modules

- Depends on [[03 JetStream Management API]] (create/delete the `KV_<bucket>` stream), [[04 JetStream Publishing]] (PUT/CREATE/UPDATE/DELETE/PURGE writes + expectation headers), [[05 JetStream Consuming]] (ordered consumer behind Watch/History/Keys).
- Mirrored by [[07 Object Store]] (also a stream-backed convention with per-subject rollup and watchers) — do KV first.
- Field detail lives in [[KvConfig]], [[KvEntry]], [[KvStatus]], [[StreamConfig]]; new to NATS? see [[NATS in 5 Minutes]] and [[Glossary]].

## Sources
- [ADR-8 — JetStream based Key-Value Stores](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-8.md)
- [Key/Value Store (NATS concepts)](https://docs.nats.io/nats-concepts/jetstream/key-value-store)
- [Develop JetStream — KV](https://docs.nats.io/using-nats/developer/develop_jetstream/kv)
