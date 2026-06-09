import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonechat/src/crypto/envelope.dart';
import 'package:stonechat/src/data/database.dart';

void main() {
  group('EnvelopeType opcodes', () {
    test('new opcodes have stable wire values (append-only)', () {
      expect(EnvelopeType.message.wire, 0);
      expect(EnvelopeType.ack.wire, 1);
      expect(EnvelopeType.hello.wire, 5);
      expect(EnvelopeType.announceName.wire, 6);
      expect(EnvelopeType.read.wire, 7);
      expect(EnvelopeType.image.wire, 8);
    });

    test('fromWire round-trips the new opcodes', () {
      for (final t in [
        EnvelopeType.announceName,
        EnvelopeType.read,
        EnvelopeType.image,
      ]) {
        expect(EnvelopeType.fromWire(t.wire), t);
      }
    });
  });

  group('peerLabelFor', () {
    Peer peer({String? displayName, String? nickname}) => Peer(
          id: 'abcdef0123456789',
          displayName: displayName,
          nickname: nickname,
          identityPublicKey: Uint8List(0),
          boxPublicKey: Uint8List(0),
          lastSeenMs: null,
        );

    test('prefers nickname, then announced name, then short id', () {
      expect(peerLabelFor(peer(nickname: 'Wifey', displayName: 'Mara'), 'x'),
          'Wifey');
      expect(peerLabelFor(peer(displayName: 'Mara'), 'x'), 'Mara');
      expect(peerLabelFor(peer(), 'x'), 'Peer abcdef01');
      expect(peerLabelFor(null, 'deadbeefcafe'), 'Peer deadbeef');
    });

    test('ignores blank names', () {
      expect(peerLabelFor(peer(nickname: '  ', displayName: 'Mara'), 'x'),
          'Mara');
    });
  });

  group('database upgrades', () {
    late AppDatabase db;
    const peerId = 'aabbccdd';

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.upsertPeer(PeersCompanion(
        id: const Value(peerId),
        identityPublicKey: Value(Uint8List.fromList([1])),
        boxPublicKey: Value(Uint8List.fromList([2])),
        lastSeenMs: const Value(1),
      ));
    });
    tearDown(() async => db.close());

    test('settings round-trip', () async {
      expect(await db.getSetting('myDisplayName'), isNull);
      await db.setSetting('myDisplayName', 'Pete');
      expect(await db.getSetting('myDisplayName'), 'Pete');
      await db.setSetting('myDisplayName', 'Chief');
      expect(await db.getSetting('myDisplayName'), 'Chief');
    });

    test('peer display name and nickname', () async {
      await db.setPeerDisplayName(peerId, 'Mara');
      expect((await db.peerById(peerId))!.displayName, 'Mara');
      await db.setPeerNickname(peerId, 'Wifey');
      expect((await db.peerById(peerId))!.nickname, 'Wifey');
      await db.setPeerNickname(peerId, null);
      expect((await db.peerById(peerId))!.nickname, isNull);
    });

    test('inboundAwaitingReceipt returns only unread inbound', () async {
      await db.insertMessage(MessagesCompanion(
        messageId: const Value('in1'),
        peerId: const Value(peerId),
        direction: const Value(MessageDirection.inbound),
        body: const Value('hi'),
        timestampMs: const Value(10),
        state: const Value(MessageDeliveryState.received),
        createdAtMs: const Value(10),
      ));
      await db.insertMessage(MessagesCompanion(
        messageId: const Value('in2'),
        peerId: const Value(peerId),
        direction: const Value(MessageDirection.inbound),
        body: const Value('already read'),
        timestampMs: const Value(11),
        state: const Value(MessageDeliveryState.seen),
        createdAtMs: const Value(11),
      ));
      await db.insertMessage(MessagesCompanion(
        messageId: const Value('out1'),
        peerId: const Value(peerId),
        direction: const Value(MessageDirection.outbound),
        body: const Value('mine'),
        timestampMs: const Value(12),
        state: const Value(MessageDeliveryState.received),
        createdAtMs: const Value(12),
      ));

      final pending = await db.inboundAwaitingReceipt(peerId);
      expect(pending.map((m) => m.messageId), ['in1']);

      await db.markState('in1', MessageDeliveryState.seen);
      expect(await db.inboundAwaitingReceipt(peerId), isEmpty);
    });

    test('pendingFor excludes seen so the retry loop cannot clobber it',
        () async {
      Future<void> add(String id, MessageDeliveryState state) =>
          db.insertMessage(MessagesCompanion(
            messageId: Value(id),
            peerId: const Value(peerId),
            direction: const Value(MessageDirection.outbound),
            body: Value(id),
            timestampMs: const Value(1),
            state: Value(state),
            createdAtMs: const Value(1),
            envelope: Value(Uint8List.fromList([1, 2, 3])),
          ));
      await add('queued', MessageDeliveryState.queued);
      await add('sent', MessageDeliveryState.sent);
      await add('delivered', MessageDeliveryState.acked);
      await add('seen', MessageDeliveryState.seen);

      final pending = await db.pendingFor(peerId);
      expect(pending.map((m) => m.messageId).toSet(), {'queued', 'sent'});
    });
  });
}
