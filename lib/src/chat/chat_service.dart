import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import '../crypto/envelope.dart';
import '../crypto/identity.dart';
import '../data/database.dart';
import '../relay/relay_client.dart';
import '../transport/transport_api.g.dart';

/// Hex-encode bytes (used as the stable peer/message key in the database).
String hex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// The live channel to a peer, for the connection indicator. Bluetooth is
/// preferred; the relay ("web") is the fallback; otherwise we're offline (and
/// anything sent simply queues).
enum PeerChannel { bluetooth, web, offline }

/// A WebRTC call-setup message surfaced from an inbound signaling envelope.
enum CallSignalType { offer, answer, ice, end }

class CallSignal {
  CallSignal(this.peerId, this.type, this.json, this.callId);
  final String peerId;
  final CallSignalType type;
  final String json;

  /// The offer envelope's message_id as a canonical UUID. The relay derives the
  /// same id for the VoIP push, so a CallKit call rung from a push lines up with
  /// the one the app sets up once the offer is decrypted.
  final String callId;
}

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
  ChatService({
    required this.db,
    required this.crypto,
    RelayClient? relay,
    TransportHostApi? api,
  })  : _relay = relay,
        _api = api ?? TransportHostApi();

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

  /// The optional "web" channel: a relay used when Bluetooth can't reach the
  /// peer. Null when no relay is configured (pure-offline mode).
  final RelayClient? _relay;

  /// Whether the relay was reachable on the last attempt — drives the
  /// Bluetooth/Web/Offline indicator. Always false without a configured relay.
  final ValueNotifier<bool> relayReachable = ValueNotifier<bool>(false);

  bool get hasRelay => _relay != null;

  /// The current channel to a peer for the UI indicator: Bluetooth if connected,
  /// else web if the relay is reachable, else offline.
  PeerChannel channelFor(String identityHex) {
    if (onlineIdentities.value.contains(identityHex)) {
      return PeerChannel.bluetooth;
    }
    if (relayReachable.value) return PeerChannel.web;
    return PeerChannel.offline;
  }

  /// Messages already handed to the relay, so the periodic flush doesn't re-POST
  /// them every tick (the relay dedups anyway; this just saves the round-trips).
  final Set<String> _relayed = {};

  /// Inbound WebRTC call-signaling messages (offer/answer/ICE/hangup), consumed
  /// by the call layer.
  final StreamController<CallSignal> _callSignals =
      StreamController<CallSignal>.broadcast();
  Stream<CallSignal> get callSignals => _callSignals.stream;

  /// Sends a WebRTC signaling message (SDP / ICE / hangup) over whichever
  /// channel can reach the peer.
  Future<void> sendCallSignal(
      String identityHex, CallSignalType type, String json) async {
    final keys = await _resolvePeerKeys(identityHex);
    if (keys == null) return;
    final opcode = switch (type) {
      CallSignalType.offer => EnvelopeType.callOffer,
      CallSignalType.answer => EnvelopeType.callAnswer,
      CallSignalType.ice => EnvelopeType.callIce,
      CallSignalType.end => EnvelopeType.callEnd,
    };
    final env = crypto.seal(
      type: opcode,
      plaintext: Uint8List.fromList(utf8.encode(json)),
      recipient: keys,
    );
    await _dispatchEnvelope(identityHex, env.toBytes());
  }

  Future<void> _onCallSignal(
      Envelope env, String identityHex, CallSignalType type) async {
    final keys = await _resolvePeerKeys(identityHex);
    if (keys == null) return;
    try {
      final json = utf8.decode(crypto.open(env, sender: keys));
      _callSignals.add(
          CallSignal(identityHex, type, json, _uuidFromBytes(env.messageId)));
    } on SignatureVerificationException {
      // ignore
    }
  }

  /// Formats a 16-byte message_id as a canonical UUID (8-4-4-4-12), matching the
  /// relay's `uuid_from_hex` so the CallKit call id is identical on both sides.
  static String _uuidFromBytes(Uint8List b) {
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}'
        '-${h.substring(16, 20)}-${h.substring(20, 32)}';
  }

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
    _retryTimer = Timer.periodic(_retryInterval, (_) {
      unawaited(_retryOutbox());
      // Poll the web channel while in the foreground: pull relayed messages and
      // push anything still undelivered to the relay.
      unawaited(drainRelay());
      unawaited(_flushPendingToRelay());
      unawaited(_registerPushIfNeeded());
    });
    await _api.startAdvertising();
    await _api.startScanning();
    await drainInbox();
    // Pull anything relayed while we were away on this cold launch, and register
    // for wake-up pushes once the OS hands us a token.
    await drainRelay();
    unawaited(_registerPushIfNeeded());
  }

  String? _lastPushToken;
  String? _lastVoipToken;

  /// Registers this device's APNs token — and PushKit VoIP token, once iOS hands
  /// it over — with the relay so relayed messages and calls can wake it. Both
  /// tokens arrive asynchronously after launch (and the VoIP one usually lags
  /// the APNs one), so this re-registers whenever either first appears or
  /// changes, rather than only once.
  Future<void> _registerPushIfNeeded() async {
    final relay = _relay;
    if (relay == null) return;
    final token = await _api.pushToken();
    if (token == null || token.isEmpty) return;
    String? voip;
    try {
      final dynamic v = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
      if (v is String && v.isNotEmpty) voip = v;
    } catch (_) {
      // CallKit plugin not ready yet — try again on the next tick.
    }
    if (token == _lastPushToken && voip == _lastVoipToken) return;
    await relay.register(token, voipToken: voip);
    _lastPushToken = token;
    _lastVoipToken = voip;
  }

  /// Called when the app returns to the foreground (and from a manual refresh):
  /// re-kick advertising + scanning — which on the native side also re-arms
  /// connections to known peers — then reconcile the background inbox and flush
  /// anything queued to peers that are reachable again. This is the reliable
  /// recovery path, since iOS heavily throttles background BLE and a link that
  /// died while both apps were backgrounded only heals once one is foregrounded.
  Future<void> resume() async {
    await _api.startAdvertising();
    await _api.startScanning();
    await drainInbox();
    await _retryOutbox();
    // Sync the web channel too: pull anything relayed to us, then push our
    // still-undelivered messages to the relay for peers we can't reach by BLE.
    await drainRelay();
    await _flushPendingToRelay();
    unawaited(_registerPushIfNeeded());
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
    relayReachable.dispose();
    await _callSignals.close();
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
    // Bind this BLE connection to the sender's identity so replies route over it.
    _identityByConnection[connectionId] = identityHex;
    _connectionByIdentity[identityHex] = connectionId;
    await _routeEnvelope(env, identityHex);
  }

  /// Handles one decoded envelope regardless of how it arrived (Bluetooth or
  /// relay). Any reply (ack, name announce) is sent via [_dispatchEnvelope],
  /// which picks whichever channel can currently reach the peer.
  Future<void> _routeEnvelope(Envelope env, String identityHex) async {
    switch (env.type) {
      case EnvelopeType.hello:
        await _onHello(env, identityHex);
      case EnvelopeType.announceName:
        await _onAnnounceName(env, identityHex);
      case EnvelopeType.ack:
        await _onAck(env, identityHex);
      case EnvelopeType.read:
        await _onRead(env, identityHex);
      case EnvelopeType.reaction:
        await _onReaction(env, identityHex);
      case EnvelopeType.callOffer:
        await _onCallSignal(env, identityHex, CallSignalType.offer);
      case EnvelopeType.callAnswer:
        await _onCallSignal(env, identityHex, CallSignalType.answer);
      case EnvelopeType.callIce:
        await _onCallSignal(env, identityHex, CallSignalType.ice);
      case EnvelopeType.callEnd:
        await _onCallSignal(env, identityHex, CallSignalType.end);
      case EnvelopeType.message:
      case EnvelopeType.image:
        await _onMessage(env, identityHex);
      case EnvelopeType.fragmentStart:
      case EnvelopeType.fragmentCont:
      case EnvelopeType.fragmentEnd:
        // Fragmentation is reassembled in the native transport; these never
        // surface here.
        break;
    }
  }

  /// Sends an envelope to a peer over the best available channel: Bluetooth if
  /// connected, otherwise the relay ("web"), otherwise gives up (false). This is
  /// the single choke point that makes delivery Bluetooth-first, web-fallback.
  Future<bool> _dispatchEnvelope(String identityHex, Uint8List bytes) async {
    final connectionId = _connectionByIdentity[identityHex];
    if (connectionId != null && await _api.sendEnvelope(connectionId, bytes)) {
      return true;
    }
    final relay = _relay;
    if (relay != null && await relay.send(bytes)) {
      relayReachable.value = true;
      return true;
    }
    return false;
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
    final keys =
        _keysByIdentity[identityHex] ?? await _resolvePeerKeys(identityHex);
    final pending = await db.inboundAwaitingReceipt(identityHex);
    for (final message in pending) {
      // Always mark locally read; emit a receipt over whichever channel works.
      await db.markState(message.messageId, MessageDeliveryState.seen);
      if (keys == null) continue;
      final receipt = crypto.seal(
        type: EnvelopeType.read,
        plaintext: _messageIdBytes(message.messageId),
        recipient: keys,
      );
      await _dispatchEnvelope(identityHex, receipt.toBytes());
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

  Future<void> _onMessage(Envelope env, String identityHex) async {
    final keys = await _resolvePeerKeys(identityHex);
    if (keys == null) return; // No hello yet. TODO: buffer until handshake.

    final messageIdHex = hex(env.messageId);
    // Dedup: a re-sent duplicate is dropped but still re-ACKed so the sender
    // stops retrying.
    if (await db.hasMessage(messageIdHex)) {
      await _sendAck(env);
      return;
    }

    try {
      final (replyTo, payload) = _decodeReply(crypto.open(env, sender: keys));
      final isImage = env.type == EnvelopeType.image;
      await db.insertMessage(MessagesCompanion(
        messageId: Value(messageIdHex),
        peerId: Value(identityHex),
        direction: Value(MessageDirection.inbound),
        kind: Value(isImage ? MessageKind.image : MessageKind.text),
        body: Value(isImage ? '' : utf8.decode(payload)),
        mediaBytes: Value(isImage ? payload : null),
        replyToMessageId: Value(replyTo),
        timestampMs: Value(env.timestampMs),
        state: Value(MessageDeliveryState.received),
        createdAtMs: Value(DateTime.now().millisecondsSinceEpoch),
      ));
      await _sendAck(env);
    } on SignatureVerificationException {
      // drop
    }
  }

  /// ACKs by boxing the original `message_id` back to the sender, over whichever
  /// channel can reach them (Bluetooth or relay).
  Future<void> _sendAck(Envelope original) async {
    final senderHex = hex(original.senderId);
    final keys = await _resolvePeerKeys(senderHex);
    if (keys == null) return;
    final ack = crypto.seal(
      type: EnvelopeType.ack,
      plaintext: original.messageId,
      recipient: keys,
    );
    await _dispatchEnvelope(senderHex, ack.toBytes());
  }

  /// Sends a text message to a known peer, optionally as a reply. Works offline:
  /// sealed + queued immediately, delivered by the outbox on reconnect — so a
  /// dropped link never surfaces an error.
  Future<void> sendText(String identityHex, String text, {String? replyTo}) =>
      _enqueueOutbound(
        identityHex: identityHex,
        type: EnvelopeType.message,
        payload: Uint8List.fromList(utf8.encode(text)),
        kind: MessageKind.text,
        body: text,
        replyTo: replyTo,
      );

  /// Sends a photo (already-compressed bytes), optionally as a reply.
  Future<void> sendImage(String identityHex, Uint8List imageBytes,
          {String? replyTo}) =>
      _enqueueOutbound(
        identityHex: identityHex,
        type: EnvelopeType.image,
        payload: imageBytes,
        kind: MessageKind.image,
        mediaBytes: imageBytes,
        replyTo: replyTo,
      );

  /// Sends a tapback reaction (or clears it with an empty emoji) for a message.
  Future<void> sendReaction(
      String identityHex, String messageId, String emoji) async {
    final keys = await _resolvePeerKeys(identityHex);
    if (keys == null) return;
    await db.setReaction(messageId, identityHex, true, emoji);
    final payload = BytesBuilder()
      ..add(_messageIdBytes(messageId))
      ..add(utf8.encode(emoji));
    final env = crypto.seal(
      type: EnvelopeType.reaction,
      plaintext: payload.toBytes(),
      recipient: keys,
    );
    await _dispatchEnvelope(identityHex, env.toBytes());
  }

  Future<void> _onReaction(Envelope env, String identityHex) async {
    final keys = await _resolvePeerKeys(identityHex);
    if (keys == null) return;
    try {
      final plaintext = crypto.open(env, sender: keys);
      if (plaintext.length < Envelope.messageIdLen) return;
      final referenced = hex(plaintext.sublist(0, Envelope.messageIdLen));
      final emoji = utf8.decode(plaintext.sublist(Envelope.messageIdLen));
      await db.setReaction(referenced, identityHex, false, emoji);
    } on SignatureVerificationException {
      // ignore
    } on FormatException {
      // ignore
    }
  }

  /// Reply framing: an outbound payload is `"SCR1" + replyTo(16) + payload` when
  /// it's a reply, else the raw payload. The magic makes false positives on
  /// arbitrary bytes vanishingly unlikely.
  static final Uint8List _replyMagic =
      Uint8List.fromList([0x53, 0x43, 0x52, 0x31]); // "SCR1"

  (String?, Uint8List) _decodeReply(Uint8List plaintext) {
    if (plaintext.length >= 20 &&
        plaintext[0] == 0x53 &&
        plaintext[1] == 0x43 &&
        plaintext[2] == 0x52 &&
        plaintext[3] == 0x31) {
      return (
        hex(plaintext.sublist(4, 20)),
        Uint8List.fromList(plaintext.sublist(20)),
      );
    }
    return (null, plaintext);
  }

  /// Seals an outbound message, records it as `queued`, and dispatches it now if
  /// reachable. If offline (or dispatch fails), it stays `queued` and the outbox
  /// flushes it later — never throwing for "not connected". Throws only for a
  /// peer we've never met (no keys on record), which the UI can't reach anyway.
  Future<void> _enqueueOutbound({
    required String identityHex,
    required EnvelopeType type,
    required Uint8List payload,
    required MessageKind kind,
    String body = '',
    Uint8List? mediaBytes,
    String? replyTo,
  }) async {
    final keys = await _resolvePeerKeys(identityHex);
    if (keys == null) {
      throw StateError('No handshake on record for this peer yet');
    }

    // Frame the reply (if any) into the sealed plaintext.
    final Uint8List plaintext;
    if (replyTo != null) {
      plaintext = (BytesBuilder()
            ..add(_replyMagic)
            ..add(_messageIdBytes(replyTo))
            ..add(payload))
          .toBytes();
    } else {
      plaintext = payload;
    }

    final env = crypto.seal(type: type, plaintext: plaintext, recipient: keys);
    final messageIdHex = hex(env.messageId);

    await db.insertMessage(MessagesCompanion(
      messageId: Value(messageIdHex),
      peerId: Value(identityHex),
      direction: Value(MessageDirection.outbound),
      kind: Value(kind),
      body: Value(body),
      mediaBytes: Value(mediaBytes),
      replyToMessageId: Value(replyTo),
      timestampMs: Value(env.timestampMs),
      state: Value(MessageDeliveryState.queued),
      createdAtMs: Value(DateTime.now().millisecondsSinceEpoch),
      envelope: Value(env.toBytes()),
    ));

    // Deliver now over the best available channel (Bluetooth-first, then web).
    // On failure it stays `queued`; the outbox + relay flush retry it later.
    final dispatched = await _dispatchEnvelope(identityHex, env.toBytes());
    if (dispatched) {
      await db.markState(messageIdHex, MessageDeliveryState.sent);
      if (_connectionByIdentity[identityHex] == null) _relayed.add(messageIdHex);
    }
  }

  /// Pulls any relayed envelopes for us, routes each (so messages, acks and read
  /// receipts that arrived over the web are applied), then clears them from the
  /// relay queue. Updates [relayReachable]. No-op without a relay.
  Future<void> drainRelay() async {
    final relay = _relay;
    if (relay == null) return;
    final envelopes = await relay.inbox();
    if (envelopes == null) {
      relayReachable.value = false;
      return;
    }
    relayReachable.value = true;
    final processed = <String>[];
    for (final bytes in envelopes) {
      final Envelope env;
      try {
        env = Envelope.fromBytes(bytes);
      } on FormatException {
        continue;
      }
      await _routeEnvelope(env, hex(env.senderId));
      processed.add(hex(env.messageId));
    }
    await relay.ack(processed);
  }

  /// Pushes still-undelivered outbound messages to the relay for peers we can't
  /// currently reach over Bluetooth, so they're waiting when the peer next syncs.
  /// Each is sent to the relay at most once (the relay dedups regardless).
  Future<void> _flushPendingToRelay() async {
    final relay = _relay;
    if (relay == null) return;
    final pending = await db.allPending();
    var reached = false;
    for (final message in pending) {
      final bytes = message.envelope;
      if (bytes == null) continue;
      if (_connectionByIdentity[message.peerId] != null) continue; // BLE will do it
      if (_relayed.contains(message.messageId)) continue;
      if (await relay.send(bytes)) {
        _relayed.add(message.messageId);
        await db.markState(message.messageId, MessageDeliveryState.sent);
        reached = true;
      }
    }
    if (reached) relayReachable.value = true;
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
      case EnvelopeType.image:
        final keys = await _resolvePeerKeys(identityHex);
        if (keys == null) return;
        final messageIdHex = hex(env.messageId);
        if (await db.hasMessage(messageIdHex)) return;
        try {
          final (replyTo, payload) = _decodeReply(crypto.open(env, sender: keys));
          final isImage = env.type == EnvelopeType.image;
          await db.insertMessage(MessagesCompanion(
            messageId: Value(messageIdHex),
            peerId: Value(identityHex),
            direction: Value(MessageDirection.inbound),
            kind: Value(isImage ? MessageKind.image : MessageKind.text),
            body: Value(isImage ? '' : utf8.decode(payload)),
            mediaBytes: Value(isImage ? payload : null),
            replyToMessageId: Value(replyTo),
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
      case EnvelopeType.reaction:
        await _onReaction(env, identityHex);
      case EnvelopeType.callOffer:
        await _onCallSignal(env, identityHex, CallSignalType.offer);
      case EnvelopeType.callAnswer:
        await _onCallSignal(env, identityHex, CallSignalType.answer);
      case EnvelopeType.callIce:
        await _onCallSignal(env, identityHex, CallSignalType.ice);
      case EnvelopeType.callEnd:
        await _onCallSignal(env, identityHex, CallSignalType.end);
      case EnvelopeType.fragmentStart:
      case EnvelopeType.fragmentCont:
      case EnvelopeType.fragmentEnd:
        break;
    }
  }
}
