import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Owns this device's long-lived E2EE key material. **Private keys are generated
/// on-device and never leave it** — they live in the platform keystore
/// (Android Keystore / iOS Keychain) via [FlutterSecureStorage]; only public
/// material is ever published to the server.
///
/// Keys:
///  - identity signing key (Ed25519) — its public half is the device's stable
///    identity, used for safety-number verification and to sign the signed
///    prekey.
///  - identity DH key (X25519) — used in the X3DH key agreement.
///  - a signed prekey (X25519), rotated periodically, signed by the identity.
///  - a pool of one-time prekeys (X25519), each consumed by one session hand-off.
///
/// This is the key-management foundation. The message ratchet that consumes
/// these keys is a separate, security-reviewed layer.
class E2eeKeyStore {
  E2eeKeyStore._();
  static final E2eeKeyStore instance = E2eeKeyStore._();

  // Defaults are hardware-backed where available (Android Keystore / iOS
  // Keychain, with the device unlocked).
  static const _storage = FlutterSecureStorage();

  static const _kMyUserId = 'e2ee.myUserId';
  static const _kDeviceId = 'e2ee.deviceId';
  static const _kRegistrationId = 'e2ee.registrationId';
  static const _kIdentitySign = 'e2ee.identity.sign'; // Ed25519 private seed
  static const _kIdentityDh = 'e2ee.identity.dh'; // X25519 private
  static const _kSignedPreKeyId = 'e2ee.spk.id';
  static const _kSignedPreKeyPriv = 'e2ee.spk.priv';
  static const _kOneTimePrefix = 'e2ee.otk.'; // + keyId -> private

  final _ed25519 = Ed25519();
  final _x25519 = X25519();
  final _rng = Random.secure();

  /// E2EE relies on a hardware-backed keystore, which browsers don't provide,
  /// so it is mobile-only (matches the recommended rollout).
  bool get supported => !kIsWeb;

  String _b64(List<int> bytes) => base64Encode(bytes);
  List<int> _unb64(String s) => base64Decode(s);

  int _rand31() => _rng.nextInt(0x7fffffff);

  /// Whether this device already has a registered identity.
  Future<bool> get isInitialised async =>
      (await _storage.read(key: _kIdentitySign)) != null;

  Future<void> saveMyUserId(String id) async {
    if (id.isNotEmpty) await _storage.write(key: _kMyUserId, value: id);
  }

  Future<String?> myUserId() => _storage.read(key: _kMyUserId);

  Future<String> deviceId() async {
    var id = await _storage.read(key: _kDeviceId);
    if (id == null || id.isEmpty) {
      // 16 random bytes, url-safe — opaque, stable per install.
      final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
      id = base64Url.encode(bytes).replaceAll('=', '');
      await _storage.write(key: _kDeviceId, value: id);
    }
    return id;
  }

  Future<int> registrationId() async {
    final existing = await _storage.read(key: _kRegistrationId);
    if (existing != null) return int.parse(existing);
    final id = _rand31();
    await _storage.write(key: _kRegistrationId, value: '$id');
    return id;
  }

  Future<SimpleKeyPair> _identitySignKeyPair() async {
    final seed = await _storage.read(key: _kIdentitySign);
    if (seed != null) {
      return _ed25519.newKeyPairFromSeed(_unb64(seed));
    }
    final pair = await _ed25519.newKeyPair();
    final data = await pair.extract();
    await _storage.write(key: _kIdentitySign, value: _b64(data.bytes));
    return pair;
  }

  Future<SimpleKeyPair> _identityDhKeyPair() async {
    final priv = await _storage.read(key: _kIdentityDh);
    if (priv != null) {
      // X25519 private key stored as raw bytes; reconstruct the pair.
      final pub = await _x25519.newKeyPairFromSeed(_unb64(priv));
      return pub;
    }
    final pair = await _x25519.newKeyPair();
    final data = await pair.extract();
    await _storage.write(key: _kIdentityDh, value: _b64(data.bytes));
    return pair;
  }

  Future<String> identitySignPublicB64() async {
    final pub = await (await _identitySignKeyPair()).extractPublicKey();
    return _b64(pub.bytes);
  }

  Future<String> identityDhPublicB64() async {
    final pub = await (await _identityDhKeyPair()).extractPublicKey();
    return _b64(pub.bytes);
  }

  /// Generate (or rotate) the signed prekey. Returns the public bundle fields.
  Future<SignedPreKeyPublic> generateSignedPreKey() async {
    final pair = await _x25519.newKeyPair();
    final data = await pair.extract();
    final id = _rand31();
    await _storage.write(key: _kSignedPreKeyId, value: '$id');
    await _storage.write(key: _kSignedPreKeyPriv, value: _b64(data.bytes));
    final pub = await pair.extractPublicKey();
    // Sign the signed prekey's public bytes with the identity signing key.
    final signature = await _ed25519.sign(pub.bytes, keyPair: await _identitySignKeyPair());
    return SignedPreKeyPublic(
      id: id,
      publicKeyB64: _b64(pub.bytes),
      signatureB64: _b64(signature.bytes),
    );
  }

  /// Generate a batch of one-time prekeys, persist their private halves, and
  /// return the public halves to upload.
  Future<List<OneTimePreKeyPublic>> generateOneTimePreKeys(int count) async {
    final out = <OneTimePreKeyPublic>[];
    for (var i = 0; i < count; i++) {
      final pair = await _x25519.newKeyPair();
      final data = await pair.extract();
      final id = _rand31();
      await _storage.write(key: '$_kOneTimePrefix$id', value: _b64(data.bytes));
      final pub = await pair.extractPublicKey();
      out.add(OneTimePreKeyPublic(id: id, publicKeyB64: _b64(pub.bytes)));
    }
    return out;
  }

  // ---- Private-key access for X3DH (responder side) ----

  /// The identity DH key pair (private) — needed for both X3DH roles.
  Future<SimpleKeyPair> identityDhKeyPair() => _identityDhKeyPair();

  /// A fresh single-use ephemeral key pair (initiator side).
  Future<SimpleKeyPair> newEphemeral() => _x25519.newKeyPair();

  /// The signed-prekey key pair for [id], or null if it's been rotated away
  /// (this store keeps only the current signed prekey).
  Future<SimpleKeyPair?> signedPreKeyKeyPair(int id) async {
    final storedId = await _storage.read(key: _kSignedPreKeyId);
    final priv = await _storage.read(key: _kSignedPreKeyPriv);
    if (storedId == null || priv == null || int.parse(storedId) != id) return null;
    return _x25519.newKeyPairFromSeed(_unb64(priv));
  }

  /// The one-time prekey key pair for [id], consuming it (each is single-use).
  /// Returns null if already consumed / unknown.
  Future<SimpleKeyPair?> takeOneTimePreKey(int id) async {
    final priv = await _storage.read(key: '$_kOneTimePrefix$id');
    if (priv == null) return null;
    await _storage.delete(key: '$_kOneTimePrefix$id');
    return _x25519.newKeyPairFromSeed(_unb64(priv));
  }

  /// Wipe every private key (e.g. on sign-out or account reset). After this the
  /// device must re-register and past encrypted history becomes unreadable.
  Future<void> wipe() async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith('e2ee.')) await _storage.delete(key: key);
    }
  }
}

class SignedPreKeyPublic {
  const SignedPreKeyPublic({required this.id, required this.publicKeyB64, required this.signatureB64});
  final int id;
  final String publicKeyB64;
  final String signatureB64;
}

class OneTimePreKeyPublic {
  const OneTimePreKeyPublic({required this.id, required this.publicKeyB64});
  final int id;
  final String publicKeyB64;
}
