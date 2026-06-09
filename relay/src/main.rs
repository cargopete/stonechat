//! stonechat relay — a blind store-and-forward + APNs waker.
//!
//! It forwards already-sealed (end-to-end encrypted) envelopes between peers and
//! pushes the recipient awake. It can read routing metadata (which public key
//! talks to which, and when) but never message content. See README for the
//! privacy posture.

mod apns;
mod envelope;
mod store;

use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use axum::{
    body::Bytes,
    extract::State,
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use base64::Engine;
use ed25519_dalek::{Signature, VerifyingKey};
use serde::{Deserialize, Serialize};

use apns::Apns;
use store::Store;

struct AppState {
    store: Store,
    apns: Option<Apns>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info".into()),
        )
        .init();

    let db_path =
        std::env::var("DATABASE_PATH").unwrap_or_else(|_| "stonechat-relay.sqlite".into());
    let bind = std::env::var("BIND_ADDR").unwrap_or_else(|_| "0.0.0.0:8080".into());

    let store = Store::open(&db_path)?;
    let apns = Apns::from_env()?;
    if apns.is_none() {
        tracing::warn!("APNs not configured — running as forward-only (no wake-ups)");
    }
    let state = Arc::new(AppState { store, apns });

    // Periodic queue cleanup: drop undelivered envelopes older than 7 days.
    {
        let state = state.clone();
        tokio::spawn(async move {
            loop {
                tokio::time::sleep(std::time::Duration::from_secs(3600)).await;
                let cutoff = now_ms() - 7 * 24 * 3600 * 1000;
                if let Ok(n) = state.store.cleanup(cutoff) {
                    if n > 0 {
                        tracing::info!("cleaned {n} expired queued envelopes");
                    }
                }
            }
        });
    }

    let app = Router::new()
        .route("/health", get(|| async { "ok" }))
        .route("/register", post(register))
        .route("/send", post(send))
        .route("/inbox", post(inbox))
        .route("/ack", post(ack))
        .with_state(state);

    let listener = tokio::net::TcpListener::bind(&bind).await?;
    tracing::info!("stonechat relay listening on {bind}");
    axum::serve(listener, app).await?;
    Ok(())
}

fn now_ms() -> i64 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis() as i64
}

/// Proves the caller holds the Ed25519 private key for `identity` by verifying a
/// signature over `stonechat-auth|<ts>`, with `ts` (epoch ms) within ±5 min.
fn verify_auth(identity_hex: &str, ts: i64, sig_hex: &str) -> bool {
    if (now_ms() - ts).abs() > 5 * 60 * 1000 {
        return false;
    }
    let Ok(id) = hex::decode(identity_hex) else { return false };
    let Ok(id32): Result<[u8; 32], _> = id.try_into() else { return false };
    let Ok(vk) = VerifyingKey::from_bytes(&id32) else { return false };
    let Ok(sig) = hex::decode(sig_hex) else { return false };
    let Ok(sig64): Result<[u8; 64], _> = sig.try_into() else { return false };
    let signature = Signature::from_bytes(&sig64);
    vk.verify_strict(format!("stonechat-auth|{ts}").as_bytes(), &signature)
        .is_ok()
}

#[derive(Deserialize)]
struct RegisterReq {
    identity: String,
    push_token: String,
    ts: i64,
    sig: String,
}

async fn register(
    State(state): State<Arc<AppState>>,
    Json(req): Json<RegisterReq>,
) -> impl IntoResponse {
    if !verify_auth(&req.identity, req.ts, &req.sig) {
        return (StatusCode::UNAUTHORIZED, "bad auth").into_response();
    }
    match state.store.upsert_registration(&req.identity, &req.push_token, now_ms()) {
        Ok(()) => StatusCode::NO_CONTENT.into_response(),
        Err(e) => {
            tracing::error!("register failed: {e}");
            StatusCode::INTERNAL_SERVER_ERROR.into_response()
        }
    }
}

/// Body is the raw sealed envelope bytes. We verify its signature, enqueue it
/// for the recipient encoded in the header, and wake them.
async fn send(State(state): State<Arc<AppState>>, body: Bytes) -> impl IntoResponse {
    let meta = match envelope::parse_and_verify(&body) {
        Ok(m) => m,
        Err(e) => return (StatusCode::BAD_REQUEST, e).into_response(),
    };
    if let Err(e) = state.store.enqueue(
        &meta.recipient_hex,
        &meta.message_id_hex,
        &body,
        now_ms(),
    ) {
        tracing::error!("enqueue failed: {e}");
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    }
    // Wake the recipient if we have a push token for them.
    if let Some(apns) = &state.apns {
        if let Ok(Some(token)) = state.store.push_token(&meta.recipient_hex) {
            apns.wake(&token, now_ms() / 1000).await;
        }
    }
    StatusCode::ACCEPTED.into_response()
}

#[derive(Deserialize)]
struct AuthOnly {
    identity: String,
    ts: i64,
    sig: String,
}

#[derive(Serialize)]
struct InboxResp {
    envelopes: Vec<String>, // base64 of each sealed envelope
}

async fn inbox(
    State(state): State<Arc<AppState>>,
    Json(req): Json<AuthOnly>,
) -> impl IntoResponse {
    if !verify_auth(&req.identity, req.ts, &req.sig) {
        return (StatusCode::UNAUTHORIZED, "bad auth").into_response();
    }
    match state.store.inbox(&req.identity) {
        Ok(items) => {
            let b64 = base64::engine::general_purpose::STANDARD;
            let envelopes = items.into_iter().map(|q| b64.encode(q.envelope)).collect();
            Json(InboxResp { envelopes }).into_response()
        }
        Err(e) => {
            tracing::error!("inbox failed: {e}");
            StatusCode::INTERNAL_SERVER_ERROR.into_response()
        }
    }
}

#[derive(Deserialize)]
struct AckReq {
    identity: String,
    ts: i64,
    sig: String,
    message_ids: Vec<String>,
}

async fn ack(
    State(state): State<Arc<AppState>>,
    Json(req): Json<AckReq>,
) -> impl IntoResponse {
    if !verify_auth(&req.identity, req.ts, &req.sig) {
        return (StatusCode::UNAUTHORIZED, "bad auth").into_response();
    }
    match state.store.ack(&req.identity, &req.message_ids) {
        Ok(()) => StatusCode::NO_CONTENT.into_response(),
        Err(e) => {
            tracing::error!("ack failed: {e}");
            StatusCode::INTERNAL_SERVER_ERROR.into_response()
        }
    }
}
