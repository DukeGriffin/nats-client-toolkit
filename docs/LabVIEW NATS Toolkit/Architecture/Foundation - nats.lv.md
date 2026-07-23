---
type: architecture
source: https://github.com/drew-herron/nats.lv
---

# Foundation: nats.lv

[nats.lv](https://github.com/drew-herron/nats.lv) is the existing **Core NATS only** LabVIEW client this toolkit builds on. Native LabVIEW, no external dependencies, installable via VIPM.

- Package id: `nats_core`, version 1.0.0.1 (released 2022-08-09), BSD-3-Clause.
- Tested against `nats-server` v2.8.4 ([README](https://github.com/drew-herron/nats.lv)).

## What it provides
- Client commands: `CONNECT`, `PUB`, `HPUB`, `SUB`, `UNSUB`, `PING`, `PONG`
- Server message parsing: `INFO`, `MSG`, `HMSG`, `PING`, `PONG`, `+OK`, `-ERR`
- Queue group support
- TCP connection refnum exposed → usable with LabVIEW 2020+ native TLS
- Automatic `PONG` response to server `PING` (keep-alive)
- Server/client config checks for `HPUB` support
- Server `INFO` and client `CONNECT` kept in JSON format "to aid in futureproofing" ([README](https://github.com/drew-herron/nats.lv))

## Public VI API surface
Source: repo tree at [github.com/drew-herron/nats.lv](https://github.com/drew-herron/nats.lv) (`git/trees/main`). `.vi` files are binary and cannot be read as text, so inputs/outputs below are inferred from VI names + the [[Core NATS Protocol]] unless the README states otherwise — inferred IO is flagged `#question`.

> **Fastest way to resolve the `#question` IO: open the shipped examples.** After installing the package, open **NI » Help » Find Examples** (Example Finder) and load `Simple NATS Client Publisher.vi` and `Simple NATS Client Reader.vi`. Their connector panes and block diagrams show the *real* inputs/outputs for `CONNECT`/`PUB`/`SUB`/`READ`, and the Reader example is the canonical implementation of the poll-`NATS READ.vi` loop. Read these before trusting any inferred IO in the table below.

All VIs live under `VIs/` and are exposed via the library **`NATS Core.lvlib`** in the **Functions » Data Communication** palette.

| VI | Purpose | Notes |
|----|---------|-------|
| `NATS Open TCP.vi` | Open the raw TCP connection to host:port | Produces/wraps the connection refnum; this is the socket [[02 Authentication]] TLS wraps. |
| `NATS CONNECT.vi` | Send `CONNECT` protocol message | Payload built as JSON (see `Add Version and Language JSON Entries.vi`, `Validate CONNECT.vi`). Host/port/auth/verbose inputs `#question` — not enumerated in README. |
| `NATS PUB.vi` | Publish `PUB <subj> [reply] <#bytes>` | Reply-to input `#question`. |
| `NATS HPUB.vi` | Publish `HPUB` with `NATS/1.0` headers | Header + reply-to input encoding `#question`. |
| `NATS Publish (Polymorphic).vi` | Polymorphic wrapper over `PUB`/`HPUB` | Likely selects plain vs header publish by input type. `#question` on instances. |
| `NATS SUB.vi` | Send `SUB <subj> [queue] <sid>` | Registers subscription; does **not** itself deliver messages — see delivery model below. |
| `NATS UNSUB.vi` | Send `UNSUB <sid> [max_msgs]` | |
| `NATS READ.vi` | Read + parse the next server frame off the socket | **This is the message-delivery primitive** (INFO/MSG/HMSG/+OK/-ERR/PING/PONG). See below. |
| `NATS PING.vi` | Send `PING` | |
| `NATS CLOSE.vi` | Close the TCP connection | |

subVIs (`VIs/subVIs/`, internal — not palette API): `Add Version and Language JSON Entries.vi`, `Check for Authorization.vi`, `Determine Message Type.vi`, `PONG.vi` (auto keep-alive responder), `Package Version Constant.vi`, `Parse MSG.vi`, `Set Timeout.vi`, `Validate CONNECT.vi`.

Note: there is no top-level `NATS PONG.vi` — `PONG` is emitted automatically by the `PONG.vi` subVI inside the read path. There are no dedicated `+OK`/`-ERR`/`INFO` parse VIs; message discrimination happens in `Determine Message Type.vi` and payload parsing in `Parse MSG.vi`.

## Connection refnum / handle type
The library ships typedefs under `Controls/`:
- **`nats connection.ctl`** — the connection handle/cluster threaded through every VI. This is the refnum type [[01 Request-Reply Helper]] and [[02 Authentication]] (TLS) build on. It wraps the LabVIEW **TCP connection refnum** ("TCP connection refnum exposed to allow use of LabVIEW 2020 native TLS", [README](https://github.com/drew-herron/nats.lv)). Whether it also carries state like the last server `INFO` cluster or a subscription table is `#question` (binary VI).
- **`nats message.ctl`** — the parsed server-message cluster returned by `NATS READ.vi` (subject, sid, reply-to, headers, payload, type). Exact field names `#question`.
- **`msg type.ctl`** — enum discriminating the server message kind (INFO / MSG / HMSG / +OK / -ERR / PING / PONG), output of `Determine Message Type.vi`.

## Message delivery model (constrains async design)
There is a single reader VI, **`NATS READ.vi`**, and no queue/event/callback controls in the tree — so delivery is **poll-based**: the caller repeatedly calls `NATS READ.vi`, which reads one server frame, classifies it (`msg type.ctl`), and returns a parsed `nats message.ctl`. Subscriptions (`NATS SUB.vi`) only register interest server-side; matching `MSG`/`HMSG` frames arrive interleaved on the same socket and surface only when the caller polls `NATS READ.vi`. The `Set Timeout.vi` subVI implies `READ` takes a timeout (bounded/non-blocking read).

Implications for the toolkit:
- There is **no built-in demultiplexer**: a single read loop returns frames for *all* subscriptions plus protocol control frames (`+OK`, `-ERR`, `PING`). Any request-reply or multi-subscription layer must own the read loop and route by `sid`/subject itself.
> [!warning] `#question` — Must resolve before building the concurrency model
> The exact semantics of `NATS READ.vi` are undocumented and every concurrency decision hinges on them:
> - Does it **block** until a full frame arrives, or **return empty/time out** when the socket is idle?
> - Does auto-`PONG` fire *inside* `READ` — meaning keep-alive only works while something is actively polling, so a paused read loop would silently drop the connection?
>
> This is inherited by **every** layer that owns a read loop or correlates replies — [[01 Request-Reply Helper]] and all of [[03 JetStream Management API]], [[04 JetStream Publishing]], [[05 JetStream Consuming]], [[06 Key-Value Store]], [[07 Object Store]]. Confirm empirically (open the Reader example, above) **before** choosing the async delivery model in [[Layering Overview]].

## Reply-to and headers
- **Reply-to**: Core NATS `PUB`/`MSG` carry an optional reply subject (`PUB <subj> [reply-to] <#bytes>`, [docs.nats.io](https://docs.nats.io/reference/reference-protocols/nats-protocol)). `NATS PUB.vi` should expose a reply-to input and `Parse MSG.vi` should surface it in `nats message.ctl`, but the README does not confirm either — `#question`. This is the exact primitive [[01 Request-Reply Helper]] needs (publish with reply subject + `SUB` an inbox).
- **Headers**: `NATS HPUB.vi` implements `HPUB` (the `NATS/1.0` header block); `HMSG` is parsed on read. Header cluster encoding (map vs string) is `#question`. Headers are what JetStream acks and message metadata ride on.
- No inbox-generation helper exists; the request-reply layer must mint its own `_INBOX.<nuid>` subjects.

## TLS story
Confirmed: nats.lv **does not implement TLS itself** — it deliberately exposes the underlying LabVIEW TCP connection refnum so callers can hand it to LabVIEW 2020+'s **native TLS** VIs after the initial `INFO`/`CONNECT` handshake ([README](https://github.com/drew-herron/nats.lv)). [[02 Authentication]] / TLS work is therefore standard LabVIEW TLS on the exposed refnum, not new socket code. `#question`: the upgrade ordering (NATS `tls_required` from `INFO`, upgrade before `CONNECT`) is a protocol detail nats.lv leaves to the caller.

## Requirements
- LabVIEW 2013 or later.
- No package dependencies ("written entirely in LabVIEW with no additional package dependencies", [README](https://github.com/drew-herron/nats.lv)).
- A reachable `nats-server` (nats.io). Precompiled linux-386 server binary runs on a cRIO 904x with no extra dependencies.

## Install / packaging
- VIPM package **`nats_core`**, built from **`NATS.vipb`** (VIPM package spec at repo root). Pre-build step: `VIPM/Pre-Build Custom Action.vi`.
- After install, API appears under **Functions » Data Communication**.
- Two examples in NI Example Finder: `Examples/Simple NATS Client Publisher.vi` and `Examples/Simple NATS Client Reader.vi` — the Reader example is the canonical reference for the poll-`NATS READ.vi` loop.

## Gaps this toolkit must fill
Confirmed *not* provided by nats.lv (must be built on top):
- **Request-reply convenience API** — no inbox mint, no reply correlation, no read-loop router. Buildable from `PUB`(reply-to)+`SUB`+`NATS READ.vi`. → [[01 Request-Reply Helper]]
- **Async delivery / demux** — only a single poll VI; no per-subscription queue/event dispatch.
- **JetStream** — explicitly out ("This is not a JetStream enabled client"). Stream/consumer/ack, all JSON over Core NATS subjects.
- **Key/Value & Object Store** — none.
- **NKey / JWT / user-credentials auth** — only whatever `CONNECT` JSON + `Check for Authorization.vi` covers (likely user/pass/token). → [[02 Authentication]]
- **TLS orchestration** — refnum is exposed but upgrade sequencing is the caller's job.
- **QoS above at-most-once** — nats.lv is at-most-once by design.

## Why this matters for the toolkit
Everything in [[Layering Overview]] beyond Core NATS sits on top of this without needing to touch its TCP framing/protocol parser — see [[Core NATS Protocol]] for what's already handled at the wire level. The two hard constraints it hands upward: (1) the `nats connection.ctl` refnum is the single shared handle, and (2) message arrival is **poll-driven through `NATS READ.vi`**, so any concurrency/routing model is the toolkit's responsibility.

## Sources
- [nats.lv — LabVIEW Core NATS client (drew-herron/nats.lv)](https://github.com/drew-herron/nats.lv)
- [NATS client/server protocol reference](https://docs.nats.io/reference/reference-protocols/nats-protocol)

#reference
