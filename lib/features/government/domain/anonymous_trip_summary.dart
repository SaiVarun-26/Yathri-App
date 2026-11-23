import 'package:flutter/foundation.dart';

import '../../trips/domain/transport_mode.dart';
import '../../trips/domain/trip.dart';
import '../../trips/domain/zone.dart';

/// The only trip data the Government ever receives.
///
/// Deliberately lacks: user id, name, phone, exact GPS, route, exact times.
/// Values are coarsened (distance → 0.5 km, time → the hour, duration → 5 min)
/// to reduce re-identification risk.
@immutable
class AnonymousTripSummary {
  const AnonymousTripSummary({
    required this.originZone,
    required this.destinationZone,
    required this.mode,
    required this.distanceKm,
    required this.hourStart,
    required this.durationMinutes,
  });

  final Zone originZone;
  final Zone destinationZone;
  final TransportMode mode;
  final double distanceKm;

  /// Start time truncated to the hour.
  final DateTime hourStart;
  final int durationMinutes;

  int get hour => hourStart.hour;
  int get weekday => hourStart.weekday;

  factory AnonymousTripSummary.fromTrip(Trip t) {
    final s = t.startTime;
    return AnonymousTripSummary(
      originZone: t.originZone,
      destinationZone: t.destinationZone,
      mode: t.mode,
      distanceKm: (t.distanceKm * 2).round() / 2,
      hourStart: DateTime(s.year, s.month, s.day, s.hour),
      durationMinutes: (t.duration.inMinutes / 5).round() * 5,
    );
  }
}
