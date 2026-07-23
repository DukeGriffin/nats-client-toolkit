---
type: reference
source: https://github.com/nats-io/jsm.go/tree/main/schemas
---

# Schema Catalog

One page per JSON type the toolkit (de)serializes, each with a full field table (**type · required · default · description**), enum values, validation rules, an example, and links back to the operations that use it. This is the type-level companion to the operation-level manifest in [[JetStream JSON Schemas]].

**Reading the Required column:** a field is **Required** only if it appears in the schema's `required` array (or, for KV/Object types, is mandated by the ADR). Everything else is **Optional** — many optional fields have a server-side default, noted per row. Requests generally send the whole object; responses may omit optional fields entirely, so decoders must treat every non-required field as possibly-absent.

See the governing [[Layering Overview#Invariant raw wire protocol over TCP only|wire-level invariant]]: these types are JSON payloads on `PUB`/`SUB` frames, not a client-library object model.

## Stream types
- [[StreamConfig]] — stream definition (create/update request body; embedded in info responses)
  - [[SubjectTransform]] · [[Placement]] · [[StreamSource]] (mirror & sources) · [[Republish]] · [[StreamConsumerLimits]]
- [[StreamInfo]] — stream info/create response payload
  - [[StreamState]] · [[ClusterInfo]] · [[PeerInfo]]
- [[StoredMsg]] — a raw stored message (`STREAM.MSG.GET` response)

## Consumer types
- [[ConsumerConfig]] — consumer definition (create request body; embedded in info responses)
- [[ConsumerInfo]] — consumer info/create response payload
  - [[SequenceInfo]] — delivered / ack_floor sequence pairs

## Publishing, errors, account
- [[PubAck]] — reply to a message published into a stream
- [[ApiError]] — the shared `error` object + standard response envelope (present on every `$JS.API.*` response)
- [[AccountInfo]] — `$JS.API.INFO` account/usage response

## Request bodies
- [[ConsumerGetnextRequest]] — pull-consumer NEXT request
- [[StreamMsgGetRequest]] — get a stored message by seq / last-by-subject
- [[StreamPurgeRequest]] — selective purge
- [[ListPaging]] — the shared offset/limit/total paging on LIST/NAMES

## Services (micro)
- [[ServiceInfo]] · [[ServicePing]] · [[ServiceStats]]

## Key-Value types (ADR-8; no jsm.go schema files)
- [[KvConfig]] — bucket config (maps to a [[StreamConfig]]) · [[KvEntry]] — a returned entry · [[KvStatus]] — bucket status

## Object Store types (ADR-20; no jsm.go schema files)
- [[ObjectInfo]] — object metadata (`ObjectMeta`/`ObjectInfo`) · [[ObjectMetaOptions]] (+ link) · [[ObjectStoreStatus]]

---
Back to: [[JetStream JSON Schemas]] · [[JetStream Wire API]] · [[NATS Docs Map]]

## Sources
- [jsm.go schemas (all JSON Schema files)](https://github.com/nats-io/jsm.go/tree/main/schemas)
- [JetStream `api/v1` schemas](https://github.com/nats-io/jsm.go/tree/main/schemas/jetstream/api/v1) · [micro `v1` schemas](https://github.com/nats-io/jsm.go/tree/main/schemas/micro/v1)
- [NATS Architecture & Design (ADRs)](https://github.com/nats-io/nats-architecture-and-design/tree/main/adr) — canonical for KV (ADR-8) and Object Store (ADR-20) types
- [NATS official docs](https://docs.nats.io)

#reference #schema
