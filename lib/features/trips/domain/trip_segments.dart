import 'package:flutter/foundation.dart';

import '../../../core/geo/geo_utils.dart';
import 'trip.dart';

@immutable
class TripSegment {
  const TripSegment({
    required this.start,
    required this.end,
    required this.distanceMeters,
    required this.isStop,
  });

  final DateTime start;
  final DateTime end;
  final double distanceMeters;
  final bool isStop;

  Duration get duration => end.difference(start);
}

/// Splits a trip into alternating moving / stopped segments for the timeline.
abstract final class TripSegments {
  static const _stopSpeedMps = 1.0;
  static const _minStop = Duration(seconds: 60);

  static List<TripSegment> of(Trip trip) {
    final route = trip.route;
    if (route.length < 2) {
      return [
        TripSegment(
            start: trip.startTime, end: trip.endTime, distanceMeters: trip.distanceMeters, isStop: false),
      ];
    }

    final raw = <TripSegment>[];
    var segStart = route.first.time;
    var segDist = 0.0;
    var stopped = false;
    var first = true;

    for (var i = 1; i < route.length; i++) {
      final a = route[i - 1];
      final b = route[i];
      final dt = b.time.difference(a.time).inMilliseconds / 1000;
      if (dt <= 0) continue;
      final d = GeoUtils.haversine(a.lat, a.lng, b.lat, b.lng);
      final isStopHere = d / dt < _stopSpeedMps;
      if (first) {
        stopped = isStopHere;
        first = false;
      }
      if (isStopHere != stopped) {
        raw.add(TripSegment(start: segStart, end: a.time, distanceMeters: segDist, isStop: stopped));
        segStart = a.time;
        segDist = 0;
        stopped = isStopHere;
      }
      if (!isStopHere) segDist += d;
    }
    raw.add(TripSegment(start: segStart, end: route.last.time, distanceMeters: segDist, isStop: stopped));

    // Absorb tiny stops (traffic lights) into the surrounding movement.
    final merged = <TripSegment>[];
    for (final s in raw) {
      final tinyStop = s.isStop && s.duration < _minStop;
      if (merged.isNotEmpty && (tinyStop || merged.last.isStop == s.isStop)) {
        final last = merged.removeLast();
        merged.add(TripSegment(
          start: last.start,
          end: s.end,
          distanceMeters: last.distanceMeters + s.distanceMeters,
          isStop: last.isStop && s.isStop,
        ));
      } else {
        merged.add(s);
      }
    }
    return merged;
  }
}
