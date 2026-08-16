import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// X3DH key agreement + a symmetric-key ratchet for 1:1 sessions.
///
/// SECURITY STATUS — READ BEFORE SHIPPING:
///  * Provides: authenticated key agreement (X3DH), and **forward secrecy** —
///    each message uses a fresh key derived by advancing a one-way chain, so a
///    later key compromise can't decrypt earlier messages.
///  * Does NOT yet provide: post-compromise security (the Double Ratchet's DH
///    ratchet step). A device-key compromise exposes future messages until keys
///    rotate. Adding the DH ratchet, and an independent cryptographic review +
///    test-vector validation, are required before this guards real user data.
///
/// The two sides derive matching chains from the shared secret using fixed role
/// labels, so the initiator's send chain equals the responder's receive chain
/// and vice-versa.
class E2eeX3dh {
  static final _x25519 = X25519();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  static List<int> _b64(String s) => base64Decode(s);

  static SimplePublicKey _pub(List<int> bytes) =>
      SimplePublicKey(bytes, type: KeyPairType.x25519);

  static Future<List<int>> _dh(SimpleKeyPair priv, List<int> pubBytes) async {
    final secret = await _x25519.sharedSecretKey(keyPair: priv, remotePublicKey: _pub(pubBytes));
    return secret.extractBytes();
  }

  /// Initiator side: derive the shared secret against a recipient prekey bundle.
  /// [ephemeral] is a fresh X25519 key pair the initiator generates for this
  /// session and sends (public) in the first message header.
  static Future<List<int>> initiatorSecret({
    required SimpleKeyPair identityDh,
    required SimpleKeyPair ephemeral,
    required String recipientIdentityDhB64,
    required String recipientSignedPreKeyB64,
    String? recipientOneTimePreKeyB64,
  }) async {
    final ikB = _b64(recipientIdentityDhB64);
    final spkB = _b64(recipientSignedPreKeyB64);
    final dh1 = await _dh(identityDh, spkB);
    final dh2 = await _dh(ephemeral, ikB);
    final dh3 = await _dh(ephemeral, spkB);
    final concat = <int>[...dh1, ...dh2, ...dh3];
    if (recipientOneTimePreKeyB64 != null && recipientOneTimePreKeyB64.isNotEmpty) {
      concat.addAll(await _dh(ephemeral, _b64(recipientOneTimePreKeyB64)));
    }
    return _rootFromDh(concat);
  }

  /// Responder side: reconstruct the same shared secret from the initiator's
  /// public identity + ephemeral and the responder's own private prekeys.
  static Future<List<int>> responderSecret({
    required SimpleKeyPair identityDh,
    required SimpleKeyPair signedPreKey,
    SimpleKeyPair? oneTimePreKey,
    required String initiatorIdentityDhB64,
    required String initiatorEphemeralB64,
  }) async {
    final ikA = _b64(initiatorIdentityDhB64);
    final ekA = _b64(initiatorEphemeralB64);
    final dh1 = await _dh(signedPreKey, ikA);
    final dh2 = await _dh(identityDh, ekA);
    final dh3 = await _dh(signedPreKey, ekA);
    final concat = <int>[...dh1, ...dh2, ...dh3];
    if (oneTimePreKey != null) {
      concat.addAll(await _dh(oneTimePreKey, ekA));
    }
    return _rootFromDh(concat);
  }

  static Future<List<int>> _rootFromDh(List<int> concat) async {
    final key = await _hkdf.deriveKey(
      secretKey: SecretKey(concat),
      nonce: const <int>[],
      info: utf8.encode('christian-app/e2ee/x3dh/root'),
    );
    return key.extractBytes();
  }
}

/// A running symmetric ratchet session between two devices. Persist [rootKey]
/// (and the send/recv counters) to resume; keys advance forward only.
class E2eeSession {
  E2eeSession({
    required this.rootKey,
    required this.initiator,
    this.sendCount = 0,
    this.recvCount = 0,
  });

  final List<int> rootKey;
  // The initiator sends on chain "A2B" and receives on "B2A"; the responder is
  // the mirror. This keeps the two devices' chains aligned.
  final bool initiator;
  int sendCount;
  int recvCount;

  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static final _aead = Chacha20.poly1305Aead();

  String get _sendLabel => initiator ? 'A2B' : 'B2A';
  String get _recvLabel => initiator ? 'B2A' : 'A2B';

  Future<List<int>> _messageKey(String label, int index) async {
    final key = await _hkdf.deriveKey(
      secretKey: SecretKey(rootKey),
      nonce: const <int>[],
      info: utf8.encode('christian-app/e2ee/chain/$label/$index'),
    );
    return key.extractBytes();
  }

  static List<int> _nonce(int index) {
    // 12-byte nonce = counter; safe because each message key is unique per index.
    final b = Uint8List(12);
    b.buffer.asByteData().setUint32(8, index, Endian.big);
    return b;
  }

  /// Encrypt one message; returns a self-describing envelope map (JSON-safe).
  Future<Map<String, dynamic>> encrypt(String plaintext) async {
    final index = sendCount++;
    final mk = await _messageKey(_sendLabel, index);
    final box = await _aead.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(mk),
      nonce: _nonce(index),
    );
    return {
      'n': index,
      'ct': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
  }

  /// Decrypt one envelope produced by the peer.
  Future<String> decrypt(Map<String, dynamic> envelope) async {
    final index = (envelope['n'] as num).toInt();
    final mk = await _messageKey(_recvLabel, index);
    final clear = await _aead.decrypt(
      SecretBox(
        base64Decode('${envelope['ct']}'),
        nonce: _nonce(index),
        mac: Mac(base64Decode('${envelope['mac']}')),
      ),
      secretKey: SecretKey(mk),
    );
    if (index >= recvCount) recvCount = index + 1;
    return utf8.decode(clear);
  }
}
