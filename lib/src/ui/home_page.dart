import 'package:flutter/material.dart';

import '../call/call_manager.dart';
import '../chat/chat_service.dart';
import '../data/database.dart';
import '../transport/transport_api.g.dart';
import 'conversation_page.dart';
import 'theme.dart';

/// A short, human-ish label for a peer: their nickname, else announced name,
/// else "Peer XXXX".
String peerLabel(Peer peer) => peerLabelFor(peer, peer.id);

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.service,
    required this.db,
    required this.callManager,
  });

  final ChatService service;
  final AppDatabase db;
  final CallManager callManager;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  ChatService get service => widget.service;
  AppDatabase get db => widget.db;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      service.resume();
    }
  }

  Future<void> _editMyName() async {
    final current = await db.getSetting('myDisplayName') ?? '';
    if (!mounted) return;
    final controller = TextEditingController(text: current);
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'What nearby people see'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty) return;
    await db.setSetting('myDisplayName', result);
    await service.updateMyName(result);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You\'ll show up as "$result"')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'stonechat',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        actions: [
          IconButton(
            tooltip: 'Reconnect',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              service.resume();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reconnecting…'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Your name',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: _editMyName,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _AdapterBanner(service: service),
          Expanded(
            child: StreamBuilder<List<Peer>>(
              stream: db.watchPeers(),
              builder: (context, snapshot) {
                final peers = snapshot.data ?? const [];
                if (peers.isEmpty) return const _EmptyState();
                return ValueListenableBuilder<Set<String>>(
                  valueListenable: service.onlineIdentities,
                  builder: (context, online, _) {
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: peers.length,
                      separatorBuilder: (_, _) => const Padding(
                        padding: EdgeInsets.only(left: 78),
                        child: Divider(height: 1),
                      ),
                      itemBuilder: (context, i) {
                        final peer = peers[i];
                        return _PeerRow(
                          peer: peer,
                          online: online.contains(peer.id),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ConversationPage(
                                service: service,
                                db: db,
                                peer: peer,
                                callManager: widget.callManager,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PeerRow extends StatelessWidget {
  const _PeerRow({
    required this.peer,
    required this.online,
    required this.onTap,
  });

  final Peer peer;
  final bool online;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = peerLabel(peer);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            _Monogram(label: label, online: online),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Stone.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    online ? 'Active now' : 'Tap to chat',
                    style: TextStyle(
                      fontSize: 13,
                      color: online ? Stone.online : Stone.inkDim,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Stone.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.label, required this.online});
  final String label;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final initial =
        label.trim().isEmpty ? '?' : label.trim().characters.first.toUpperCase();
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A2F3A), Color(0xFF1B1F28)],
              ),
              border: online
                  ? Border.all(color: Stone.online, width: 2)
                  : Border.all(color: Stone.hairline, width: 1),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Stone.accent,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ),
          if (online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: Stone.online,
                  shape: BoxShape.circle,
                  border: Border.all(color: Stone.bg, width: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A subtle status strip, shown only when the radio isn't simply running.
class _AdapterBanner extends StatelessWidget {
  const _AdapterBanner({required this.service});

  final ChatService service;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BleAdapterState>(
      valueListenable: service.adapterState,
      builder: (context, state, _) {
        if (state == BleAdapterState.poweredOn) return const SizedBox.shrink();
        final (text, color) = switch (state) {
          BleAdapterState.poweredOff => ('Bluetooth is off', Color(0xFFF87171)),
          BleAdapterState.unauthorized =>
            ('Bluetooth permission denied', Color(0xFFF87171)),
          BleAdapterState.unsupported =>
            ('Bluetooth not supported', Color(0xFFF87171)),
          _ => ('Starting Bluetooth…', Stone.accent),
        };
        return Container(
          width: double.infinity,
          color: color.withValues(alpha: 0.10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: [
              Icon(Icons.bluetooth, size: 16, color: color),
              const SizedBox(width: 8),
              Text(text, style: TextStyle(color: color, fontSize: 13)),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Stone.surfaceHigh,
              ),
              child: const Icon(Icons.bluetooth_searching_rounded,
                  size: 30, color: Stone.accent),
            ),
            const SizedBox(height: 18),
            const Text(
              'No one here yet',
              style: TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w700, color: Stone.ink),
            ),
            const SizedBox(height: 8),
            const Text(
              'Open stonechat on another phone nearby to find each other — or '
              'connect over the internet once you’ve met once.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.45, color: Stone.inkDim),
            ),
          ],
        ),
      ),
    );
  }
}
