import 'package:christian_youth_super_app/data/e2ee/e2ee_safety_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final keyA = List<int>.generate(32, (i) => (i * 3 + 1) & 0xff);
  final keyB = List<int>.generate(32, (i) => (i * 7 + 5) & 0xff);
  const idA = 'user-aaaa';
  const idB = 'user-bbbb';

  test('both parties compute the identical 60-digit safety number', () async {
    final fromA = await E2eeSafetyNumber.compute(
      myIdentityKey: keyA, myUserId: idA, theirIdentityKey: keyB, theirUserId: idB,
    );
    final fromB = await E2eeSafetyNumber.compute(
      myIdentityKey: keyB, myUserId: idB, theirIdentityKey: keyA, theirUserId: idA,
    );
    expect(fromA, fromB, reason: 'safety number must match on both sides');
    expect(fromA.length, 60);
    expect(RegExp(r'^\d{60}$').hasMatch(fromA), isTrue);
  });

  test('a swapped (MITM) key changes the safety number', () async {
    final honest = await E2eeSafetyNumber.compute(
      myIdentityKey: keyA, myUserId: idA, theirIdentityKey: keyB, theirUserId: idB,
    );
    final attackerKey = List<int>.generate(32, (i) => (i * 11 + 9) & 0xff);
    final mitm = await E2eeSafetyNumber.compute(
      myIdentityKey: keyA, myUserId: idA, theirIdentityKey: attackerKey, theirUserId: idB,
    );
    expect(honest == mitm, isFalse);
  });
}
