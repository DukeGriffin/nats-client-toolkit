---
type: module
status: stretch
---

# 09 — Monitoring & Admin (optional/stretch)

## Scope
- The `/varz`, `/connz`, `/jsz`, etc. endpoints are **plain HTTP**, not NATS protocol.
- Could be built with LabVIEW's native HTTP client VIs, entirely independent of the rest of the toolkit.

## Depends on
- Nothing else in this vault — low coupling. Could be built at any point, including before Core NATS work if useful for early visibility into a running server.

## Docs
- `running-a-nats-service/nats_admin/monitoring`
- `running-a-nats-service/nats_admin/monitoring/monitoring_jetstream`

## Notes / decisions log
-

---

## Reference — Monitoring & admin surfaces

Source: `running-a-nats-service/nats_admin/monitoring` (docs.nats.io). Three distinct monitoring
surfaces exist; only the first is plain HTTP.

### 1. HTTP monitoring endpoints (default port 8222) — HTTP/JSON, NOT the NATS protocol

Enabled with `http_port: 8222` (or `-m 8222`); TLS variant `https_port`. All endpoints return
**JSON** (support JSONP callbacks + CORS). **Built with LabVIEW's native HTTP client VIs, entirely
independent of `nats.lv`** — this is a REST-style admin API served by the nats-server, not framed
NATS messages.

| Endpoint | Returns (one line) |
| --- | --- |
| `/varz` | General server state + configuration (version, uptime, mem, connections, slow consumers). |
| `/connz` | Current and recently-closed **client connections**, with paging (default 1024). |
| `/routez` | Active **cluster route** connections, optionally with their subscriptions. |
| `/subsz` | The server's **subscription** table / routing data structure. |
| `/jsz` | **JetStream** metrics — accounts, streams, consumers, and JS memory/store usage. |
| `/healthz` | Health check — returns OK if the server is up and accepting connections. |
| `/accountz` | Active **accounts** (or metrics for a specified account). |
| `/leafz` | **Leaf node** connections and their subscriptions. |
| `/gatewayz` | Gateway connections for **superclusters** (bonus, same family). |
| `/accstatz` | Per-account stats — connections, messages, bytes (bonus). |

Most endpoints accept query params (e.g. `/connz?subs=1`, `/jsz?accounts=true`). For JetStream
detail see `monitoring/monitoring_jetstream` and cross-check against [[JetStream Wire API]].

### 2. JetStream advisories/events — in-protocol alternative
For push-based monitoring without polling HTTP, subscribe to **`$JS.EVENT.ADVISORY.>`** over the
normal NATS connection (works with `nats.lv` PUB/SUB — see [[JetStream Wire API]] and
[[Foundation - nats.lv]]). These advisories cover stream/consumer create/delete, max-deliveries,
consumer leader elections, etc. Advantage: uses the existing NATS connection and is event-driven
rather than a polled REST call.

### 3. System account events — high level
The **system account** publishes internal events under **`$SYS.>`** (e.g. connection connect/
disconnect events, account/server statz, server pings via `$SYS.REQ.SERVER.*`). These require
connecting with system-account credentials. This is also in-protocol (subscribe via `nats.lv`),
distinct from the HTTP endpoints above. #question whether the toolkit needs `$SYS.>` monitoring at
all, or whether `/varz` + `$JS.EVENT.ADVISORY.>` cover our visibility needs — treat `$SYS.>` as
lowest priority.

### Decision hint
Because surface #1 is pure HTTP, this module has **zero coupling to the NATS protocol layer** and
can be built at any time (even before Core NATS work) for early server visibility. Surfaces #2/#3
depend on the Core NATS subscribe path and belong after that lands.

## Sources
- [Monitoring a NATS service](https://docs.nats.io/running-a-nats-service/nats_admin/monitoring)
- [Monitoring JetStream](https://docs.nats.io/running-a-nats-service/nats_admin/monitoring/monitoring_jetstream)
