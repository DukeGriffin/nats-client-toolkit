---
type: module
status: idea
---

# 10 — Object Messaging (NATS Actor Bridge)

Optional / stretch, and LabVIEW-specific. A convenience layer for sending **Actor Framework `Message` objects** over NATS: publish a serialized `Message` (payload) with its type in a header; the subscriber reconstructs the concrete `Message`, deserializes it, and dispatches it into an actor. Effectively **distributed Actor Framework over NATS** — a command/event bus. **Not** for high-rate data (see the high-rate note in [[04 JetStream Publishing]]).

## Scope
- **Publish:** serialize a `Message` → NATS payload; set a type header; `HPUB` to a subject.
- **Subscribe:** receive `HMSG`; reconstruct the concrete `Message` type; deserialize; enqueue to the target actor (its `Do` runs). This is the receive half of an `Actor Message` delivery strategy — see the `IDelivery` discussion in [[Library and Project Structure]].

## Reuse the AF Network Endpoint Actor #decision
The LabVIEW Actor Framework **Network Endpoint Actor** already implements the hard parts — **serialize/deserialize of Messages (flatten/unflatten with concrete-type fidelity) and encryption/decryption**. Reuse it; the only real change is swapping its **TCP transport for NATS pub/sub** (reuse per its license).

- **Transfers directly:** message flatten/unflatten, encrypt/decrypt, reconstruct-and-dispatch, and its handling of "the message classes must be in memory."
- **Gets simpler — drop the framing:** over TCP it length-prefixes and reassembles a byte *stream*; NATS preserves message boundaries (one `PUB` = one whole message), so there's no reassembly to do.
- **Transport swap:** TCP Write/Read → `PUB` + a subscription feeding the same deserialize→dispatch path (via the client pub/sub + the `Actor Message` delivery strategy).
- **New design decision — subject addressing:** the point-to-point link becomes subject-based pub/sub (fan-out, queue groups, request-reply, location transparency). Decide how "send to remote actor X" maps to subjects (per-endpoint / per-message-type / routing scheme).

## Serialization routes
- **Native `Flatten`/`Unflatten To String`** — the flattened form carries the concrete class, so it reconstructs directly; near-zero code but **LabVIEW-only and version-brittle** (embeds a class version; differing class data between ends breaks it). Good when the same codebase is deployed both ends. *This is the route the Network Endpoint Actor uses.*
- **Explicit `Serialize`/`Deserialize` (JSON or versioned binary) + a type registry/factory** — version-tolerant and interoperable, more work; use the type header + an allowlist registry to construct the class.

## Encryption
Its payload encryption is **end-to-end** — the NATS server and JetStream's on-disk store only ever see ciphertext. Complementary to NATS **TLS** (which only protects the hop to the server) and gives **encryption at rest** when messages flow through JetStream. Keep the type header unencrypted for routing, or fold the type into the encrypted blob if it must be secret.

## Caveats
- **Build inclusion:** classes constructed dynamically by name must be forced into the built EXE (Always Include) or they won't be loadable — reuse the endpoint actor's approach.
- **Versioning:** prefer explicit serialize/deserialize if sender/receiver deploy independently; native flatten only for same-build systems.
- **Security:** "construct the class named in a header and run its `Do`" is RCE-shaped on an untrusted bus — use an **allowlist/registry** of known message types, not arbitrary class-by-name. Fine on a trusted internal bus.
- **Delivery semantics:** Core NATS = at-most-once; JetStream = at-least-once (make `Do` idempotent / dedup via `Nats-Msg-Id`). For a command needing a result, layer on request-reply.
- **Header naming:** don't prefix the custom type header with `Nats-` (the server reserves/interprets several `Nats-*`); use your own, e.g. `LV-Msg-Type`.
- **Interop:** these subjects become LabVIEW-only unless you standardize the serialization + type convention.
- **Not for high rate:** per-message object allocation + dynamic construction + AF enqueue is heavy (and allocation-jittery on RT). Commands/events only.

## Depends on
- [[01 Request-Reply Helper]] (command/reply), the client pub/sub + the `Actor Message` delivery strategy ([[Library and Project Structure]]); optionally [[04 JetStream Publishing]] / [[05 JetStream Consuming]] if carried over JetStream.
- The AF Network Endpoint Actor (external — source of the serialize/crypto code).

## Notes / decisions log
-

## Sources
- LabVIEW Actor Framework **Network Endpoint Actor** (serialize/deserialize + encryption reference).
- [[Core NATS Protocol]] (HPUB/HMSG header block), [[JetStream Wire API]].

#idea
