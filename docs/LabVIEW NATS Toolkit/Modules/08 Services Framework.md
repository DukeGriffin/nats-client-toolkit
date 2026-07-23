---
type: module
status: stretch
---

# 08 — Services Framework (optional/stretch)

## Scope
- NATS "micro"-style service definitions (`$SRV.*` discovery subjects) for building request/reply services with built-in stats and discovery.
- Nice-to-have for a polished toolkit; not required for core messaging use cases.

## Depends on
- [[01 Request-Reply Helper]]

## Docs
- `using-nats/developer/services`

## Notes / decisions log
-

---

## Reference — NATS Services (micro) protocol

Sources: `using-nats/developer/services` (docs.nats.io) and **ADR-32 "NATS Service API"**
(nats-io/nats-architecture-and-design). ADR-32 is canonical for the wire schemas.

### Key principle: no new wire protocol
The services framework **layers entirely on Core NATS** — "it doesn't require any special
functionality from the NATS server or JetStream." A service endpoint is just a **queue-group
subscription** answering request/reply (see [[01 Request-Reply Helper]] and [[Foundation - nats.lv]]).

> **Queue group** · multiple subscribers share one subject and the server delivers each message to exactly ONE of them — load balancing. (Contrast a plain subscription, where every subscriber gets every message.) Running several service instances in the same queue group spreads requests across them; see [[Glossary]].
The only addition is a set of **control-plane responders** on the `$SRV.*` subjects. The NATS
*client library* is responsible for auto-answering PING/INFO/STATS; the developer only writes the
actual endpoint handlers. Since `nats.lv` gives us PUB/SUB + queue groups, this whole module can be
built in LabVIEW with no protocol extensions.

### Concepts
- **Service** — top-level grouping of related functionality. Requires a `name` and a `version`
  that conforms to **semver**.
- **Endpoint** — one operation the client interacts with; implemented as a queue-group subscription
  on a subject with request/reply.
- **Group** — a collection of endpoints sharing an optional common subject prefix.

### Control / discovery subjects
Three verbs — **PING**, **INFO**, **STATS** — each with three addressing scopes:

| Subject pattern | Scope |
| --- | --- |
| `$SRV.PING` / `$SRV.INFO` / `$SRV.STATS` | all services respond |
| `$SRV.PING.<name>` / `$SRV.INFO.<name>` / `$SRV.STATS.<name>` | only services with that name |
| `$SRV.PING.<name>.<id>` / `$SRV.INFO.<name>.<id>` / `$SRV.STATS.<name>.<id>` | one specific instance |

- **PING** — discovery + RTT; every matching instance replies (used to enumerate a fleet).
- **INFO** — returns the service definition/metadata and its endpoints.
- **STATS** — returns per-endpoint performance counters.

A requester publishes on the `$SRV.<VERB>...` subject **with a reply-to subject**; each matching
service instance sends one reply. Crucially, the service publishes its response **to the request's
reply-to subject, NOT back onto `$SRV.*`** — this is ordinary NATS request/reply, exactly the pattern
in [[01 Request-Reply Helper]] (the `$SRV.*` subject is only how the *request* is addressed). For the
wildcard scopes this is a fan-in of many replies to the one reply-to subject — collect until timeout.

> No SCHEMA verb in current ADR-32 (earlier drafts had one; dropped). #question if a SCHEMA endpoint
> is required for our use, revisit ADR revision.

### Response JSON schemas (ADR-32)

**PING** — `io.nats.micro.v1.ping_response`
```json
{ "type": "io.nats.micro.v1.ping_response",
  "name": "string", "id": "string", "version": "string",
  "metadata": { "k": "v" } }
```

#### Worked flow — a `$SRV.PING` responder

Shows that the reply goes to the request's reply-to subject, not `$SRV.*`. Also in [[Cookbook]].

```text
Setup: our service is name="calc", id="ax7k2p9qz", version="1.2.0".
At startup we SUB "$SRV.PING" (and "$SRV.PING.calc", "$SRV.PING.calc.ax7k2p9qz").

1. A discovery client sends a request on $SRV.PING with a reply-to subject:
     PUB $SRV.PING _INBOX.7Gd3nQ.reply 0\r\n
     \r\n
   (empty payload; "_INBOX.7Gd3nQ.reply" is the reply-to the client is subscribed to)

2. Our SUB on $SRV.PING fires with reply-to = "_INBOX.7Gd3nQ.reply".

3. We build the ping_response JSON:
     {"type":"io.nats.micro.v1.ping_response","name":"calc","id":"ax7k2p9qz","version":"1.2.0","metadata":{}}

4. We PUBLISH it to the REQUEST'S REPLY-TO subject — NOT to $SRV.* :
     PUB _INBOX.7Gd3nQ.reply 104\r\n
     {"type":"io.nats.micro.v1.ping_response","name":"calc","id":"ax7k2p9qz","version":"1.2.0","metadata":{}}\r\n

   The client receives exactly one reply per matching instance on _INBOX.7Gd3nQ.reply and
   collects them until its timeout (that is how it enumerates the fleet).
```

**INFO** — `io.nats.micro.v1.info_response`
```json
{ "type": "io.nats.micro.v1.info_response",
  "name": "string", "id": "string", "version": "string",
  "metadata": { "k": "v" }, "description": "string",
  "endpoints": [
    { "name": "string", "subject": "string",
      "queue_group": "string", "metadata": { "k": "v" } }
  ] }
```

**STATS** — `io.nats.micro.v1.stats_response`
```json
{ "type": "io.nats.micro.v1.stats_response",
  "name": "string", "id": "string", "version": "string",
  "metadata": { "k": "v" }, "started": "ISO-8601 UTC timestamp",
  "endpoints": [
    { "name": "string", "subject": "string", "queue_group": "string",
      "num_requests": 0, "num_errors": 0,
      "last_error": "string (optional)", "data": "any (optional)",
      "processing_time": 0, "average_processing_time": 0 } ]
}
```

Counter notes:
- `num_requests` / `num_errors` — cumulative totals per endpoint.
- `processing_time` / `average_processing_time` — **nanoseconds** (total and mean per request).
- `started` — service start time, UTC ISO-8601.
- `id` — a unique per-instance identifier the client generates at startup (lets `.<name>.<id>`
  addressing target one running instance).

### Implementation sketch for the toolkit
1. On service create: generate `id`, store `name`/`version`/`metadata`/endpoint defs.
2. Subscribe each endpoint on its subject in a shared **queue group** (load-balanced handlers).
3. Subscribe the nine `$SRV.<VERB>[.name[.id]]` control subjects; auto-reply with the JSON above.
4. Wrap each endpoint invocation to increment `num_requests`/`num_errors` and accumulate
   `processing_time` — feed the STATS responder.

## Sources
- [Services (NATS developer docs)](https://docs.nats.io/using-nats/developer/services)
- [ADR-32 — NATS Service API](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-32.md)
