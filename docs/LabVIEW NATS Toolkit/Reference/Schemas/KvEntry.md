---
type: schema
source: https://raw.githubusercontent.com/nats-io/nats-architecture-and-design/main/adr/ADR-8.md
---

# KvEntry

> A single Key-Value entry returned by Get / GetRevision / History / Watch. KV has **no jsm.go JSON schema file** — an entry is **not a wire message**. The client assembles it from a delivered JetStream `MSG`/`HMSG` frame: the payload, the subject, the `$JS.ACK`/message sequence, the message timestamp, and the `KV-Operation` header (ADR-8 `Entry` interface). See [[06 Key-Value Store]].

**Required fields:** none formally specified (ADR-defined `Entry` interface, not a JSON schema). Every accessor is always populated by the client — see Wire source column.
**Used by:** [[06 Key-Value Store]]

## Fields
| Field (Go accessor / conceptual) | Type | Required | Wire source / Default | Description |
|---|---|---|---|---|
| `Bucket` | `string` | see notes | Stream name minus `KV_` prefix (stream metadata) | Bucket the data came from. |
| `Key` | `string` | see notes | Subject minus `$KV.<bucket>.` prefix | Key retrieved. |
| `Value` | `bytes` | see notes | **Message payload** | Value bytes. Empty for `DEL`/`PURGE` markers. |
| `Revision` | `uint64` | see notes | **Stream sequence** (from `$JS.ACK` token / stored-msg `seq`) | Unique sequence for this value = the stream sequence. |
| `Created` | `int64 (ns)` / timestamp | see notes | **Message timestamp** (server-set on store) | When the message entered the bucket. |
| `Delta` | `uint64` | see notes | Consumer `num_pending` (pending + 1) or history index | Distance from the latest value: `0` = latest, `1` = one before, … |
| `Operation` | `string` enum | see notes | **`KV-Operation` header** (absent ⇒ `PUT`) | One of `PUT`, `DEL`, `PURGE`. |

## Enums
- **Operation** — `PUT`: a normal value write (header absent/unset); `DEL`: a delete marker (empty body, key logically removed, history preserved); `PURGE`: a purge marker (empty body, all prior revisions of the key rolled up/removed).

## Constraints & validation / Notes
- ADR-8 defines `Entry` as an interface, not a JSON schema — there is no formal `required` array, hence "see notes" above. In practice the client populates every field on every returned entry.
- **Operation derivation:** any `KV-Operation` value other than unset means "deleted". Canonical values are `DEL` and `PURGE`; an absent header is `PUT`. A GET landing on a `DEL`/`PURGE` marker returns *key-not-found*; History/Watch surface it as an entry with `Operation` set.
- **Server-generated markers** (buckets with `allow_msg_ttl`) carry a `Nats-Marker-Reason` header instead of `KV-Operation`; map it to an operation: `MaxAge` ⇒ `PURGE`, `Purge` ⇒ `PURGE`, `Remove` ⇒ `DEL`.
- `Revision` is the JetStream **stream** sequence (not a per-key counter); `GetRevision` reads by that sequence via `stream_msg_get_request`.
- KV does **not** provide read-after-write consistency (ADR-8): a read may hit an out-of-date replica.

## Example JSON
`KvEntry` is a client-assembled cluster, not a wire payload. Illustrative shape (for documentation only):
```json
{
  "bucket": "CONFIGURATION",
  "key": "auth.username",
  "value": "YWRtaW4=",
  "revision": 42,
  "created": "2026-07-23T12:20:11Z",
  "delta": 0,
  "operation": "PUT"
}
```
On the wire this is a single delivered message: payload `admin`, subject `$KV.CONFIGURATION.auth.username`, sequence `42`, no `KV-Operation` header.

## Referenced by
[[06 Key-Value Store]] · [[StreamConfig]] · [[Schema Catalog]] · [[JetStream JSON Schemas]]

## Sources
- [ADR-8 — JetStream based Key-Value Stores](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-8.md)
- [NATS docs — Key/Value Store concept](https://docs.nats.io/nats-concepts/jetstream/key-value-store)
- [NATS docs — Developing with KV](https://docs.nats.io/using-nats/developer/develop_jetstream/kv)

#reference #schema
