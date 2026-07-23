---
type: schema
schema_id: io.nats.jetstream.api.v1 (shared response envelope + error object)
source: https://raw.githubusercontent.com/nats-io/nats-architecture-and-design/main/adr/ADR-1.md
---

# ApiError

> The shared response envelope carried by **every** `$JS.API.*` reply, and the `error` object embedded within it. Every JetStream management/info/publish response is a JSON payload on a Core NATS reply frame; each one begins with a `type` hint and, on failure, carries a single `error` object. This page is the canonical definition referenced by all other response types.

**Required fields:** `type` (on responses that declare it; see notes). Within the error object: `code`. All others optional.
**Used by:** all `$JS.API.*` responses — [[PubAck]], [[AccountInfo]], [[StreamInfo]], [[ConsumerInfo]], and every other response schema.

## The response envelope

Each JetStream API reply is JSON with a leading `type` hint identifying its schema, plus the operation-specific payload. On failure the payload is replaced by a single `error` object.

| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `type` | `string` | **Yes** | — | Schema identifier of the response, of the form `io.nats.jetstream.api.v1.<operation>_response` (e.g. `io.nats.jetstream.api.v1.pub_ack_response`). Replies carry a type hint; requests generally do not — the kind is inferred from the subject requested. |
| `error` | `object` | No | — | Present **only** on failure. Its presence/absence is the sole success-vs-error discriminator (see below). Fields defined in the table under "The error object". |

## The error object

| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `code` | `int` | **Yes** | — | HTTP-like status code. Range `300`–`699` per schema (commonly `400`, `404`, `500`, `503`). Coarse category only — do not branch program logic on it alone. |
| `err_code` | `int` | No | — | The **stable, programmatic** NATS error identifier, unique to each kind of error. Range `0`–`65535`; JetStream errors occupy the `10000`–`19999` band. This is the value to switch on in code — it does not change across server versions, unlike `description`. |
| `description` | `string` | No | — | Human-friendly explanation of the error. **Varies between server versions** and is for display/logging only — never parse or match on it. |

## Constraints & validation / Notes
- **Discriminator rule.** A response is a *success* if and only if the `error` object is **absent**. The absence of `error` indicates success; its presence indicates failure. Always test for `error` before reading any success field (e.g. `seq` on [[PubAck]], `memory` on [[AccountInfo]]).
- **Branch on `err_code`, not `description`.** `code` is a coarse HTTP-like category and `description` is version-dependent free text; only `err_code` is a stable contract. Within the error object schema, only `code` is `required`, so tolerate a missing `err_code`/`description`.
- **503 no-responders is *not* an ApiError.** When no server is subscribed to the requested `$JS.API.*` subject (JetStream not enabled, leader not yet elected, wrong subject), Core NATS returns a **503 no-responders** status message — an empty-payload reply with a `Nats-Status: 503` header — *before* any JSON is produced. That is a transport-level signal, not this JSON `error` object. Treat it as "service unavailable / retry".
- **Canonical error list.** Per **ADR-7 (NATS Server Error Codes)**, the ADR does **not** hard-enumerate the codes; the authoritative machine-readable list is `server/errors.json` in the nats-server repo (constants are generated from it via `go generate`). The table below is a curated subset of common codes verified against that file — it is **not exhaustive**; consult `server/errors.json` for the full set. #question if any downstream page cites an `err_code` not present in that file.

### Common err_codes (subset — see `server/errors.json` for the complete list)
| err_code | code | description |
|---|---|---|
| `10003` | `400` | bad request |
| `10008` | `503` | JetStream system temporarily unavailable |
| `10014` | `404` | consumer not found |
| `10023` | `503` | insufficient resources |
| `10026` | `400` | maximum consumers limit reached |
| `10027` | `400` | maximum number of streams reached |
| `10037` | `404` | no message found |
| `10039` | `503` | JetStream not enabled for account |
| `10054` | `400` | message size exceeds maximum allowed |
| `10058` | `400` | stream name already in use with a different configuration |
| `10059` | `404` | stream not found |
| `10063` | `503` | expected stream sequence does not match |
| `10071` | `400` | wrong last sequence: {seq} |

## Example JSON
Error payload (as embedded in any `$JS.API.*` response — e.g. a STREAM.INFO for a missing stream):
```json
{
  "type": "io.nats.jetstream.api.v1.stream_info_response",
  "error": {
    "code": 404,
    "err_code": 10059,
    "description": "stream not found"
  }
}
```

Success payload (same envelope, `type` present, no `error`):
```json
{
  "type": "io.nats.jetstream.api.v1.stream_names_response",
  "total": 2,
  "offset": 0,
  "limit": 1024,
  "streams": ["ORDERS", "EVENTS"]
}
```

## Referenced by
[[PubAck]] · [[AccountInfo]] · [[StreamInfo]] · [[ConsumerInfo]] · [[Schema Catalog]] · [[JetStream JSON Schemas]]

## Sources
- [ADR-1: JetStream JSON API Design](https://raw.githubusercontent.com/nats-io/nats-architecture-and-design/main/adr/ADR-1.md)
- [ADR-7: NATS Server Error Codes](https://raw.githubusercontent.com/nats-io/nats-architecture-and-design/main/adr/ADR-7.md)
- [server/errors.json (canonical err_code list)](https://raw.githubusercontent.com/nats-io/nats-server/main/server/errors.json)
- [pub_ack_response.json (error object shape)](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/pub_ack_response.json)

#reference #schema
