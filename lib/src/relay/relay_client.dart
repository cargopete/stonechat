import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// HTTP client for the stonechat relay — the optional "web" channel used when
/// Bluetooth can't reach the peer. The relay only ever sees already-sealed
/// (end-to-end encrypted) envelopes; content stays unreadable to it.
///
/// `register`/`inbox`/`ack` are authenticated by signing `stonechat-auth|<ts>`
/// with this device's Ed25519 identity key (proving ownership of the identity).
class RelayClient {
  RelayClient({
    required String baseUrl,
    required this.identityHex,
    required this.sign,
  }) : baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;

  final String baseUrl;
  final String identityHex;

  /// Signs `stonechat-auth|<ts>` with the Ed25519 identity secret key.
  final Uint8List Function(int ts) sign;

  static const Duration _timeout = Duration(seconds: 12);

  Map<String, dynamic> _authBody() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return {'identity': identityHex, 'ts': ts, 'sig': _hex(sign(ts))};
  }

  /// Posts a sealed envelope for relaying. Returns true on accept (202).
  Future<bool> send(Uint8List envelope) async {
    try {
      final r = await http
          .post(
            Uri.parse('$baseUrl/send'),
            headers: {'content-type': 'application/octet-stream'},
            body: envelope,
          )
          .timeout(_timeout);
      return r.statusCode == 202;
    } catch (_) {
      return false;
    }
  }

  /// Fetches queued sealed envelopes for this identity, or null if unreachable
  /// (which the caller treats as "web channel down").
  Future<List<Uint8List>?> inbox() async {
    try {
      final r = await http
          .post(
            Uri.parse('$baseUrl/inbox'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode(_authBody()),
          )
          .timeout(_timeout);
      if (r.statusCode != 200) return null;
      final list = ((jsonDecode(r.body) as Map)['envelopes'] as List)
          .cast<String>();
      return list.map(base64.decode).toList();
    } catch (_) {
      return null;
    }
  }

  /// Drops delivered envelopes from this identity's relay queue.
  Future<void> ack(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    try {
      await http
          .post(
            Uri.parse('$baseUrl/ack'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({..._authBody(), 'message_ids': messageIds}),
          )
          .timeout(_timeout);
    } catch (_) {
      // best-effort
    }
  }

  /// Registers (or refreshes) this identity's APNs push token, plus the optional
  /// PushKit VoIP token used to ring incoming calls on a killed app.
  Future<void> register(String pushToken, {String? voipToken}) async {
    try {
      await http
          .post(
            Uri.parse('$baseUrl/register'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              ..._authBody(),
              'push_token': pushToken,
              'voip_token': ?voipToken,
            }),
          )
          .timeout(_timeout);
    } catch (_) {
      // best-effort
    }
  }

  Future<bool> health() async {
    try {
      final r =
          await http.get(Uri.parse('$baseUrl/health')).timeout(_timeout);
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static String _hex(Uint8List b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
}
