import 'package:geolocator/geolocator.dart';

import 'api_client.dart';

/// Requests location permission, reads the device's current position, and
/// sends it to the courtship service for distance-based matching. Best-effort:
/// silently does nothing if location is off or permission is denied.
Future<bool> captureAndSendCourtshipLocation({
  required ApiClient apiClient,
  required String token,
}) async {
  if (token.isEmpty) return false;
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    );
    await apiClient.updateRelationshipLocation(
        token, position.latitude, position.longitude);
    return true;
  } catch (_) {
    // Location unavailable — distance matching just won't apply for this user.
    return false;
  }
}
