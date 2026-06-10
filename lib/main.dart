import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:sodium/sodium.dart';

import 'src/chat/chat_service.dart';
import 'src/crypto/identity.dart';
import 'src/crypto/identity_store.dart';
import 'src/data/database.dart';
import 'src/call/call_manager.dart';
import 'src/call/call_screen.dart';
import 'src/relay/relay_client.dart';
import 'src/ui/conversation_page.dart';
import 'src/ui/home_page.dart';
import 'src/ui/theme.dart';

/// Default relay ("web" channel) URL. Overridable via the `relayUrl` setting.
/// The sslip.io host resolves straight to the VPS, so it works without any
/// custom DNS; set the `relayUrl` setting to swap in relay.nbgn.app later.
const String _defaultRelayUrl = 'https://relay.89.167.109.4.sslip.io';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StonechatApp());
}

/// Long-lived singletons, assembled once at startup.
class AppBootstrap {
  AppBootstrap._(
      this.db, this.identity, this.service, this.callManager, this.demoPeer);

  final AppDatabase db;
  final DeviceIdentity identity;
  final ChatService service;
  final CallManager callManager;

  /// Non-null only under the dev-only `--dart-define=SEED=demo` build, which
  /// populates a sample conversation so screens can be captured without a real
  /// Bluetooth peer. Never set in a normal build.
  final Peer? demoPeer;

  static Future<AppBootstrap> create() async {
    final sodium = await SodiumInit.init();
    final db = AppDatabase();
    final identity = await IdentityStore(sodium).loadOrCreate();
    final crypto = EnvelopeCrypto(sodium, identity);
    // The relay is the optional "web" channel. Empty URL → pure-offline (no relay).
    final relayUrl = await db.getSetting('relayUrl') ?? _defaultRelayUrl;
    final relay = relayUrl.isEmpty
        ? null
        : RelayClient(
            baseUrl: relayUrl,
            identityHex: hex(identity.identityPublicKey),
            sign: crypto.signAuth,
          );
    final service = ChatService(db: db, crypto: crypto, relay: relay);
    // Never seed in a release build, even if the SEED define leaks into an
    // archive — this is purely a dev-only screenshot aid.
    const seed = !kReleaseMode && String.fromEnvironment('SEED') == 'demo';
    // The demo seed is purely for capturing screenshots: skip starting the live
    // transport so the BLE/notification permission prompts never fire over the
    // shot. A normal build always starts the transport.
    if (!seed) {
      // Announce the name the user chose (falling back to a generic label).
      final myName = await db.getSetting('myDisplayName') ?? 'stonechat';
      await service.start(displayName: myName);
    }
    final callManager = CallManager(service: service, db: db);
    Peer? demoPeer;
    if (seed) {
      demoPeer = await _seedDemo(db);
    }
    return AppBootstrap._(db, identity, service, callManager, demoPeer);
  }

  static Future<Peer> _seedDemo(AppDatabase db) async {
    const peerId = 'demo-mara';
    final now = DateTime.now().millisecondsSinceEpoch;
    final dummyKey = Uint8List.fromList(List<int>.filled(32, 7));
    await db.upsertPeer(
      PeersCompanion.insert(
        id: peerId,
        displayName: const Value('Mara'),
        identityPublicKey: dummyKey,
        boxPublicKey: dummyKey,
        lastSeenMs: Value(now),
      ),
    );
    const convo = <(MessageDirection, String)>[
      (MessageDirection.inbound, 'hey! did you get stonechat working?'),
      (MessageDirection.outbound, 'yep — no wifi, no signal, still talking 😄'),
      (MessageDirection.inbound, 'wild. straight over bluetooth?'),
      (MessageDirection.outbound, 'phone to phone. nothing ever hits a server.'),
      (MessageDirection.inbound, 'love it. lunch at the usual spot?'),
      (MessageDirection.outbound, 'on my way 🚶'),
    ];
    for (var i = 0; i < convo.length; i++) {
      final (dir, body) = convo[i];
      final t = now - (convo.length - i) * 60000;
      await db.insertMessage(
        MessagesCompanion.insert(
          messageId: 'demo-$i',
          peerId: peerId,
          direction: dir,
          body: body,
          timestampMs: t,
          state: dir == MessageDirection.inbound
              ? MessageDeliveryState.received
              : MessageDeliveryState.acked,
          createdAtMs: t,
        ),
      );
    }
    return (await db.peerById(peerId))!;
  }
}

class StonechatApp extends StatelessWidget {
  const StonechatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'stonechat',
      debugShowCheckedModeBanner: false,
      theme: stonechatTheme(),
      darkTheme: stonechatTheme(),
      themeMode: ThemeMode.dark,
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
        // Dev-only seed opens straight into the sample conversation for a clean
        // screenshot; normal builds always land on the peer list.
        final Widget home = boot.demoPeer != null
            ? ConversationPage(
                service: boot.service,
                db: boot.db,
                peer: boot.demoPeer!,
                callManager: boot.callManager,
              )
            : HomePage(
                service: boot.service,
                db: boot.db,
                callManager: boot.callManager,
              );
        return CallHost(manager: boot.callManager, child: home);
      },
    );
  }
}
