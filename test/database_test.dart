import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonechat/src/data/database.dart';

void main() {
  late AppDatabase db;
  const peerId = 'aabbccdd';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.upsertPeer(PeersCompanion(
      id: const Value(peerId),
      identityPublicKey: Value(Uint8List.fromList([1, 2, 3])),
      boxPublicKey: Value(Uint8List.fromList([4, 5, 6])),
      lastSeenMs: const Value(1000),
    ));
  });

  tearDown(() async => db.close());

  MessagesCompanion message(
    String id, {
    MessageDirection direction = MessageDirection.outbound,
    MessageDeliveryState state = MessageDeliveryState.queued,
    int timestampMs = 0,
    Uint8List? envelope,
  }) {
    return MessagesCompanion(
      messageId: Value(id),
      peerId: const Value(peerId),
      direction: Value(direction),
      body: Value('body-$id'),
      timestampMs: Value(timestampMs),
      state: Value(state),
      createdAtMs: const Value(0),
      envelope: Value(envelope),
    );
  }

  group('dedup', () {
    test('inserting the same message id twice keeps one row', () async {
      expect(await db.insertMessage(message('A')), isTrue);
      expect(await db.insertMessage(message('A')), isFalse);
      final all = await db.select(db.messages).get();
      expect(all, hasLength(1));
    });

    test('hasMessage reflects presence', () async {
      expect(await db.hasMessage('A'), isFalse);
      await db.insertMessage(message('A'));
      expect(await db.hasMessage('A'), isTrue);
    });
  });

  group('outbox', () {
    test('pendingFor returns queued + sent, excludes acked/failed', () async {
      await db.insertMessage(message('q', state: MessageDeliveryState.queued));
      await db.insertMessage(message('s', state: MessageDeliveryState.sent));
      await db.insertMessage(message('a', state: MessageDeliveryState.acked));
      await db.insertMessage(message('f', state: MessageDeliveryState.failed));

      final pending = await db.pendingFor(peerId);
      expect(pending.map((m) => m.messageId).toSet(), {'q', 's'});
    });

    test('pendingFor excludes inbound messages', () async {
      await db.insertMessage(
          message('in', direction: MessageDirection.inbound, state: MessageDeliveryState.received));
      expect(await db.pendingFor(peerId), isEmpty);
    });

    test('markState moves a message out of the outbox', () async {
      await db.insertMessage(message('m'));
      expect(await db.pendingFor(peerId), hasLength(1));
      await db.markState('m', MessageDeliveryState.acked);
      expect(await db.pendingFor(peerId), isEmpty);
    });

    test('envelope bytes round-trip', () async {
      final bytes = Uint8List.fromList([9, 8, 7, 6]);
      await db.insertMessage(message('m', envelope: bytes));
      final stored = (await db.pendingFor(peerId)).single;
      expect(stored.envelope, bytes);
    });
  });

  test('watchConversation orders by timestamp then id', () async {
    await db.insertMessage(message('b', timestampMs: 200));
    await db.insertMessage(message('a', timestampMs: 100));
    await db.insertMessage(message('c', timestampMs: 200));

    final ordered = await db.watchConversation(peerId).first;
    expect(ordered.map((m) => m.messageId).toList(), ['a', 'b', 'c']);
  });
}
