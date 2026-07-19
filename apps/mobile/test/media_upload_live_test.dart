import 'dart:typed_data';

import 'package:christian_youth_super_app/data/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

// Live upload test — runs only when INTEGRATION_API_URL + a token are provided.
// Exercises the streamed PUT with progress against the real media pipeline.
const apiUrl = String.fromEnvironment('INTEGRATION_API_URL');
const token = String.fromEnvironment('INTEGRATION_TOKEN');

void main() {
  test('uploadMediaAsset streams bytes and reports progress', () async {
    final api = ApiClient(baseUrl: apiUrl);
    // A minimal valid PNG (1x1).
    final png = Uint8List.fromList([
      137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82,0,0,0,1,0,0,0,1,8,2,0,0,0,
      144,119,83,222,0,0,0,12,73,68,65,84,120,156,99,248,207,192,0,0,3,1,1,0,
      24,221,141,176,0,0,0,0,73,69,78,68,174,66,96,130
    ]);
    final progress = <double>[];
    final asset = await api.uploadMediaAsset(
      token: token,
      usage: 'post_media',
      fileName: 'live_test.png',
      contentType: 'image/png',
      byteSize: png.length,
      bytes: png,
      onProgress: progress.add,
    );
    expect(asset['publicUrl'], isNotNull);
    expect((asset['publicUrl'] as String), contains('/christian-super-app-media/'));
    // Progress must have advanced to completion.
    expect(progress, isNotEmpty);
    expect(progress.last, closeTo(1.0, 0.001));
  }, skip: apiUrl.isEmpty || token.isEmpty);
}
