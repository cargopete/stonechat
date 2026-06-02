import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stonechat/src/crypto/envelope.dart';

Uint8List _filled(int len, int value) =>
    Uint8List.fromList(List<int>.filled(len, value));

void main() {
  group('Envelope wire format', () {
    test('round-trips through bytes', () {
      final original = Envelope(
        type: EnvelopeType.message,
        messageId: _filled(Envelope.messageIdLen, 0x11),
        senderId: _filled(Envelope.idLen, 0x22),
        recipientId: _filled(Envelope.idLen, 0x33),
        timestampMs: 1717243200000,
        nonce: _filled(Envelope.nonceLen, 0x44),
        ciphertext: Uint8List.fromList([1, 2, 3, 4, 5]),
        signature: _filled(Envelope.signatureLen, 0x55),
      );

      final decoded = Envelope.fromBytes(original.toBytes());

      expect(decoded.version, Envelope.currentVersion);
      expect(decoded.type, EnvelopeType.message);
      expect(decoded.messageId, original.messageId);
      expect(decoded.senderId, original.senderId);
      expect(decoded.recipientId, original.recipientId);
      expect(decoded.timestampMs, original.timestampMs);
      expect(decoded.nonce, original.nonce);
      expect(decoded.ciphertext, original.ciphertext);
      expect(decoded.signature, original.signature);
    });

    test('signed region excludes the signature', () {
      final env = Envelope(
        type: EnvelopeType.hello,
        messageId: _filled(Envelope.messageIdLen, 0),
        senderId: _filled(Envelope.idLen, 1),
        recipientId: _filled(Envelope.idLen, 0),
        timestampMs: 0,
        nonce: _filled(Envelope.nonceLen, 0),
        ciphertext: Uint8List(0),
        signature: _filled(Envelope.signatureLen, 9),
      );
      expect(
        env.signedRegion().length,
        env.toBytes().length - Envelope.signatureLen,
      );
    });

    test('rejects truncated input', () {
      expect(
        () => Envelope.fromBytes(Uint8List(10)),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
