import 'package:flutter/foundation.dart';

/// A coarse geographic cell (~1.1 km at the equator). This is the ONLY
/// location granularity that ever leaves the device.
@immutable
class Zone {
  const Zone(this.latIndex, this.lngIndex);

  /// Cell size in degrees.
  static const double cellDegrees = 0.01;

  final int latIndex;
  final int lngIndex;

  factory Zone.fromLatLng(double lat, double lng) =>
      Zone((lat / cellDegrees).floor(), (lng / cellDegrees).floor());

  factory Zone.parse(String id) {
    final parts = id.split('_');
    return Zone(int.parse(parts[0]), int.parse(parts[1]));
  }

  String get id => '${latIndex}_$lngIndex';

  double get centerLat => (latIndex + 0.5) * cellDegrees;
  double get centerLng => (lngIndex + 0.5) * cellDegrees;

  @override
  bool operator ==(Object other) =>
      other is Zone && other.latIndex == latIndex && other.lngIndex == lngIndex;

  @override
  int get hashCode => Object.hash(latIndex, lngIndex);

  @override
  String toString() => id;
}
