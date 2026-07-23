---
type: reference
source: https://docs.nats.io
---

# NATS Docs Map

Official docs: https://docs.nats.io — full index at https://docs.nats.io/llms.txt. Any page is also available as Markdown by appending `.md` to its URL.

## By module

| Module | Primary docs |
|---|---|
| [[01 Request-Reply Helper]] | `using-nats/developer/sending/request_reply` |
| [[02 Authentication]] | `running-a-nats-service/configuration/securing_nats/auth_intro/*`, `using-nats/developer/connecting/{token,nkey,creds,tls}` |
| [[03 JetStream Management API]] | [[JetStream Wire API]], `using-nats/developer/develop_jetstream/{streams,consumers}` |
| [[04 JetStream Publishing]] | `using-nats/developer/develop_jetstream/publish`, `nats-concepts/jetstream/headers` |
| [[05 JetStream Consuming]] | `using-nats/developer/develop_jetstream/model_deep_dive` |
| [[06 Key-Value Store]] | `nats-concepts/jetstream/key-value-store`, `using-nats/developer/develop_jetstream/kv` |
| [[07 Object Store]] | `nats-concepts/jetstream/obj_store`, `using-nats/developer/develop_jetstream/object` |
| [[08 Services Framework]] | `using-nats/developer/services` |
| [[09 Monitoring and Admin]] | `running-a-nats-service/nats_admin/monitoring*` |

## Site structure (top level)
- Release notes (2.0 → 2.14)
- NATS Concepts — overview, subjects, Core NATS, JetStream, security, connectivity
- Using NATS — CLI tools (`nats`, `nk`, `nsc`, `nats-top`), Developing With NATS
- Running a NATS Service — install/deploy, config, clustering, gateways, leaf nodes, securing NATS, admin/monitoring
- Reference — FAQ, protocol specs, roadmap, contributing

## Architecture Decision Records (ADRs) — the canonical spec

The prose docs at docs.nats.io are often incomplete on exact JSON schemas and subject grammar. The **canonical source** is the ADR repo and the JSON schemas in `jsm.go`. Used heavily when building out the reference notes.

- ADR index: https://github.com/nats-io/nats-architecture-and-design/tree/main/adr — fetch any as raw markdown: `https://raw.githubusercontent.com/nats-io/nats-architecture-and-design/main/adr/ADR-<n>-<slug>.md`
- JSON schemas (authoritative field lists): `nats-io/jsm.go` → `schemas/jetstream/api/v1/*.json` (e.g. `stream_configuration.json`, `consumer_configuration.json`, `pub_ack_response.json`)

| ADR | Topic | Feeds |
|---|---|---|
| ADR-1 | JetStream JSON API design (subjects, response envelope, `type` values, error object) | [[JetStream Wire API]], [[03 JetStream Management API]] |
| ADR-4 | NATS message headers / HPUB framing (case-preserving) | [[Core NATS Protocol]], [[04 JetStream Publishing]] |
| ADR-6 | JetStream naming rules (no `. * > / \`, ≤255 chars) | [[03 JetStream Management API]] |
| ADR-7 | JetStream error codes | [[03 JetStream Management API]] |
| ADR-8 | Key-Value Store API & design | [[06 Key-Value Store]] |
| ADR-9 | Consumer idle heartbeats | [[05 JetStream Consuming]] |
| ADR-13 | Pull subscribe internals (NEXT request, status msgs) | [[05 JetStream Consuming]] |
| ADR-15/17 | Stream / storage config | [[JetStream Wire API]] |
| ADR-20 | Object Store | [[07 Object Store]] |
| ADR-22 | Publish retries on no-responders (503) | [[04 JetStream Publishing]] |
| ADR-32 | NATS Service (micro) API | [[08 Services Framework]] |

For NKey/JWT crypto the canonical sources are the client libraries, not the docs: `nats-io/nkeys` (`strkey.go`, `crc16.go`) and `nats.go` (`connectProto`, `SignatureCB`) — see [[02 Authentication]].

See also: [[Core NATS Protocol]], [[JetStream Wire API]], [[JetStream JSON Schemas]], [[Schema Catalog]]

#reference
