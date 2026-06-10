import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../ui/theme.dart';
import 'call_manager.dart';

/// Listens to the call manager and presents the call full-screen (as a root
/// route, so it covers every pushed page) whenever a call is active, dismissing
/// it when the call ends.
class CallHost extends StatefulWidget {
  const CallHost({super.key, required this.manager, required this.child});

  final CallManager manager;
  final Widget child;

  @override
  State<CallHost> createState() => _CallHostState();
}

class _CallHostState extends State<CallHost> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    widget.manager.addListener(_sync);
  }

  @override
  void dispose() {
    widget.manager.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    // Incoming calls ring through CallKit's native UI; our screen takes over
    // only once the call is outgoing or has been answered.
    final inCall = widget.manager.inCall &&
        widget.manager.state != CallState.incoming;
    if (inCall && !_showing) {
      _showing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true)
            .push(MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (_) => CallScreen(manager: widget.manager),
            ))
            .then((_) {
          _showing = false;
          // Dismissed by hand mid-call → hang up.
          if (widget.manager.inCall) widget.manager.hangUp();
        });
      });
    } else if (!inCall && _showing) {
      _showing = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context, rootNavigator: true).maybePop();
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.manager});
  final CallManager manager;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  DateTime? _activeSince;

  CallManager get m => widget.manager;

  @override
  void initState() {
    super.initState();
    m.addListener(_onChange);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (m.state == CallState.active && _activeSince != null && mounted) {
        setState(() => _elapsed = DateTime.now().difference(_activeSince!));
      }
    });
  }

  void _onChange() {
    if (m.state == CallState.active && _activeSince == null) {
      _activeSince = DateTime.now();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    m.removeListener(_onChange);
    _ticker?.cancel();
    super.dispose();
  }

  String _status() => switch (m.state) {
        CallState.outgoing => 'Calling…',
        CallState.incoming => m.isVideo ? 'Incoming video call' : 'Incoming call',
        CallState.connecting => 'Connecting…',
        CallState.active => _fmt(_elapsed),
        CallState.idle => '',
      };

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final videoActive =
        m.isVideo && m.state == CallState.active && m.remoteRenderer.srcObject != null;
    return Material(
      color: Stone.bg,
      child: SafeArea(
        child: Stack(
          children: [
            if (videoActive) Positioned.fill(child: _videoLayer()) else _portrait(),
            if (videoActive) _videoOverlay(),
          ],
        ),
      ),
    );
  }

  // --- Audio / pre-connect portrait --------------------------------------

  Widget _portrait() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 36),
      child: Column(
        children: [
          const Spacer(flex: 2),
          _Avatar(label: m.peerName),
          const SizedBox(height: 22),
          Text(
            m.peerName,
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w700, color: Stone.ink),
          ),
          const SizedBox(height: 8),
          Text(_status(),
              style: const TextStyle(fontSize: 15, color: Stone.inkDim)),
          const Spacer(flex: 3),
          if (m.state == CallState.incoming) _incomingControls() else _activeControls(),
        ],
      ),
    );
  }

  // --- Video --------------------------------------------------------------

  Widget _videoLayer() {
    return RTCVideoView(
      m.remoteRenderer,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }

  Widget _videoOverlay() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.peerName,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    Text(_fmt(_elapsed),
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              if (!m.cameraOff)
                Container(
                  width: 96,
                  height: 132,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: RTCVideoView(m.localRenderer, mirror: true),
                ),
            ],
          ),
          const Spacer(),
          _activeControls(),
        ],
      ),
    );
  }

  // --- Controls -----------------------------------------------------------

  Widget _incomingControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CallButton(
          icon: Icons.call_end_rounded,
          label: 'Decline',
          bg: const Color(0xFFEF4444),
          onTap: m.decline,
          big: true,
        ),
        _CallButton(
          icon: m.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
          label: 'Accept',
          bg: Stone.online,
          fg: Colors.black,
          onTap: () => m.acceptCall(),
          big: true,
        ),
      ],
    );
  }

  Widget _activeControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CallButton(
              icon: m.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: 'Mute',
              active: m.muted,
              onTap: m.toggleMute,
            ),
            _CallButton(
              icon: m.speaker ? Icons.volume_up_rounded : Icons.volume_down_rounded,
              label: 'Speaker',
              active: m.speaker,
              onTap: m.toggleSpeaker,
            ),
            if (m.isVideo)
              _CallButton(
                icon: m.cameraOff
                    ? Icons.videocam_off_rounded
                    : Icons.videocam_rounded,
                label: 'Camera',
                active: !m.cameraOff,
                onTap: m.toggleCamera,
              ),
            if (m.isVideo)
              _CallButton(
                icon: Icons.cameraswitch_rounded,
                label: 'Flip',
                onTap: m.switchCamera,
              ),
          ],
        ),
        const SizedBox(height: 24),
        _CallButton(
          icon: Icons.call_end_rounded,
          label: '',
          bg: const Color(0xFFEF4444),
          onTap: m.hangUp,
          big: true,
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final initial =
        label.trim().isEmpty ? '?' : label.trim().characters.first.toUpperCase();
    return Container(
      width: 112,
      height: 112,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2F3A), Color(0xFF161A21)],
        ),
      ),
      child: Text(
        initial,
        style: const TextStyle(
            color: Stone.accent, fontWeight: FontWeight.w700, fontSize: 46),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.onTap,
    this.label,
    this.bg,
    this.fg,
    this.active = false,
    this.big = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final Color? bg;
  final Color? fg;
  final bool active;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 68.0 : 58.0;
    final background =
        bg ?? (active ? Stone.accent : Colors.white.withValues(alpha: 0.12));
    final foreground = fg ?? (active && bg == null ? Stone.accentInk : Colors.white);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: background, shape: BoxShape.circle),
            child: Icon(icon, color: foreground, size: big ? 30 : 26),
          ),
        ),
        if (label != null && label!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(label!,
              style: const TextStyle(fontSize: 12, color: Stone.inkDim)),
        ],
      ],
    );
  }
}
