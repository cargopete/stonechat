import 'package:flutter/material.dart';

import '../chat/chat_service.dart';
import '../data/database.dart';
import '../transport/transport_api.g.dart';
import 'conversation_page.dart';

/// A short, human-ish label for a peer: their nickname, else announced name,
/// else "Peer XXXX".
String peerLabel(Peer peer) => peerLabelFor(peer, peer.id);

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.service, required this.db});

  final ChatService service;
  final AppDatabase db;

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
      // Reconcile anything the native side received while we were backgrounded.
      service.drainInbox();
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
          decoration: const InputDecoration(
            hintText: 'What nearby people see',
          ),
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
        title: const Text('stonechat'),
        actions: [
          IconButton(
            tooltip: 'Your name',
            icon: const Icon(Icons.badge_outlined),
            onPressed: _editMyName,
          ),
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
                if (peers.isEmpty) {
                  return const _EmptyState();
                }
                return ValueListenableBuilder<Set<String>>(
                  valueListenable: service.onlineIdentities,
                  builder: (context, online, _) {
                    return ListView.separated(
                      itemCount: peers.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final peer = peers[i];
                        final isOnline = online.contains(peer.id);
                        return ListTile(
                          leading: _PresenceDot(online: isOnline),
                          title: Text(peerLabel(peer)),
                          subtitle: Text(
                            peer.id.substring(0, peer.id.length.clamp(0, 16)),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ConversationPage(
                                service: service,
                                db: db,
                                peer: peer,
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

class _AdapterBanner extends StatelessWidget {
  const _AdapterBanner({required this.service});

  final ChatService service;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BleAdapterState>(
      valueListenable: service.adapterState,
      builder: (context, state, _) {
        final (text, color) = switch (state) {
          BleAdapterState.poweredOn => ('Scanning for nearby devices…', Colors.teal),
          BleAdapterState.poweredOff => ('Bluetooth is off', Colors.red),
          BleAdapterState.unauthorized => ('Bluetooth permission denied', Colors.red),
          BleAdapterState.unsupported => ('Bluetooth not supported', Colors.red),
          _ => ('Starting Bluetooth…', Colors.orange),
        };
        return Container(
          width: double.infinity,
          color: color.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.bluetooth, size: 18, color: color),
              const SizedBox(width: 8),
              Text(text, style: TextStyle(color: color)),
            ],
          ),
        );
      },
    );
  }
}

class _PresenceDot extends StatelessWidget {
  const _PresenceDot({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.circle,
      size: 14,
      color: online ? Colors.green : Colors.grey,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No peers yet.\n\nBring another stonechat device nearby, '
          'in the foreground, to exchange a hello.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
