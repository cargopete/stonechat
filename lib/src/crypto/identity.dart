import 'dart:typed_data';

import 'package:sodium/sodium.dart';
import 'package:uuid/uuid.dart';

import 'envelope.dart';

/// A device's long-term cryptographic identity.
///
/// Two keypairs, per the brief's crypto split:
///  - [signKeyPair] — Ed25519, the stable identity used as `sender_id` and to
///    sign the whole envelope (authenticity).
///  - [boxKeyPair]  — X25519, used for `crypto_box` confidentiality.
///
/// Note: static-key boxing gives **no forward secrecy** — the accepted
/// "casual privacy" tradeoff over a double-ratchet.
class DeviceIdentity {
  DeviceIdentity({required this.signKeyPair, required this.boxKeyPair});

  final KeyPair signKeyPair;
  final KeyPair boxKeyPair;

  /// 32-byte Ed25519 public key — this device's `sender_id`.
  Uint8List get identityPublicKey => signKeyPair.publicKey;

  /// 32-byte X25519 public key — shared with peers in the `hello` handshake.
  Uint8List get boxPublicKey => boxKeyPair.publicKey;

  factory DeviceIdentity.generate(Sodium sodium) => DeviceIdentity(
        signKeyPair: sodium.crypto.sign.keyPair(),
        boxKeyPair: sodium.crypto.box.keyPair(),
      );
}

/// The public half of a peer's identity, learned on first contact (`hello`).
class PeerKeys {
  PeerKeys({required this.identityPublicKey, required this.boxPublicKey});

  /// Ed25519 — verifies the peer's envelope signatures.
  final Uint8List identityPublicKey;

  /// X25519 — the recipient/sender key for `crypto_box`.
  final Uint8List boxPublicKey;
}

class SignatureVerificationException implements Exception {
  const SignatureVerificationException();
  @override
  String toString() => 'Envelope signature verification failed';
}

/// Seals (sign-then-box) and opens envelopes for one [DeviceIdentity].
class EnvelopeCrypto {
  EnvelopeCrypto(this._sodium, this.self);

  final Sodium _sodium;
  final DeviceIdentity self;
  static const Uuid _uuid = Uuid();

  /// Boxes [plaintext] to [recipient], then signs the whole envelope.
  Envelope seal({
    required EnvelopeType type,
    required Uint8List plaintext,
    required PeerKeys recipient,
  }) {
    final nonce = _sodium.randombytes.buf(_sodium.crypto.box.nonceBytes);
    final ciphertext = _sodium.crypto.box.easy(
      message: plaintext,
      nonce: nonce,
      publicKey: recipient.boxPublicKey,
      secretKey: self.boxKeyPair.secretKey,
    );

    final unsigned = Envelope(
      type: type,
      messageId: _messageId(),
      senderId: self.identityPublicKey,
      recipientId: recipient.identityPublicKey,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      nonce: nonce,
      ciphertext: ciphertext,
      signature: Uint8List(Envelope.signatureLen),
    );

    final signature = _sodium.crypto.sign.detached(
      message: unsigned.signedRegion(),
      secretKey: self.signKeyPair.secretKey,
    );

    return Envelope(
      type: unsigned.type,
      messageId: unsigned.messageId,
      senderId: unsigned.senderId,
      recipientId: unsigned.recipientId,
      timestampMs: unsigned.timestampMs,
      nonce: unsigned.nonce,
      ciphertext: unsigned.ciphertext,
      signature: signature,
    );
  }

  /// Verifies the signature, then unboxes. Throws
  /// [SignatureVerificationException] on a bad signature.
  Uint8List open(Envelope envelope, {required PeerKeys sender}) {
    final verified = _sodium.crypto.sign.verifyDetached(
      message: envelope.signedRegion(),
      signature: envelope.signature,
      publicKey: sender.identityPublicKey,
    );
    if (!verified) throw const SignatureVerificationException();

    return _sodium.crypto.box.openEasy(
      cipherText: envelope.ciphertext,
      nonce: envelope.nonce,
      publicKey: sender.boxPublicKey,
      secretKey: self.boxKeyPair.secretKey,
    );
  }

  /// A `hello` identity bundle: an unboxed, signed envelope whose payload is
  /// this device's X25519 box public key. It can't be boxed (the recipient's
  /// box key is exactly what we're trying to exchange), so the payload is in
  /// the clear — confidentiality isn't needed, only authenticity (TOFU on the
  /// self-asserted [senderId]).
  Envelope sealHello() {
    final unsigned = Envelope(
      type: EnvelopeType.hello,
      messageId: _messageId(),
      senderId: self.identityPublicKey,
      recipientId: Uint8List(Envelope.idLen), // broadcast / unspecified
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      nonce: Uint8List(Envelope.nonceLen), // unused for hello
      ciphertext: self.boxPublicKey,
      signature: Uint8List(Envelope.signatureLen),
    );
    final signature = _sodium.crypto.sign.detached(
      message: unsigned.signedRegion(),
      secretKey: self.signKeyPair.secretKey,
    );
    return Envelope(
      type: unsigned.type,
      messageId: unsigned.messageId,
      senderId: unsigned.senderId,
      recipientId: unsigned.recipientId,
      timestampMs: unsigned.timestampMs,
      nonce: unsigned.nonce,
      ciphertext: unsigned.ciphertext,
      signature: signature,
    );
  }

  /// Verifies a `hello` envelope (TOFU) and returns the peer's public keys.
  PeerKeys openHello(Envelope envelope) {
    final verified = _sodium.crypto.sign.verifyDetached(
      message: envelope.signedRegion(),
      signature: envelope.signature,
      publicKey: envelope.senderId,
    );
    if (!verified) throw const SignatureVerificationException();
    return PeerKeys(
      identityPublicKey: envelope.senderId,
      boxPublicKey: envelope.ciphertext,
    );
  }

  /// 16 random bytes — the envelope `message_id` / primary dedup key.
  Uint8List _messageId() {
    final buffer = Uint8List(Envelope.messageIdLen);
    _uuid.v4buffer(buffer);
    return buffer;
  }
}
