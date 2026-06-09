# stonechat-relay

A **blind store-and-forward relay + APNs waker** for stonechat. It lets the app
work online-first (internet) and fall back to Bluetooth, without giving up
end-to-end encryption.

## What it can and can't see

Every envelope is already **end-to-end sealed** by the app (Curve25519 box +
Ed25519 signature) before it reaches the relay. So the relay:

- **CAN** see routing metadata: which identity public key sends to which, message
  ids, timestamps, and APNs push tokens.
- **CANNOT** see message content — the `ciphertext` is never decryptable here.

It verifies each envelope's Ed25519 signature, so it won't forward forged or junk
traffic, and authenticates `register`/`inbox`/`ack` by requiring a signature over
`stonechat-auth|<ts>` from the identity's key.

The queue is pruned after **7 days**; delivered envelopes are deleted on `ack`.

## API

- `POST /send` — body is the raw sealed envelope bytes. Verifies + enqueues for
  the recipient (from the header) and sends an APNs wake. `202` on success.
- `POST /register` — `{identity, push_token, ts, sig}`. Stores the push token.
- `POST /inbox` — `{identity, ts, sig}` → `{envelopes: [base64,…]}`.
- `POST /ack` — `{identity, ts, sig, message_ids: [hex,…]}`. Drops delivered rows.
- `GET /health` — `ok`.

`sig` is hex Ed25519 over `stonechat-auth|<ts>` (epoch ms, ±5 min).

## Configuration (env)

| var | default | meaning |
|-----|---------|---------|
| `BIND_ADDR` | `0.0.0.0:8080` | listen address |
| `DATABASE_PATH` | `stonechat-relay.sqlite` | SQLite file |
| `APNS_KEY_PATH` | — | path to the `.p8` auth key |
| `APNS_KEY_ID` | — | the key's 10-char ID |
| `APNS_TEAM_ID` | — | Apple team id (`TRG36N45GH`) |
| `APNS_TOPIC` | — | bundle id (`com.stonechat.stonechat`) |
| `APNS_PRODUCTION` | `true` | `true` for TestFlight/App Store, `false` for dev |

If the `APNS_*` vars are absent the relay still runs, forwarding without wake-ups.

## Deploy (Hetzner VPS, bare-metal + nginx)

```sh
# on the box
cargo build --release                      # or scp the prebuilt binary
sudo install -m755 target/release/stonechat-relay /usr/local/bin/
sudo mkdir -p /var/lib/stonechat-relay
sudo cp AuthKey_XXXXXXXXXX.p8 /var/lib/stonechat-relay/apns.p8

sudo cp stonechat-relay.service /etc/systemd/system/
# edit the Environment= lines with your APNS_KEY_ID etc.
sudo systemctl daemon-reload && sudo systemctl enable --now stonechat-relay
```

Then front it with nginx + a Let's Encrypt cert on your subdomain (iOS requires
HTTPS):

```nginx
server {
    server_name relay.example.com;
    location / { proxy_pass http://127.0.0.1:8080; }
}
```

```sh
sudo certbot --nginx -d relay.example.com
```

The app then points at `https://relay.example.com`.
