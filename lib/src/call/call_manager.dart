import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../chat/chat_service.dart';
import '../data/database.dart';

enum CallState { idle, outgoing, incoming, connecting, active }

/// Drives a 1:1 WebRTC call. Signaling (SDP offer/answer + ICE) rides the same
/// sealed, Ed25519-signed envelopes as chat (via [ChatService.sendCallSignal]),
/// so the DTLS fingerprint inside the SDP is authenticated end-to-end. Media is
/// DTLS-SRTP; STUN tries a direct path, our coturn is the TURN fallback.
class CallManager extends ChangeNotifier {
  CallManager({required this.service, required this.db}) {
    _sub = service.callSignals.listen(_onSignal);
  }

  final ChatService service;
  final AppDatabase db;
  StreamSubscription<CallSignal>? _sub;

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
    await _setup(video);
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    await service.sendCallSignal(
      id,
      CallSignalType.offer,
      jsonEncode({'sdp': offer.sdp, 'type': offer.type, 'video': video}),
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
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    await service.sendCallSignal(
      peerId!,
      CallSignalType.answer,
      jsonEncode({'sdp': answer.sdp, 'type': answer.type}),
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
    _pc!.onIceCandidate = (c) {
      if (c.candidate == null || peerId == null) return;
      service.sendCallSignal(
        peerId!,
        CallSignalType.ice,
        jsonEncode({
          'candidate': c.candidate,
          'sdpMid': c.sdpMid,
          'sdpMLineIndex': c.sdpMLineIndex,
        }),
      );
    };
    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
        notifyListeners();
      }
    };
    _pc!.onConnectionState = (s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
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
        if (inCall) {
          // Busy — auto-decline so the caller isn't left ringing.
          await service.sendCallSignal(sig.peerId, CallSignalType.end, '{}');
          return;
        }
        peerId = sig.peerId;
        isVideo = (o['video'] as bool?) ?? false;
        cameraOff = false;
        peerName = peerLabelFor(await db.peerById(sig.peerId), sig.peerId);
        _incomingOffer = o;
        _set(CallState.incoming);
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
    muted = false;
    speaker = true;
    cameraOff = false;
    _remoteSet = false;
    _pendingIce.clear();
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
    _teardown();
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }
}
