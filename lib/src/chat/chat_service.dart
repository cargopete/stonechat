import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../crypto/envelope.dart';
import '../crypto/identity.dart';
import '../data/database.dart';
import '../transport/transport_api.g.dart';

/// Hex-encode bytes (used as the stable peer/message key in the database).
String hex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Exponential outbox retry backoff: 2s, 4s, 8s … capped at 5 minutes.
/// Pure function, kept top-level so it can be unit-tested without a transport.
Duration outboxBackoff(int attempts) {
  const baseMs = 2000;
  const capMs = 5 * 60 * 1000;
  final shift = attempts.clamp(0, 20);
  final ms = baseMs * (1 << shift);
  return Duration(milliseconds: ms > capMs ? capMs : ms);
}

/// Wires the native BLE transport, the crypto layer and the database into the
/// direct + store-and-forward delivery model (brief §7).
///
/// Foreground: events stream live from the transport. Background (Stage 2):
/// the native side writes inbound envelopes to an App Group inbox; [drainInbox]
/// reconciles them into drift on launch/resume, resolving peer keys from the
/// database since the in-memory caches are empty after a cold restore.
class ChatService {
  ChatService({required this.db, required this.crypto, TransportHostApi? api})
      : _api = api ?? TransportHostApi();

  // Must match the Swift `BleConstants`.
  static const String serviceUuid = '9F2A1C00-5B3E-4D7A-8C21-7E0B6A4F1D90';
  static const String characteristicUuid =
      '9F2A1C01-5B3E-4D7A-8C21-7E0B6A4F1D90';
  static const String _centralRestoreId = 'com.stonechat.transport.central';
  static const String _peripheralRestoreId =
      'com.stonechat.transport.peripheral';

  final AppDatabase db;
  final EnvelopeCrypto crypto;
  final TransportHostApi _api;

  final StreamController<TransportEvent> _events =
      StreamController<TransportEvent>.broadcast();

  /// Raw transport events, re-broadcast for the UI (peer discovery, RSSI, etc).
  Stream<TransportEvent> get events => _events.stream;

  /// Latest Bluetooth adapter state, for the UI status banner.
  final ValueNotifier<BleAdapterState> adapterState =
      ValueNotifier<BleAdapterState>(BleAdapterState.unknown);

  /// Identity hexes of peers currently connected *and* handshaked (reachable).
  final ValueNotifier<Set<String>> onlineIdentities =
      ValueNotifier<Set<String>>(const {});

  StreamSubscription<TransportEvent>? _sub;

  // The transport addresses peers by connection id (CBPeripheral/CBCentral
  // UUID); the app addresses them by Ed25519 identity (hex). The binding is
  // learned from the first signed envelope on a connection.
  final Map<String, String> _identityByConnection = {};
  final Map<String, String> _connectionByIdentity = {};
  final Map<String, PeerKeys> _keysByIdentity = {};

  // Per-message outbox retry state (in-memory; a cold restart simply flushes
  // everything afresh on the next connection).
  static const int _maxOutboxAttempts = 10;
  static const Duration _retryInterval = Duration(seconds: 15);
  final Map<String, int> _attempts = {};
  final Map<String, DateTime> _lastAttempt = {};
  Timer? _retryTimer;

  /// The name this device announces to peers (a boxed `announceName` envelope).
  /// Defaults to a generic label until the user sets their own in settings.
  String _myName = 'stonechat';

  Future<void> start({required String displayName}) async {
    _myName = displayName;
    await _api.configure(TransportConfig(
      serviceUuid: serviceUuid,
      characteristicUuid: characteristicUuid,
      displayName: displayName,
      centralRestoreIdentifier: _centralRestoreId,
      peripheralRestoreIdentifier: _peripheralRestoreId,
    ));
    _sub = streamTransportEvents().listen(_onEvent);
    _retryTimer = Timer.periodic(_retryInterval, (_) => unawaited(_retryOutbox()));
    await _api.startAdvertising();
    await _api.startScanning();
    await drainInbox();
  }

  /// Updates the name announced to peers and re-announces to everyone currently
  /// connected. Persisting it is the caller's job (see settings).
  Future<void> updateMyName(String name) async {
    _myName = name;
    for (final identityHex in onlineIdentities.value) {
      final connectionId = _connectionByIdentity[identityHex];
      final keys = _keysByIdentity[identityHex];
      if (connectionId != null && keys != null) {
        await _announceNameTo(connectionId, keys);
      }
    }
  }

  /// Resolves a peer's public keys, falling back from the in-memory cache to
  /// the `peers` table (the cache is empty after a cold background restore).
  Future<PeerKeys?> _resolvePeerKeys(String identityHex) async {
    final cached = _keysByIdentity[identityHex];
    if (cached != null) return cached;
    final peer = await db.peerById(identityHex);
    if (peer == null) return null;
    final keys = PeerKeys(
      identityPublicKey: peer.identityPublicKey,
      boxPublicKey: peer.boxPublicKey,
    );
    _keysByIdentity[identityHex] = keys;
    return keys;
  }

  Future<void> dispose() async {
    _retryTimer?.cancel();
    await _sub?.cancel();
    await _events.close();
    adapterState.dispose();
    onlineIdentities.dispose();
  }

  void _onEvent(TransportEvent event) {
    _events.add(event);
    switch (event) {
      case AdapterStateEvent(:final state):
        adapterState.value = state;
      case PeerDiscoveredEvent(:final peer):
        unawaited(_api.connect(peer.peerId));
      case PeerConnectionEvent(:final peerId, :final state):
        switch (state) {
          case PeerConnectionState.connected:
            unawaited(_sendHello(peerId));
          case PeerConnectionState.disconnected:
            _onDisconnected(peerId);
          case PeerConnectionState.connecting:
          case PeerConnectionState.disconnecting:
            break;
        }
      case EnvelopeReceivedEvent(:final peerId, :final envelope):
        unawaited(_onEnvelope(peerId, envelope));
    }
  }

  void _onDisconnected(String connectionId) {
    final identityHex = _identityByConnection.remove(connectionId);
    if (identityHex != null) {
      _connectionByIdentity.remove(identityHex);
      _setOnline(identityHex, false);
    }
  }

  void _setOnline(String identityHex, bool online) {
    final next = Set<String>.from(onlineIdentities.value);
    if (online ? next.add(identityHex) : next.remove(identityHex)) {
      onlineIdentities.value = next;
    }
  }

  Future<void> _sendHello(String connectionId) async {
    await _api.sendEnvelope(connectionId, crypto.sealHello().toBytes());
  }

  Future<void> _onEnvelope(String connectionId, Uint8List bytes) async {
    final Envelope env;
    try {
      env = Envelope.fromBytes(bytes);
    } on FormatException {
      return;
    }

    final identityHex = hex(env.senderId);
    _identityByConnection[connectionId] = identityHex;
    _connectionByIdentity[identityHex] = connectionId;

    switch (env.type) {
      case EnvelopeType.hello:
        await _onHello(env, identityHex);
      case EnvelopeType.announceName:
        await _onAnnounceName(env, identityHex);
      case EnvelopeType.ack:
        await _onAck(env, identityHex);
      case EnvelopeType.read:
        await _onRead(env, identityHex);
      case EnvelopeType.message:
        await _onMessage(connectionId, env, identityHex);
      case EnvelopeType.image:
        // Photo messages arrive in a later build; ignore for forward-compat.
        break;
      case EnvelopeType.fragmentStart:
      case EnvelopeType.fragmentCont:
      case EnvelopeType.fragmentEnd:
        // Fragmentation is reassembled in the native transport; these never
        // surface here.
        break;
    }
  }

  Future<void> _onHello(Envelope env, String identityHex) async {
    try {
      final keys = crypto.openHello(env);
      _keysByIdentity[identityHex] = keys;
      await db.upsertPeer(PeersCompanion(
        id: Value(identityHex),
        identityPublicKey: Value(keys.identityPublicKey),
        boxPublicKey: Value(keys.boxPublicKey),
        lastSeenMs: Value(DateTime.now().millisecondsSinceEpoch),
      ));
      await _refreshPeerNameCache(identityHex);
      _setOnline(identityHex, true);
      final connectionId = _connectionByIdentity[identityHex];
      if (connectionId != null) {
        // We now hold the peer's box key, so we can announce our name to them.
        await _announceNameTo(connectionId, keys);
        await _flushOutbox(identityHex, connectionId, respectBackoff: false);
      }
    } on SignatureVerificationException {
      // Forged hello — ignore.
    }
  }

  /// Sends our chosen display name to a peer (boxed). Best-effort.
  Future<void> _announceNameTo(String connectionId, PeerKeys keys) async {
    final env = crypto.seal(
      type: EnvelopeType.announceName,
      plaintext: Uint8List.fromList(utf8.encode(_myName)),
      recipient: keys,
    );
    await _api.sendEnvelope(connectionId, env.toBytes());
  }

  Future<void> _onAnnounceName(Envelope env, String identityHex) async {
    final keys = await _resolvePeerKeys(identityHex);
    if (keys == null) return;
    try {
      final name = utf8.decode(crypto.open(env, sender: keys)).trim();
      if (name.isEmpty) return;
      await db.setPeerDisplayName(identityHex, name);
      await _refreshPeerNameCache(identityHex);
    } on SignatureVerificationException {
      // ignore
    } on FormatException {
      // Non-UTF8 payload — ignore.
    }
  }

  /// Pushes the peer's resolved label (nickname → announced name → "Peer XXXX")
  /// into the native name cache, so background notifications show a real name.
  Future<void> _refreshPeerNameCache(String identityHex) async {
    final peer = await db.peerById(identityHex);
    unawaited(_api.cachePeerName(identityHex, peerLabelFor(peer, identityHex)));
  }

  /// Re-pushes a peer's label after a local nickname change (UI hook).
  Future<void> refreshPeerName(String identityHex) =>
      _refreshPeerNameCache(identityHex);

  Future<void> _onAck(Envelope env, String identityHex) async {
    final keys = await _resolvePeerKeys(identityHex);
    if (keys == null) return;
    try {
      final referencedId = crypto.open(env, sender: keys);
      final referencedHex = hex(referencedId);
      await db.markState(referencedHex, MessageDeliveryState.acked);
      _clearBackoff(referencedHex); // delivered — stop retrying.
    } on SignatureVerificationException {
      // ignore
    }
  }

  /// A read receipt: the peer opened the conversation and read our message. The
  /// payload is the original message_id; we promote it from `acked` to `seen`.
  /// Never downgrade a later state, so only `received`/`sent`/`acked` advance.
  Future<void> _onRead(Envelope env, String identityHex) async {
    final keys = await _resolvePeerKeys(identityHex);
    if (keys == null) return;
    try {
      final referencedHex = hex(crypto.open(env, sender: keys));
      await db.markState(referencedHex, MessageDeliveryState.seen);
      _clearBackoff(referencedHex);
    } on SignatureVerificationException {
      // ignore
    }
  }

  /// Call when the user is viewing a conversation: send a read receipt for each
  /// inbound message not yet acknowledged as read, and record locally (state
  /// `seen`) that we've done so, so we don't re-send receipts endlessly.
  Future<void> markConversationRead(String identityHex) async {
    final connectionId = _connectionByIdentity[identityHex];
    final keys = _keysByIdentity[identityHex] ??
        await _resolvePeerKeys(identityHex);
    final pending = await db.inboundAwaitingReceipt(identityHex);
    for (final message in pending) {
      // Always mark locally read; only emit a receipt if we can reach the peer.
      await db.markState(message.messageId, MessageDeliveryState.seen);
      if (connectionId == null || keys == null) continue;
      final receipt = crypto.seal(
        type: EnvelopeType.read,
        plaintext: _messageIdBytes(message.messageId),
        recipient: keys,
      );
      await _api.sendEnvelope(connectionId, receipt.toBytes());
    }
  }

  /// Decodes a 32-hex-char message id back to its 16 raw bytes.
  Uint8List _messageIdBytes(String messageIdHex) {
    final out = Uint8List(Envelope.messageIdLen);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(messageIdHex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  Future<void> _onMessage(
      String connectionId, Envelope env, String identityHex) async {
    final keys = await _resolvePeerKeys(identityHex);
    if (keys == null) return; // No hello yet. TODO: buffer until handshake.

    final messageIdHex = hex(env.messageId);
    // Dedup: a re-sent duplicate is dropped but still re-ACKed so the sender
    // stops retrying.
    if (await db.hasMessage(messageIdHex)) {
      await _sendAck(connectionId, env);
      return;
    }

    try {
      final plaintext = crypto.open(env, sender: keys);
      await db.insertMessage(MessagesCompanion(
        messageId: Value(messageIdHex),
        peerId: Value(identityHex),
        direction: Value(MessageDirection.inbound),
        body: Value(utf8.decode(plaintext)),
        timestampMs: Value(env.timestampMs),
        state: Value(MessageDeliveryState.received),
        createdAtMs: Value(DateTime.now().millisecondsSinceEpoch),
      ));
      await _sendAck(connectionId, env);
    } on SignatureVerificationException {
      // drop
    }
  }

  /// ACKs by boxing the original `message_id` back to the sender.
  Future<void> _sendAck(String connectionId, Envelope original) async {
    final keys = await _resolvePeerKeys(hex(original.senderId));
    if (keys == null) return;
    final ack = crypto.seal(
      type: EnvelopeType.ack,
      plaintext: original.messageId,
      recipient: keys,
    );
    await _api.sendEnvelope(connectionId, ack.toBytes());
  }

  /// Sends a text message to a known peer, persisting outbox state.
  Future<void> sendText(String identityHex, String text) async {
    final keys = _keysByIdentity[identityHex];
    final connectionId = _connectionByIdentity[identityHex];
    if (keys == null || connectionId == null) {
      throw StateError('Peer $identityHex is not connected / not handshaked');
    }

    final env = crypto.seal(
      type: EnvelopeType.message,
      plaintext: Uint8List.fromList(utf8.encode(text)),
      recipient: keys,
    );
    final messageIdHex = hex(env.messageId);

    await db.insertMessage(MessagesCompanion(
      messageId: Value(messageIdHex),
      peerId: Value(identityHex),
      direction: Value(MessageDirection.outbound),
      body: Value(text),
      timestampMs: Value(env.timestampMs),
      state: Value(MessageDeliveryState.queued),
      createdAtMs: Value(DateTime.now().millisecondsSinceEpoch),
      envelope: Value(env.toBytes()),
    ));

    final dispatched = await _api.sendEnvelope(connectionId, env.toBytes());
    await db.markState(
      messageIdHex,
      dispatched ? MessageDeliveryState.sent : MessageDeliveryState.failed,
    );
  }

  /// Periodic retry: re-flush the outbox to every online peer, honouring each
  /// message's exponential backoff so we don't hammer the link.
  Future<void> _retryOutbox() async {
    for (final identityHex in onlineIdentities.value) {
      final connectionId = _connectionByIdentity[identityHex];
      if (connectionId != null) {
        await _flushOutbox(identityHex, connectionId);
      }
    }
  }

  /// Store-and-forward: re-send un-acked outbound messages to a peer, using the
  /// stored envelope bytes so the message_id — and therefore dedup + ACK
  /// matching — is preserved. With [respectBackoff] (the periodic path) each
  /// message waits out its [outboxBackoff]; on reconnect we flush immediately
  /// and reset counters.
  Future<void> _flushOutbox(
    String identityHex,
    String connectionId, {
    bool respectBackoff = true,
  }) async {
    final pending = await db.pendingFor(identityHex);
    final now = DateTime.now();
    for (final message in pending) {
      final bytes = message.envelope;
      if (bytes == null) continue; // inbound or pre-envelope row; skip.

      final attempts = _attempts[message.messageId] ?? 0;
      if (respectBackoff) {
        if (attempts >= _maxOutboxAttempts) {
          await db.markState(message.messageId, MessageDeliveryState.failed);
          _clearBackoff(message.messageId);
          continue;
        }
        final last = _lastAttempt[message.messageId];
        if (last != null && now.difference(last) < outboxBackoff(attempts)) {
          continue; // not due yet.
        }
      } else {
        _clearBackoff(message.messageId); // fresh start on reconnect.
      }

      final dispatched = await _api.sendEnvelope(connectionId, bytes);
      if (dispatched) {
        await db.markState(message.messageId, MessageDeliveryState.sent);
      }
      // Track the attempt either way; backoff grows until an ACK arrives.
      _attempts[message.messageId] = (_attempts[message.messageId] ?? 0) + 1;
      _lastAttempt[message.messageId] = now;
    }
  }

  void _clearBackoff(String messageId) {
    _attempts.remove(messageId);
    _lastAttempt.remove(messageId);
  }

  /// Drains the App Group inbox the native side fills during background wakes.
  /// Each envelope file is decoded, reconciled into drift, then deleted. Safe
  /// to call repeatedly (on launch and on every foreground resume).
  Future<void> drainInbox() async {
    final path = await _api.inboxDirectoryPath();
    if (path == null) return;
    final dir = Directory(path);
    if (!await dir.exists()) return;

    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.env')) continue;
      try {
        await _ingestRestored(await entity.readAsBytes());
        await entity.delete();
      } catch (_) {
        // Leave the file in place for a later attempt.
      }
    }
  }

  /// Reconciles one envelope that arrived while Dart was asleep. There is no
  /// live connection, so ACKs aren't sent here — the sender's outbox will
  /// re-send on reconnect, where dedup drops the duplicate and re-ACKs it.
  Future<void> _ingestRestored(Uint8List bytes) async {
    final Envelope env;
    try {
      env = Envelope.fromBytes(bytes);
    } on FormatException {
      return;
    }
    final identityHex = hex(env.senderId);

    switch (env.type) {
      case EnvelopeType.hello:
        try {
          final keys = crypto.openHello(env);
          _keysByIdentity[identityHex] = keys;
          await db.upsertPeer(PeersCompanion(
            id: Value(identityHex),
            identityPublicKey: Value(keys.identityPublicKey),
            boxPublicKey: Value(keys.boxPublicKey),
            lastSeenMs: Value(DateTime.now().millisecondsSinceEpoch),
          ));
          await _refreshPeerNameCache(identityHex);
        } on SignatureVerificationException {
          // forged — ignore
        }
      case EnvelopeType.announceName:
        await _onAnnounceName(env, identityHex);
      case EnvelopeType.message:
        final keys = await _resolvePeerKeys(identityHex);
        if (keys == null) return;
        final messageIdHex = hex(env.messageId);
        if (await db.hasMessage(messageIdHex)) return;
        try {
          final plaintext = crypto.open(env, sender: keys);
          await db.insertMessage(MessagesCompanion(
            messageId: Value(messageIdHex),
            peerId: Value(identityHex),
            direction: Value(MessageDirection.inbound),
            body: Value(utf8.decode(plaintext)),
            timestampMs: Value(env.timestampMs),
            state: Value(MessageDeliveryState.received),
            createdAtMs: Value(DateTime.now().millisecondsSinceEpoch),
          ));
        } on SignatureVerificationException {
          // drop
        }
      case EnvelopeType.ack:
        await _onAck(env, identityHex);
      case EnvelopeType.read:
        await _onRead(env, identityHex);
      case EnvelopeType.image:
        // Photo messages arrive in a later build; ignore for forward-compat.
        break;
      case EnvelopeType.fragmentStart:
      case EnvelopeType.fragmentCont:
      case EnvelopeType.fragmentEnd:
        break;
    }
  }
}
