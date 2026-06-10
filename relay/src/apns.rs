//! APNs waker. Token-based (.p8 / ES256 JWT) HTTP/2 push so a relayed message
//! can wake the recipient's app even when it's been killed. The alert body is
//! deliberately generic ("New message") — the server never knows who's who
//! beyond a public key, and the app re-labels with the real nickname on open.

use std::sync::Mutex;
use std::time::{Duration, Instant};

use jsonwebtoken::{encode, Algorithm, EncodingKey, Header};
use serde::Serialize;

pub struct Apns {
    client: reqwest::Client,
    encoding_key: EncodingKey,
    key_id: String,
    team_id: String,
    topic: String,
    host: String,
    cached_jwt: Mutex<Option<(String, Instant)>>,
}

#[derive(Serialize)]
struct Claims {
    iss: String,
    iat: i64,
}

impl Apns {
    /// Builds from env. Returns Ok(None) when APNs isn't configured, so the
    /// relay still runs (forwarding only, no wake-ups) during local dev.
    pub fn from_env() -> anyhow::Result<Option<Self>> {
        let (Ok(key_path), Ok(key_id), Ok(team_id), Ok(topic)) = (
            std::env::var("APNS_KEY_PATH"),
            std::env::var("APNS_KEY_ID"),
            std::env::var("APNS_TEAM_ID"),
            std::env::var("APNS_TOPIC"),
        ) else {
            return Ok(None);
        };
        let production = std::env::var("APNS_PRODUCTION")
            .map(|v| v != "false" && v != "0")
            .unwrap_or(true);
        let host = if production {
            "https://api.push.apple.com".to_string()
        } else {
            "https://api.sandbox.push.apple.com".to_string()
        };
        let pem = std::fs::read(&key_path)?;
        let encoding_key = EncodingKey::from_ec_pem(&pem)?;
        Ok(Some(Self {
            client: reqwest::Client::builder()
                .timeout(Duration::from_secs(10))
                .build()?,
            encoding_key,
            key_id,
            team_id,
            topic,
            host,
            cached_jwt: Mutex::new(None),
        }))
    }

    /// APNs caps regenerating the bearer token; reuse it for ~50 minutes.
    fn jwt(&self, now_secs: i64) -> anyhow::Result<String> {
        let mut cache = self.cached_jwt.lock().unwrap();
        if let Some((token, minted)) = cache.as_ref() {
            if minted.elapsed() < Duration::from_secs(50 * 60) {
                return Ok(token.clone());
            }
        }
        let mut header = Header::new(Algorithm::ES256);
        header.kid = Some(self.key_id.clone());
        let claims = Claims { iss: self.team_id.clone(), iat: now_secs };
        let token = encode(&header, &claims, &self.encoding_key)?;
        *cache = Some((token.clone(), Instant::now()));
        Ok(token)
    }

    /// Best-effort visible push that also wakes the app to fetch. Logs and
    /// swallows failures — a missed wake just means delivery waits for the next
    /// app open or a Bluetooth meet-up.
    pub async fn wake(
        &self,
        device_token: &str,
        body: &str,
        sender_hex: &str,
        now_secs: i64,
    ) {
        let jwt = match self.jwt(now_secs) {
            Ok(j) => j,
            Err(e) => {
                tracing::warn!("apns jwt mint failed: {e}");
                return;
            }
        };
        let url = format!("{}/3/device/{}", self.host, device_token);
        // `mutable-content` lets a Notification Service Extension swap the title
        // for the real sender name (looked up client-side from `sender`); until
        // one exists it just shows "stonechat — <body>". `sender` is a public
        // key, never content.
        let payload = serde_json::json!({
            "aps": {
                "alert": { "title": "stonechat", "body": body },
                "sound": "default",
                "mutable-content": 1,
                "content-available": 1
            },
            "sender": sender_hex
        });
        let res = self
            .client
            .post(&url)
            .header("authorization", format!("bearer {jwt}"))
            .header("apns-topic", &self.topic)
            .header("apns-push-type", "alert")
            .header("apns-priority", "10")
            .json(&payload)
            .send()
            .await;
        match res {
            Ok(r) if r.status().is_success() => {}
            Ok(r) => {
                let status = r.status();
                let text = r.text().await.unwrap_or_default();
                tracing::warn!("apns push rejected ({status}): {text}");
            }
            Err(e) => tracing::warn!("apns push error: {e}"),
        }
    }
}
