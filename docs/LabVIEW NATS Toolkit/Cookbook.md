---
type: reference
---

# Cookbook — worked end-to-end examples

Each recipe below is a complete request/response exchange with **real subjects and real bytes**, so you can see how an operation actually works before building it. The same example is also embedded inline in the relevant module note; this page collects them in one place.

New to NATS? Read [[NATS in 5 Minutes]] first; unfamiliar terms are in the [[Glossary]].

**Notation:** `C→S` = client→server, `S→C` = server→client. `␍␊` is the CRLF (`\r\n`) that terminates every protocol line. `PUB`/`HPUB` byte counts are real (payload length, or header-length + total-length for `HPUB`). Everything here is composed only from the raw NATS frames [[Foundation - nats.lv|nats.lv]] provides — see the [[Layering Overview#Invariant raw wire protocol over TCP only|wire-level invariant]].

Recipes follow the [[Build Order]]:
1. [Core NATS request/reply](#1-core-nats-requestreply) · 2. [Create a stream → verify](#2-create-a-stream--verify) · 3. [Publish with ack](#3-publish-with-ack) · 4. [Pull consumer: fetch → ack loop](#4-pull-consumer-fetch--ack-loop) · 5. [Key/Value end to end](#5-keyvalue-end-to-end) · 6. [Object Store: store & fetch](#6-object-store-store--fetch) · 7. [Authenticate with a .creds file](#7-authenticate-with-a-creds-file) · 8. [A service PING responder](#8-a-service-ping-responder)

---

## 1 · Core NATS request/reply
Module: [[01 Request-Reply Helper]]. A requester asks `greet.bob` with payload `hello` and gets back `hello, bob`. **The reply-to subject is how the responder learns where to send its answer** — the requester picks a private inbox, hands it over on the `PUB`, and the responder publishes to whatever reply-to it received. `A` = requester, `B` = responder (already subscribed to `greet.bob` as `sid 9`).

```
--- Requester (client A) ------------------------------------------------
A → S   SUB _INBOX.aTgB4kQ9wZ1pR6nS0x 1␍␊          # subscribe to my inbox, sid 1
A → S   UNSUB 1 1␍␊                                 # auto-unsub after exactly 1 reply
A → S   PUB greet.bob _INBOX.aTgB4kQ9wZ1pR6nS0x 5␍␊hello␍␊   # request; reply-to = my inbox

--- Responder (client B) ------------------------------------------------
S → B   MSG greet.bob 9 _INBOX.aTgB4kQ9wZ1pR6nS0x 5␍␊hello␍␊ # delivered on B's sid 9; B reads reply-to
B → S   PUB _INBOX.aTgB4kQ9wZ1pR6nS0x 10␍␊hello, bob␍␊       # answer sent to the reply-to subject

--- Requester receives the reply ----------------------------------------
S → A   MSG _INBOX.aTgB4kQ9wZ1pR6nS0x 1 10␍␊hello, bob␍␊     # arrives on sid 1; no reply-to field
```

The reply `MSG` carries **no** reply-to token and arrives stamped with `sid 1` — the requester's inbox subscription — which is how the request loop recognises it as *its* reply. Because `A` sent `UNSUB 1 1`, the server tore the inbox subscription down after this one frame. Remember there is a single shared `NATS READ.vi` loop (see [[Foundation - nats.lv]]): the requester matches by `sid`, routes other frames onward, and answers `PING` while waiting.

---

## 2 · Create a stream → verify
Module: [[03 JetStream Management API]]. A full round-trip using only Core NATS request/reply. Success is signalled by the **absence** of an `error` object.

```
# 1 · Create — PUB the StreamConfig to $JS.API.STREAM.CREATE.ORDERS with a reply inbox
C→S  SUB _INBOX.c 1␍␊
C→S  PUB $JS.API.STREAM.CREATE.ORDERS _INBOX.c 140␍␊
     {"name":"ORDERS","subjects":["orders.>"],"retention":"limits","max_consumers":-1,"max_msgs":-1,"max_bytes":-1,"max_age":0,"storage":"file","num_replicas":3}␍␊

# 2 · Reply on the inbox — a stream_create_response, whose body IS a StreamInfo (config + state)
S→C  MSG _INBOX.c 1 <n>␍␊
     {"type":"io.nats.jetstream.api.v1.stream_create_response","config":{"name":"ORDERS","subjects":["orders.>"],"retention":"limits","storage":"file","num_replicas":3, …},"state":{"messages":0,"bytes":0,"first_seq":0,"last_seq":0,"consumer_count":0},"created":"2026-07-23T10:15:00Z"}␍␊
```

Confirm success: no `Nats-Status: 503` (a service answered — JetStream is enabled) **and** no `error` object in the body. The returned `config` echoes what the server actually stored (defaults filled in); `state` shows a fresh stream. On failure, branch on `error.err_code` (see [[ApiError]]). Re-check anytime with an empty request to `$JS.API.STREAM.INFO.ORDERS` → another [[StreamInfo]] with the current `state`. Full field docs: [[StreamConfig]] · [[StreamInfo]].

---

## 3 · Publish with ack
Module: [[04 JetStream Publishing]]. Publish into the `ORDERS` stream and get a [[PubAck]] confirming it was stored. Uses `HPUB` to carry the `Nats-Msg-Id` dedup header (`hdr` = 37, `total` = 64).

```
# 1 · Publish via HPUB (Nats-Msg-Id enables dedup) with a reply inbox
C→S  SUB _INBOX.y 1␍␊
C→S  HPUB ORDERS _INBOX.y 37 64␍␊
     NATS/1.0␍␊
     Nats-Msg-Id: order-1001␍␊
     ␍␊
     {"id":1001,"item":"widget"}␍␊

# 2 · Server stores it and replies on the inbox with a PubAck (plain MSG, JSON body)
S→C  MSG _INBOX.y 1 43␍␊
     {"stream":"ORDERS","seq":42,"domain":"hub"}␍␊
```

`seq` is the message's position in the stream. If a second publish reuses `Nats-Msg-Id: order-1001` within the stream's dedup window, the PubAck comes back with `"duplicate":true` and no new message is stored. Full field docs: [[PubAck]].

---

## 4 · Pull consumer: fetch → ack loop
Module: [[05 JetStream Consuming]]. Create a durable pull consumer, then repeatedly fetch a batch and ack each message. Pull is the recommended first target — the LabVIEW loop paces itself.

```
# 1 · Create the pull consumer (durable, explicit ack, NO deliver_subject = pull)
C→S  SUB _INBOX.create 1␍␊
C→S  PUB $JS.API.CONSUMER.CREATE.ORDERS.order-workers _INBOX.create 90␍␊
     {"stream_name":"ORDERS","config":{"durable_name":"order-workers","ack_policy":"explicit"}}␍␊
S→C  MSG _INBOX.create 1 <n>␍␊
     {"type":"io.nats.jetstream.api.v1.consumer_create_response", …}␍␊   # body is a ConsumerInfo

# 2 · Ask for a batch of 2 · the JSON below IS the PUB payload · reply inbox = where messages land
C→S  SUB _INBOX.pull 2␍␊
C→S  PUB $JS.API.CONSUMER.MSG.NEXT.ORDERS.order-workers _INBOX.pull 32␍␊
     {"batch":2,"expires":5000000000}␍␊

# 3 · Two data messages arrive · each carries a $JS.ACK.… reply subject encoding its sequence
S→C  MSG orders.new 2 $JS.ACK.ORDERS.order-workers.1.42.1.1737550000000000000.1 27␍␊
     {"id":1001,"item":"widget"}␍␊
S→C  MSG orders.new 2 $JS.ACK.ORDERS.order-workers.1.43.2.1737550000000000000.0 27␍␊
     {"id":1002,"item":"gadget"}␍␊

# 4 · Ack each message by PUBlishing +ACK to ITS reply subject
C→S  PUB $JS.ACK.ORDERS.order-workers.1.42.1.1737550000000000000.1 4␍␊+ACK␍␊
C→S  PUB $JS.ACK.ORDERS.order-workers.1.43.2.1737550000000000000.0 4␍␊+ACK␍␊

# Batch complete: 2 data messages received = requested batch → loop to step 2 for the next batch.
# A 100 (idle heartbeat) status frame would NOT count as data; a 404/408 status ends the batch early.
```

Full field docs: [[ConsumerConfig]] · [[ConsumerGetnextRequest]]. Ack tokens (`+ACK`/`-NAK`/`+WPI`/`+TERM`/`+NXT`) and the `$JS.ACK` subject grammar are detailed in [[05 JetStream Consuming]].

---

## 5 · Key/Value end to end
Module: [[06 Key-Value Store]]. Bucket `CONFIG` ⇒ stream **`KV_CONFIG`** · subject space **`$KV.CONFIG.>`**. Store key `auth.username` = `labview-01` with CREATE semantics, read it back via Direct GET, then watch `auth.>`.

```
# 1 · Create the bucket = a stream CREATE with KV-specific settings
C→S  SUB _INBOX.b 1␍␊
C→S  PUB $JS.API.STREAM.CREATE.KV_CONFIG _INBOX.b 191␍␊
     {"name":"KV_CONFIG","subjects":["$KV.CONFIG.>"],"retention":"limits","max_msgs_per_subject":5,"discard":"new","storage":"file","allow_direct":true,"allow_rollup_hdrs":true,"deny_delete":true}␍␊
S→C  MSG _INBOX.b 1 <n>␍␊
     {"type":"io.nats.jetstream.api.v1.stream_create_response", …}␍␊     # body is a StreamInfo

# 2 · PUT auth.username with CREATE semantics (Nats-Expected-Last-Subject-Sequence: 0 = "must be new")
C→S  SUB _INBOX.p 2␍␊
C→S  HPUB $KV.CONFIG.auth.username _INBOX.p 52 62␍␊
     NATS/1.0␍␊Nats-Expected-Last-Subject-Sequence: 0␍␊␍␊labview-01␍␊
S→C  MSG _INBOX.p 2 30␍␊
     {"stream":"KV_CONFIG","seq":1}␍␊                                    # PubAck — the entry's revision = seq = 1

# 3 · GET the latest value via Direct GET (no consumer; allow_direct)
C→S  SUB _INBOX.g 3␍␊
C→S  PUB $JS.API.DIRECT.GET.KV_CONFIG.$KV.CONFIG.auth.username _INBOX.g 0␍␊␍␊
S→C  HMSG _INBOX.g 3 <hdr> <tot>␍␊
     NATS/1.0␍␊Nats-Stream: KV_CONFIG␍␊Nats-Subject: $KV.CONFIG.auth.username␍␊Nats-Sequence: 1␍␊␍␊labview-01␍␊

# 4 · WATCH auth.> = ephemeral ordered consumer over $KV.CONFIG.auth.> (last_per_subject + live updates)
C→S  SUB _INBOX.w 4␍␊                                                    # delivery subject for the watch
C→S  SUB _INBOX.wc 5␍␊
C→S  PUB $JS.API.CONSUMER.CREATE.KV_CONFIG _INBOX.wc 186␍␊
     {"stream_name":"KV_CONFIG","config":{"filter_subject":"$KV.CONFIG.auth.>","deliver_policy":"last_per_subject","ack_policy":"none","deliver_subject":"_INBOX.w","replay_policy":"instant"}}␍␊
S→C  MSG _INBOX.wc 5 <n>␍␊                                               # ConsumerInfo reply
S→C  MSG _INBOX.w 4 10␍␊
     labview-01␍␊                                                        # first delivery: current value
# subsequent PUT / DEL / PURGE on $KV.CONFIG.auth.> now arrive on _INBOX.w as they happen
```

The "ordered consumer" is the wire recipe in [[05 JetStream Consuming]]. Full field docs: [[KvConfig]] · [[KvEntry]].

---

## 6 · Object Store: store & fetch
Module: [[07 Object Store]]. Bucket `ASSETS` ⇒ stream **`OBJ_ASSETS`** · chunk subjects `$O.ASSETS.C.>` · meta subjects `$O.ASSETS.M.>`. Store `sensor-calibration.bin` (307 200 bytes) as three 128 KiB chunks, then read it back and verify the digest. The name token is base64url **with padding** of the object name — `sensor-calibration.bin` → `c2Vuc29yLWNhbGlicmF0aW9uLmJpbg==` (note the trailing `==`).

```
# --- PUT ---
# 1 · Assign nuid, publish chunks to $O.ASSETS.C.<nuid> IN ORDER (128 KiB = 131072; 307200 = 131072+131072+45056)
C→S  PUB $O.ASSETS.C.CkuyLEX4z2hbyjj1aWCfiH 131072␍␊<…131072 raw bytes…>␍␊
C→S  PUB $O.ASSETS.C.CkuyLEX4z2hbyjj1aWCfiH 131072␍␊<…131072 raw bytes…>␍␊
C→S  PUB $O.ASSETS.C.CkuyLEX4z2hbyjj1aWCfiH 45056␍␊<…45056 raw bytes…>␍␊
#     rolling SHA-256 over the raw bytes → SHA-256=EKYWmBP8wEELPXJXT_LdGZeTa5DbghQnE2MVlnz_K7k=

# 2 · Publish the meta to $O.ASSETS.M.<base64url(name)> WITH the rollup header (latest meta wins)
C→S  SUB _INBOX.m 1␍␊
C→S  HPUB $O.ASSETS.M.c2Vuc29yLWNhbGlicmF0aW9uLmJpbg== _INBOX.m 30 202␍␊
     NATS/1.0␍␊Nats-Rollup: sub␍␊␍␊{"name":"sensor-calibration.bin","bucket":"ASSETS","nuid":"CkuyLEX4z2hbyjj1aWCfiH","size":307200,"chunks":3,"digest":"SHA-256=EKYWmBP8wEELPXJXT_LdGZeTa5DbghQnE2MVlnz_K7k="}␍␊
S→C  MSG _INBOX.m 1 <n>␍␊
     {"stream":"OBJ_ASSETS","seq":4}␍␊                                   # PubAck for the meta message

# --- GET & verify ---
# 3 · Read current meta via Direct GET → nuid, size, chunks, digest
C→S  SUB _INBOX.g 2␍␊
C→S  PUB $JS.API.DIRECT.GET.OBJ_ASSETS.$O.ASSETS.M.c2Vuc29yLWNhbGlicmF0aW9uLmJpbg== _INBOX.g 0␍␊␍␊
S→C  HMSG _INBOX.g 2 <hdr> <tot>␍␊
     NATS/1.0␍␊Nats-Stream: OBJ_ASSETS␍␊…␍␊␍␊{"name":"sensor-calibration.bin","nuid":"CkuyLEX4z2hbyjj1aWCfiH","size":307200,"chunks":3,"digest":"SHA-256=EKYWmBP8wEELPXJXT_LdGZeTa5DbghQnE2MVlnz_K7k="}␍␊

# 4 · Read the chunks IN STREAM ORDER — ordered consumer over $O.ASSETS.C.<nuid>
C→S  SUB _INBOX.c 3␍␊
C→S  SUB _INBOX.cc 4␍␊
C→S  PUB $JS.API.CONSUMER.CREATE.OBJ_ASSETS _INBOX.cc 191␍␊
     {"stream_name":"OBJ_ASSETS","config":{"filter_subject":"$O.ASSETS.C.CkuyLEX4z2hbyjj1aWCfiH","deliver_policy":"all","ack_policy":"none","deliver_subject":"_INBOX.c","replay_policy":"instant"}}␍␊
S→C  MSG _INBOX.cc 4 <n>␍␊                                              # ConsumerInfo reply
S→C  MSG _INBOX.c 3 131072␍␊<…chunk 1…>␍␊
S→C  MSG _INBOX.c 3 131072␍␊<…chunk 2…>␍␊
S→C  MSG _INBOX.c 3 45056␍␊<…chunk 3…>␍␊

# 5 · Feed each chunk into a rolling SHA-256; after chunk 3 compare against the meta digest → match = OK.
#     Also cross-check bytes read = 307200 (size) and messages = 3 (chunks).
```

Full field docs: [[ObjectInfo]] · [[ObjectMetaOptions]].

---

## 7 · Authenticate with a `.creds` file
Module: [[02 Authentication]]. Mechanism 5 (JWT/creds). This is the one path needing the **Ed25519** primitive (see the module's implementation options).

```
1. Parse the .creds file (plain text — no crypto):
     jwt   = text between "-----BEGIN NATS USER JWT-----"   and "------END NATS USER JWT------"
     seedS = text between "-----BEGIN USER NKEY SEED-----"  and "------END USER NKEY SEED------"

2. Base32-decode seedS (std alphabet, NO padding) → [ b1 ][ b2 ][ 32-byte raw seed ][ 2-byte CRC16 ]
   - verify CRC16/XMODEM (little-endian) over all but the last 2 bytes
   - strip the 2 prefix bytes and the 2 CRC bytes → rawSeed (the middle 32 bytes)

3. Derive the Ed25519 signing key from rawSeed (ed25519.NewKeyFromSeed equivalent).

4. Connect the TCP socket and WAIT for the server INFO:
     INFO {..., "nonce":"YWxwaGFudW1lcmljcmFuZG9t", ...}

5. Sign the RAW nonce bytes as received (do NOT base64-decode the nonce first):
     sigRaw = Ed25519-Sign(privKey, bytesOf(nonce))     → 64 bytes

6. base64url-encode sigRaw with NO padding (RawURLEncoding):
     sig = "u5Kx…nopad…"

7. Send CONNECT with the jwt and sig (omit "nkey" — the public key is inside the JWT):
     CONNECT {"jwt":"eyJ0eXAiOiJKV1Qi…","sig":"u5Kx…","verbose":false,"pedantic":false}␍␊
```

The server validates the JWT chain (operator→account→user) and the `sig` against the `U…` key in the JWT. On success the connection is authenticated; on failure it sends `-ERR` and closes. Note the `sig` uses **no-padding** base64url — unlike the Object Store name/digest, which use padding.

---

## 8 · A service PING responder
Module: [[08 Services Framework]] (stretch). Shows that a service replies to the **request's reply-to subject**, not back onto `$SRV.*`.

```
# Service: name="calc", id="ax7k2p9qz", version="1.2.0"; at startup it SUBs $SRV.PING (+ .calc, .calc.ax7k2p9qz)

# 1 · A discovery client pings with a reply-to inbox
C→S  PUB $SRV.PING _INBOX.7Gd3nQ.reply 0␍␊␍␊

# 2 · Our SUB on $SRV.PING fires with reply-to = _INBOX.7Gd3nQ.reply
# 3 · We PUBLISH the ping_response to the REQUEST'S REPLY-TO subject — NOT to $SRV.*
C→S  PUB _INBOX.7Gd3nQ.reply 104␍␊
     {"type":"io.nats.micro.v1.ping_response","name":"calc","id":"ax7k2p9qz","version":"1.2.0","metadata":{}}␍␊
```

The client collects one reply per running instance on its inbox until a timeout — that's how it enumerates the fleet. Full field docs: [[ServicePing]] · [[ServiceInfo]] · [[ServiceStats]].

---
See also: [[NATS in 5 Minutes]] · [[Glossary]] · [[Layering Overview]] · [[JetStream JSON Schemas]] · [[Schema Catalog]]

#reference
