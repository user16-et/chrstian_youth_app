import '../api_client.dart';
import 'e2ee_key_store.dart';

/// Publishes this device's public E2EE key material to the server and keeps its
/// one-time prekey pool topped up. Best-effort: if it fails, encryption simply
/// stays unavailable until a later attempt succeeds — it never blocks the app.
class E2eeRegistration {
  E2eeRegistration(this._api);

  final ApiClient _api;
  final E2eeKeyStore _store = E2eeKeyStore.instance;

  // Keep ~100 one-time prekeys available; replenish when the server reports the
  // pool has dropped below the low watermark.
  static const int _target = 100;
  static const int _lowWatermark = 20;

  bool _inFlight = false;

  /// Register (first run) or replenish (subsequent runs). Safe to call on every
  /// sign-in / app resume.
  Future<void> ensureRegistered(String token) async {
    if (!_store.supported || token.isEmpty || _inFlight) return;
    _inFlight = true;
    try {
      final deviceId = await _store.deviceId();
      final registrationId = await _store.registrationId();

      if (!await _store.isInitialised) {
        final identityKey = await _store.identitySignPublicB64();
        final identityDhKey = await _store.identityDhPublicB64();
        final spk = await _store.generateSignedPreKey();
        await _api.registerE2eeDevice(token, {
          'deviceId': deviceId,
          'registrationId': registrationId,
          'identityKey': identityKey,
          'identityDhKey': identityDhKey,
          'signedPreKeyId': spk.id,
          'signedPreKey': spk.publicKeyB64,
          'signedPreKeySignature': spk.signatureB64,
        });
        await _replenish(token, deviceId, _target);
        return;
      }

      final count = await _api.fetchE2eePreKeyCount(token, deviceId);
      if (count < _lowWatermark) {
        await _replenish(token, deviceId, _target - count);
      }
    } catch (_) {
      // Best-effort; try again next time.
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _replenish(String token, String deviceId, int count) async {
    if (count <= 0) return;
    final keys = await _store.generateOneTimePreKeys(count);
    await _api.uploadE2eePreKeys(
      token,
      deviceId,
      keys.map((k) => {'keyId': k.id, 'publicKey': k.publicKeyB64}).toList(),
    );
  }
}
