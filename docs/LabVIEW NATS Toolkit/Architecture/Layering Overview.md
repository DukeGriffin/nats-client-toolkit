---
type: architecture
---

# Layering Overview

> New to NATS? Read [[NATS in 5 Minutes]] first — this note assumes you know what streams, consumers, KV, and Object Store are. Terms are in the [[Glossary]].

## Key insight
JetStream, KV, and Object Store are **not new wire protocols**. They're JSON request/reply services running over ordinary Core NATS subjects (`$JS.API.*`, `$KV.*`, `$OBJ.*`), using the same `PUB`/`SUB`/inbox mechanism [[Foundation - nats.lv|nats.lv]] already implements.

Consequence: the work is almost entirely **JSON schema (de)serialization + LabVIEW-idiomatic clusters/VIs**, not networking. The one genuine wire-protocol-level gap is NKey/JWT auth (Ed25519 signing) — see [[02 Authentication]] and [[Risks and Open Questions]].

## Invariant: raw wire protocol over TCP only
This toolkit talks to `nats-server` **only** through the raw NATS text protocol over a TCP socket, via [[Foundation - nats.lv|nats.lv]]. The complete interface is:

- **Client → server frames:** `CONNECT`, `PUB`, `HPUB`, `SUB`, `UNSUB`, `PING`, `PONG`
- **Server → client frames:** `INFO`, `MSG`, `HMSG`, `+OK`, `-ERR`, `PING`, `PONG`

There is nothing else. Every feature — request/reply, JetStream publish/consume, KV, Object Store, Services — **decomposes into those frames** plus JSON/byte payloads on specific subjects.

**Why this matters for the docs:** the official NATS docs and almost every example online are written against a *client library's convenience API* — `nc.Request()`, `js.Subscribe()`, `kv.Get()/Put()`, `OrderedConsumer`, `ObjectWatcher`, auto-ack, fetch iterators, callbacks. **None of those exist for us.** They are patterns we must *reimplement* from the frames above, not APIs we call. Throughout these notes, any such name is **shorthand for a wire recipe** — a sequence of `PUB`/`SUB`/`HPUB` + JSON that we build ourselves. Where a note names one, it should either spell out the recipe or link to where it's spelled out (e.g. "ordered consumer" → [[05 JetStream Consuming]]).

Corollary: the language-specific reference implementations we cite (`nats.go`, `nats-io/nkeys`) are consulted **only to pin down the exact bytes/JSON that cross the wire** (ack tokens, `sig` encoding, subject grammar), never as an API surface to mimic. If a fact can't be reduced to "these bytes go out / these bytes come back," it doesn't belong in the wire recipe.

## Stack diagram (conceptual)

```
┌─────────────────────────────────────────────┐
│  08 Services Framework   09 Monitoring/Admin │  (stretch)
├─────────────────────────────────────────────┤
│      06 KV Store        07 Object Store      │
├─────────────────────────────────────────────┤
│  03 JetStream Mgmt │ 04 Publish │ 05 Consume  │
├─────────────────────────────────────────────┤
│         01 Request-Reply Helper              │
├─────────────────────────────────────────────┤
│   nats.lv — Core NATS (PUB/SUB/CONNECT/TLS)  │
├─────────────────────────────────────────────┤
│              02 Authentication                │  (cross-cutting;
│        (extends CONNECT, decoupled from       │   not layered — can be
│         the messaging stack above)            │   built independently)
└─────────────────────────────────────────────┘
```

> **Reading the diagram:** boxes above nats.lv stack in dependency order (each needs the ones below it). [[02 Authentication]] is drawn at the bottom only for space — it is **cross-cutting, not a foundation layer**. It extends the `CONNECT` handshake every layer already uses, so picture it *beside* the stack, buildable at any time, not beneath it.

## Notes
- Modules 3–7 all depend on [[01 Request-Reply Helper]] existing first.
- [[06 Key-Value Store]] and [[07 Object Store]] both depend on [[03 JetStream Management API]], [[04 JetStream Publishing]], and [[05 JetStream Consuming]] being solid, since they're materialized views over JetStream streams.
- [[02 Authentication]] is decoupled from the rest — it extends the `CONNECT` message nats.lv already sends, so it can be built in parallel or deferred without blocking the messaging stack.

## Sources
This note is an internal architecture synthesis; the links below are the background NATS concepts and reference-client sources it rests on.
- [JetStream (NATS concepts)](https://docs.nats.io/nats-concepts/jetstream)
- [nats.go reference client](https://github.com/nats-io/nats.go)
- [nats-io/nkeys](https://github.com/nats-io/nkeys)

#architecture
