---
type: reference
---

# Glossary

One-line definitions of the NATS terms used across this vault. New to NATS? Read [[NATS in 5 Minutes]] first. Each term links to where it's used in depth.

## Core NATS
- **`nats-server`** — the central broker all clients connect to over TCP.
- **Subject** — the dotted-string address a message is published to (e.g. `sensors.temp.tank1`). See [[Core NATS Protocol]].
- **Publish (PUB)** — send one message to a subject; fire-and-forget. See [[Core NATS Protocol]].
- **Subscribe (SUB)** — register interest in a subject (with a `sid`) to receive matching messages.
- **`sid`** — subscription id: a client-chosen token put on `SUB`; the server stamps it on every matching `MSG` so the client knows which subscription a frame belongs to (how you demultiplex one socket). See [[Foundation - nats.lv]].
- **Wildcard** — `*` matches one subject token, `>` matches all remaining tokens (subscribe side only).
- **Queue group** — multiple subscribers on one subject; the server delivers each message to exactly one of them (load balancing).
- **Inbox** — a temporary private subject (`_INBOX.<random>`) a client subscribes to in order to receive a reply. See [[01 Request-Reply Helper]].
- **Reply-to** — a subject carried on a message telling the receiver where to publish its answer; the mechanism behind request/reply.
- **Request/reply** — publish a request with a reply-to inbox and wait for one answer. See [[01 Request-Reply Helper]].
- **At-most-once** — Core NATS delivery guarantee: no persistence, no replay; if nobody is subscribed, the message is lost.
- **Header (HPUB/HMSG)** — optional `NATS/1.0` key/value block on a message; how JetStream metadata (msg-id, expected sequences, KV/rollup markers) rides along. See [[Core NATS Protocol]].
- **Nonce** — a one-time random challenge the server sends in `INFO`; signed during NKey/JWT auth. See [[02 Authentication]].

## JetStream
- **JetStream** — the persistence layer in `nats-server`, used via JSON request/reply on `$JS.API.*` subjects (not a new protocol). See [[JetStream Wire API]].
- **Stream** — a durable, append-only log storing messages captured from matching subjects. Configured by [[StreamConfig]]. See [[03 JetStream Management API]].
- **Consumer** — a named server-side read cursor over a stream. Configured by [[ConsumerConfig]]. See [[05 JetStream Consuming]].
- **Durable vs ephemeral** — a durable consumer persists its read position across disconnects; an ephemeral one is discarded when its subscription ends.
- **Pull vs push** — pull: the client requests batches when ready; push: the server delivers to a subject the client subscribes to.
- **Ack / nak / term** — a consumer publishes `+ACK` (processed), `-NAK` (redeliver), `+TERM` (stop trying) to a message's reply subject; unacked messages are redelivered. See [[05 JetStream Consuming]].
- **`ack_wait`** — how long the server waits for an ack before redelivering.
- **`max_ack_pending`** — cap on unacknowledged in-flight messages; the primary backpressure lever.
- **At-least-once** — JetStream delivery guarantee: messages are redelivered until acked (so handlers must tolerate duplicates).
- **PubAck** — the JSON confirmation returned when a message is stored in a stream (`stream`, `seq`, `duplicate`). See [[04 JetStream Publishing]] / [[PubAck]].
- **Dedup window** — a time window in which the server rejects duplicate publishes carrying the same `Nats-Msg-Id`.
- **`$JS.ACK` subject** — the structured reply subject on each delivered JetStream message, encoding its stream/consumer sequence and redelivery count.
- **Ordered consumer** — a client-side pattern (ephemeral push consumer, no acks, gap-detect + recreate) for single-reader in-order reads; underpins KV/Object watch. See [[05 JetStream Consuming]].
- **Domain** — an isolated JetStream instance (e.g. a leaf node); changes the subject prefix to `$JS.{domain}.API`.
- **Response envelope / `err_code`** — every `$JS.API.*` reply is JSON with an optional `error {code, err_code, description}`; `err_code` is the stable identifier to branch on. See [[ApiError]].

## KV / Object Store / Services
- **Bucket** — a named namespace of keys (KV) or objects (Object Store), each backed by one JetStream stream (`KV_<bucket>` / `OBJ_<bucket>`).
- **Revision** — a KV entry's version = its underlying stream sequence number. See [[KvEntry]].
- **CAS (compare-and-swap)** — a conditional write that only succeeds if the current revision matches what you expected (via `Nats-Expected-Last-Subject-Sequence`).
- **Rollup** — publishing with the `Nats-Rollup: sub` header tells the server to delete all prior messages on that subject, keeping only this one; how KV PURGE and Object "latest-wins" work.
- **Watch** — subscribe to future (and optionally current) changes of a key/object via an ordered consumer. See [[06 Key-Value Store]].
- **Chunk / digest** — Object Store splits a blob into message-sized chunks and records a `SHA-256=` **digest** (hash) to verify integrity on read. See [[07 Object Store]].
- **Service / endpoint** — a request/reply RPC handler (a queue-group subscription) plus discovery/stats responders on `$SRV.*`. See [[08 Services Framework]].

## Authentication
- **NKey** — a NATS-specific Ed25519 public-key identity, encoded in base32 (`U…` user, `A…` account, `O…` operator). See [[02 Authentication]].
- **Seed** — the secret from which an NKey keypair is derived (`S…`); the only part that must be kept private.
- **JWT** — JSON Web Token: a signed claims document; in NATS, users/accounts are described by JWTs in a trust chain (operator → account → user).
- **Ed25519** — the elliptic-curve digital-signature algorithm NATS uses to sign the connect-time nonce; LabVIEW has no native primitive for it (the one true wire-level gap).
- **`.creds` file** — a file bundling a user JWT and its NKey seed, used to authenticate.

## Sources
- [NATS glossary & concepts (docs.nats.io)](https://docs.nats.io/nats-concepts/overview) — authoritative definitions
- Definitions here are distilled from the module/reference notes each term links to; see [[NATS Docs Map]].

#reference
