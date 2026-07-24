---
type: moc
project: labview-nats-toolkit
---

# LabVIEW NATS Toolkit

**NATS** is a lightweight publish/subscribe messaging system: programs connect to a central `nats-server` and exchange messages addressed by *subject*. This project is a **LabVIEW client** for it — a toolkit implementing the NATS client API over the raw TCP protocol, built on [[Foundation - nats.lv|nats.lv]] (which already does *Core NATS* — basic pub/sub + request/reply) and adding the persistence-based features: *JetStream* (durable streams), *Key/Value*, *Object Store*, and *authentication*.

New to NATS? **Read [[NATS in 5 Minutes]] first**, then skim the [[Glossary]].

## Start here
- [[NATS in 5 Minutes]] — plain-language primer (what NATS/JetStream/KV/etc. are)
- [[Glossary]] — one-line definitions of every NATS term used here
- [[Foundation - nats.lv]] — what the base library already provides vs. what this toolkit must build
- [[Layering Overview]] — how the pieces stack on top of nats.lv
- [[Library and Project Structure]] — how the LabVIEW libraries are organized (structure decision)
- [[Cookbook]] — worked, end-to-end examples of each operation
- [[Build Order]] — suggested sequencing across modules
- [[Risks and Open Questions]] — decisions to make & spikes to run before/while building

## Modules

| # | Module | Status |
|---|---|---|
| 1 | [[01 Request-Reply Helper]] | planned |
| 2 | [[02 Authentication]] | planned |
| 3 | [[03 JetStream Management API]] | planned |
| 4 | [[04 JetStream Publishing]] | planned |
| 5 | [[05 JetStream Consuming]] | planned |
| 6 | [[06 Key-Value Store]] | planned |
| 7 | [[07 Object Store]] | planned |
| 8 | [[08 Services Framework]] | stretch |
| 9 | [[09 Monitoring and Admin]] | stretch |
| 10 | [[10 Object Messaging]] | idea |

## Reference
- [[NATS Docs Map]] — index of the official docs + ADRs, mapped to modules
- [[JetStream Wire API]] — subject/schema notes for `$JS.API.*`
- [[JetStream JSON Schemas]] — request/response schema manifest (operation → schema file)
- [[Schema Catalog]] — one page per JSON type (fields · required · default · enum) — the wrapper-building reference
- [[Core NATS Protocol]] — wire protocol nats.lv already implements

## Conventions used in this vault
- Each module note has: **Scope**, **Depends on**, **Docs**, **Open questions**, **Notes / decisions log**
- Use the `#decision` tag inline when a design decision is made, so it's searchable across the vault
- Use the `#question` tag for anything unresolved
