---
type: architecture
---

# Library & Project Structure

How the LabVIEW libraries for the client API (JetStream, KV, Object Store, Auth) are organized. New here? Read [[NATS in 5 Minutes]] and [[Layering Overview]] first.

## Base: build on `NATS Core.lvlib` #decision
The Core NATS foundation is **`NATS Core.lvlib`** from the `nats_core` VIP package (see [[Foundation - nats.lv]]) — the raw wire client (CONNECT/PUB/HPUB/SUB/UNSUB/READ + message parsing, `nats connection.ctl`). It is an **external dependency: do not modify it** (edits are lost when the package updates) — depend on it and call its public VIs.

> The `NATS Client.lvlib` and `NATS Subscription.lvlib` folders inherited from the forked repo are **unrelated leftovers — ignore/remove them**. `NATS Infrastructure` is ours (server install/start/stop/health).

## Layered libraries #decision
A small set of layered libraries mirroring [[Layering Overview]], with dependencies pointing **downward only** (no cycles):

| Layer / Library | Contains | Depends on |
|---|---|---|
| `NATS Core.lvlib` *(external, `nats_core` VIP)* | raw wire client; `nats connection.ctl` | — *(do not modify)* |
| **`NATS Connection.lvlib`** *(toolkit foundation)* | wraps the Core connection; owns the **READ loop + sid/inbox demux router**; **request-reply helper** ([[01 Request-Reply Helper]]); **unified error/result cluster**; the **async-delivery primitive** | NATS Core |
| `NATS JetStream.lvlib` | shared JS helpers (JSON↔cluster, `$JS.API.*` subject builder, response-envelope + [[ApiError]] decode, [[StreamConfig]]/[[ConsumerConfig]] typedefs, ack helpers) + Management / Publish / Consume as virtual folders | NATS Connection |
| `NATS KV.lvlib` / `NATS Object Store.lvlib` | bucket/object classes, ops, watch | NATS JetStream |
| `NATS Auth.lvlib` | NKey/JWT/creds, nonce signing (Ed25519) | NATS Connection / NATS Core (CONNECT) |
| `NATS Services.lvlib` *(stretch)* | micro service framework | NATS Connection |

Name the foundation lib as you like (`NATS Connection`, `NATS`, …) — just **not** `NATS Client`, to avoid confusion with the fork leftover.

Keep **Management + Publish + Consume in one JetStream lib** (they share the configs, the envelope, and the `$JS.API` request pattern — splitting them would force LabVIEW "friend library" relationships for little gain). Split **KV, Object Store, and Auth** into their own libs — distinct features, one layer up, evolving independently; Auth also carries the Ed25519 external-dependency risk, so isolating it helps.

## Why a "Connection" foundation library exists
It is **not just a helpers bucket** — it is the toolkit's concurrency engine, required by the way [[Foundation - nats.lv]] works.

### The READ loop + sid/inbox demux router
`NATS Core.lvlib` exposes a single `READ` that pulls **one frame at a time off the one TCP socket** — and NATS multiplexes *every* subscription, every request reply, and control frames (`+OK`/`-ERR`/`PING`) over that same socket. There is **no per-subscription delivery and no demultiplexer**. So if two parts of the app both called `READ`, they would steal each other's frames.

The fix: exactly **one background loop owns `READ`** per connection (the *router* / dispatcher). It:
- reads every frame in a tight loop;
- keeps a routing table **`sid` → destination** (a queue/notifier/user-event). Each `SUB` registers `(sid, subject, destination)`; each incoming `MSG`/`HMSG` carries its `sid` (the id the client chose on `SUB`), so the router looks it up and delivers the parsed message there;
- handles control frames itself: reply `PONG` to `PING`, surface `-ERR`, update state from `INFO` (nonce, `max_payload`).

Callers never touch `READ`; they register a route and consume from their destination. This is what makes concurrent subscriptions + request-reply possible on one connection.

### Request-reply is the simplest case
The [[01 Request-Reply Helper]] mints an inbox subject + a unique `sid`, registers a **single-shot** destination (a notifier / 1-element queue), `SUB`s the inbox, `PUB`s the request with reply-to = inbox, then waits on that destination with a timeout. The router delivers the reply; the helper then `UNSUB`s and unregisters. The wait is on the router's handoff, not on `READ`.

### Async delivery model — a pluggable `IDelivery` strategy #decision
"Async delivery" is **how the router hands a message to the consuming code** — the destination in the routing table. Rather than hard-pick one, expose a **pluggable strategy**: an `IDelivery` interface (LV 2020+) with a `Deliver(message)` dynamic method, chosen per subscription. Ship these implementations (full trade-offs in [[05 JetStream Consuming]]):
- **Queue** — default, RT-safe (preallocated/bounded, no per-message heap allocation). General consuming; backpressure maps to `max_ack_pending`.
- **Notifier** — latest-value only, lossy; for "current value" reads (e.g. KV latest).
- **User Event** — UI / event-loop integration; unbounded-queue memory risk, weaker backpressure.
- **Actor message** — wrap + send an AF message ([[10 Object Messaging]]); heaviest (allocation + actor dispatch).

The strategy's dynamic-dispatch cost is negligible (~1% of the per-message budget at 10 kHz) — per-message parse + the transport op dominate, not the vtable. Bound every Queue with an explicit overflow policy (slow-consumer protection). Request-reply's reply is the single-shot (N=1) case. The interface + implementations live in `NATS Connection.lvlib` alongside the router. **Remaining:** pin the concrete strategy set + default before building KV/Object watch.

## Connection model #decision
Follow the NATS idiom: **one long-lived connection per application**, shared across all publishers and subscribers and multiplexed by the router above. This is how every native client works — do **not** open a connection per subscription or per "process" by default.

- **Publishes** funnel through the one connection's write path (thread-safe; concurrent publishers append to a shared buffer). **Subscriptions** are doled out by the router (`sid` → delivery). One connection carries many subjects comfortably.
- **Parallelism is fan-out *after* the read, not more sockets.** For CPU-bound processing, keep the read loop lean (read → route → enqueue) and run **N worker loops** off the delivery Queue — that parallelizes work without paying for N connections/auths/keepalives. High-rate data also wants message **batching** (see [[04 JetStream Publishing]]).
- **Open multiple connections only when justified**, not for raw speed: different **credentials/accounts**, **isolation** (one subsystem's reconnect storm shouldn't disturb another; a high-rate firehose vs. a control plane), or — LabVIEW-specific — when a *measured* single read+parse loop is the throughput wall. Each connection is a full CONNECT + auth + its own router/read loop, so they are not free (and LabVIEW read loops compete for the thread pool). Server default cap is 65,536 connections; the practical LabVIEW limit is far lower.
- Model the connection as a **by-ref class** (DVR) so N instances are naturally supported, each owning its own router.

## Where shared helpers live
Rule: **a helper lives in the lowest library that all its callers can depend on.**
- Used by everything (request-reply, error/result cluster, the router, async delivery) → `NATS Connection.lvlib`.
- JetStream-and-above (JSON, subjects, envelope decode, config typedefs) → `NATS JetStream.lvlib`; KV/Object inherit them via dependency.
- No standalone "utils" library — it becomes a dumping ground and invites cycles. Since you cannot add code to the external `NATS Core.lvlib`, `NATS Connection.lvlib` is the toolkit's true bottom layer.

## Encapsulation mechanics
- **Access scope is the encapsulation tool, not library count**: mark user-facing VIs **public** (they form the palette) and helpers **private**. A well-scoped single lib beats a sprawl of tiny ones.
- **Virtual folders** organize within a lib (`Management/`, `Publish/`, `Consume/`, `_internal/`).
- **Model stateful things as by-ref classes** (DVR), consistent with `nats connection.ctl`: the connection/router, JetStream context, Stream/Consumer handles, KV bucket, Object store.
- **Friend libraries** only if a separate lib must reach another's private members — treat needing them as a sign the layering is off.

## Anti-patterns
Circular dependencies; a god "utils" lib; exposing internal helpers on the public palette; duplicating the request-reply / JSON / envelope logic instead of calling down into the shared layer.

#architecture #decision
