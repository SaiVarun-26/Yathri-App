import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../analytics/domain/period_stats.dart';
import '../../rewards/domain/rewards.dart';
import '../../trips/domain/transport_mode.dart';
import '../../trips/domain/trip.dart';

enum MilestoneScope { trip, weekly, monthly }

@immutable
class MilestoneCard {
  const MilestoneCard({
    required this.id,
    required this.scope,
    required this.title,
    required this.period,
    required this.distanceKm,
    required this.duration,
    required this.mode,
    required this.moneySavedInr,
    required this.ecoPoints,
  });

  final String id;
  final MilestoneScope scope;
  final String title;
  final String period;
  final double distanceKm;
  final Duration duration;
  final TransportMode? mode;
  final double moneySavedInr;
  final int ecoPoints;

  String get shareText =>
      'Yathri · $title\n${distanceKm.toStringAsFixed(1)} km · ${_fmt(duration)}'
      '${mode != null ? ' · ${mode!.label}' : ''}\n'
      'Saved ₹${moneySavedInr.round()} · $ecoPoints eco points\n#Yathri';

  static String _fmt(Duration d) =>
      d.inHours > 0 ? '${d.inHours} h ${d.inMinutes % 60} min' : '${d.inMinutes} min';
}

abstract final class MilestoneGenerator {
  static double _saved(Trip t) {
    // Money saved vs the same distance by car.
    final carCost = TransportMode.car.estimateCost(t.distanceKm);
    final diff = carCost - t.costInr;
    return diff < 0 ? 0 : diff;
  }

  static MilestoneCard forTrip(Trip t) => MilestoneCard(
        id: 'trip-${t.id}',
        scope: MilestoneScope.trip,
        title: t.mode.isGreen ? 'A greener journey' : 'Journey complete',
        period: DateFormat('d MMM, h:mm a').format(t.startTime),
        distanceKm: t.distanceKm,
        duration: t.duration,
        mode: t.mode,
        moneySavedInr: _saved(t),
        ecoPoints: RewardsEngine.pointsForTrip(t),
      );

  static MilestoneCard? weekly(List<Trip> trips, DateTime now) {
    final start = DateRanges.startOfWeek(now);
    final week = DateRanges.within(trips, start, start.add(const Duration(days: 7))).toList();
    if (week.isEmpty) return null;
    final s = PeriodStats.of(week);
    return MilestoneCard(
      id: 'week-${start.toIso8601String()}',
      scope: MilestoneScope.weekly,
      title: 'Your week in motion',
      period: 'Week of ${DateFormat('d MMM').format(start)}',
      distanceKm: s.distanceKm,
      duration: s.duration,
      mode: s.dominantMode,
      moneySavedInr: week.fold(0.0, (a, t) => a + _saved(t)),
      ecoPoints: week.fold(0, (a, t) => a + RewardsEngine.pointsForTrip(t)),
    );
  }

}
