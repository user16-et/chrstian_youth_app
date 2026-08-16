import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// A "safety number" both people can compare (read aloud or scan) to confirm no
/// one — including a malicious/compromised server that brokers public keys — has
/// swapped in their own keys (an active MITM). Deterministic and symmetric: both
/// devices compute the exact same number from the two identity keys + user ids.
///
/// This is our own scheme (both ends are our clients — no Signal interop), but
/// it follows the same shape as Signal's numeric fingerprint: an iterated hash
/// per party, rendered as digits, concatenated in a stable order.
class E2eeSafetyNumber {
  static final _sha512 = Sha512();
  static const int _iterations = 5200;
  static const int _version = 1;

  static Future<String> _fingerprint(List<int> identityKey, String userId) async {
    var buf = <int>[
      _version & 0xff,
      (_version >> 8) & 0xff,
      ...identityKey,
      ...utf8.encode(userId),
    ];
    for (var i = 0; i < _iterations; i++) {
      buf = (await _sha512.hash([...buf, ...identityKey])).bytes;
    }
    // 30 digits: six 5-digit groups, each from 5 bytes of the final hash.
    final sb = StringBuffer();
    for (var c = 0; c < 6; c++) {
      var v = 0;
      for (var j = 0; j < 5; j++) {
        v = (v << 8) | buf[c * 5 + j];
      }
      sb.write((v % 100000).toString().padLeft(5, '0'));
    }
    return sb.toString();
  }

  /// The 60-digit safety number for the pair. Identical for both users.
  static Future<String> compute({
    required List<int> myIdentityKey,
    required String myUserId,
    required List<int> theirIdentityKey,
    required String theirUserId,
  }) async {
    final mine = await _fingerprint(myIdentityKey, myUserId);
    final theirs = await _fingerprint(theirIdentityKey, theirUserId);
    // Order by user id so both sides concatenate in the same order.
    final ordered = myUserId.compareTo(theirUserId) <= 0 ? [mine, theirs] : [theirs, mine];
    return ordered.join();
  }

  /// Group the digits into readable blocks of five.
  static String format(String digits) {
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i += 5) {
      if (i > 0) b.write(i % 25 == 0 ? '\n' : '  ');
      b.write(digits.substring(i, (i + 5) > digits.length ? digits.length : i + 5));
    }
    return b.toString();
  }
}
