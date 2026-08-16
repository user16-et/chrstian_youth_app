import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api_client.dart';
import 'e2ee_key_store.dart';
import 'e2ee_session.dart';

/// Orchestrates 1:1 E2EE sessions on top of [E2eeKeyStore] (this device's keys),
/// [E2eeX3dh]/[E2eeSession] (the crypto), and the server key directory.
///
/// A session is per (conversation, peer user, peer device). On the first message
/// the initiator fetches the peer's prekey bundle, runs X3DH, and attaches a
/// handshake header ("hs") so the responder can derive the same secret. The
/// header keeps being sent until we hear back (so a lost first message still
/// establishes the session); the responder ignores repeat headers once it has a
/// session.
///
/// Phase 1: single device per user. Multi-device is shaped in (envelopes are
/// keyed by "userId:deviceId") but new peer devices are only picked up when a
/// fresh session is established.
class E2eeManager {
  E2eeManager(this._api);

  final ApiClient _api;
  final E2eeKeyStore _keys = E2eeKeyStore.instance;
  static const _storage = FlutterSecureStorage();

  bool get supported => _keys.supported;

  String _sessionKey(String conversationId, String peerUserId, String peerDeviceId) =>
      'e2ee.sess.$conversationId.$peerUserId.$peerDeviceId';

  Future<_SessionRecord?> _loadRecord(String key) async {
    final raw = await _storage.read(key: key);
    if (raw == null) return null;
    try {
      return _SessionRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveRecord(String key, _SessionRecord rec) =>
      _storage.write(key: key, value: jsonEncode(rec.toJson()));

  // Existing sessions for a peer in a conversation: peerDeviceId -> storage key.
  Future<Map<String, String>> _existingSessions(String conversationId, String peerUserId) async {
    final prefix = 'e2ee.sess.$conversationId.$peerUserId.';
    final all = await _storage.readAll();
    final out = <String, String>{};
    for (final key in all.keys) {
      if (key.startsWith(prefix)) {
        out[key.substring(prefix.length)] = key;
      }
    }
    return out;
  }

  List<int> _pubBytes(SimplePublicKey k) => k.bytes;

  /// Encrypt [plaintext] for every device the recipient has published. Returns
  /// the metadata to merge into the outgoing message ({encrypted, envelope,
  /// senderDeviceId}), or null when E2EE isn't possible (unsupported platform,
  /// recipient has no keys) — in which case the caller sends plaintext.
  Future<Map<String, dynamic>?> encryptMessage({
    required String token,
    required String conversationId,
    required String recipientUserId,
    required String plaintext,
  }) async {
    if (!supported) return null;
    try {
      final myDeviceId = await _keys.deviceId();
      final envelope = <String, dynamic>{};
      final existing = await _existingSessions(conversationId, recipientUserId);

      if (existing.isEmpty) {
        // First message: establish sessions from the peer's prekey bundles.
        final bundles = await _api.fetchE2eeBundle(token, recipientUserId);
        for (final bundle in bundles) {
          final peerDeviceId = '${bundle['deviceId']}';
          final rec = await _establishInitiator(bundle);
          if (rec == null) continue;
          final msg = await rec.session.encrypt(plaintext);
          // Keyed by the recipient's globally-unique device id, so a device can
          // find its own entry without needing to know its user id here.
          envelope[peerDeviceId] = {'hs': rec.pendingHs, 'msg': msg};
          await _saveRecord(_sessionKey(conversationId, recipientUserId, peerDeviceId), rec);
        }
      } else {
        for (final e in existing.entries) {
          final rec = await _loadRecord(e.value);
          if (rec == null) continue;
          final msg = await rec.session.encrypt(plaintext);
          final entry = <String, dynamic>{'msg': msg};
          // Keep sending the handshake until the peer has replied.
          if (rec.session.recvCount == 0 && rec.pendingHs != null) entry['hs'] = rec.pendingHs;
          envelope[e.key] = entry;
          await _saveRecord(e.value, rec);
        }
      }

      if (envelope.isEmpty) return null;
      // senderDeviceId rides in metadata (both message backends preserve the
      // caller's metadata and merge encrypted+envelope onto it).
      return {
        'encrypted': true,
        'envelope': envelope,
        'metadata': {'senderDeviceId': myDeviceId},
      };
    } catch (_) {
      // Any failure → fall back to plaintext rather than dropping the message.
      return null;
    }
  }

  Future<_SessionRecord?> _establishInitiator(Map<String, dynamic> bundle) async {
    final identityKey = '${bundle['identityKey']}';
    final signedPreKey = '${bundle['signedPreKey']}';
    final signature = '${bundle['signedPreKeySignature']}';
    // Reject a forged signed prekey (server key-swap protection).
    final ok = await E2eeX3dh.verifySignedPreKey(
      signedPreKeyB64: signedPreKey,
      signatureB64: signature,
      identitySignPubB64: identityKey,
    );
    if (!ok) return null;

    final identityDh = await _keys.identityDhKeyPair();
    final ephemeral = await _keys.newEphemeral();
    final preKey = bundle['preKey'] == null ? null : '${bundle['preKey']}';
    final secret = await E2eeX3dh.initiatorSecret(
      identityDh: identityDh,
      ephemeral: ephemeral,
      recipientIdentityDhB64: '${bundle['identityDhKey']}',
      recipientSignedPreKeyB64: signedPreKey,
      recipientOneTimePreKeyB64: preKey,
    );
    final session = await E2eeSession.create(rootKey: secret, initiator: true);
    final ephPub = await ephemeral.extractPublicKey();
    final hs = {
      'ik': await _keys.identityDhPublicB64(),
      'ek': base64Encode(_pubBytes(ephPub)),
      'spkId': bundle['signedPreKeyId'],
      'otkId': bundle['preKeyId'] ?? -1,
    };
    return _SessionRecord(session: session, pendingHs: hs);
  }

  /// Decrypt an incoming message if it's addressed to this device and encrypted.
  /// Returns the plaintext, or null when the message isn't encrypted for us or
  /// can't be decrypted.
  Future<String?> decryptMessage({
    required String conversationId,
    required String senderUserId,
    required Map<String, dynamic> message,
  }) async {
    if (!supported) return null;
    final meta = (message['metadata'] as Map?)?.cast<String, dynamic>();
    if (meta == null || meta['encrypted'] != true) return null;
    final envelope = (meta['envelope'] as Map?)?.cast<String, dynamic>();
    if (envelope == null) return null;
    final senderDeviceId = '${meta['senderDeviceId'] ?? ''}';
    if (senderUserId.isEmpty || senderDeviceId.isEmpty) return null;

    try {
      final myDeviceId = await _keys.deviceId();
      final entry = (envelope[myDeviceId] as Map?)?.cast<String, dynamic>();
      if (entry == null) return null; // not addressed to this device

      final key = _sessionKey(conversationId, senderUserId, senderDeviceId);
      var rec = await _loadRecord(key);
      if (rec == null) {
        final hs = (entry['hs'] as Map?)?.cast<String, dynamic>();
        if (hs == null) return null; // no session and no handshake to build one
        rec = await _establishResponder(hs);
        if (rec == null) return null;
      }
      final msg = (entry['msg'] as Map?)?.cast<String, dynamic>();
      if (msg == null) return null;
      final plain = await rec.session.decrypt(msg);
      await _saveRecord(key, rec);
      return plain;
    } catch (_) {
      return null;
    }
  }

  Future<_SessionRecord?> _establishResponder(Map<String, dynamic> hs) async {
    final spkId = (hs['spkId'] as num?)?.toInt();
    if (spkId == null) return null;
    final signedPreKey = await _keys.signedPreKeyKeyPair(spkId);
    if (signedPreKey == null) return null;
    final otkId = (hs['otkId'] as num?)?.toInt() ?? -1;
    SimpleKeyPair? oneTime;
    if (otkId >= 0) {
      oneTime = await _keys.takeOneTimePreKey(otkId);
      if (oneTime == null) return null; // initiator used an OTK we no longer have
    }
    final identityDh = await _keys.identityDhKeyPair();
    final secret = await E2eeX3dh.responderSecret(
      identityDh: identityDh,
      signedPreKey: signedPreKey,
      oneTimePreKey: oneTime,
      initiatorIdentityDhB64: '${hs['ik']}',
      initiatorEphemeralB64: '${hs['ek']}',
    );
    final session = await E2eeSession.create(rootKey: secret, initiator: false);
    return _SessionRecord(session: session, pendingHs: null);
  }

  // ---- Local record of my own sent plaintext ----
  // An encrypted message I send is addressed to the recipient's device, not
  // mine, so I can't decrypt my own copy. Keep the plaintext locally (my own
  // data, on my device) so my sent messages remain readable after a restart.
  Future<void> rememberSent(String messageId, String plaintext) =>
      _storage.write(key: 'e2ee.sent.$messageId', value: plaintext);

  Future<String?> sentPlaintext(String messageId) =>
      _storage.read(key: 'e2ee.sent.$messageId');

  /// Forget all sessions for a conversation (e.g. on leaving/blocking).
  Future<void> clearConversation(String conversationId) async {
    final prefix = 'e2ee.sess.$conversationId.';
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith(prefix)) await _storage.delete(key: key);
    }
  }
}

class _SessionRecord {
  _SessionRecord({required this.session, required this.pendingHs});
  final E2eeSession session;
  final Map<String, dynamic>? pendingHs;

  Map<String, dynamic> toJson() => {'session': session.toJson(), 'hs': pendingHs};

  factory _SessionRecord.fromJson(Map<String, dynamic> j) => _SessionRecord(
        session: E2eeSession.fromJson((j['session'] as Map).cast<String, dynamic>()),
        pendingHs: (j['hs'] as Map?)?.cast<String, dynamic>(),
      );
}
