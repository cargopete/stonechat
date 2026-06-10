import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../chat/chat_service.dart';
import '../data/database.dart';

enum CallState { idle, outgoing, incoming, connecting, active }

/// Drives a 1:1 WebRTC call. Signaling (SDP offer/answer) rides the same sealed,
/// Ed25519-signed envelopes as chat (via [ChatService.sendCallSignal]), so the
/// DTLS fingerprint inside the SDP is authenticated end-to-end. Media is
/// DTLS-SRTP; STUN tries a direct path, our coturn is the TURN fallback.
///
/// Incoming calls ring through CallKit (driven by [FlutterCallkitIncoming]) so a
/// killed app still rings — woken by a PushKit VoIP push the relay fires for the
/// offer. ICE is non-trickle (candidates are gathered into the offer/answer SDP
/// before it's sent) so call setup survives the relay's lazy delivery without a
/// flurry of per-candidate round trips.
class CallManager extends ChangeNotifier {
  CallManager({required this.service, required this.db}) {
    _sub = service.callSignals.listen(_onSignal);
    _ckSub = FlutterCallkitIncoming.onEvent.listen(_onCallKitEvent);
  }

  final ChatService service;
  final AppDatabase db;
  StreamSubscription<CallSignal>? _sub;
  StreamSubscription<CallEvent?>? _ckSub;

  /// The CallKit call id for the in-flight incoming call (an offer's UUID).
  String? _callKitId;

  /// Set when CallKit reports "answer" before the offer has been decrypted (a
  /// cold launch woken by the VoIP push); the offer auto-accepts on arrival.
  String? _pendingAcceptId;

  Timer? _fastPoll;
  Completer<void>? _iceGathering;

  // STUN (direct attempt) + our coturn (relay fallback for cellular NATs).
  static const Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {
        'urls': 'turn:89.167.109.4:3478?transport=udp',
        'username': 'stonechat',
        'credential': 'I41xcSawpo6SipCf1CqxX3',
      },
      {
        'urls': 'turn:89.167.109.4:3478?transport=tcp',
        'username': 'stonechat',
        'credential': 'I41xcSawpo6SipCf1CqxX3',
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  CallState state = CallState.idle;
  String? peerId;
  String peerName = '';
  bool isVideo = false;
  bool muted = false;
  bool speaker = true;
  bool cameraOff = false;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  bool _renderersReady = false;
  final List<RTCIceCandidate> _pendingIce = [];
  bool _remoteSet = false;
  Map<String, dynamic>? _incomingOffer;

  bool get inCall => state != CallState.idle;
  bool get hasRemoteVideo => remoteRenderer.srcObject != null && isVideo;

  // --- Outbound -----------------------------------------------------------

  Future<void> startCall(String id, String name, {required bool video}) async {
    if (inCall) return;
    peerId = id;
    peerName = name;
    isVideo = video;
    cameraOff = false;
    _set(CallState.outgoing);
    _startFastPoll();
    await _setup(video);
    await _pc!.setLocalDescription(await _pc!.createOffer());
    final local = await _localAfterGathering();
    await service.sendCallSignal(
      id,
      CallSignalType.offer,
      jsonEncode({'sdp': local.sdp, 'type': local.type, 'video': video}),
    );
  }

  Future<void> acceptCall() async {
    final offer = _incomingOffer;
    if (state != CallState.incoming || offer == null || peerId == null) return;
    _set(CallState.connecting);
    await _setup(isVideo);
    await _pc!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'] as String, offer['type'] as String),
    );
    _remoteSet = true;
    await _flushIce();
    await _pc!.setLocalDescription(await _pc!.createAnswer());
    final local = await _localAfterGathering();
    await service.sendCallSignal(
      peerId!,
      CallSignalType.answer,
      jsonEncode({'sdp': local.sdp, 'type': local.type}),
    );
  }

  void decline() => hangUp();

  Future<void> hangUp() async {
    if (peerId != null && state != CallState.idle) {
      await service.sendCallSignal(peerId!, CallSignalType.end, '{}');
    }
    await _teardown();
  }

  // --- Controls -----------------------------------------------------------

  void toggleMute() {
    muted = !muted;
    for (final t in _localStream?.getAudioTracks() ?? const []) {
      t.enabled = !muted;
    }
    notifyListeners();
  }

  void toggleCamera() {
    cameraOff = !cameraOff;
    for (final t in _localStream?.getVideoTracks() ?? const []) {
      t.enabled = !cameraOff;
    }
    notifyListeners();
  }

  Future<void> switchCamera() async {
    final tracks = _localStream?.getVideoTracks() ?? const [];
    if (tracks.isNotEmpty) await Helper.switchCamera(tracks.first);
  }

  void toggleSpeaker() {
    speaker = !speaker;
    Helper.setSpeakerphoneOn(speaker);
    notifyListeners();
  }

  // --- Plumbing -----------------------------------------------------------

  Future<void> _ensureRenderers() async {
    if (_renderersReady) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _renderersReady = true;
  }

  Future<void> _setup(bool video) async {
    await _ensureRenderers();
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': video ? {'facingMode': 'user'} : false,
    });
    localRenderer.srcObject = _localStream;
    _pc = await createPeerConnection(_iceConfig);
    // Non-trickle: candidates are baked into the local SDP and travel inside the
    // single offer/answer envelope, so there's nothing to send per-candidate.
    // We just note when gathering finishes so the SDP is complete before send.
    _pc!.onIceGatheringState = (s) {
      if (s == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        _iceGathering?.complete();
      }
    };
    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
        notifyListeners();
      }
    };
    _pc!.onConnectionState = (s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _stopFastPoll();
        _set(CallState.active);
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _teardown();
      }
    };
    for (final track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }
    Helper.setSpeakerphoneOn(speaker);
  }

  Future<void> _onSignal(CallSignal sig) async {
    switch (sig.type) {
      case CallSignalType.offer:
        final o = jsonDecode(sig.json) as Map<String, dynamic>;
        // Duplicate delivery of the call we're already handling (a VoIP push
        // plus the inbox copy, or BLE + relay) — ignore, don't decline ourselves.
        if (sig.callId == _callKitId) return;
        if (inCall) {
          // Busy with a different call — auto-decline so the caller isn't left
          // ringing.
          await service.sendCallSignal(sig.peerId, CallSignalType.end, '{}');
          return;
        }
        peerId = sig.peerId;
        isVideo = (o['video'] as bool?) ?? false;
        cameraOff = false;
        peerName = peerLabelFor(await db.peerById(sig.peerId), sig.peerId);
        _incomingOffer = o;
        _callKitId = sig.callId;
        _startFastPoll();
        _set(CallState.incoming);
        if (_pendingAcceptId == sig.callId) {
          // Cold launch: the user already answered the CallKit ring (from the
          // VoIP push) before the offer finished decrypting. Accept now.
          _pendingAcceptId = null;
          await acceptCall();
        } else {
          await _showIncomingCallKit(sig.callId, peerName, isVideo);
        }
      case CallSignalType.answer:
        if (_pc == null) return;
        final a = jsonDecode(sig.json) as Map<String, dynamic>;
        await _pc!.setRemoteDescription(
          RTCSessionDescription(a['sdp'] as String, a['type'] as String),
        );
        _remoteSet = true;
        await _flushIce();
        if (state == CallState.outgoing) _set(CallState.connecting);
      case CallSignalType.ice:
        final c = jsonDecode(sig.json) as Map<String, dynamic>;
        final cand = RTCIceCandidate(
          c['candidate'] as String?,
          c['sdpMid'] as String?,
          c['sdpMLineIndex'] as int?,
        );
        if (_pc != null && _remoteSet) {
          await _pc!.addCandidate(cand);
        } else {
          _pendingIce.add(cand);
        }
      case CallSignalType.end:
        await _teardown();
    }
  }

  Future<void> _flushIce() async {
    for (final c in _pendingIce) {
      await _pc?.addCandidate(c);
    }
    _pendingIce.clear();
  }

  /// Waits until ICE gathering completes so the local SDP carries every
  /// candidate, then returns it. Capped so a stubborn TURN server can't wedge
  /// the call forever — whatever candidates we have by then still travel.
  Future<RTCSessionDescription> _localAfterGathering() async {
    if (_pc!.iceGatheringState !=
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      _iceGathering = Completer<void>();
      await _iceGathering!.future
          .timeout(const Duration(seconds: 4), onTimeout: () {});
      _iceGathering = null;
    }
    return (await _pc!.getLocalDescription())!;
  }

  // --- CallKit ------------------------------------------------------------

  Future<void> _showIncomingCallKit(
      String id, String name, bool video) async {
    await FlutterCallkitIncoming.showCallkitIncoming(CallKitParams(
      id: id,
      nameCaller: name,
      appName: 'stonechat',
      handle: 'stonechat',
      type: video ? 1 : 0,
      ios: const IOSParams(
        handleType: 'generic',
        supportsVideo: true,
        iconName: 'CallKitLogo',
      ),
    ));
  }

  Future<void> _onCallKitEvent(CallEvent? e) async {
    switch (e) {
      case CallEventActionCallAccept(:final id):
        if (state == CallState.incoming && _incomingOffer != null) {
          await acceptCall();
        } else {
          // Offer not decrypted yet (cold launch) — accept once it lands.
          _pendingAcceptId = id;
        }
      case CallEventActionCallDecline() ||
            CallEventActionCallEnded() ||
            CallEventActionCallTimeout():
        await hangUp();
      case CallEventActionCallToggleMute(:final isMuted):
        // User muted from the native CallKit screen — keep our state in step.
        if (muted != isMuted) toggleMute();
      default:
        break;
    }
  }

  void _startFastPoll() {
    // While a call is being set up, the lazy 15 s relay poll is far too slow for
    // the answer to come back — pull the inbox briskly until media connects.
    _fastPoll ??= Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (state == CallState.idle || state == CallState.active) {
        _stopFastPoll();
        return;
      }
      unawaited(service.drainRelay());
    });
  }

  void _stopFastPoll() {
    _fastPoll?.cancel();
    _fastPoll = null;
  }

  void _set(CallState s) {
    state = s;
    notifyListeners();
  }

  Future<void> _teardown() async {
    if (state == CallState.idle) return;
    state = CallState.idle;
    peerId = null;
    peerName = '';
    _incomingOffer = null;
    _callKitId = null;
    _pendingAcceptId = null;
    muted = false;
    speaker = true;
    cameraOff = false;
    _remoteSet = false;
    _pendingIce.clear();
    _stopFastPoll();
    // Clear any native CallKit UI (the ringer, or the system in-call screen).
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (_) {}
    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;
    for (final t in _localStream?.getTracks() ?? const []) {
      await t.stop();
    }
    await _localStream?.dispose();
    _localStream = null;
    remoteRenderer.srcObject = null;
    localRenderer.srcObject = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ckSub?.cancel();
    _stopFastPoll();
    _teardown();
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }
}
