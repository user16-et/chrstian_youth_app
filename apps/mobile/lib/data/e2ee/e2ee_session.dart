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

  /// Verify a fetched signed prekey against the peer's identity *signing* key
  /// (Ed25519) — rejects a server that swaps in a forged prekey.
  static Future<bool> verifySignedPreKey({
    required String signedPreKeyB64,
    required String signatureB64,
    required String identitySignPubB64,
  }) async {
    final ed = Ed25519();
    return ed.verify(
      _b64(signedPreKeyB64),
      signature: Signature(
        _b64(signatureB64),
        publicKey: SimplePublicKey(_b64(identitySignPubB64), type: KeyPairType.ed25519),
      ),
    );
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

/// A running symmetric-ratchet session between two devices. Chain keys advance
/// one-way and the previous chain key is discarded after each message, so a
/// compromise of the *current* state can't recompute earlier message keys —
/// that is the forward secrecy this layer provides. Persist the chain keys +
/// counters + any cached skipped keys to resume across restarts.
///
/// Construct with [create] (key derivation is async).
class E2eeSession {
  E2eeSession._(this._sendChain, this._recvChain, this.initiator,
      {this.sendCount = 0, this.recvCount = 0, Map<int, List<int>>? skipped})
      : _skipped = skipped ?? {};

  // The initiator sends on chain "A2B" and receives on "B2A"; the responder is
  // the mirror, so the two devices' chains stay aligned.
  final bool initiator;
  List<int> _sendChain;
  List<int> _recvChain;
  int sendCount;
  int recvCount;
  // Message keys derived while skipping ahead to an out-of-order message, so a
  // later-arriving earlier message can still be read. Bounded to avoid a DoS.
  final Map<int, List<int>> _skipped;
  static const int _maxSkip = 256;

  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static final _aead = Chacha20.poly1305Aead();

  static Future<List<int>> _kdf(List<int> key, String label) async {
    final k = await _hkdf.deriveKey(
      secretKey: SecretKey(key),
      nonce: const <int>[],
      info: utf8.encode('christian-app/e2ee/$label'),
    );
    return k.extractBytes();
  }

  /// Derive the two initial chain keys from the X3DH root secret.
  static Future<E2eeSession> create({required List<int> rootKey, required bool initiator}) async {
    final sendChain = await _kdf(rootKey, initiator ? 'chain/A2B' : 'chain/B2A');
    final recvChain = await _kdf(rootKey, initiator ? 'chain/B2A' : 'chain/A2B');
    return E2eeSession._(sendChain, recvChain, initiator);
  }

  /// Serialize the ratchet state for persistence (secure storage).
  Map<String, dynamic> toJson() => {
        'i': initiator,
        'sc': base64Encode(_sendChain),
        'rc': base64Encode(_recvChain),
        'sn': sendCount,
        'rn': recvCount,
        'sk': _skipped.map((k, v) => MapEntry('$k', base64Encode(v))),
      };

  factory E2eeSession.fromJson(Map<String, dynamic> j) => E2eeSession._(
        base64Decode('${j['sc']}'),
        base64Decode('${j['rc']}'),
        j['i'] == true,
        sendCount: (j['sn'] as num).toInt(),
        recvCount: (j['rn'] as num).toInt(),
        skipped: ((j['sk'] as Map?) ?? const {}).map(
            (k, v) => MapEntry(int.parse('$k'), base64Decode('$v'))),
      );

  static List<int> _nonce(int index) {
    // 12-byte nonce = message counter; safe because each message key is unique.
    final b = Uint8List(12);
    b.buffer.asByteData().setUint32(8, index, Endian.big);
    return b;
  }

  // Derive this step's message key from a chain key and return the *advanced*
  // chain key alongside it. The caller discards the old chain key.
  Future<(List<int> messageKey, List<int> nextChain)> _step(List<int> chain) async {
    final mk = await _kdf(chain, 'msg');
    final next = await _kdf(chain, 'chn');
    return (mk, next);
  }

  /// Encrypt one message; returns a self-describing, JSON-safe envelope.
  Future<Map<String, dynamic>> encrypt(String plaintext) async {
    final (mk, next) = await _step(_sendChain);
    _sendChain = next;
    final index = sendCount++;
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

  Future<List<int>> _messageKeyForRecv(int index) async {
    final cached = _skipped.remove(index);
    if (cached != null) return cached;
    if (index < recvCount) {
      // Chain already advanced past this and its key was discarded (forward
      // secrecy) or evicted — it can no longer be read.
      throw StateError('message_key_unavailable');
    }
    // Advance the receive chain up to `index`, caching skipped message keys.
    while (recvCount < index) {
      final (mk, next) = await _step(_recvChain);
      _recvChain = next;
      _skipped[recvCount] = mk;
      recvCount++;
      if (_skipped.length > _maxSkip) {
        _skipped.remove(_skipped.keys.first);
      }
    }
    final (mk, next) = await _step(_recvChain);
    _recvChain = next;
    recvCount++;
    return mk;
  }

  /// Decrypt one envelope produced by the peer.
  Future<String> decrypt(Map<String, dynamic> envelope) async {
    final index = (envelope['n'] as num).toInt();
    final mk = await _messageKeyForRecv(index);
    final clear = await _aead.decrypt(
      SecretBox(
        base64Decode('${envelope['ct']}'),
        nonce: _nonce(index),
        mac: Mac(base64Decode('${envelope['mac']}')),
      ),
      secretKey: SecretKey(mk),
    );
    return utf8.decode(clear);
  }
}
