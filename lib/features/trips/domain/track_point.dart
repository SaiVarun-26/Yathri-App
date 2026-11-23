import 'package:flutter/foundation.dart';

/// A single accepted GPS fix. Immutable.
@immutable
class TrackPoint {
  const TrackPoint({
    required this.lat,
    required this.lng,
    required this.time,
    this.speed = 0,
    this.accuracy = 0,
    this.heading,
  });

  final double lat;
  final double lng;
  final DateTime time;

  /// Metres per second as reported by the device. May be 0 / unreliable.
  final double speed;

  /// Horizontal accuracy in metres.
  final double accuracy;

  /// Degrees from north, if available.
  final double? heading;

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        't': time.millisecondsSinceEpoch,
        's': speed,
        'a': accuracy,
        if (heading != null) 'h': heading,
      };

  factory TrackPoint.fromJson(Map<dynamic, dynamic> j) => TrackPoint(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        time: DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt()),
        speed: (j['s'] as num?)?.toDouble() ?? 0,
        accuracy: (j['a'] as num?)?.toDouble() ?? 0,
        heading: (j['h'] as num?)?.toDouble(),
      );
}
