import 'dart:math' as math;

/// Pure geodesy helpers. No Flutter imports so they can run in any isolate.
abstract final class GeoUtils {
  static const _earthRadiusM = 6371000.0;

  static double _rad(double deg) => deg * math.pi / 180;

  /// Great-circle distance in metres.
  static double haversine(double lat1, double lng1, double lat2, double lng2) {
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * _earthRadiusM * math.asin(math.min(1, math.sqrt(a)));
  }

  /// Initial bearing in degrees [0, 360).
  static double bearing(double lat1, double lng1, double lat2, double lng2) {
    final dLng = _rad(lng2 - lng1);
    final y = math.sin(dLng) * math.cos(_rad(lat2));
    final x = math.cos(_rad(lat1)) * math.sin(_rad(lat2)) -
        math.sin(_rad(lat1)) * math.cos(_rad(lat2)) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// Smallest absolute difference between two bearings, in degrees [0, 180].
  static double bearingDelta(double a, double b) {
    final d = (a - b).abs() % 360;
    return d > 180 ? 360 - d : d;
  }
}
