import 'package:flutter/material.dart';
import 'package:sodium/sodium.dart';

import 'src/chat/chat_service.dart';
import 'src/crypto/identity.dart';
import 'src/crypto/identity_store.dart';
import 'src/data/database.dart';
import 'src/ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StonechatApp());
}

/// Long-lived singletons, assembled once at startup.
class AppBootstrap {
  AppBootstrap._(this.db, this.identity, this.service);

  final AppDatabase db;
  final DeviceIdentity identity;
  final ChatService service;

  static Future<AppBootstrap> create() async {
    final sodium = await SodiumInit.init();
    final db = AppDatabase();
    final identity = await IdentityStore(sodium).loadOrCreate();
    final crypto = EnvelopeCrypto(sodium, identity);
    final service = ChatService(db: db, crypto: crypto);
    await service.start(displayName: 'stonechat');
    return AppBootstrap._(db, identity, service);
  }
}

class StonechatApp extends StatelessWidget {
  const StonechatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'stonechat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const _Bootstrapper(),
    );
  }
}

class _Bootstrapper extends StatefulWidget {
  const _Bootstrapper();

  @override
  State<_Bootstrapper> createState() => _BootstrapperState();
}

class _BootstrapperState extends State<_Bootstrapper> {
  late final Future<AppBootstrap> _future = AppBootstrap.create();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppBootstrap>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Startup failed: ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final boot = snapshot.data!;
        return HomePage(service: boot.service, db: boot.db);
      },
    );
  }
}
