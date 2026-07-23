---
type: primer
---

# NATS in 5 Minutes

A plain-language orientation for someone who has never used NATS. Read this before the module/reference notes. Terms in **bold** are collected in the [[Glossary]].

## What NATS is
**NATS** is a lightweight messaging system. Programs (clients) open a TCP connection to a central **`nats-server`** and exchange small messages through it, instead of talking to each other directly. It's used for command/telemetry buses, request/reply APIs, and event streaming — the kind of thing a LabVIEW system might otherwise do with raw TCP, but with addressing, fan-out, and (optionally) persistence handled for you.

This toolkit is a **LabVIEW client** for NATS: it speaks the NATS protocol over a TCP socket so LabVIEW code can publish, subscribe, and use the higher-level features below.

## The core idea: subjects and pub/sub
Every message is published to a **subject** — a dotted string that acts as its address, e.g. `sensors.temp.tank1`. Clients **subscribe** to subjects they care about, and the server delivers each published message to every matching subscriber. Publishers and subscribers never know about each other; they only share the subject name.

- **Subject** — the topic/address a message is sent to (`orders.new`, `sensors.temp.tank1`).
- **Wildcards** (subscribe side): `*` matches one token (`sensors.temp.*`), `>` matches the rest (`sensors.>`).
- **Publish** — send one message to a subject (fire-and-forget; nobody may be listening).
- **Subscribe** — register interest in a subject and receive matching messages.
- **Queue group** — several subscribers on the same subject where the server delivers each message to exactly *one* of them (load balancing).

### Request/reply
NATS also supports asking a question and getting one answer. The requester creates a temporary private subject called an **inbox** (`_INBOX.<random>`), subscribes to it, and publishes the request with that inbox set as the **reply-to** subject. Whoever handles the request publishes its answer to that inbox. This request/reply pattern is the foundation for everything above Core NATS — see [[01 Request-Reply Helper]].

### "Core NATS"
The features so far — publish, subscribe, request/reply, queue groups — are **Core NATS**. Delivery is **at-most-once**: if no one is subscribed when a message is published, it's simply gone. The existing [[Foundation - nats.lv|nats.lv]] library already implements all of Core NATS.

## JetStream: persistence on top of Core NATS
**JetStream** is a layer built into `nats-server` that adds durability. Crucially, it is **not a new network protocol** — you use it by sending ordinary JSON request/reply messages to special subjects (`$JS.API.*`). That's why most of this toolkit is JSON encoding/decoding, not networking.

JetStream introduces two concepts:

- **Stream** — a durable, append-only log that captures and stores every message published to a set of subjects. Unlike Core NATS, the messages persist (on disk or in memory) whether or not anyone is listening. You create/configure streams with a [[StreamConfig]].
- **Consumer** — a named "read cursor" over a stream that tracks how far a client has read. Two axes:
  - **pull** (client asks for the next batch when ready — good for LabVIEW loops that pace themselves) vs **push** (server delivers to a subject you subscribe to).
  - **durable** (survives disconnects, remembers its position) vs **ephemeral** (disappears when you stop).
  - You configure consumers with a [[ConsumerConfig]].
- **Ack** — with JetStream, a client tells the server "I've processed this message" by publishing an acknowledgement; unacked messages get redelivered. This gives **at-least-once** delivery.

See [[03 JetStream Management API]] (create/inspect streams & consumers), [[04 JetStream Publishing]] (store messages, get a confirmation), and [[05 JetStream Consuming]] (read them back).

## KV, Object Store, Services — conveniences over JetStream
These are higher-level patterns. **None are new protocols** — each is a convention layered on JetStream streams (or plain Core NATS):

- **Key/Value Store** ([[06 Key-Value Store]]) — a bucket of keys and values, like a shared dictionary, backed by a stream. Put/get/delete keys, and *watch* for changes.
- **Object Store** ([[07 Object Store]]) — store large blobs (files) by splitting them into message-sized chunks across a stream. [[07 Object Store]].
- **Services (micro)** ([[08 Services Framework]]) — a thin convention for building request/reply RPC services with built-in discovery and stats over `$SRV.*` subjects.

## How this toolkit is built
It sits on [[Foundation - nats.lv|nats.lv]], which already does Core NATS (CONNECT/PUB/SUB/etc.). Everything this toolkit adds — JetStream, KV, Object Store, auth — is composed from those same raw frames plus JSON payloads on specific subjects. We do **not** call any other language's NATS library; see the [[Layering Overview#Invariant raw wire protocol over TCP only|wire-level invariant]] for why that matters when reading the official docs (which show library convenience APIs we must reimplement).

## Where to go next
1. [[Layering Overview]] — how the modules stack.
2. [[Cookbook]] — worked, end-to-end examples of each operation (the fastest way to see how a call actually works).
3. [[Build Order]] — the recommended sequence to implement the modules.
4. [[Core NATS Protocol]] — the exact wire grammar, once you want to build.
5. [[Glossary]] — any unfamiliar term.

## Sources
- [NATS concepts (docs.nats.io)](https://docs.nats.io/nats-concepts/overview) — the official conceptual overview this primer distills
- [[NATS Docs Map]] — where to read more, mapped to modules

#reference
