---
type: schema
schema_id: io.nats.jetstream.api.v1.stream_purge_request
source: https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_purge_request.json
---

# StreamPurgeRequest

> Request to selectively purge messages from a stream. Published (PUB with a reply inbox) to `$JS.API.STREAM.PURGE.<stream>`. An empty body `{}` purges the entire stream; the fields below narrow the purge. This is a request body on the wire, not a client-library object.

**Required fields:** none. All fields optional (empty body = purge everything).
**Used by:** [[03 JetStream Management API]]

## Fields
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `filter` | `string` | No | — | Restrict purging to messages that match this subject. |
| `seq` | `uint64` | No | — | Purge all messages up to but **not** including the message with this sequence. Can be combined with `filter` but **not** with `keep`. Min `0`. |
| `keep` | `uint64` | No | — | Ensure this many messages remain present after the purge. Can be combined with `filter` but **not** with `seq`. Min `0`. |

## Constraints & validation
- The schema defines **no** `required` fields. Sending `{}` purges the whole stream.
- **Mutually-exclusive fields:** `seq` and `keep` cannot be used together — the schema descriptions on both state so explicitly. Choose one purge strategy:
  - **Up-to-sequence** — `seq`: delete everything below that sequence number.
  - **Keep-N** — `keep`: delete oldest messages but retain the newest `keep` messages.
- **`filter` composes with either.** It is a subject narrower, not a strategy: `filter` alone purges only messages on that subject; `filter` + `seq` purges that subject up to the sequence; `filter` + `keep` purges that subject while keeping the newest `keep` on it.
- **Precedence / combinations:**
  - `filter` only → purge matching subject entirely.
  - `seq` only → purge whole stream below `seq`.
  - `keep` only → purge whole stream, retain newest `keep`.
  - `filter` + `seq` → subject-scoped up-to-sequence purge.
  - `filter` + `keep` → subject-scoped keep-N purge.
  - `seq` + `keep` → **invalid** (mutually exclusive).

## Example JSON
```json
{
  "filter": "orders.us.east",
  "keep": 10
}
```

## Referenced by
[[03 JetStream Management API]] · [[Schema Catalog]] · [[JetStream JSON Schemas]]

## Sources
- [stream_purge_request.json](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_purge_request.json)
- [JetStream — Purging a Stream (docs.nats.io)](https://docs.nats.io/nats-concepts/jetstream/streams)

#reference #schema
