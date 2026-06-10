# stonechat

[![CI](https://github.com/cargopete/stonechat/actions/workflows/ci.yml/badge.svg)](https://github.com/cargopete/stonechat/actions/workflows/ci.yml)

Private, end-to-end-encrypted, one-to-one chat for iOS. **Bluetooth-first, web
when you're apart** — two phones talk directly over Bluetooth Low Energy when
they're near each other, and fall back to an optional self-hosted relay (with a
push wake-up) when they're not. No accounts, no third parties; the relay only
ever sees sealed ciphertext. Flutter UI on a custom native Swift Core Bluetooth
transport.

**Status:** v1.1.0 — hybrid delivery shipping on TestFlight.

## Features

- **Offline P2P over BLE** — discovery → handshake → signed+boxed message → ACK
  → dedup, with a store-and-forward outbox and persistent auto-reconnect.
- **Hybrid delivery** — Bluetooth-first, then an optional **relay ("web")**
  channel, else queue. A per-peer indicator shows 🔵 Bluetooth / 🌐 web / ⚪ offline.
- **APNs wake-up** — a relayed message pushes the recipient awake even if the app
  has been killed (the relay never learns message content).
- **Read receipts** — sent → delivered → **seen**.
- **Photo messages** — compressed and fragmented over BLE (or relayed).
- **Nicknames** — announce your own display name; set a private nickname per peer.
- **Offline-tolerant** — sending never errors; messages queue and deliver when a
  channel returns.

## Architecture

```
┌───────────────────────────── Flutter (Dart) ──────────────────────────────┐
│  UI ── ChatService ── EnvelopeCrypto (sodium) ── AppDatabase (drift)       │
│             │  Pigeon HostApi ▲ EventChannel        │  RelayClient (HTTP)  │
└─────────────┼───────────────────┼──────────────────┼──────────────────────┘
              ▼                    │                  ▼
┌──────────── Native (Swift) ──────────────┐   ┌──── Relay (Rust/axum) ─────┐
│  BleTransport — dual-role CBCentral +     │   │  blind store-and-forward   │
│  CBPeripheral, fragmentation, State       │   │  + APNs waker; verifies    │
│  Restoration, APNs token, local notifs    │   │  Ed25519 sigs, never reads │
└───────────────────────────────────────────┘   │  content. /send /inbox /ack│
                                                 └────────────────────────────┘
```

**Why these choices:**

- **Raw Core Bluetooth, dual-role**, not MultipeerConnectivity — CB is the only
  Apple P2P transport with documented background modes + relaunch-on-BLE-event.
- **Swift owns the transport**; on a background BLE wake the Flutter engine isn't
  running, so inbound persistence + local notifications happen natively, and Dart
  reconciles on next launch.
- **Every message is sealed before it leaves the device** (`crypto_box`:
  Curve25519 + XSalsa20-Poly1305, with Ed25519 signatures), so the relay is a
  blind forwarder — it routes by public key and can't read a word.
- **Pigeon** for the type-safe Dart↔Swift bridge; **drift** (SQLite) for
  messages/peers with dedup-by-id + outbox state; **dedup-by-message-id** means
  Bluetooth and relay can both carry a message harmlessly.

> Static-key boxing gives **no forward secrecy** — the accepted "casual privacy"
> bar. Two backgrounded iOS apps can't reliably find each other over BLE for long
> (an OS limit) — the relay + push is what covers the away/cold case.

## The relay

A small **Rust/axum** service (`relay/`) — blind store-and-forward + APNs waker.
It sees routing metadata (which public key → which, timestamps, push tokens) but
never message content. Self-hostable behind any reverse proxy with TLS; the app's
relay URL is overridable via the `relayUrl` setting. See [`relay/README.md`](relay/README.md)
for the API and a one-box deploy (systemd + Caddy auto-TLS).

## Layout

| Path | Role |
|---|---|
| `pigeons/transport.dart` | Bridge contract (`dart run pigeon --input pigeons/transport.dart`) |
| `lib/src/crypto/` | `Envelope` wire format, `EnvelopeCrypto` (sign-then-box), `IdentityStore` (Keychain) |
| `lib/src/data/` | drift database (`dart run build_runner build`) |
| `lib/src/chat/` | `ChatService` — hybrid routing, outbox, receipts, nicknames |
| `lib/src/relay/` | `RelayClient` — HTTP client for the web channel |
| `lib/src/ui/` | Home (peer list) + conversation (messages, photos, channel indicator) |
| `ios/Runner/Transport/` | `BleTransport`, fragmenter, `EnvelopeInbox`/`PushTokenStore` (App Group) |
| `relay/` | The Rust relay server |

## Building

Requires Flutter 3.44+, Xcode 26+. Plugins via **Swift Package Manager**.

```sh
flutter pub get
dart run pigeon --input pigeons/transport.dart   # regenerate bridge
dart run build_runner build                       # regenerate drift
flutter test
flutter run -d <ios-device>                       # two physical devices to see BLE
```

> **macOS gotcha:** if Xcode/`flutter build ipa` fails with `exportArchive Copy
> failed` / `rsync --extended-attributes: unknown option`, a Homebrew rsync is
> shadowing Apple's. `brew unlink rsync` and rebuild.

> **App Group `group.com.stonechat`** (shared inbox + push token) and **Push
> Notifications** (for relay wake-ups) must be enabled on the App ID.
