import 'package:flutter/material.dart';
import 'package:sodium/sodium.dart';

import 'src/chat/chat_service.dart';
import 'src/crypto/identity.dart';
import 'src/data/database.dart';
import 'src/transport/transport_api.g.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StonechatApp());
}

/// Holds the long-lived singletons. In a real build these would live behind a
/// proper DI/provider; for the Stage 1 skeleton a plain bootstrap is enough.
class AppBootstrap {
  AppBootstrap._(this.sodium, this.db, this.identity, this.service);

  final Sodium sodium;
  final AppDatabase db;
  final DeviceIdentity identity;
  final ChatService service;

  static Future<AppBootstrap> create() async {
    final sodium = await SodiumInit.init();
    final db = AppDatabase();
    // TODO(stage2): persist the identity in the Keychain instead of minting a
    // fresh one each launch.
    final identity = DeviceIdentity.generate(sodium);
    final crypto = EnvelopeCrypto(sodium, identity);
    final service = ChatService(db: db, crypto: crypto);
    await service.start(displayName: 'stonechat');
    return AppBootstrap._(sodium, db, identity, service);
  }
}

class StonechatApp extends StatelessWidget {
  const StonechatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'stonechat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<AppBootstrap> _bootstrap = AppBootstrap.create();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('stonechat')),
      body: FutureBuilder<AppBootstrap>(
        future: _bootstrap,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Startup failed: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _PeerList(service: snapshot.data!.service);
        },
      ),
    );
  }
}

/// Live view of transport events: adapter state + discovered peers.
class _PeerList extends StatelessWidget {
  const _PeerList({required this.service});

  final ChatService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TransportEvent>(
      stream: service.events,
      builder: (context, _) {
        // The skeleton simply reflects that events are flowing; a real UI would
        // keep a reduced model of discovered peers + connection state.
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Scanning for nearby stonechat devices…\n\n'
              'Transport, crypto and storage are wired. Pair two devices in '
              'the foreground to exchange a hello and start chatting.',
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}
