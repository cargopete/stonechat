//! Minimal, content-blind view of a stonechat envelope.
//!
//! The relay only ever parses the *cleartext header* (versions, ids, lengths)
//! and verifies the sender's Ed25519 signature so it won't forward forged or
//! garbage traffic. It never touches the boxed `ciphertext` — message content
//! stays end-to-end encrypted and unreadable to the server.
//!
//! Wire layout (see the app's `envelope.dart`):
//!   version(1) type(1) message_id(16) sender_id(32) recipient_id(32)
//!   timestamp(8) nonce(24) ciphertext(N) signature(64)

use ed25519_dalek::{Signature, VerifyingKey};

const HEADER_LEN: usize = 1 + 1 + 16 + 32 + 32 + 8 + 24; // 114
const SIG_LEN: usize = 64;

pub struct EnvelopeMeta {
    pub message_id_hex: String,
    pub sender_hex: String,
    pub recipient_hex: String,
    /// Envelope opcode (0 = message, 8 = image, …) — used only to pick the push
    /// body text; the relay never reads the encrypted content.
    pub msg_type: u8,
}

/// Validates an envelope's structure and signature, returning the routing
/// metadata. Errors (never panics) on anything malformed or forged.
pub fn parse_and_verify(bytes: &[u8]) -> Result<EnvelopeMeta, &'static str> {
    if bytes.len() < HEADER_LEN + SIG_LEN {
        return Err("envelope too short");
    }
    let message_id = &bytes[2..18];
    let sender_id = &bytes[18..50];
    let recipient_id = &bytes[50..82];

    let signed_region = &bytes[..bytes.len() - SIG_LEN];
    let signature_bytes = &bytes[bytes.len() - SIG_LEN..];

    let vk_bytes: [u8; 32] = sender_id.try_into().map_err(|_| "bad sender id")?;
    let verifying_key =
        VerifyingKey::from_bytes(&vk_bytes).map_err(|_| "bad sender key")?;
    let sig_bytes: [u8; 64] =
        signature_bytes.try_into().map_err(|_| "bad signature")?;
    let signature = Signature::from_bytes(&sig_bytes);

    verifying_key
        .verify_strict(signed_region, &signature)
        .map_err(|_| "signature verification failed")?;

    Ok(EnvelopeMeta {
        message_id_hex: hex::encode(message_id),
        sender_hex: hex::encode(sender_id),
        recipient_hex: hex::encode(recipient_id),
        msg_type: bytes[1],
    })
}
