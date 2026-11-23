import 'package:flutter/foundation.dart';

import '../../analytics/domain/eco_score.dart';
import '../../analytics/domain/period_stats.dart';
import '../../fuel/domain/fuel_profile.dart';
import '../../trips/domain/transport_mode.dart';
import '../../trips/domain/trip.dart';

/// Targets the user chooses. Stored on the device.
@immutable
class TravelGoals {
  const TravelGoals({
    this.walkKmPerWeek = 10,
    this.cycleKmPerWeek = 15,
    this.fuelBudgetPerMonth = 0,
    this.ecoScoreTarget = 70,
  });

  final double walkKmPerWeek;
  final double cycleKmPerWeek;

  /// Monthly fuel budget in rupees. 0 means no budget set.
  final double fuelBudgetPerMonth;
  final int ecoScoreTarget;

  TravelGoals copyWith({
    double? walkKmPerWeek,
    double? cycleKmPerWeek,
    double? fuelBudgetPerMonth,
    int? ecoScoreTarget,
  }) =>
      TravelGoals(
        walkKmPerWeek: walkKmPerWeek ?? this.walkKmPerWeek,
        cycleKmPerWeek: cycleKmPerWeek ?? this.cycleKmPerWeek,
        fuelBudgetPerMonth: fuelBudgetPerMonth ?? this.fuelBudgetPerMonth,
        ecoScoreTarget: ecoScoreTarget ?? this.ecoScoreTarget,
      );
}

enum GoalKind { walk, cycle, fuel, eco }

@immutable
class GoalProgress {
  const GoalProgress({
    required this.kind,
    required this.title,
    required this.detail,
    required this.fraction,
    required this.achieved,
    this.isSet = true,
    this.warning = false,
  });

  final GoalKind kind;
  final String title;
  final String detail;
  final double fraction;
  final bool achieved;
  final bool isSet;

  /// True when the user is over a limit (fuel budget).
  final bool warning;
}

abstract final class GoalsEngine {
  static List<GoalProgress> evaluate(
    List<Trip> trips,
    TravelGoals goals,
    FuelProfile profile,
    DateTime now,
  ) {
    final weekStart = DateRanges.startOfWeek(now);
    final week = DateRanges.within(trips, weekStart, weekStart.add(const Duration(days: 7))).toList();
    final monthStart = DateRanges.startOfMonth(now);
    final month = DateRanges.within(trips, monthStart, DateTime(now.year, now.month + 1)).toList();

    double kmBy(Iterable<Trip> ts, TransportMode m) =>
        ts.where((t) => t.mode == m).fold(0.0, (a, t) => a + t.distanceKm);

    final walked = kmBy(week, TransportMode.walking);
    final cycled = kmBy(week, TransportMode.cycling);
    final fuel = FuelCalculator.totalFuel(month, profile);
    final eco = EcoScore.of(month);

    String km(double v) => v.toStringAsFixed(v < 10 ? 1 : 0);

    return [
      GoalProgress(
        kind: GoalKind.walk,
        title: 'Walk ${km(goals.walkKmPerWeek)} km this week',
        detail: '${km(walked)} of ${km(goals.walkKmPerWeek)} km',
        fraction: (walked / goals.walkKmPerWeek).clamp(0.0, 1.0),
        achieved: walked >= goals.walkKmPerWeek,
      ),
      GoalProgress(
        kind: GoalKind.cycle,
        title: 'Cycle ${km(goals.cycleKmPerWeek)} km this week',
        detail: '${km(cycled)} of ${km(goals.cycleKmPerWeek)} km',
        fraction: (cycled / goals.cycleKmPerWeek).clamp(0.0, 1.0),
        achieved: cycled >= goals.cycleKmPerWeek,
      ),
      if (goals.fuelBudgetPerMonth > 0)
        GoalProgress(
          kind: GoalKind.fuel,
          title: 'Keep fuel under ₹${goals.fuelBudgetPerMonth.round()} this month',
          detail: fuel <= goals.fuelBudgetPerMonth
              ? '₹${fuel.round()} spent, ₹${(goals.fuelBudgetPerMonth - fuel).round()} left'
              : '₹${(fuel - goals.fuelBudgetPerMonth).round()} over budget',
          fraction: (fuel / goals.fuelBudgetPerMonth).clamp(0.0, 1.0),
          achieved: fuel <= goals.fuelBudgetPerMonth,
          warning: fuel > goals.fuelBudgetPerMonth,
        )
      else
        const GoalProgress(
          kind: GoalKind.fuel,
          title: 'Set a monthly fuel budget',
          detail: 'Tap to choose a limit',
          fraction: 0,
          achieved: false,
          isSet: false,
        ),
      GoalProgress(
        kind: GoalKind.eco,
        title: 'Keep your green score at ${goals.ecoScoreTarget} or more',
        detail: eco == null
            ? 'No trips this month yet'
            : 'This month: $eco out of 100 (100 means no emissions, 0 means driving everywhere)',
        fraction: eco == null ? 0 : (eco / goals.ecoScoreTarget).clamp(0.0, 1.0),
        achieved: eco != null && eco >= goals.ecoScoreTarget,
      ),
    ];
  }
}
