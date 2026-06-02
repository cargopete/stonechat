import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../crypto/envelope.dart';
import '../crypto/identity.dart';
import '../data/database.dart';
import '../transport/transport_api.g.dart';

/// Hex-encode bytes (used as the stable peer/message key in the database).
String hex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Wires the native BLE transport, the crypto layer and the database into the
/// direct + store-and-forward delivery model (brief §7).
///
/// Scope note: this is the Stage 1 happy path. Outbox flush-on-reconnect and
/// retry/backoff are left as marked TODOs — the structure is here, the policy
/// is the next increment.
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

  Future<void> start({required String displayName}) async {
    await _api.configure(TransportConfig(
      serviceUuid: serviceUuid,
      characteristicUuid: characteristicUuid,
      displayName: displayName,
      centralRestoreIdentifier: _centralRestoreId,
      peripheralRestoreIdentifier: _peripheralRestoreId,
    ));
    _sub = streamTransportEvents().listen(_onEvent);
    await _api.startAdvertising();
    await _api.startScanning();
  }

  Future<void> dispose() async {
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
      case EnvelopeType.ack:
        await _onAck(env, identityHex);
      case EnvelopeType.message:
        await _onMessage(connectionId, env, identityHex);
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
      _setOnline(identityHex, true);
    } on SignatureVerificationException {
      // Forged hello — ignore.
    }
  }

  Future<void> _onAck(Envelope env, String identityHex) async {
    final keys = _keysByIdentity[identityHex];
    if (keys == null) return;
    try {
      final referencedId = crypto.open(env, sender: keys);
      await db.markState(hex(referencedId), MessageDeliveryState.acked);
    } on SignatureVerificationException {
      // ignore
    }
  }

  Future<void> _onMessage(
      String connectionId, Envelope env, String identityHex) async {
    final keys = _keysByIdentity[identityHex];
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
    final keys = _keysByIdentity[hex(original.senderId)];
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
    ));

    final dispatched = await _api.sendEnvelope(connectionId, env.toBytes());
    await db.markState(
      messageIdHex,
      dispatched ? MessageDeliveryState.sent : MessageDeliveryState.failed,
    );
  }
}
