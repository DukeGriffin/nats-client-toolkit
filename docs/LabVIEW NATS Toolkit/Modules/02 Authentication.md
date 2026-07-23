---
type: module
status: planned
---

# 02 — Authentication

Cross-cutting: extends the `CONNECT` message nats.lv already sends. Decoupled from the messaging stack — see [[Layering Overview]].

## Scope
- **Username/password, token**: trivial — just fields in the `CONNECT` JSON nats.lv already sends.
- **TLS mutual auth**: should already work via the exposed TCP refnum + LabVIEW 2020 native TLS VIs. Needs validation, not new development.
- **NKey auth**: server sends a `nonce` in `INFO`; client must sign it with an Ed25519 private key and return the signature. **Blocking dependency: no native Ed25519 in LabVIEW.** See [[Risks and Open Questions]].
- **JWT (decentralized) auth**: layers on top of NKey — client presents a JWT plus signs the nonce with the corresponding NKey. JWT parsing itself (base64url + JSON) needs no crypto, but signing does.
- **Credentials file (`.creds`)**: simple format embedding JWT + seed — easy to parse once NKey signing exists.

## Depends on
- [[Foundation - nats.lv]] (CONNECT message, TCP refnum for TLS)
- An Ed25519 signing capability — external to LabVIEW (see below)
- **CONNECT ordering (mechanisms 4–5)** · for NKey/JWT the `CONNECT` cannot be sent until the server's `INFO` nonce has been received and signed · the sequence is *connect → receive `INFO` → sign nonce → THEN send `CONNECT`* · this differs from mechanisms 1–3, where `CONNECT` can be sent immediately · **confirm [[Foundation - nats.lv]] surfaces the `INFO` nonce to the client and allows deferring/populating the `CONNECT` fields** rather than sending a fixed `CONNECT` on connect

## Terms

New to NATS auth? One line each · see [[Glossary]] for the full list.

- **NKey** · a NATS-specific Ed25519 public-key identity, encoded in base32
- **seed** · the private key the NKey is derived from
- **JWT** · JSON Web Token — a signed claims document
- **Ed25519** · an elliptic-curve digital-signature algorithm
- **nonce** · a one-time random challenge the server sends

## Docs
- `running-a-nats-service/configuration/securing_nats/auth_intro/*`
- `using-nats/developer/connecting/{token,nkey,creds,tls}`

---

## The auth ladder (simplest → hardest)

Every mechanism below is just extra fields on the `CONNECT` JSON that [[Foundation - nats.lv|nats.lv]] already sends (see the `CONNECT` message in [[Core NATS Protocol]]). Field names are taken from the `connectInfo` struct in the nats.go client (`nats.go`, source: github.com/nats-io/nats.go).

| # | Mechanism | CONNECT JSON field(s) | Crypto needed? | Notes |
|---|-----------|-----------------------|----------------|-------|
| 1 | **TLS** (server / mutual) | *(none — transport layer)* | No | Handshake is below the protocol. Server presents cert; mutual TLS adds a client cert+key. Handled by LabVIEW 2020 native TLS on the exposed TCP refnum. See `connecting/tls`. |
| 2 | **Token** | `auth_token` | No | Single shared secret. Can also ride in the URL as `nats://token@host:port`. "Only as safe as it is secret." Source: `connecting/token`. |
| 3 | **User / password** | `user`, `pass` | No | Plaintext or bcrypt-hashed on the server side; client always sends plaintext in `pass`. Can ride in URL as `nats://user:pass@host:port`. Source: `connecting/userpass`. |
| 4 | **NKey** | `nkey` (public `U…`) + `sig` | **Yes — Ed25519** | Challenge-response: sign the server nonce. `nkey` is the base32 public key; `sig` is the base64url signature. Source: `connecting/nkey`, `auth_intro/nkey_auth`. |
| 5 | **JWT / creds** (decentralized) | `jwt` (user JWT) + `sig` | **Yes — Ed25519** | Layers on NKey: present the user JWT **and** sign the nonce with the user seed. `nkey` is omitted (the public key is inside the JWT). Source: `connecting/creds`, `auth_intro/jwt`. |

Mechanisms 1–3 need **no new crypto** and are effectively "populate a field." Mechanisms 4–5 are the genuine wire-level gap — they require Ed25519 signing of the server nonce, which LabVIEW has no native primitive for. See [[Risks and Open Questions]].

> **Recommended starting point:** Start with TLS + token or user/password (rows 1–3, no crypto); only implement NKey/JWT (rows 4–5) if the deployment requires decentralized auth.

## Nonce → signature sequence (NKey / JWT)

This is the connect-time challenge-response. Verified against nats.go (`nats.go`) and `auth_intro/nkey_auth`.

1. **Server → client `INFO`**: on TCP connect the server sends `INFO {...,"nonce":"<random>",...}`. The `nonce` is a fresh random challenge per connection (immune to replay). It arrives as an ASCII/base64-ish string in the INFO JSON.
2. **Client obtains the raw seed**: from an NKey seed string (`S…`) or extracted from a `.creds` file. Decoding the seed yields the 32-byte Ed25519 seed (see NKey format below).
3. **Sign the nonce bytes as-is**: the client signs the **raw bytes of the nonce string** (the nonce is *not* base64-decoded first — the UTF-8/ASCII bytes of the nonce as received are the message). In nats.go: `sigraw, _ := SignatureCB([]byte(nc.info.Nonce))`. Ed25519 produces a 64-byte signature.
4. **Encode the signature**: `sig = base64.RawURLEncoding.EncodeToString(sigraw)` — **base64 URL-safe alphabet, NO padding** (`-`/`_`, no trailing `=`). Source (exact, load-bearing): nats.go `connectProto`, `base64.RawURLEncoding.EncodeToString(sigraw)`.
5. **Client → server `CONNECT`**: send `sig` plus either `nkey` (NKey auth) or `jwt` (JWT/creds auth). Server verifies the signature against the public key (given directly for NKey, or embedded in the JWT for creds).

> **Encoding to get right:** nonce is signed **unmodified** (raw received bytes); the signature is **base64url without padding** (`RawURLEncoding`), not standard base64 and not hex. Getting this wrong is the most likely silent failure in a LabVIEW port.

## NKey format

NKeys are an Ed25519-based public-key system encoded like Stellar keys: **base32 + version/prefix byte + CRC16**. Sources: github.com/nats-io/nkeys `strkey.go` and `crc16.go`; `auth_intro/nkey_auth`.

**Encoding (public / private keys — single prefix byte):**
```
[ 1 prefix byte ][ 32-byte Ed25519 key payload ][ 2-byte CRC16 ]
        └────────────── base32 (std alphabet, NO padding) ──────────────┘
```
- CRC16 is **little-endian**, computed over `prefix || payload`. Algorithm: **CRC16 CCITT / XMODEM** via a 256-entry lookup table (`crc16.go`).
- Base32 is `base32.StdEncoding.WithPadding(base32.NoPadding)`.

**Prefix bytes → leading character after base32:**
| Prefix | Encodes to | Meaning |
|--------|-----------|---------|
| `PrefixByteSeed` | `S…` | Seed (the private secret) |
| `PrefixByteUser` | `U…` | User public key |
| `PrefixByteAccount` | `A…` | Account public key |
| `PrefixByteOperator` | `O…` | Operator public key |
| `PrefixByteServer` | `N…` | Server |
| `PrefixByteCluster` | `C…` | Cluster |
| `PrefixBytePrivate` | `P…` | Raw private key |

**Seeds use TWO prefix bytes** so the string shows both "this is a seed" and the key type — hence a user seed reads `SU…`, an account seed `SA…`, etc. The two bytes are packed from the seed prefix combined with the public-key type (from `EncodeSeed` in `strkey.go`):
```
b1 = PrefixByteSeed | (publicPrefix >> 5)
b2 = (publicPrefix & 31) << 3
```
Layout: `[ b1 ][ b2 ][ 32-byte raw seed ][ 2-byte CRC16 ]`, then base32 (no padding).

**Ed25519 keypair derivation from the seed:** the 32 bytes recovered after decoding the seed string ARE the RFC 8032 Ed25519 seed. Feed them to Ed25519 key generation (`ed25519.NewKeyFromSeed(rawSeed)` in Go) → the 64-byte expanded private key (`seed || publicKey`) and the 32-byte public key. So one `S…` seed deterministically yields both the `U…` public key and the signing key. This is why only the seed must be kept secret.

## Trust hierarchy: operator → account → user

Mechanism 5 is called **decentralized** because the server never holds a shared secret for each user. Instead it trusts a **signature chain** built from the NKey prefix types above:

- An **operator** (`O…`) signs **account** JWTs.
- An **account** (`A…`) signs **user** JWTs.
- A **user** (`U…`) proves identity at connect time by signing the nonce with its user seed.

So at connect the client presents a **JWT** (not a bare nkey): the user JWT carries the `U…` public key and is signed by an account the operator vouches for. The server validates the chain (operator → account → user) offline against the operator public key it was configured with — no per-user credentials live on the server, and users/accounts can be added or revoked without touching server config. This is the difference from plain NKey auth (mechanism 4), where the server is directly configured with each authorized `U…` public key.

## `.creds` file format

A `.creds` file bundles the user JWT and the user seed in two PEM-like armored blocks (source: `connecting/creds`):
```
-----BEGIN NATS USER JWT-----
eyJ0eXAiOiJKV1Qi...            <- base64url-encoded JWT (header.payload.sig)
------END NATS USER JWT------

************************* IMPORTANT *************************
NKEY Seed printed below can be used to sign and prove identity.
NKEYs are sensitive and should be treated as secrets.

-----BEGIN USER NKEY SEED-----
SUAG...                       <- the SU… user seed (base32 NKey seed)
------END USER NKEY SEED------

*************************************************************
```
**Client extraction (all no-crypto, plain text parsing):**
- Grab the block between `-----BEGIN NATS USER JWT-----` and its `END` marker → the `jwt` value sent in `CONNECT`.
- Grab the block between `-----BEGIN USER NKEY SEED-----` and its `END` marker → the `SU…` seed, decode it (base32 → strip prefix/CRC) to the raw 32-byte Ed25519 seed used to sign the nonce.
- The JWT itself is `base64url(header).base64url(payload).base64url(sig)` — parse-only, no crypto to *read* it (verification is the server's job). This matches ADR-14 "JWT library-free JWT user generation," which documents the NATS JWT structure.

### Worked flow — connect with a `.creds` file

End-to-end, matching the sequence and encodings verified above. Also in [[Cookbook]].

```text
Goal: authenticate a NATS connection using a user.creds file (mechanism 5, JWT/creds).

1. Parse the .creds file (plain text — no crypto):
     jwt   = text between "-----BEGIN NATS USER JWT-----" and "------END NATS USER JWT------"
     seedS = text between "-----BEGIN USER NKEY SEED-----" and "------END USER NKEY SEED------"
     e.g. jwt   = "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJqdGki..."
          seedS = "SUAKEYGVNQKVW3AJ5A6QK7T4X6..."   (a SU… user seed)

2. Base32-decode seedS (std alphabet, NO padding) → raw bytes:
     [ b1 ][ b2 ][ 32-byte raw Ed25519 seed ][ 2-byte CRC16 ]
   - verify CRC16/XMODEM (little-endian) over everything except the last 2 bytes
   - strip the 2 prefix bytes (b1/b2 = seed + user type) and the 2 CRC bytes
   - rawSeed = the middle 32 bytes

3. Derive the Ed25519 signing key from rawSeed (ed25519.NewKeyFromSeed equivalent):
     rawSeed (32B) → 64-byte expanded private key (seed || publicKey)

4. Connect the TCP socket and WAIT for the server's INFO:
     INFO {..., "nonce":"YWxwaGFudW1lcmljcmFuZG9t", ...}

5. Sign the RAW nonce bytes (the ASCII bytes as received — do NOT base64-decode the nonce first):
     sigRaw = Ed25519-Sign(expandedPrivKey, bytesOf("YWxwaGFudW1lcmljcmFuZG9t"))   → 64 bytes

6. base64url-encode sigRaw with NO padding (RawURLEncoding: -/_ alphabet, no trailing '='):
     sig = "u5Kx... nopad..."

7. Send CONNECT with the jwt and the sig (omit "nkey" — the public key is inside the JWT):
     CONNECT {"jwt":"eyJ0eXAiOiJKV1Qi...","sig":"u5Kx...","verbose":false,"pedantic":false}\r\n

   Server validates: JWT signature chain (operator→account→user) + sig against the U… key in the JWT.
   On success the connection is authenticated; on failure the server sends -ERR and closes.
```

## Ed25519 implementation options for LabVIEW

This is the crux and expands the [[Risks and Open Questions]] item. All three paths must produce a raw 64-byte Ed25519 signature over the nonce bytes; the surrounding base32/base64url/JSON glue is pure LabVIEW and low-risk.

> **"Pure LabVIEW glue" still means writing code.** Beyond Ed25519, the encoders this module needs — **base32 (no padding)**, **CRC16/XMODEM**, and **base64url (no padding)** — are also *not* native LabVIEW primitives and must be implemented. They are low-risk (small, well-specified, easily unit-tested against known vectors) but non-zero effort, so "pure LabVIEW glue" shouldn't be read as "no work."

**(a) .NET interop (.NET nodes / assembly refnum)**
- Options: **BouncyCastle** (`Org.BouncyCastle.Crypto` — `Ed25519Signer`), **NSec** (libsodium-backed), or **`System.Security.Cryptography`** — but note Ed25519 landed in `System.Security.Cryptography` only in **.NET 8+**, so a legacy .NET Framework LabVIEW install can't use the built-in one.
- Pros: no native DLL to ship/marshal; managed, memory-safe; BouncyCastle is pure-managed and battle-tested; easy to also do base32/CRC16 there if convenient.
- Cons: LabVIEW .NET nodes target .NET Framework (CLR) by default — pairing with a modern .NET 8 assembly may need out-of-process or a shim; adds a .NET dependency; byte-array marshalling quirks.

**(b) Call Library Function Node → small native DLL (libsodium / monocypher)**
- **libsodium**: `crypto_sign_detached` / `crypto_sign_ed25519_seed_keypair`. **monocypher**: single-file, tiny, easy to compile.
- Pros: canonical, audited crypto; libsodium's `_seed_keypair` matches NKey's seed→keypair model exactly; deterministic ABI; works regardless of .NET version.
- Cons: ship and version a platform-specific binary (x64/ARM, RT targets?); CLFN calling-convention and pointer/byte-array setup; own the build/signing of the DLL.

**(c) Pure-LabVIEW Ed25519 (high risk)**
- Pros: zero external dependencies; single-tier deployment; works on any LabVIEW target including RT/FPGA hosts.
- Cons: implementing Ed25519 (Curve25519 field arithmetic, SHA-512, constant-time scalar mult) correctly in LabVIEW is a large, error-prone effort; timing side-channels; hard to validate. Only justified under a hard "no external deps" mandate.

**What a spike should test (any path):**
1. Sign a known test vector (RFC 8032) and byte-compare the 64-byte signature.
2. Round-trip a real `.creds` / `SU…` seed: decode base32, verify CRC16, derive the `U…` public key, and confirm it matches.
3. Sign an actual server `nonce`, `base64.RawURLEncoding`-encode it, and complete a live `CONNECT` against a nats-server configured for NKey and again for JWT/creds.
4. Confirm deployment story on the real target (desktop vs. RT) — especially for option (b)'s native binary.

## Reference sources
- NATS docs: `using-nats/developer/connecting/{token,userpass,nkey,creds,tls}`, `running-a-nats-service/configuration/securing_nats/auth_intro/{nkey_auth,jwt}`.
- NKey encoding: github.com/nats-io/nkeys — `strkey.go` (layout, base32 no-padding, seed prefix packing), `crc16.go` (CCITT/XMODEM).
- Signature/CONNECT encoding: github.com/nats-io/nats.go — `nats.go` (`base64.RawURLEncoding`, `connectInfo` fields `jwt`/`nkey`/`sig`/`user`/`pass`/`auth_token`).
- ADRs (github.com/nats-io/nats-architecture-and-design): **ADR-14** JWT library-free JWT user generation; **ADR-26** NATS Authorization Callouts; **ADR-38** OCSP Peer Verification; **ADR-39** Certificate Store.

## Open questions
- #question Ed25519 path: .NET interop (BouncyCastle or NSec, since `System.Security.Cryptography` didn't natively include Ed25519 pre-.NET 8/9), a Call Library Function Node to a small external DLL/shared lib, or a pure-LabVIEW implementation? Pure-LabVIEW crypto is high-effort and error-prone — probably avoid unless there's a hard "no external deps" requirement. See the "Ed25519 implementation options for LabVIEW" section above for pros/cons and the spike plan — decision left open.
- #question Does this project actually need NKey/JWT, or is TLS + token/user-pass sufficient for the target deployments? Worth confirming before sinking time into the Ed25519 spike.

## Notes / decisions log
-

## Sources
- [Connecting — Token auth](https://docs.nats.io/using-nats/developer/connecting/token)
- [Connecting — Username/password auth](https://docs.nats.io/using-nats/developer/connecting/userpass)
- [Connecting — NKey auth](https://docs.nats.io/using-nats/developer/connecting/nkey)
- [Connecting — Credentials (.creds)](https://docs.nats.io/using-nats/developer/connecting/creds)
- [Connecting — TLS](https://docs.nats.io/using-nats/developer/connecting/tls)
- [Authentication intro (securing NATS)](https://docs.nats.io/running-a-nats-service/configuration/securing_nats/auth_intro)
- [NKey authentication](https://docs.nats.io/running-a-nats-service/configuration/securing_nats/auth_intro/nkey_auth)
- [nats.go reference client](https://github.com/nats-io/nats.go)
- [nats-io/nkeys](https://github.com/nats-io/nkeys)
- [ADR-14 — JWT library-free user JWT generation](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-14.md)
- [ADR-26 — NATS Authorization Callouts](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-26.md)
- [ADR-38 — OCSP Peer Verification](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-38.md)
- [ADR-39 — Certificate Store](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-39.md)
