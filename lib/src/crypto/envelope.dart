import 'dart:typed_data';

/// Message envelope wire format (architecture brief §7).
///
/// The envelope is *signed* over every field except the signature itself, and
/// the inner payload is *boxed* (NaCl `crypto_box`: Curve25519 + XSalsa20-
/// Poly1305) before being placed in [ciphertext]. Signing and boxing live in
/// the crypto layer; this type is purely the byte layout + (de)serialisation.
///
///   version      : u8
///   type         : u8
///   message_id   : 16 bytes   (primary dedup key)
///   sender_id    : 32 bytes   (sender Ed25519 identity public key)
///   recipient_id : 32 bytes   (recipient public key)
///   timestamp    : u64 BE     (ms since epoch, sender clock)
///   nonce        : 24 bytes   (crypto_box nonce, per-message random)
///   ciphertext   : N bytes
///   signature    : 64 bytes   (Ed25519 over all preceding fields)
enum EnvelopeType {
  message(0),
  ack(1),
  fragmentStart(2),
  fragmentCont(3),
  fragmentEnd(4),
  hello(5),
  // Appended only — the wire value is persisted/exchanged, never reorder.
  // announceName: boxed UTF-8 display name the sender wants to be known by.
  // read: a read receipt; payload is the 16-byte message_id being marked seen.
  // image: a photo message; payload is the (compressed) image bytes.
  announceName(6),
  read(7),
  image(8),
  // reaction: payload is the 16-byte referenced message_id followed by the
  // reaction emoji (UTF-8); an empty emoji clears the reaction.
  reaction(9),
  // Call signaling — payload is a UTF-8 JSON blob. The whole envelope is
  // Ed25519-signed, so the DTLS fingerprint carried inside the SDP is
  // authenticated end-to-end (the relay can't MITM call setup).
  callOffer(10),
  callAnswer(11),
  callIce(12),
  callEnd(13);

  const EnvelopeType(this.wire);
  final int wire;

  static EnvelopeType fromWire(int value) =>
      values.firstWhere((t) => t.wire == value,
          orElse: () => throw FormatException('Unknown envelope type $value'));
}

class Envelope {
  Envelope({
    this.version = currentVersion,
    required this.type,
    required this.messageId,
    required this.senderId,
    required this.recipientId,
    required this.timestampMs,
    required this.nonce,
    required this.ciphertext,
    required this.signature,
  });

  static const int currentVersion = 1;
  static const int messageIdLen = 16;
  static const int idLen = 32;
  static const int nonceLen = 24;
  static const int signatureLen = 64;

  /// Byte offset at which [ciphertext] begins.
  static const int _headerLen =
      1 + 1 + messageIdLen + idLen + idLen + 8 + nonceLen;

  final int version;
  final EnvelopeType type;
  final Uint8List messageId;
  final Uint8List senderId;
  final Uint8List recipientId;
  final int timestampMs;
  final Uint8List nonce;
  final Uint8List ciphertext;
  final Uint8List signature;

  /// The region the Ed25519 signature is computed over: everything except the
  /// trailing signature. Used by both signer and verifier.
  Uint8List signedRegion() {
    final b = BytesBuilder(copy: false);
    final head = ByteData(_headerLen);
    var o = 0;
    head.setUint8(o, version);
    o += 1;
    head.setUint8(o, type.wire);
    o += 1;
    // message_id, sender_id, recipient_id are written below via the builder;
    // timestamp sits between recipient_id and nonce, so assemble in order.
    b.add(Uint8List.view(head.buffer, 0, 2));
    _addFixed(b, messageId, messageIdLen);
    _addFixed(b, senderId, idLen);
    _addFixed(b, recipientId, idLen);
    final ts = ByteData(8)..setUint64(0, timestampMs);
    b.add(ts.buffer.asUint8List());
    _addFixed(b, nonce, nonceLen);
    b.add(ciphertext);
    return b.toBytes();
  }

  /// Full wire bytes including the signature.
  Uint8List toBytes() {
    final b = BytesBuilder(copy: false)..add(signedRegion());
    _addFixed(b, signature, signatureLen);
    return b.toBytes();
  }

  factory Envelope.fromBytes(Uint8List bytes) {
    if (bytes.length < _headerLen + signatureLen) {
      throw const FormatException('Envelope too short');
    }
    final view = ByteData.sublistView(bytes);
    var o = 0;
    final version = view.getUint8(o);
    o += 1;
    final type = EnvelopeType.fromWire(view.getUint8(o));
    o += 1;
    final messageId = _slice(bytes, o, messageIdLen);
    o += messageIdLen;
    final senderId = _slice(bytes, o, idLen);
    o += idLen;
    final recipientId = _slice(bytes, o, idLen);
    o += idLen;
    final timestampMs = view.getUint64(o);
    o += 8;
    final nonce = _slice(bytes, o, nonceLen);
    o += nonceLen;
    final cipherLen = bytes.length - o - signatureLen;
    final ciphertext = _slice(bytes, o, cipherLen);
    o += cipherLen;
    final signature = _slice(bytes, o, signatureLen);
    return Envelope(
      version: version,
      type: type,
      messageId: messageId,
      senderId: senderId,
      recipientId: recipientId,
      timestampMs: timestampMs,
      nonce: nonce,
      ciphertext: ciphertext,
      signature: signature,
    );
  }

  static void _addFixed(BytesBuilder b, Uint8List data, int expectedLen) {
    if (data.length != expectedLen) {
      throw FormatException('Expected $expectedLen bytes, got ${data.length}');
    }
    b.add(data);
  }

  static Uint8List _slice(Uint8List src, int offset, int len) =>
      Uint8List.fromList(src.sublist(offset, offset + len));
}
