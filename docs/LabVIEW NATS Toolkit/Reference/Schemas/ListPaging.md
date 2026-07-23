---
type: schema
source: https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_list_request.json
---

# ListPaging

> The shared offset/limit/total paging convention used by every JetStream LIST and NAMES operation. Requests carry an `offset` (and STREAM listings may carry a `subject` filter); responses echo `total`, `offset`, `limit` alongside the result array (`streams` / `consumers` / `streams` for names). This page documents the pattern once; per-operation pages in [[JetStream JSON Schemas]] link here rather than repeating it.

**Required fields:** varies per request (see below); responses require `total`, `offset`, `limit` (plus the response `type`).
**Used by:** [[03 JetStream Management API]]

## Request fields
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `offset` | `int64` | see notes | — | Index of the first item to return. Min `0`. Increment across calls to page. Required in `CONSUMER.LIST` (`additionalProperties:false, required:["offset"]`); optional in `STREAM.LIST` / `STREAM.NAMES`. |
| `subject` | `string` | No | — | Limit the listing to assets matching this subject filter. Present on `STREAM.LIST` and `STREAM.NAMES` requests only. |

- **`$JS.API.STREAM.LIST`** request (`stream_list_request.json`): `offset` (optional), `subject` (optional).
- **`$JS.API.STREAM.NAMES`** request (`stream_names_request.json`): `offset` (optional), `subject` (optional).
- **`$JS.API.CONSUMER.LIST`** request (`consumer_list_request.json`): `offset` (**required**, `additionalProperties:false`).
- **`$JS.API.CONSUMER.NAMES`** / **`$JS.API.STREAM.NAMES`** follow the same offset paging.

## Response fields
| Field (JSON key) | Type | Required | Default | Description |
|---|---|---|---|---|
| `total` | `int64` | **Yes** | — | Total number of items available across all pages. Min `0`. |
| `offset` | `int64` | **Yes** | — | The offset this page starts at (echoes the request). Min `0`. |
| `limit` | `int64` | **Yes** | — | Maximum number of items the server returns per page (server-chosen page size). Min `0`. |
| `streams` / `consumers` | `array` | see notes | — | The result array for this page. `STREAM.LIST` → `streams` (full [[StreamInfo]] objects); `CONSUMER.LIST` → `consumers` (full [[ConsumerInfo]] objects); `STREAM.NAMES` → `streams` (array of name strings). Present on the success branch of the `oneOf` (`required` in that branch). |
| `type` | `string` | **Yes** | — | Response type discriminator, e.g. `io.nats.jetstream.api.v1.stream_list_response`. |
| `error` | `object` | — | — | Present instead of the result array on the error branch of the `oneOf`. See [[ApiError]]. |
| `missing` | `array of string` | No | — | In clustered environments, assets whose info timed out and could not be gathered. |

## Constraints & validation
- The response is a `oneOf`: **either** an `error` object **or** the result array — never both. `total`/`offset`/`limit` and `type` are always present (`allOf` + top-level `required`).
- The server, not the client, chooses the page size (`limit`); it is not a request parameter here.
- **How to page:** start at `offset: 0`. After each response, compute `offset + len(returned array)`. Keep issuing requests with `offset` incremented by the number of items returned until `offset + returned >= total`. Stop when the running count reaches `total` (or the returned array is empty).
- The `subject` filter, where supported, narrows both `total` and the returned set — page against the filtered `total`, not the stream's absolute count.

## Example JSON
Request (`CONSUMER.LIST`, second page):
```json
{
  "offset": 100
}
```

Response (`STREAM.LIST`):
```json
{
  "type": "io.nats.jetstream.api.v1.stream_list_response",
  "total": 250,
  "offset": 0,
  "limit": 100,
  "streams": [ { "config": { "name": "ORDERS" }, "state": {}, "created": "2026-07-23T10:00:00Z" } ]
}
```
Here `offset(0) + returned(100) = 100 < total(250)` → request again with `offset: 100`, then `offset: 200`; that page returns 50 items, `200 + 50 = 250 >= 250` → done.

## Referenced by
[[StreamInfo]] · [[ConsumerInfo]] · [[ApiError]] · [[03 JetStream Management API]] · [[Schema Catalog]] · [[JetStream JSON Schemas]]

## Sources
- [stream_list_request.json](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_list_request.json)
- [stream_list_response.json](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_list_response.json)
- [consumer_list_request.json](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_list_request.json)
- [consumer_list_response.json](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/consumer_list_response.json)
- [stream_names_request.json](https://raw.githubusercontent.com/nats-io/jsm.go/main/schemas/jetstream/api/v1/stream_names_request.json)

#reference #schema
