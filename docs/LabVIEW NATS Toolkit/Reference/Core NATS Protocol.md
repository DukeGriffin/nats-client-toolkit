---
type: reference
source: https://docs.nats.io/reference/reference-protocols/nats-protocol
---

# Core NATS Protocol (already implemented by nats.lv)

**New to NATS? Read [[NATS in 5 Minutes]] first, then come back here for the wire-level detail.**

NATS is a publish/subscribe message broker. Clients open a TCP connection to a `nats-server`; a publisher sends a message addressed by a **subject** (a dot-delimited topic string like `time.us.east`, *not* a destination address), and the server delivers a copy of that message to every client currently subscribed to a matching subject. Publishers and subscribers never know about each other — they only agree on subject names. **"Core NATS"** is this base layer: fire-and-forget pub/sub plus request-reply, with **at-most-once** delivery (if no one is subscribed when you publish, the message is simply gone). JetStream (persistence, replay, at-least-once) is a separate layer built on top — see [[JetStream Wire API]].

> **subject** — the topic string a message is addressed by. One or more tokens separated by `.` (e.g. `orders.us.new`). Publishers use a fully-specified subject; subscribers may use wildcards (see [[#Subject rules (token structure)]] and [[#Wildcards]] below). See also [[Glossary]].

The wire grammar, `CONNECT`/`INFO`, header, and subject rules below are distilled from the NATS **protocol spec** and **subjects** docs — the primary references for what [[Foundation - nats.lv|nats.lv]] already handles at the wire level. (The limits / ordering / queue-group section near the end is sourced from the FAQ.)

---

## Wire protocol (on-the-wire grammar)

Source: [NATS client/server protocol](https://docs.nats.io/reference/reference-protocols/nats-protocol).

The protocol is a **plain-text, line-oriented** protocol over TCP. Two rules matter for the LabVIEW implementation:

- **Every protocol message is terminated by CRLF** (`\r\n`, `0x0D 0x0A`). This includes control lines *and* the payload trailer.
- **Fields on a control line are whitespace-delimited** (space or tab); runs of whitespace collapse to one separator. Operation names (`PUB`, `SUB`, `INFO`, …) are case-insensitive per spec but conventionally uppercase.

`nats.lv` already handles CONNECT/PUB/HPUB/SUB/UNSUB/PING/PONG; the tables below are the reference for what those lines look like and for parsing the server → client side (INFO/MSG/HMSG/+OK/-ERR) that the toolkit sits on top of.

### Message summary

| Op | Direction | Grammar (CRLF shown as `\r\n`) |
|----|-----------|--------------------------------|
| `INFO` | server → client | `INFO {json}\r\n` |
| `CONNECT` | client → server | `CONNECT {json}\r\n` |
| `PUB` | client → server | `PUB <subject> [reply-to] <#bytes>\r\n<payload>\r\n` |
| `HPUB` | client → server | `HPUB <subject> [reply-to] <#hdr bytes> <#total bytes>\r\n<headers>\r\n\r\n<payload>\r\n` |
| `SUB` | client → server | `SUB <subject> [queue group] <sid>\r\n` |
| `UNSUB` | client → server | `UNSUB <sid> [max_msgs]\r\n` |
| `MSG` | server → client | `MSG <subject> <sid> [reply-to] <#bytes>\r\n<payload>\r\n` |
| `HMSG` | server → client | `HMSG <subject> <sid> [reply-to] <#hdr bytes> <#total bytes>\r\n<headers>\r\n\r\n<payload>\r\n` |
| `PING` | both | `PING\r\n` |
| `PONG` | both | `PONG\r\n` |
| `+OK` | server → client | `+OK\r\n` (only when `verbose:true`) |
| `-ERR` | server → client | `-ERR '<message>'\r\n` |

**`sid`** (subscription id): a client-assigned token supplied on every `SUB` — any unique string works (reference clients just use `1`, `2`, `3`, …). The server stamps that same `sid` onto every matching `MSG`/`HMSG` it delivers, so the client can tell *which* subscription a given frame belongs to (demultiplex) when many subscriptions share one socket. This is the linchpin of the delivery model: because the toolkit has one read loop and no built-in demux, matching frames back to a request/subscription by `sid` (and/or reply subject) is the caller's job — see [[Foundation - nats.lv]] and [[01 Request-Reply Helper]]. See also [[Glossary]].

Note the byte-count field: for `PUB`/`MSG` it is the payload length; for `HPUB`/`HMSG` there are **two** counts — the header-block byte count (including the `NATS/1.0\r\n` line and the terminating `\r\n\r\n`) and the *total* byte count (header bytes + payload bytes). The payload length is therefore `total − header`. All counts are byte counts, not character counts — matters for UTF-8 payloads.

### CONNECT options (client → server JSON)

Sent once, immediately after receiving `INFO`. Source: [protocol spec — CONNECT](https://docs.nats.io/reference/reference-protocols/nats-protocol).

| Field | Type | Meaning |
|-------|------|---------|
| `verbose` | bool | If true, server replies `+OK` / `-ERR` to every message. Clients normally set **false** to avoid the round-trip chatter. |
| `pedantic` | bool | Strict protocol/subject validation on the server side. |
| `tls_required` | bool | Client requires TLS. |
| `auth_token` | string | Bearer/token auth (sent only if `auth_required`). |
| `user` | string | Username (user/pass auth). |
| `pass` | string | Password (user/pass auth). |
| `name` | string | Optional client connection name (shows up in monitoring). |
| `lang` | string | Client language, e.g. `"labview"`. |
| `version` | string | Client library version string. |
| `protocol` | int | `0`/absent = original; `1` = supports async `INFO` (dynamic cluster topology via `connect_urls`). |
| `echo` | bool | If false, server won't echo a client's own publishes back to its own matching subscriptions. |
| `sig` | string | Base64 signature of the server `nonce` (NKey/JWT auth). |
| `jwt` | string | User JWT (account-scoped permissions). |
| `no_responders` | bool | Opt in to the **no-responders 503** fast-fail (requires `headers:true`). Directly relevant to [[01 Request-Reply Helper]]. |
| `headers` | bool | Client supports `HPUB`/`HMSG` headers. Must be true to use headers or `no_responders`. |
| `nkey` | string | Public NKey used to authenticate the client. |

### INFO fields (server → client JSON)

Sent by the server on connect, and again asynchronously if topology changes (when `protocol >= 1`). Source: [protocol spec — INFO](https://docs.nats.io/reference/reference-protocols/nats-protocol).

| Field | Type | Meaning |
|-------|------|---------|
| `server_id` | string | Unique server id. |
| `server_name` | string | Server name. |
| `version` | string | Server version. |
| `go` | string | Go runtime version of the server build. |
| `host` / `port` | string / int | Advertised listen address. |
| `max_payload` | int | **Max message payload the server will accept, in bytes.** The client must reject/split larger messages — see [[07 Object Store]] chunking. |
| `proto` | int | Server protocol version (`1+` = dynamic topology). |
| `headers` | bool | Server supports headers (`HPUB`/`HMSG`). Gate `no_responders` on this. |
| `nonce` | string | Random challenge to be signed into CONNECT `sig` for NKey/JWT auth. |
| `connect_urls` | [string] | Advertised peer server URLs for client-side reconnect/load-balancing. |
| `auth_required` | bool | Auth needed before any other operation. |
| `tls_required` / `tls_verify` / `tls_available` | bool | TLS negotiation requirements. |
| `client_id` / `client_ip` | uint64 / string | This connection's server-assigned id / observed IP. |
| `jetstream` | bool | JetStream enabled on this server — gates [[JetStream Wire API]] / [[03 JetStream Management API]]. |
| `ldm` | bool | Server is in Lame Duck Mode (draining; reconnect elsewhere). |
| `cluster` / `domain` | string | Cluster name / JetStream domain. |

### Connection handshake (ordered)

Every connection starts with a fixed exchange before any `SUB`/`PUB` is allowed. Source: [protocol spec](https://docs.nats.io/reference/reference-protocols/nats-protocol).

1. **Client opens the TCP connection** to `host:port`.
2. **Server sends `INFO {json}\r\n`** immediately — this is the *first* thing on the wire, before the client says anything. It advertises `max_payload`, `headers`, `auth_required`, `tls_required`, etc. (see table above).
3. **Client sends `CONNECT {json}\r\n`** with its chosen options (`verbose`, `headers`, auth credentials, `lang`/`version`, …).
4. **If the client set `verbose:true`**, the server replies `+OK\r\n` (or `-ERR '<msg>'\r\n`). Clients normally set `verbose:false`, so there is no acknowledgement and the connection is simply ready.
5. **Connection is ready** — the client may now `SUB`/`PUB`/`HPUB`/`UNSUB` freely.

Throughout the connection's life, **PING/PONG runs as keepalive** in both directions: either side may send `PING\r\n` and the other must answer `PONG\r\n` within the timeout, or the connection is dropped as a `Stale Connection`. `nats.lv` answers server `PING`s automatically (see [[Foundation - nats.lv]]).

`#question`: TLS ordering — when `INFO` advertises `tls_required`, the socket must be upgraded to TLS *after* receiving `INFO` but *before* sending `CONNECT`. `nats.lv` exposes the raw refnum and leaves this sequencing to the caller; see [[Foundation - nats.lv]] and [[02 Authentication]]. Still an open item.

### Header block encoding (HPUB / HMSG)

Source: [protocol spec — HPUB/HMSG](https://docs.nats.io/reference/reference-protocols/nats-protocol).

The header block is itself CRLF-framed text beginning with a version line:

```
NATS/1.0\r\n
Header-Name: value\r\n
Header-Name: value\r\n
\r\n
```

- First line is exactly `NATS/1.0` (optionally `NATS/1.0 <status> <description>` for status messages — see below).
- Each header is `Name: value` terminated by `\r\n`. A header may repeat for multi-value (`BREAKFAST: donut\r\n` then `BREAKFAST: eggs\r\n`).
- The block ends with a blank line — i.e. a trailing `\r\n\r\n` separates headers from payload.
- The `#hdr bytes` count on the `HPUB`/`HMSG` line covers everything from `N` of `NATS/1.0` through the terminating `\r\n\r\n` inclusive.

**Status headers** appear on the version line as `NATS/1.0 <code> <text>`, typically with no payload:

| Code | Meaning | Relevance |
|------|---------|-----------|
| `503` | **No responders** — request went to a subject with zero subscribers. Delivered as an empty `HMSG` to the reply inbox when `no_responders` + `headers` are negotiated. | Fast-fail for [[01 Request-Reply Helper]] instead of waiting out the timeout. |
| `100` | Idle heartbeat (and flow-control signals) on JetStream push consumers. | [[05 JetStream Consuming]] |
| `409` | Consumer/stream condition, e.g. "Consumer Deleted", "Exceeded MaxWaiting", max-bytes exceeded on pull requests. | JetStream — [[JetStream Wire API]] |

Status/description parsing on the version line is the toolkit's job even though `nats.lv` frames the bytes.

### -ERR messages

Source: [protocol spec — -ERR](https://docs.nats.io/reference/reference-protocols/nats-protocol). Some close the connection, some don't.

- **Connection-closing:** `Unknown Protocol Operation`, `Attempted To Connect To Route Port`, `Authorization Violation`, `Authorization Timeout`, `Invalid Client Protocol`, `Maximum Control Line Exceeded`, `Parser Error`, `Secure Connection - TLS Required`, `Stale Connection`, `Maximum Connections Exceeded`, `Slow Consumer`, `Maximum Payload Violation`.
- **Connection-preserving:** `Invalid Subject`, `Permissions Violation for Subscription to <subject>`, `Permissions Violation for Publish to <subject>`.

These arrive as `-ERR '<message>'\r\n` and should map into whatever error convention [[01 Request-Reply Helper]] settles on.

---

## Publish vs Request
- `Publish()` sends a message with a subject as address; server delivers to any interested subscriber. Optionally includes a reply subject.
  - On the wire this is `PUB <subject> [reply-to] <#bytes>\r\n<payload>\r\n` (or `HPUB …` when carrying headers).
- `Request()` is a convenience wrapper: creates a unique `INBOX` subject, subscribes to it, publishes with reply-to set to the inbox, waits for a response or timeout. This is exactly what [[01 Request-Reply Helper]] needs to implement.
  - Wire sequence: `SUB _INBOX.<uid> <sid>\r\n` → `PUB <subject> _INBOX.<uid> <#bytes>\r\n<payload>\r\n` → await one `MSG`/`HMSG` on that `sid` → `UNSUB <sid>\r\n`.

## INBOX subject convention
- Reply subjects use the reserved-ish prefix `_INBOX.` followed by a random, high-entropy token, e.g. `_INBOX.a1b2c3d4e5f6...`. Reference client libraries use a base32/hex-encoded random of ~12–22 chars (NUID). Any collision-resistant unique token works — `nats.lv`/the toolkit just has to generate it.
- Two token shapes are used in practice:
  - **Per-request inbox:** a fresh `_INBOX.<uid>` for each request (simplest; SUB then UNSUB per call).
  - **Shared inbox prefix + wildcard:** subscribe once to `_INBOX.<connUid>.*` and mint a new trailing token per request, correlating replies by the last token. Fewer SUB/UNSUB round-trips for high request rates. Source: [request-reply developer guide](https://docs.nats.io/using-nats/developer/sending/request_reply).
- `_INBOX` subjects are ordinary Core NATS subjects — they obey the same token/wildcard rules below.

## Queue groups
Source: [NATS FAQ](https://docs.nats.io/reference/faq).
- Non-persistent distributed queuing. Individual subscribers each get a copy of every message; queue-group subscribers get one randomly-chosen member per message. Real-time, not based on publisher logic — controlled by `nats-server` based on the interest graph.

## Wildcards
- `*` — single token wildcard (`foo.*` matches `foo.bar`, not `foo.bar.baz`)
- `>` — full wildcard (`foo.>` matches `foo.bar`, `foo.bar.baz`, etc.); must be the **last** token.
- Wildcards are **subscribe-side only** — a `PUB`/`HPUB` subject must be fully specified. Source: [subjects](https://docs.nats.io/nats-concepts/subjects).

## Subject rules (token structure)
Source: [subjects](https://docs.nats.io/nats-concepts/subjects).
- Tokens are separated by `.` (dot). A subject is one or more tokens, e.g. `time.us.east.atlanta`.
- Allowed in a token: any Unicode char **except** null, space, `.`, `*`, `>`. Recommended set: `a-z A-Z 0-9 - _`.
- `.`, `*`, `>` are reserved (separator / wildcards) and cannot appear inside a token.
- Practical guidance: keep to ≤16 tokens and <256 chars total; subjects are case-sensitive.
- Subjects beginning with `$` are reserved for system use (`$SYS`, `$JS`, `$KV`, …) — the JetStream/KV/OS modules build subjects under these prefixes.

## Message ordering
Source: [NATS FAQ](https://docs.nats.io/reference/faq).
- Source-ordered delivery per publisher only. No ordering guarantee across multiple publishers.

## Limits
Source: [NATS FAQ](https://docs.nats.io/reference/faq).
- Max payload: 1MB default, configurable up to 64MB (8MB recommended as a practical ceiling) — relevant to [[07 Object Store]] chunking decisions.
- No hard limit on number of subjects (as of nats-server v0.8.0+).
- Default max simultaneous connections per server: 65,536 (tunable).

## Delivery guarantees
Source: [NATS FAQ](https://docs.nats.io/reference/faq).
- Core NATS: at-most-once (TCP reliability only, no replay if a subscriber is offline).
- JetStream (2.2+): at-least-once and exactly-once (within a time window) — see [[JetStream Wire API]].

## Sources
Primary (wire grammar, CONNECT/INFO, handshake, headers, subjects):
- [NATS client/server protocol reference](https://docs.nats.io/reference/reference-protocols/nats-protocol)
- [Subjects (NATS concepts)](https://docs.nats.io/nats-concepts/subjects)
- [Request-Reply (NATS concepts)](https://docs.nats.io/nats-concepts/core-nats/reqreply)
- [Request-Reply developer guide](https://docs.nats.io/using-nats/developer/sending/request_reply)

Secondary (limits, message ordering, queue groups, delivery guarantees only):
- [NATS FAQ](https://docs.nats.io/reference/faq)

#reference
