import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../alerts/data/firebase_alerts_repository.dart';
import '../../alerts/domain/local_alert.dart';
import '../../auth/providers/auth_providers.dart';
import '../../fuel/domain/fuel_profile.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../milestones/domain/milestone_card.dart';
import '../../places/providers/places_providers.dart';
import '../../reminders/domain/smart_reminders.dart';
import '../../rewards/domain/goals.dart';
import '../../rewards/domain/rewards.dart';
import '../../rewards/providers/goals_providers.dart';
import '../../trips/domain/trip.dart';
import '../../trips/providers/trip_providers.dart';
import '../domain/home_summary.dart';
import '../domain/insights_engine.dart';
import '../domain/period_stats.dart';
import '../domain/travel_analytics.dart';

/// Re-evaluates date-dependent providers every minute without a rebuild storm.
final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
});

final nowProvider = Provider<DateTime>((ref) => ref.watch(clockProvider).value ?? DateTime.now());

final todaysTripsProvider = Provider<List<Trip>>((ref) {
  final now = ref.watch(nowProvider);
  final start = DateRanges.startOfDay(now);
  return DateRanges.within(ref.watch(tripListProvider), start, start.add(const Duration(days: 1))).toList();
});

/// Today, this week and this month, with fuel, for the Home screen.
final homeSummaryProvider = Provider<HomeSummary>((ref) => HomeSummary.build(
      ref.watch(tripListProvider),
      ref.watch(fuelProfileValueProvider),
      ref.watch(nowProvider),
    ));

/// Fuel used and spent for today, this week, month, year and all time.
final fuelSummaryProvider = Provider<FuelSummary>((ref) => FuelSummary.of(
      ref.watch(tripListProvider),
      ref.watch(fuelProfileValueProvider),
      ref.watch(nowProvider),
    ));

final maintenanceProvider = Provider<MaintenanceStatus?>((ref) =>
    FuelCalculator.maintenance(ref.watch(tripListProvider), ref.watch(fuelProfileValueProvider)));

/// The one most useful sentence for the Home screen.
final smartInsightProvider = Provider<Insight>((ref) => SmartInsights.pick(
      trips: ref.watch(tripListProvider),
      now: ref.watch(nowProvider),
      profile: ref.watch(fuelProfileValueProvider),
      namer: ref.watch(placeNamerProvider),
    ));

/// Which period the Insights page is showing.
class InsightPeriodNotifier extends Notifier<InsightPeriod> {
  @override
  InsightPeriod build() => InsightPeriod.month;

  void select(InsightPeriod period) => state = period;
}

final insightPeriodProvider =
    NotifierProvider<InsightPeriodNotifier, InsightPeriod>(InsightPeriodNotifier.new);

final travelAnalyticsProvider = Provider<TravelAnalytics>((ref) => TravelAnalytics.build(
      allTrips: ref.watch(tripListProvider),
      period: ref.watch(insightPeriodProvider),
      now: ref.watch(nowProvider),
      profile: ref.watch(fuelProfileValueProvider),
      namer: ref.watch(placeNamerProvider),
    ));

final rewardsProvider = Provider<RewardsState>(
    (ref) => RewardsEngine.evaluate(ref.watch(tripListProvider), now: ref.watch(nowProvider)));

final goalProgressProvider = Provider<List<GoalProgress>>((ref) => GoalsEngine.evaluate(
      ref.watch(tripListProvider),
      ref.watch(goalsValueProvider),
      ref.watch(fuelProfileValueProvider),
      ref.watch(nowProvider),
    ));

final remindersProvider = Provider<List<SmartReminder>>((ref) {
  final namer = ref.watch(placeNamerProvider);
  return SmartReminderEngine.remindersFor(
    ref.watch(tripListProvider),
    ref.watch(nowProvider),
    nameOf: namer.name,
  );
});

/// Shareable recap of the current week.
final weeklyMilestoneProvider = Provider<MilestoneCard?>(
    (ref) => MilestoneGenerator.weekly(ref.watch(tripListProvider), ref.watch(nowProvider)));

final alertsRepositoryProvider = Provider<AlertsRepository>((ref) {
  if (ref.watch(firebaseAvailableProvider)) return FirebaseAlertsRepository(FirebaseDatabase.instance);
  return EmptyAlertsRepository();
});

final alertsProvider = StreamProvider<List<LocalAlert>>((ref) {
  // Database rules require a signed-in user; subscribing earlier would fail
  // permanently. Re-evaluates when the anonymous session resolves.
  final session = ref.watch(authSessionProvider).value;
  if (session == null || !session.cloud) return Stream.value(const <LocalAlert>[]);
  final now = DateTime.now();
  return ref
      .watch(alertsRepositoryProvider)
      .watch()
      .map((list) => list.where((a) => a.isActive(now)).toList());
});
