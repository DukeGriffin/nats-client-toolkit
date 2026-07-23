---
type: reference
source: https://github.com/nats-io/jsm.go/tree/main/schemas
---

# JetStream JSON Schemas (request/response manifest)

> **What this note is for** · the *manifest* mapping each operation → its `.json` schema file (request + response), so you know which schema to codegen/validate against · **not** here: the subjects & response envelope (see [[JetStream Wire API]]) · per-field type docs (see [[Schema Catalog]] and the type pages) · the LabVIEW module scope (see [[03 JetStream Management API]])

New to NATS? See [[NATS in 5 Minutes]] and the [[Glossary]].

The canonical, machine-readable JSON Schemas for every JetStream admin request and response. **This is the master list for the LabVIEW wrapper work** — most of the toolkit is a cluster↔JSON (de)serializer per row below. Each schema's `$id` is the same string that appears in a response message's `type` field (e.g. `io.nats.jetstream.api.v1.stream_info_response`).

Source repo: [`nats-io/jsm.go/schemas`](https://github.com/nats-io/jsm.go/tree/main/schemas). See [[JetStream Wire API]] for the subjects these ride on, and [[NATS Docs Map]] for the ADR index.

> **Per-type field docs:** this page maps *operations → schema files*. For the *field-level* documentation of each type (every field with type / **required** / default / enum), see the [[Schema Catalog]] — one page per type. Key types below link to their detail page.

## How to fetch a schema
- Human-readable (rendered): `https://github.com/nats-io/jsm.go/blob/main/schemas/jetstream/api/v1/<file>`
- Raw JSON (for tooling / codegen): `https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/<file>`
- `type` string ↔ file: `io.nats.jetstream.api.v1.<basename>` ⇄ `<basename>.json` (micro uses `io.nats.micro.v1.<basename>`).

> Note on KV & Object Store: there are **no** `kv_*.json` / `obj_*.json` schema files here. A KV bucket is a plain [`stream_configuration`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_configuration.json) with specific settings ([[06 Key-Value Store]]); the KV entry is a message + headers. Object Store's `ObjectMeta`/`ObjectInfo` is defined only in **ADR-20** ([[07 Object Store]]), not as a jsm.go api/v1 schema. So those wrappers are hand-built from the ADRs, not generated from a schema file.

---

## Shared config objects (embedded in many messages)
| Object | Detail page | Schema file | Used in |
|---|---|---|---|
| StreamConfig | [[StreamConfig]] | [`stream_configuration.json`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_configuration.json) | stream create/update requests, info/list responses, KV & Object buckets |
| ConsumerConfig | [[ConsumerConfig]] | [`consumer_configuration.json`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_configuration.json) | consumer create request, info/list responses |
| PubAck | [[PubAck]] | [`pub_ack_response.json`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/pub_ack_response.json) | reply to publishing into a stream |
| Error envelope | [[ApiError]] | (in every response schema) | shared by all `$JS.API.*` responses |

## Streams — `$JS.API.STREAM.*` ([[03 JetStream Management API]])
| Operation / subject | What it does | Request schema | Response schema |
|---|---|---|---|
| CREATE `.CREATE.<name>` | Create a new stream from a [[StreamConfig]]. Errors if the name already exists or the config is invalid. | [`stream_create_request`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_create_request.json) | [`stream_create_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_create_response.json) → [[StreamInfo]] |
| UPDATE `.UPDATE.<name>` | Change an existing stream's config in place. Some fields are immutable (e.g. `storage`, `retention`, `name`) — the server rejects changes to them. | [`stream_update_request`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_update_request.json) | [`stream_update_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_update_response.json) → [[StreamInfo]] |
| INFO `.INFO.<name>` | Fetch a stream's current config **and** runtime state (message count, bytes, first/last sequence, consumer count, cluster). The primary "read" call. | [`stream_info_request`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_info_request.json) | [`stream_info_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_info_response.json) → [[StreamInfo]] |
| DELETE `.DELETE.<name>` | Permanently delete the stream **and every message in it**. Irreversible. | *(no body)* | [`stream_delete_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_delete_response.json) |
| PURGE `.PURGE.<name>` | Delete messages from the stream without deleting the stream. Optional [[StreamPurgeRequest]] narrows it: `filter` (subject), `seq` (up to), or `keep` (retain last N). | [`stream_purge_request`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_purge_request.json) | [`stream_purge_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_purge_response.json) |
| LIST (full configs) `.LIST` | Page through the **full config + state** of every stream in the account. Heavier; use [[ListPaging]] to iterate. | [`stream_list_request`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_list_request.json) | [`stream_list_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_list_response.json) |
| NAMES (names only) `.NAMES` | Page through stream **names only** (lightweight). Optional `subject` filter answers "which stream captures this subject?". | [`stream_names_request`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_names_request.json) | [`stream_names_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_names_response.json) |
| MSG GET `.MSG.GET.<name>` | Read a single stored message directly — by `seq`, or the last message on a subject ([[StreamMsgGetRequest]]) — **without creating a consumer**. Underpins KV/Object direct reads. | [`stream_msg_get_request`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_msg_get_request.json) | [`stream_msg_get_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_msg_get_response.json) |
| MSG DELETE `.MSG.DELETE.<name>` | Delete (or securely erase) a single stored message by sequence. | [`stream_msg_delete_request`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_msg_delete_request.json) | [`stream_msg_delete_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_msg_delete_response.json) |

The `stream_create_response` / `stream_update_response` / `stream_info_response` schemas are the same payload: the create/info response body **is** a [[StreamInfo]] (`config` + runtime `state`) wrapped in the standard envelope — decode one, reuse for all three.

Clustering/backup (lower priority — [[09 Monitoring and Admin]]): [`stream_snapshot_request`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_snapshot_request.json)/[`_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_snapshot_response.json), [`stream_restore_request`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_restore_request.json)/[`_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_restore_response.json), [`stream_leader_stepdown_request`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_leader_stepdown_request.json)/[`_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_leader_stepdown_response.json), [`stream_remove_peer_request`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_remove_peer_request.json)/[`_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_remove_peer_response.json).

## Consumers — `$JS.API.CONSUMER.*` ([[05 JetStream Consuming]])
| Operation / subject | What it does | Request schema | Response schema |
|---|---|---|---|
| CREATE `.CREATE.<stream>` (+ legacy `.DURABLE.CREATE.<stream>.<name>`) | Create a consumer (a server-side cursor/view over a stream) from a [[ConsumerConfig]]. Durable vs ephemeral and push vs pull are decided by the config, not the subject. | [`consumer_create_request`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_create_request.json) | [`consumer_create_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_create_response.json) → [[ConsumerInfo]] |
| INFO `.INFO.<stream>.<consumer>` | Fetch a consumer's config + runtime state (`delivered`/`ack_floor` sequences, num pending/redelivered/waiting). The primary consumer "read" call. | [`consumer_info_request`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_info_request.json) | [`consumer_info_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_info_response.json) → [[ConsumerInfo]] |
| DELETE `.DELETE.<stream>.<consumer>` | Delete the consumer and discard its durable delivery/ack state. | *(no body)* | [`consumer_delete_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_delete_response.json) |
| LIST (full) `.LIST.<stream>` | Page through the full config + state of every consumer on a stream ([[ListPaging]]). | [`consumer_list_request`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_list_request.json) | [`consumer_list_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_list_response.json) |
| NAMES `.NAMES.<stream>` | Page through consumer **names only** on a stream (lightweight). | [`consumer_names_request`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_names_request.json) | [`consumer_names_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_names_response.json) |
| MSG NEXT (pull) `.MSG.NEXT.<stream>.<consumer>` | **Pull** the next batch of messages for a pull consumer: publish a [[ConsumerGetnextRequest]] with a reply inbox; the server delivers up to `batch` messages there (then a status message). This is the read loop for pull consumers. | [`consumer_getnext_request`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_getnext_request.json) | *(none — messages delivered to the reply inbox; see [[05 JetStream Consuming]])* |

Newer admin (defer unless needed): [`consumer_pause_request`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_pause_request.json)/[`_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_pause_response.json), [`consumer_reset_request`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_reset_request.json)/[`_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_reset_response.json), [`consumer_unpin_request`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_unpin_request.json)/[`_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_unpin_response.json), [`consumer_leader_stepdown_request`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_leader_stepdown_request.json)/[`_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_leader_stepdown_response.json).

## Publish ack ([[04 JetStream Publishing]])
| What | Schema |
|---|---|
| Reply to a message published into a stream | [`pub_ack_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/pub_ack_response.json) |

## Account / meta — `$JS.API.INFO`, admin
| Operation | What it does | Request | Response |
|---|---|---|---|
| Account info `$JS.API.INFO` | Report JetStream usage + limits for the account (memory/storage bytes, stream/consumer counts, API call totals, tiers). Also the handshake to confirm JetStream is enabled for the account. | *(no body)* | [`account_info_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/account_info_response.json) |
| Account purge | (Admin/`$SYS`) Purge all JetStream data for an account. | *(admin)* | [`account_purge_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/account_purge_response.json) |
| Meta leader stepdown | (Cluster admin) Force the JetStream metadata (RAFT meta-group) leader to step down and trigger re-election. | [`meta_leader_stepdown_request`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/meta_leader_stepdown_request.json) | [`meta_leader_stepdown_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/meta_leader_stepdown_response.json) |
| Meta server remove | (Cluster admin) Remove a server/peer from the JetStream meta cluster. | [`meta_server_remove_request`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/meta_server_remove_request.json) | [`meta_server_remove_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/meta_server_remove_response.json) |

## Services / micro — `$SRV.*` ([[08 Services Framework]])
Base: `schemas/micro/v1/` · `type` = `io.nats.micro.v1.<basename>`. Each is a reply a service instance sends when it receives the matching `$SRV.<VERB>[.name[.id]]` request.
| Verb / subject | What it does | Response schema |
|---|---|---|
| PING `$SRV.PING` | Liveness + discovery: every running service instance replies with its identity ([[ServicePing]]) so callers can enumerate what's up. | [`ping_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/micro/v1/ping_response.json) |
| INFO `$SRV.INFO` | Describe a service: identity plus its endpoints (name, subject, queue group) — see [[ServiceInfo]]. | [`info_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/micro/v1/info_response.json) |
| STATS `$SRV.STATS` | Per-endpoint operational stats: request/error counts and processing-time totals ([[ServiceStats]]). | [`stats_response`](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/micro/v1/stats_response.json) |

## Advisories & metrics ([[09 Monitoring and Admin]])
Event/advisory and metric schemas (e.g. consumer ack samples, stream/consumer actions) live under [`schemas/jetstream/advisory/v1/`](https://github.com/nats-io/jsm.go/tree/main/schemas/jetstream/advisory/v1) and [`schemas/jetstream/metric/v1/`](https://github.com/nats-io/jsm.go/tree/main/schemas/jetstream/metric/v1). Published to `$JS.EVENT.ADVISORY.>` / `$JS.EVENT.METRIC.>`. Enumerate when/if [[09 Monitoring and Admin]] is built.

## LabVIEW wrapping implications
- Every row above = one request cluster→JSON encoder and/or one JSON→response cluster decoder. This is the bulk of modules [[03 JetStream Management API]]–[[07 Object Store]].
- StreamConfig/ConsumerConfig are the two big reused clusters — build and test these first (validate against a live `stream_info_response`, per [[Risks and Open Questions]]).
- Every response shares the standard envelope with an optional `error {code, err_code, description}` — decode that once, reuse everywhere (ties to the error-convention decision in [[Risks and Open Questions]]).
- Consider generating LabVIEW typedefs from the raw `.json` schemas rather than hand-transcribing — the schemas are the source of truth and version with the server.

## Sources
- [jsm.go `schemas/` (all JSON Schemas)](https://github.com/nats-io/jsm.go/tree/main/schemas)
- [JetStream `api/v1` directory](https://github.com/nats-io/jsm.go/tree/main/schemas/jetstream/api/v1) · [micro `v1` directory](https://github.com/nats-io/jsm.go/tree/main/schemas/micro/v1)
- [NATS ADRs](https://github.com/nats-io/nats-architecture-and-design/tree/main/adr) (canonical for KV / Object Store types)
- [Wire API reference (docs.nats.io)](https://docs.nats.io/reference/reference-protocols/nats_api_reference)

#reference
