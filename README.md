# stonechat

Offline, peer-to-peer, one-to-one chat for iOS. No servers, no internet — just
two phones talking directly over Bluetooth Low Energy. Flutter UI on top of a
custom native Swift Core Bluetooth transport.

## Architecture

```
┌───────────────────────────── Flutter (Dart) ──────────────────────────────┐
│  UI  ──  ChatService  ──  EnvelopeCrypto (sodium)  ──  AppDatabase (drift)  │
│                  │  Pigeon HostApi (commands) ▲ EventChannel (events)       │
└──────────────────┼─────────────────────────────┼──────────────────────────┘
                   ▼                              │
┌───────────────────────── Native (Swift) ────────────────────────────────────┐
│  BleTransport  ── dual-role CBCentralManager + CBPeripheralManager           │
│       │  fragmentation (START/CONT/END)   │  State Restoration               │
│       └─ fires UNUserNotificationCenter on background inbound (Dart asleep)   │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Why these choices** (see the architecture brief for the full reasoning):

- **Raw Core Bluetooth, dual-role**, not MultipeerConnectivity — MC is torn down
  on backgrounding and has no State Restoration. CB is the only Apple P2P
  transport with documented background modes + relaunch-on-BLE-event.
- **Swift owns the transport and fires notifications.** On a background BLE
  wake the Flutter engine is not running, so inbound handling, persistence and
  local notifications all happen natively; Dart reconciles on next launch.
- **Pigeon** for the type-safe Dart↔Swift bridge (`@HostApi` for commands,
  `@EventChannelApi` for streaming inbound events).
- **`sodium`** (real libsodium via Dart build hooks) for `crypto_box`
  (Curve25519 + XSalsa20-Poly1305) confidentiality + Ed25519 signatures.
- **`drift`** (SQLite) for messages/peers with dedup-by-id and outbox state.

> Background delivery is **best-effort**: two backgrounded, screen-off iPhones
> effectively cannot discover each other. The reliable path is at least one
> side foreground/screen-on. Static-key boxing gives **no forward secrecy** —
> the accepted "casual privacy" bar.

## Layout

| Path | Role |
|---|---|
| `pigeons/transport.dart` | Bridge contract (regenerate: `dart run pigeon --input pigeons/transport.dart`) |
| `lib/src/transport/` | Generated Dart API + transport glue |
| `lib/src/crypto/` | `Envelope` wire format + `EnvelopeCrypto` (sign-then-box) |
| `lib/src/data/` | drift database (regenerate: `dart run build_runner build`) |
| `lib/src/chat/` | `ChatService` — discovery → hello → message → ACK → dedup |
| `ios/Runner/Transport/` | `BleTransport`, fragmenter, event stream handler, generated Swift |

## Roadmap

- **Stage 1 (this scaffold):** foreground happy path — dual-role transport,
  Pigeon bridge, signed+boxed envelopes, drift persistence. _Skeleton._
- **Stage 2:** State Restoration + Swift-side notifications + shared-container DB.
- **Stage 3:** characterise the background delivery matrix on real hardware.

## Building

Requires Flutter 3.44+, Xcode 26+. Plugins are wired via **Swift Package
Manager** (no CocoaPods).

```sh
flutter pub get
dart run pigeon --input pigeons/transport.dart   # regenerate bridge
dart run build_runner build                       # regenerate drift
flutter test                                      # envelope codec tests
flutter run -d <ios-device>
```

> **Note:** building for a connected device or simulator requires the matching
> iOS platform support component to be installed in Xcode
> (`Xcode ▸ Settings ▸ Components`, or `xcodebuild -downloadPlatform iOS`). A
> connected device whose platform is missing will block destination resolution
> for the whole scheme.
