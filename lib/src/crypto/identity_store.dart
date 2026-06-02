import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sodium/sodium.dart';

import 'identity.dart';

/// Persists the device's long-term [DeviceIdentity] in the iOS Keychain so a
/// peer can recognise this device across launches.
///
/// Accessibility is `first_unlock_this_device`: the keys become readable after
/// the first unlock following a reboot and never leave the device — which is
/// also what lets the native transport sign/decrypt during background wakes
/// (the device has, by definition, been unlocked at least once).
class IdentityStore {
  IdentityStore(this._sodium, {FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final Sodium _sodium;
  final FlutterSecureStorage _storage;

  static const _signPkKey = 'identity.sign.pk';
  static const _signSkKey = 'identity.sign.sk';
  static const _boxPkKey = 'identity.box.pk';
  static const _boxSkKey = 'identity.box.sk';

  /// Loads the stored identity, or generates + persists a fresh one on first
  /// run.
  Future<DeviceIdentity> loadOrCreate() async {
    final existing = await _load();
    if (existing != null) return existing;
    final identity = DeviceIdentity.generate(_sodium);
    await _save(identity);
    return identity;
  }

  Future<DeviceIdentity?> _load() async {
    final signPk = await _storage.read(key: _signPkKey);
    final signSk = await _storage.read(key: _signSkKey);
    final boxPk = await _storage.read(key: _boxPkKey);
    final boxSk = await _storage.read(key: _boxSkKey);
    if (signPk == null || signSk == null || boxPk == null || boxSk == null) {
      return null;
    }
    return DeviceIdentity(
      signKeyPair: KeyPair(
        publicKey: base64Decode(signPk),
        secretKey: SecureKey.fromList(_sodium, base64Decode(signSk)),
      ),
      boxKeyPair: KeyPair(
        publicKey: base64Decode(boxPk),
        secretKey: SecureKey.fromList(_sodium, base64Decode(boxSk)),
      ),
    );
  }

  Future<void> _save(DeviceIdentity identity) async {
    await _storage.write(
        key: _signPkKey,
        value: base64Encode(identity.signKeyPair.publicKey));
    await _storage.write(
        key: _signSkKey,
        value: base64Encode(identity.signKeyPair.secretKey.extractBytes()));
    await _storage.write(
        key: _boxPkKey, value: base64Encode(identity.boxKeyPair.publicKey));
    await _storage.write(
        key: _boxSkKey,
        value: base64Encode(identity.boxKeyPair.secretKey.extractBytes()));
  }
}
