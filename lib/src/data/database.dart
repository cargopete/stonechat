import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

enum MessageDirection { inbound, outbound }

/// Delivery state for the local store-and-forward outbox (brief §7).
///  - [queued]   : created, not yet written to the peer.
///  - [sent]     : frames dispatched, awaiting an app-layer ACK.
///  - [acked]    : peer ACKed; delivery confirmed.
///  - [failed]   : gave up (out of scope for the skeleton).
///  - [received] : inbound, decrypted + verified.
enum MessageDeliveryState { queued, sent, acked, failed, received }

/// Known peers, keyed by their Ed25519 identity public key (hex). The X25519
/// [boxPublicKey] is learned from the peer's `hello` envelope.
class Peers extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text().nullable()();
  BlobColumn get identityPublicKey => blob()();
  BlobColumn get boxPublicKey => blob()();
  IntColumn get lastSeenMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One-to-one messages. [messageId] is the 16-byte envelope id (hex) and is the
/// primary key, which is exactly the dedup guarantee: a re-sent duplicate
/// collides on insert and is dropped (but still re-ACKed by the app layer).
class Messages extends Table {
  TextColumn get messageId => text()();
  TextColumn get peerId => text().references(Peers, #id)();
  IntColumn get direction => intEnum<MessageDirection>()();
  TextColumn get body => text()();
  IntColumn get timestampMs => integer()();
  IntColumn get state => intEnum<MessageDeliveryState>()();
  IntColumn get createdAtMs => integer()();

  @override
  Set<Column> get primaryKey => {messageId};
}

@DriftDatabase(tables: [Peers, Messages])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  Future<void> upsertPeer(PeersCompanion peer) =>
      into(peers).insertOnConflictUpdate(peer);

  /// Reactive conversation view, oldest first (timestamp, then id tie-break).
  Stream<List<Message>> watchConversation(String peerId) {
    return (select(messages)
          ..where((m) => m.peerId.equals(peerId))
          ..orderBy([
            (m) => OrderingTerm(expression: m.timestampMs),
            (m) => OrderingTerm(expression: m.messageId),
          ]))
        .watch();
  }

  Future<bool> hasMessage(String messageId) async {
    final row = await (select(messages)
          ..where((m) => m.messageId.equals(messageId))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  /// Inserts a message, ignoring duplicates (dedup by [messageId]).
  /// Returns true if it was new.
  Future<bool> insertMessage(MessagesCompanion message) async {
    final inserted = await into(messages)
        .insert(message, mode: InsertMode.insertOrIgnore);
    return inserted != 0;
  }

  Future<void> markState(String messageId, MessageDeliveryState state) {
    return (update(messages)..where((m) => m.messageId.equals(messageId)))
        .write(MessagesCompanion(state: Value(state)));
  }

  /// Outbox: messages for [peerId] still awaiting delivery confirmation.
  Future<List<Message>> pendingFor(String peerId) {
    return (select(messages)
          ..where((m) =>
              m.peerId.equals(peerId) &
              m.direction.equalsValue(MessageDirection.outbound) &
              m.state.isNotInValues([
                MessageDeliveryState.acked,
                MessageDeliveryState.failed,
              ])))
        .get();
  }
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    // Stage 2 will move this file into the App Group shared container so the
    // Swift transport can append inbound ciphertext during background wakes.
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'stonechat.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
