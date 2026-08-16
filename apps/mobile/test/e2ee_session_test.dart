import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:christian_youth_super_app/data/e2ee/e2ee_session.dart';
import 'package:flutter_test/flutter_test.dart';

// Exercises the X3DH agreement + symmetric-ratchet session end to end: two
// parties derive the same secret and can exchange messages both ways.
void main() {
  final x = X25519();

  Future<String> pub(SimpleKeyPair kp) async =>
      base64Encode((await kp.extractPublicKey()).bytes);

  test('X3DH derives a matching secret and messages round-trip both ways', () async {
    // Recipient (B) long-term + prekeys.
    final bIdentity = await x.newKeyPair();
    final bSignedPre = await x.newKeyPair();
    final bOneTime = await x.newKeyPair();

    // Initiator (A) identity + a fresh ephemeral for this session.
    final aIdentity = await x.newKeyPair();
    final aEphemeral = await x.newKeyPair();

    final aSecret = await E2eeX3dh.initiatorSecret(
      identityDh: aIdentity,
      ephemeral: aEphemeral,
      recipientIdentityDhB64: await pub(bIdentity),
      recipientSignedPreKeyB64: await pub(bSignedPre),
      recipientOneTimePreKeyB64: await pub(bOneTime),
    );

    final bSecret = await E2eeX3dh.responderSecret(
      identityDh: bIdentity,
      signedPreKey: bSignedPre,
      oneTimePreKey: bOneTime,
      initiatorIdentityDhB64: await pub(aIdentity),
      initiatorEphemeralB64: await pub(aEphemeral),
    );

    expect(base64Encode(aSecret), base64Encode(bSecret),
        reason: 'both sides must derive the same X3DH secret');

    final a = E2eeSession(rootKey: aSecret, initiator: true);
    final b = E2eeSession(rootKey: bSecret, initiator: false);

    // A -> B
    final m1 = await a.encrypt('Grace and peace to you 🙏');
    expect(await b.decrypt(m1), 'Grace and peace to you 🙏');

    // B -> A
    final m2 = await b.encrypt('And also to you.');
    expect(await a.decrypt(m2), 'And also to you.');

    // Several in a row keep decrypting correctly.
    final sent = [for (var i = 0; i < 5; i++) 'message $i'];
    final boxes = [for (final s in sent) await a.encrypt(s)];
    for (var i = 0; i < sent.length; i++) {
      expect(await b.decrypt(boxes[i]), sent[i]);
    }
  });

  test('a tampered ciphertext fails to decrypt', () async {
    final bId = await x.newKeyPair();
    final bSpk = await x.newKeyPair();
    final aId = await x.newKeyPair();
    final aEph = await x.newKeyPair();
    final secret = await E2eeX3dh.initiatorSecret(
      identityDh: aId,
      ephemeral: aEph,
      recipientIdentityDhB64: base64Encode((await bId.extractPublicKey()).bytes),
      recipientSignedPreKeyB64: base64Encode((await bSpk.extractPublicKey()).bytes),
    );
    final respSecret = await E2eeX3dh.responderSecret(
      identityDh: bId,
      signedPreKey: bSpk,
      initiatorIdentityDhB64: base64Encode((await aId.extractPublicKey()).bytes),
      initiatorEphemeralB64: base64Encode((await aEph.extractPublicKey()).bytes),
    );
    final a = E2eeSession(rootKey: secret, initiator: true);
    final b = E2eeSession(rootKey: respSecret, initiator: false);
    final box = await a.encrypt('secret');
    box['ct'] = base64Encode([...base64Decode('${box['ct']}')]..[0] ^= 0xff);
    await expectLater(b.decrypt(box), throwsA(isA<Object>()));
  });
}
