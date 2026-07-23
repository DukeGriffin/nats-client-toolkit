---
type: module
status: planned
---

# 03 — JetStream Management API (Streams & Consumers)

> **What this note is for** · the LabVIEW *module* — its scope, what we build, and the design decisions/open questions · **not** here: full field tables (canonical: [[StreamConfig]] / [[ConsumerConfig]] / [[Schema Catalog]]) · subjects & response envelope (see [[JetStream Wire API]]) · operation→schema-file manifest (see [[JetStream JSON Schemas]])

New to NATS? Read [[NATS in 5 Minutes]] first; terms are defined in the [[Glossary]].

## Scope
- CRUD over `$JS.API.STREAM.*` and `$JS.API.CONSUMER.*` subjects: create, info, update, delete, list, purge.
- All JSON in/out; responses include a `type` field identifying the response schema.
- Establish a **shared JetStream API error/response convention** here — every later module (Publish, Consume, KV, Object Store) reuses it. Getting this right early saves rework.

## Depends on
- [[01 Request-Reply Helper]]

## Used by
- [[04 JetStream Publishing]], [[05 JetStream Consuming]], [[06 Key-Value Store]], [[07 Object Store]]

## Docs
- [[JetStream Wire API]] — subjects, response envelope, one-line purpose per op
- [[JetStream JSON Schemas]] — operation→schema-file manifest (what to codegen/validate against)
- [[Schema Catalog]] · [[StreamConfig]] · [[ConsumerConfig]] — canonical field-level reference
- `using-nats/developer/develop_jetstream/streams`
- `using-nats/developer/develop_jetstream/consumers`

## Wire / API reference

Full subject/schema detail lives in [[JetStream Wire API]]. This module implements the CRUD subset below (all Core NATS request/reply; see [[01 Request-Reply Helper]]). Sources: [ADR-1](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-1.md) (JSON API + envelope), [ADR-9](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-9.md) (consumer config), stream config schema (`jsm.go/schemas`, cf. ADR-15/17), [ADR-6](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-6.md) (naming), and the [Wire API reference](https://docs.nats.io/reference/reference-protocols/nats_api_reference).

Operations implemented here (subjects are `$JS.API.` / `$JS.{domain}.API.` prefixed):

| Operation | Subject | Request body | Response `type` (`io.nats.jetstream.api.v1.*`) |
|---|---|---|---|
| Create stream | `STREAM.CREATE.<name>` | `StreamConfig` | `stream_create_response` → [[StreamInfo]] |
| Update stream | `STREAM.UPDATE.<name>` | `StreamConfig` | `stream_update_response` → [[StreamInfo]] |
| Stream info | `STREAM.INFO.<name>` | none | `stream_info_response` → [[StreamInfo]] |
| Delete stream | `STREAM.DELETE.<name>` | none | `stream_delete_response` |
| List streams (full) | `STREAM.LIST` | `JSApiStreamListRequest` (paging) | `stream_list_response` |
| List stream names | `STREAM.NAMES` | `JSApiStreamNamesRequest` | `stream_names_response` |
| Purge stream | `STREAM.PURGE.<name>` | optional `JSApiStreamPurgeRequest` | `stream_purge_response` |
| Get message | `STREAM.MSG.GET.<name>` | `JSApiMsgGetRequest` | `stream_msg_get_response` |
| Delete message | `STREAM.MSG.DELETE.<name>` | `JSApiMsgDeleteRequest` | `stream_msg_delete_response` |
| Create consumer | `CONSUMER.CREATE.<stream>` | `{stream_name, config:ConsumerConfig}` | `consumer_create_response` → [[ConsumerInfo]] |
| Create durable (legacy) | `CONSUMER.DURABLE.CREATE.<stream>.<consumer>` | `{stream_name, config}` | `consumer_create_response` → [[ConsumerInfo]] |
| Consumer info | `CONSUMER.INFO.<stream>.<consumer>` | none | `consumer_info_response` → [[ConsumerInfo]] |
| Delete consumer | `CONSUMER.DELETE.<stream>.<consumer>` | none | `consumer_delete_response` |
| List consumers (full) | `CONSUMER.LIST.<stream>` | `JSApiConsumerListRequest` | `consumer_list_response` |
| List consumer names | `CONSUMER.NAMES.<stream>` | `JSApiConsumerNamesRequest` | `consumer_names_response` |
| Account info | `INFO` (fully qualified `$JS.API.INFO`) | none | `account_info_response` |

Config field tables are canonical on the type pages — **[[StreamConfig]]** and **[[ConsumerConfig]]** (see also [[Schema Catalog]]); the response envelope and error object shape are in [[JetStream Wire API]]. The CREATE/UPDATE/INFO response body **is** a [[StreamInfo]] (`config` + `state`); the consumer equivalent is a [[ConsumerInfo]]. Publish/consume runtime paths (`CONSUMER.MSG.NEXT`, push delivery) belong to [[04 JetStream Publishing]] / [[05 JetStream Consuming]]; [[06 Key-Value Store]] is a StreamConfig preset over the same CRUD.

**Confusable pairs** (one-liners; full descriptions in [[JetStream Wire API]]):
- **LIST vs NAMES** — `LIST` returns full config+state per stream/consumer (heavier); `NAMES` returns names only (lightweight, and for streams a `subject` filter answers "which stream captures this subject?"). Use `NAMES` to enumerate, `LIST` when you need the details.
- **PURGE vs DELETE** — `PURGE` deletes *messages* but keeps the stream (optionally narrowed by subject / up-to-seq / keep-N); `DELETE` removes the *stream itself* and all its messages, irreversibly.

## Design notes for the open questions

_Options and trade-offs to inform the decisions below — the DECISION stays with the user._

### Error/response convention (JetStream typed error vs Core `-ERR`)
Two distinct error surfaces must be unified into one toolkit error convention (per the Scope goal above):
- **Core NATS layer** (from `nats.lv`): protocol/transport `-ERR <reason>`, plus request-reply outcomes like no-responder / timeout. No structured code.
- **JetStream admin layer**: success and error share the JSON envelope; the `error` object `{code:int, err_code:int, description:string}` is present only on failure (see [[JetStream Wire API#Standardized response envelope]]). `err_code` is the stable identifier; `code` is an HTTP-style class.

Option A — single unified error cluster `{source (core|jetstream), code, err_code, description}`: every VI returns one type; callers branch on one field. Maps cleanly onto a LabVIEW error cluster if `err_code` goes into `code` and `description`/`source` into `source`, but LabVIEW error codes are I32 while some `err_code` values are large — needs an offset/namespacing scheme, and merging two numbering spaces risks collisions.
Option B — keep the native LabVIEW error cluster for transport/wiring errors and carry JetStream API errors in a separate typed cluster on the payload: no code-space collisions, honest about the two layers, but callers must check two places.
Option C — hybrid: native error cluster for transport failures, and translate a JetStream `error` object into a filled-in error cluster (custom code range + `description` in the source string) so a JetStream "stream not found" surfaces like any other LabVIEW error. Most idiomatic for LabVIEW consumers; cost is maintaining the `err_code`→LabVIEW-code mapping.
- #question Which error convention (A / B / C, or variant) becomes the shared standard reused by [[04 JetStream Publishing]], [[05 JetStream Consuming]], [[06 Key-Value Store]], [[07 Object Store]]? Decide before building CRUD VIs — every later module inherits it.

### Subject prefix / domain support
- The only difference is the admin prefix: `$JS.API` vs `$JS.{domain}.API` (see [[JetStream Wire API#Domain prefixing]]). Caveat: `$JS.FC.<stream>.>` flow-control subjects are not domain-prefixed.
- Option A — build a single "API prefix" helper VI now (config-driven, default `$JS.API`) that all subject-construction VIs consume: near-zero cost now, no rework later; the only ask is threading a prefix input/config through.
- Option B — hardcode `$JS.API` now, refactor when a domain deployment appears: less plumbing today, but touches every subject-construction VI in this module and above later.
- #question Domain support from the start (Option A) or bolt on later (Option B)? Recommendation leans A given the low cost, but the DECISION is the user's.

## Open questions
- #question Subject prefix / domain support (`$JS.{domain}.API` vs `$JS.API`) — build this in from the start or bolt on later? Affects every subject-construction VI in this module and above. (Options/trade-offs above.)
- #question Naming convention for interpolated subjects (e.g. `api.JSApiConsumerCreateT` needs stream name / consumer name substituted in) — establish a helper VI pattern once, reuse everywhere. Note the modern `CONSUMER.CREATE.<stream>` path largely supersedes the legacy `CONSUMER.DURABLE.CREATE.<stream>.<consumer>` template; the helper still needs to interpolate stream/consumer/filter tokens and enforce the [ADR-6](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-6.md) name rule (no `.` `*` `>` `/` `\`, ≤255 chars) before building subjects.
- #question Unified error/response convention (see "Design notes" above) — pick A/B/C before CRUD VIs are built, since Publish/Consume/KV/Object Store all reuse it.

## Notes / decisions log
-

## Sources
- [NATS JetStream API reference](https://docs.nats.io/reference/reference-protocols/nats_api_reference)
- [Develop JetStream — Streams](https://docs.nats.io/using-nats/developer/develop_jetstream/streams)
- [Develop JetStream — Consumers](https://docs.nats.io/using-nats/developer/develop_jetstream/consumers)
- [ADR-1 — JetStream JSON API Design](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-1.md)
- [ADR-6 — Stream/consumer naming rules](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-6.md)
- [ADR-9 — JetStream consumer configuration](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-9.md)
- [ADR-15 (NATS architecture & design)](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-15.md)
- [ADR-17 (NATS architecture & design)](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-17.md)
