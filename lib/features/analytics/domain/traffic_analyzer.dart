import 'package:flutter/foundation.dart';

import '../../reminders/domain/smart_reminders.dart';
import '../../trips/domain/trip.dart';
import '../../trips/domain/zone.dart';

@immutable
class TrafficComparison {
  const TrafficComparison({required this.trip, required this.deltaFraction, required this.usual});

  final Trip trip;

  /// +0.25 means the trip took 25% longer than the usual time for that route.
  final double deltaFraction;
  final Duration usual;
}

@immutable
class DepartureAdvice {
  const DepartureAdvice({
    required this.origin,
    required this.destination,
    required this.betterHour,
    required this.usualHour,
    required this.minutesSaved,
  });

  final Zone origin;
  final Zone destination;
  final int betterHour;
  final int usualHour;
  final int minutesSaved;
}

/// Compares journeys against the user's own history on the same route.
/// Nothing here needs outside traffic data: it learns what "normal" is.
abstract final class TrafficAnalyzer {
  static const _historyDays = 45;
  static const _minHistory = 3;

  static bool _sameRoute(Trip a, Trip b) =>
      a.originZone == b.originZone && a.destinationZone == b.destinationZone;

  static Iterable<Trip> _history(List<Trip> all, Trip t) {
    final since = t.startTime.subtract(const Duration(days: _historyDays));
    return all.where((h) =>
        h.id != t.id &&
        h.mode.isRoadTraffic &&
        _sameRoute(h, t) &&
        h.startTime.isBefore(t.startTime) &&
        h.startTime.isAfter(since));
  }

  /// Today's road trips against the usual duration on the same route.
  /// Returns the trip that differs most, if any route has enough history.
  static TrafficComparison? todayVsUsual(List<Trip> trips, DateTime now) {
    final dayStart = DateTime(now.year, now.month, now.day);
    TrafficComparison? best;
    for (final t in trips) {
      if (t.startTime.isBefore(dayStart) || !t.mode.isRoadTraffic || t.distanceKm < 1) continue;
      final history = _history(trips, t).map((h) => h.duration.inSeconds).toList()..sort();
      if (history.length < _minHistory) continue;
      final usual = history[history.length ~/ 2];
      if (usual < 300) continue;
      final delta = t.duration.inSeconds / usual - 1;
      if (best == null || delta.abs() > best.deltaFraction.abs()) {
        best = TrafficComparison(trip: t, deltaFraction: delta, usual: Duration(seconds: usual));
      }
    }
    return best;
  }

  /// If leaving at a different hour has reliably been faster on a regular
  /// route, say so.
  static DepartureAdvice? departureAdvice(List<Trip> trips, DateTime now) {
    for (final p in SmartReminderEngine.detectPatterns(trips, now)) {
      final route = trips.where((t) =>
          t.mode.isRoadTraffic &&
          t.originZone == p.origin &&
          t.destinationZone == p.destination &&
          (t.startTime.weekday <= DateTime.friday) == p.weekdayKind &&
          t.distanceKm >= 1 &&
          now.difference(t.startTime) < const Duration(days: 35));

      final byHour = <int, List<Trip>>{};
      for (final t in route) {
        byHour.putIfAbsent(t.startTime.hour, () => []).add(t);
      }
      final solid = byHour.entries.where((e) => e.value.length >= 2).toList();
      if (solid.length < 2) continue;

      double pace(List<Trip> ts) =>
          ts.fold(0.0, (a, t) => a + t.duration.inSeconds / 60 / t.distanceKm) / ts.length;

      final usual = solid.reduce((a, b) => a.value.length >= b.value.length ? a : b);
      final best = solid.reduce((a, b) => pace(a.value) <= pace(b.value) ? a : b);
      if (best.key == usual.key) continue;
      final usualPace = pace(usual.value);
      final gain = (usualPace - pace(best.value)) / usualPace;
      if (gain < 0.15) continue;
      final km = usual.value.fold(0.0, (a, t) => a + t.distanceKm) / usual.value.length;
      final saved = ((usualPace - pace(best.value)) * km).round();
      if (saved < 4) continue;
      return DepartureAdvice(
        origin: p.origin,
        destination: p.destination,
        betterHour: best.key,
        usualHour: usual.key,
        minutesSaved: saved,
      );
    }
    return null;
  }
}
