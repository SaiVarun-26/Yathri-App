import 'package:flutter/foundation.dart';

import '../../fuel/domain/fuel_profile.dart';
import '../../trips/domain/trip.dart';
import 'period_stats.dart';

/// The three summaries on Home: today, this week, this month.
@immutable
class HomeSummary {
  const HomeSummary({
    required this.today,
    required this.week,
    required this.month,
    required this.fuel,
    required this.avgDailyTravel,
  });

  final PeriodStats today;
  final PeriodStats week;
  final PeriodStats month;
  final FuelSummary fuel;

  /// Average time on the move on days this month that had any travel.
  final Duration avgDailyTravel;

  factory HomeSummary.build(List<Trip> trips, FuelProfile profile, DateTime now) {
    final dayStart = DateRanges.startOfDay(now);
    final weekStart = DateRanges.startOfWeek(now);
    final monthStart = DateRanges.startOfMonth(now);
    final monthEnd = DateTime(now.year, now.month + 1);

    final monthTrips = DateRanges.within(trips, monthStart, monthEnd).toList();
    final activeDays = {for (final t in monthTrips) DateRanges.startOfDay(t.startTime)}.length;
    final monthStats = PeriodStats.of(monthTrips);

    return HomeSummary(
      today: PeriodStats.of(DateRanges.within(trips, dayStart, dayStart.add(const Duration(days: 1)))),
      week: PeriodStats.of(DateRanges.within(trips, weekStart, weekStart.add(const Duration(days: 7)))),
      month: monthStats,
      fuel: FuelSummary.of(trips, profile, now),
      avgDailyTravel: activeDays == 0
          ? Duration.zero
          : Duration(seconds: (monthStats.duration.inSeconds / activeDays).round()),
    );
  }
}
