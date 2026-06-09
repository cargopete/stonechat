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
///  - [seen]     : peer opened the conversation and read it (read receipt).
/// Appended only — the ordinal is persisted, never reorder.
enum MessageDeliveryState { queued, sent, acked, failed, received, seen }

/// What a message carries. Appended only — the ordinal is persisted.
enum MessageKind { text, image }

/// Resolves the human label for a peer: their local nickname, else the name
/// they announced for themselves, else a short "Peer XXXX" from the identity.
String peerLabelFor(Peer? peer, String identityHex) {
  final nick = peer?.nickname?.trim();
  if (nick != null && nick.isNotEmpty) return nick;
  final name = peer?.displayName?.trim();
  if (name != null && name.isNotEmpty) return name;
  final id = peer?.id ?? identityHex;
  return 'Peer ${id.substring(0, id.length.clamp(0, 8))}';
}

/// Known peers, keyed by their Ed25519 identity public key (hex). The X25519
/// [boxPublicKey] is learned from the peer's `hello` envelope.
class Peers extends Table {
  TextColumn get id => text()();

  /// The name the peer announced for themselves (via an `announceName`
  /// envelope), or null until they announce one.
  TextColumn get displayName => text().nullable()();

  /// A local nickname the user set for this peer, overriding [displayName].
  /// Never leaves the device.
  TextColumn get nickname => text().nullable()();
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

  /// Whether this row is a text or an image message.
  IntColumn get kind =>
      intEnum<MessageKind>().withDefault(const Constant(0))();
  TextColumn get body => text()();
  IntColumn get timestampMs => integer()();
  IntColumn get state => intEnum<MessageDeliveryState>()();
  IntColumn get createdAtMs => integer()();

  /// The (compressed) image bytes for an image message, stored encrypted at
  /// rest with the rest of the DB. Null for text messages.
  BlobColumn get mediaBytes => blob().nullable()();

  /// The sealed envelope bytes for an outbound message, kept so the outbox can
  /// re-send the *identical* bytes (same message_id) on reconnect — which is
  /// what preserves dedup + ACK matching. Null for inbound messages.
  BlobColumn get envelope => blob().nullable()();

  @override
  Set<Column> get primaryKey => {messageId};
}

/// A tiny key/value store for app-level settings (e.g. the user's own display
/// name). Kept opaque so adding a setting needs no migration.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Peers, Messages, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(messages, messages.envelope);
          }
          // v3: nicknames, read receipts, image messages, settings store.
          if (from < 3) {
            await m.addColumn(peers, peers.nickname);
            await m.addColumn(messages, messages.kind);
            await m.addColumn(messages, messages.mediaBytes);
            await m.createTable(settings);
          }
        },
      );

  Future<void> upsertPeer(PeersCompanion peer) =>
      into(peers).insertOnConflictUpdate(peer);

  Future<Peer?> peerById(String id) =>
      (select(peers)..where((p) => p.id.equals(id))..limit(1)).getSingleOrNull();

  /// Reactive single peer, so the UI reflects name/nickname changes live.
  Stream<Peer?> watchPeer(String id) =>
      (select(peers)..where((p) => p.id.equals(id))..limit(1))
          .watchSingleOrNull();

  /// Reactive list of known peers, most-recently-seen first.
  Stream<List<Peer>> watchPeers() {
    return (select(peers)
          ..orderBy([
            (p) => OrderingTerm(
                  expression: p.lastSeenMs,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }

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
  /// Returns true if it was new. The existence check makes the result
  /// deterministic; `insertOrIgnore` still guards the row at the DB level.
  Future<bool> insertMessage(MessagesCompanion message) async {
    if (await hasMessage(message.messageId.value)) return false;
    await into(messages).insert(message, mode: InsertMode.insertOrIgnore);
    return true;
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

  // --- Settings -----------------------------------------------------------

  Future<String?> getSetting(String key) async {
    final row = await (select(settings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) => into(settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  // --- Peer names ---------------------------------------------------------

  /// Records the name a peer announced for themselves.
  Future<void> setPeerDisplayName(String id, String name) =>
      (update(peers)..where((p) => p.id.equals(id)))
          .write(PeersCompanion(displayName: Value(name)));

  /// Sets (or clears, with null) the local nickname for a peer.
  Future<void> setPeerNickname(String id, String? nickname) =>
      (update(peers)..where((p) => p.id.equals(id)))
          .write(PeersCompanion(nickname: Value(nickname)));

  // --- Read receipts ------------------------------------------------------

  /// Inbound messages from [peerId] the user has just read but not yet sent a
  /// read receipt for (still in the `received` state). Marking them `seen`
  /// locally records that a receipt has been emitted.
  Future<List<Message>> inboundAwaitingReceipt(String peerId) {
    return (select(messages)
          ..where((m) =>
              m.peerId.equals(peerId) &
              m.direction.equalsValue(MessageDirection.inbound) &
              m.state.equalsValue(MessageDeliveryState.received)))
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
