---
type: module
status: planned
---

# 01 — Request-Reply Helper

Not glamorous, but everything downstream depends on it.

## Scope
- Wrap [[Foundation - nats.lv|nats.lv]]'s `PUB` + `SUB` into a synchronous "Request" VI:
  1. Generate a unique `_INBOX.<uid>` subject
  2. Subscribe to it
  3. Publish the request with reply-to set to the inbox subject
  4. Wait for a response with a caller-supplied timeout
  5. Unsubscribe / clean up
- Consider an async variant (fire request, return a refnum/notifier, don't block) since [[04 JetStream Publishing]] needs it for async ack correlation.

## Depends on
- [[Foundation - nats.lv]] (PUB/SUB primitives) — nothing else.

## Used by
- [[03 JetStream Management API]], [[04 JetStream Publishing]], [[05 JetStream Consuming]], [[06 Key-Value Store]], [[07 Object Store]] — essentially everything.

## Docs
- `using-nats/developer/sending/request_reply`
- [[Core NATS Protocol]] (Request vs Publish, and the exact wire grammar, from the protocol spec)

## Wire / implementation reference

Source: [reqreply concept](https://docs.nats.io/nats-concepts/core-nats/reqreply), [request-reply developer guide](https://docs.nats.io/using-nats/developer/sending/request_reply), and [[Core NATS Protocol]] for the exact line grammar.

### Single request → single reply (the common case)
The pattern is "subscribe, get one message, unsubscribe." Precise sequence over [[Foundation - nats.lv|nats.lv]]:

1. **Generate a unique reply subject** `_INBOX.<uid>`, where `<uid>` is a high-entropy random token (NUID-style; any collision-resistant unique string). See the INBOX convention in [[Core NATS Protocol]].
2. **Subscribe** to the inbox: `SUB _INBOX.<uid> <sid>\r\n`. Optionally send `UNSUB <sid> 1\r\n` right after to have the server auto-unsubscribe after exactly one message (belt-and-suspenders cleanup even if the client crashes).
3. **Publish the request** with reply-to = the inbox: `PUB <subject> _INBOX.<uid> <#bytes>\r\n<payload>\r\n` (or `HPUB …` if sending headers).
4. **Await one `MSG`/`HMSG`** on that `sid` / inbox subject, bounded by the caller-supplied timeout. **There is no per-subscription blocking read to wait on** — [[Foundation - nats.lv|nats.lv]] gives you a single `NATS READ.vi` that returns *every* frame for *all* subscriptions plus protocol control frames, and no built-in demux (see the delivery model in [[Foundation - nats.lv]]). So "await the reply" concretely means a loop: **drive `NATS READ.vi`; for each frame, check whether its `sid`/reply-inbox matches this request** — if it matches, that's your reply, stop; if it's some *other* subscription's frame, hand it back to whoever owns the main read loop; if it's a `PING`, answer `PONG` (unless nats.lv already did so inside `READ` — that's the open `#question` in [[Foundation - nats.lv]]); if it's `-ERR`/`+OK`, handle accordingly. Repeat until a matching reply arrives, the timeout fires, or a `503` no-responders frame comes back (below). This is why request-reply cannot be a thin wrapper — it must cooperate with, or own, the connection's one read loop.
5. **Unsubscribe / clean up**: `UNSUB <sid>\r\n` (redundant if step 2 used `UNSUB … 1`), release the inbox and any refnum/notifier.

### Worked transcript (both sides)
A requester asks `greet.bob` with payload `hello` and gets back `hello, bob`. **The reply-to subject is how the responder learns where to send its answer** — the requester picks a private inbox, hands it over on the `PUB`, and the responder just publishes to whatever reply-to it received. `S` = `nats-server`, `A` = requester, `B` = responder (already subscribed to `greet.bob` as `sid 9`). Byte counts are payload lengths (`hello` = 5, `hello, bob` = 10):

```
--- Requester (client A) ------------------------------------------------
A → S   SUB _INBOX.aTgB4kQ9wZ1pR6nS0x 1\r\n          # subscribe to my inbox, sid 1
A → S   UNSUB 1 1\r\n                                 # auto-unsub after exactly 1 reply
A → S   PUB greet.bob _INBOX.aTgB4kQ9wZ1pR6nS0x 5\r\nhello\r\n   # request; reply-to = my inbox

--- Responder (client B) ------------------------------------------------
S → B   MSG greet.bob 9 _INBOX.aTgB4kQ9wZ1pR6nS0x 5\r\nhello\r\n # delivered on B's sid 9; B reads reply-to
B → S   PUB _INBOX.aTgB4kQ9wZ1pR6nS0x 10\r\nhello, bob\r\n       # answer sent to the reply-to subject

--- Requester receives the reply ----------------------------------------
S → A   MSG _INBOX.aTgB4kQ9wZ1pR6nS0x 1 10\r\nhello, bob\r\n     # arrives on sid 1; no reply-to field
```

Note the reply `MSG` carries **no** reply-to token (nobody is expected to answer the answer), and it arrives stamped with `sid 1` — the requester's inbox subscription — which is how the request-reply loop (step 4 above) recognises it as *its* reply and stops. Because `A` sent `UNSUB 1 1`, the server has already torn the inbox subscription down after this single frame.

### No-responders fast-fail (503)
If the toolkit negotiated `no_responders:true` **and** `headers:true` in CONNECT, and the server advertises `headers:true` in INFO, a request published to a subject with **zero subscribers** comes back immediately as an empty `HMSG` on the inbox with header version line `NATS/1.0 503`. Treat this as a distinct "no responders available" outcome and fail fast rather than waiting out the full timeout. If `no_responders` was not negotiated, the only signal is the timeout expiring. See status-header table in [[Core NATS Protocol]].

### Single-response vs multi-response (scatter/gather)
- **Single response:** return as soon as the first `MSG`/`HMSG` arrives; `UNSUB` immediately. This is what [[03 JetStream Management API]] and [[04 JetStream Publishing]] ack correlation need — one JSON reply per request.
- **Multi-response (scatter/gather):** the same inbox can receive many replies (e.g. "who's out there" discovery, or first-wins load-balanced responders where extras are discarded). Here **the timeout — not a message count — defines completion**: keep collecting `MSG`s on the inbox until the timeout elapses (or until an optional "at least N responses" target is met), then `UNSUB`. The async variant noted in Scope is the natural home for this: hand the caller a refnum/notifier and let them drain replies until they stop.

### Notes for the async variant
- Correlation: with a shared-inbox design (`SUB _INBOX.<connUid>.*` once, mint a new trailing token per request), route each incoming `MSG` back to the pending request by its inbox token instead of one SUB/UNSUB per call — fewer round-trips at high request rates.
- Timeout is client-side only; NATS has no server-side request timeout. A default (reference clients often use ~2 s, but leave it caller-supplied) should be exposed on the VI.

## Open questions
- #question What's the LabVIEW-idiomatic timeout/error convention (numeric error cluster vs. dedicated NATS error cluster)? This decision propagates to every module built on top. Concrete options to weigh (leaving the choice to the user):
  - **(A) Standard LV error cluster + NATS code sub-field.** Reuse the built-in `error in`/`error out` cluster so every VI chains natively on the error wire; carry NATS-specific detail (the `-ERR '<msg>'` text, or a status like `503`/`408 timeout`) either in the `source` string or via a parallel numeric NATS-code output. Pro: idiomatic, composes with all LV primitives. Con: shoehorns NATS semantics into a 32-bit `code` + string.
  - **(B) Dedicated NATS result cluster** (e.g. `{ success?, nats_status (503/100/409/…), err_text, timed_out? }`) alongside a plain LV error out for transport/framing faults. Pro: models protocol outcomes precisely (distinguishes "no responders 503" vs "timeout" vs "-ERR permissions"). Con: extra type every downstream module must understand; two things to check.
  - **(C) Hybrid:** standard error cluster for hard/transport failures, plus a separate typed enum/cluster output for protocol outcomes (`Response` / `NoResponders` / `Timeout`). Keeps the error wire clean while still surfacing 503-vs-timeout.
  - Sub-question: #question should "no responders (503)" and "timeout" be the *same* error to callers or distinct? They mean different things (nobody listening vs. responder too slow / lost reply) and downstream retry logic may care.

## Notes / decisions log
-

## Sources
- [Request-Reply (NATS concepts)](https://docs.nats.io/nats-concepts/core-nats/reqreply)
- [Request-Reply developer guide](https://docs.nats.io/using-nats/developer/sending/request_reply)
