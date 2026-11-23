import 'package:flutter/foundation.dart';

import '../../trips/domain/transport_mode.dart';
import '../../trips/domain/trip.dart';

@immutable
class PeriodStats {
  const PeriodStats({
    required this.tripCount,
    required this.distanceKm,
    required this.duration,
    required this.costInr,
    required this.co2SavedKg,
    required this.co2EmittedKg,
    required this.kmByMode,
  });

  static const empty = PeriodStats(
    tripCount: 0,
    distanceKm: 0,
    duration: Duration.zero,
    costInr: 0,
    co2SavedKg: 0,
    co2EmittedKg: 0,
    kmByMode: {},
  );

  final int tripCount;
  final double distanceKm;
  final Duration duration;
  final double costInr;
  final double co2SavedKg;
  final double co2EmittedKg;
  final Map<TransportMode, double> kmByMode;

  TransportMode? get dominantMode {
    if (kmByMode.isEmpty) return null;
    return kmByMode.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  double get greenShare {
    if (distanceKm <= 0) return 0;
    final green = kmByMode.entries.where((e) => e.key.isGreen).fold<double>(0, (a, e) => a + e.value);
    return green / distanceKm;
  }

  factory PeriodStats.of(Iterable<Trip> trips) {
    var count = 0;
    var km = 0.0;
    var dur = Duration.zero;
    var cost = 0.0;
    var saved = 0.0;
    var emitted = 0.0;
    final byMode = <TransportMode, double>{};
    for (final t in trips) {
      count++;
      km += t.distanceKm;
      dur += t.duration;
      cost += t.costInr;
      saved += t.co2SavedGrams / 1000;
      emitted += t.co2Grams / 1000;
      byMode[t.mode] = (byMode[t.mode] ?? 0) + t.distanceKm;
    }
    return PeriodStats(
      tripCount: count,
      distanceKm: km,
      duration: dur,
      costInr: cost,
      co2SavedKg: saved,
      co2EmittedKg: emitted,
      kmByMode: byMode,
    );
  }
}

/// Date-range helpers shared by all analytics.
abstract final class DateRanges {
  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Monday-based week start.
  static DateTime startOfWeek(DateTime d) =>
      startOfDay(d).subtract(Duration(days: d.weekday - DateTime.monday));

  static DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month);

  static Iterable<Trip> within(Iterable<Trip> trips, DateTime from, DateTime to) =>
      trips.where((t) => !t.startTime.isBefore(from) && t.startTime.isBefore(to));
}
