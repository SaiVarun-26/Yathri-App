import 'package:flutter/foundation.dart';

import '../../analytics/domain/period_stats.dart';
import '../../trips/domain/transport_mode.dart';
import '../../trips/domain/trip.dart';

@immutable
class RewardBadge {
  const RewardBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.progress,
    required this.target,
  });

  final String id;
  final String name;
  final String description;
  final double progress;
  final double target;

  bool get earned => progress >= target;
  double get fraction => (progress / target).clamp(0.0, 1.0);
}

/// A goal that resets every month. Completing one earns XP, counted for
/// every past month too, so XP never goes down.
@immutable
class Challenge {
  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.target,
    required this.unit,
    required this.rewardXp,
  });

  final String id;
  final String title;
  final String description;
  final double progress;
  final double target;
  final String unit;
  final int rewardXp;

  bool get done => progress >= target;
  double get fraction => (progress / target).clamp(0.0, 1.0);
}

@immutable
class PartnerOffer {
  const PartnerOffer(this.title, this.partner, this.requiredLevel);
  final String title;
  final String partner;
  final int requiredLevel;
}

@immutable
class RewardsState {
  const RewardsState({
    required this.ecoPoints,
    required this.xp,
    required this.level,
    required this.levelName,
    required this.nextLevelName,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    required this.badges,
    required this.challenges,
    required this.offers,
    required this.streakDays,
    required this.longestStreakDays,
  });

  final int ecoPoints;
  final int xp;
  final int level;
  final String levelName;
  final String? nextLevelName;
  final int xpIntoLevel;

  /// XP needed to span the current level; null at the top level.
  final int? xpForNextLevel;
  final List<RewardBadge> badges;

  /// This month's challenges.
  final List<Challenge> challenges;
  final List<PartnerOffer> offers;
  final int streakDays;
  final int longestStreakDays;

  double get levelFraction =>
      xpForNextLevel == null ? 1 : (xpIntoLevel / xpForNextLevel!).clamp(0.0, 1.0);
}

abstract final class RewardsEngine {
  static const _levels = <(int, String)>[
    (0, 'Explorer'),
    (200, 'Navigator'),
    (600, 'Commuter'),
    (1500, 'Traveller'),
    (3500, 'Road Master'),
    (7000, 'Eco Hero'),
  ];

  static const _catalogue = <PartnerOffer>[
    PartnerOffer('10% off a metro smart card top-up', 'City Metro', 1),
    PartnerOffer('Free filter coffee with any snack', 'Local cafes', 2),
    PartnerOffer('15% off cycle rentals', 'Pedal Kerala', 3),
    PartnerOffer('20% off a heritage walk', 'Tourism Board', 4),
    PartnerOffer('Free night upgrade at partner homestays', 'Homestay Network', 5),
  ];

  static const _achievementBonusXp = 100;

  /// Eco points for one trip: carbon avoided plus a bonus for active travel.
  static int pointsForTrip(Trip t) {
    final carbon = t.co2SavedGrams / 100;
    final active = t.mode.isActive ? t.distanceKm * 2 : 0;
    return (carbon + active).round();
  }

  /// XP for one trip: a base amount, distance, and the eco points.
  static int xpForTrip(Trip t) {
    final distance = (t.distanceKm * 2).clamp(0, 60);
    return (10 + distance + pointsForTrip(t)).round();
  }

  static bool _privateMotor(TransportMode m) =>
      m == TransportMode.car || m == TransportMode.taxi || m == TransportMode.bike || m == TransportMode.auto;

  /// Days on which every trip avoided private motor vehicles.
  static Set<DateTime> _greenDays(List<Trip> trips) {
    final status = <DateTime, bool>{};
    for (final t in trips) {
      final day = DateRanges.startOfDay(t.startTime);
      status[day] = (status[day] ?? true) && !_privateMotor(t.mode);
    }
    return {for (final e in status.entries) if (e.value) e.key};
  }

  static DateTime _prevDay(DateTime d) => DateTime(d.year, d.month, d.day - 1);

  /// Consecutive days with at least one trip and no private motor vehicle.
  /// A day with no trips ends the streak, except that today is not counted
  /// as missed until it is over.
  static (int current, int longest) streaks(List<Trip> trips, DateTime now) {
    final green = _greenDays(trips);
    final today = DateRanges.startOfDay(now);

    final tripDays = {for (final t in trips) DateRanges.startOfDay(t.startTime)};
    var cursor = tripDays.contains(today) ? today : _prevDay(today);
    var current = 0;
    while (green.contains(cursor)) {
      current++;
      cursor = _prevDay(cursor);
    }

    var longest = 0;
    for (final day in green) {
      if (green.contains(_prevDay(day))) continue; // not the start of a run
      var run = 0;
      var d = day;
      while (green.contains(d)) {
        run++;
        d = DateTime(d.year, d.month, d.day + 1);
      }
      if (run > longest) longest = run;
    }
    return (current, longest < current ? current : longest);
  }

  static List<Challenge> challengesFor(Iterable<Trip> monthTrips) {
    final trips = monthTrips.toList();
    final walkKm = trips.where((t) => t.mode == TransportMode.walking).fold(0.0, (a, t) => a + t.distanceKm);
    final greenKm = trips.where((t) => t.mode.isGreen).fold(0.0, (a, t) => a + t.distanceKm);
    final carFreeDays = _greenDays(trips).length;
    return [
      Challenge(
          id: 'walk',
          title: 'Walk 25 km',
          description: 'Walk 25 km in total this month.',
          progress: walkKm,
          target: 25,
          unit: 'km',
          rewardXp: 150),
      Challenge(
          id: 'green',
          title: 'Go green',
          description: 'Cover 100 km on foot, by cycle or on public transport.',
          progress: greenKm,
          target: 100,
          unit: 'km',
          rewardXp: 200),
      Challenge(
          id: 'carfree',
          title: 'Car-free days',
          description: 'Travel on 8 days without a car, bike, auto or taxi.',
          progress: carFreeDays.toDouble(),
          target: 8,
          unit: 'days',
          rewardXp: 250),
    ];
  }

  static RewardsState evaluate(List<Trip> trips, {DateTime? now}) {
    final today = now ?? DateTime.now();

    final byMonth = <DateTime, List<Trip>>{};
    for (final t in trips) {
      byMonth.putIfAbsent(DateRanges.startOfMonth(t.startTime), () => []).add(t);
    }
    final thisMonth = DateRanges.startOfMonth(today);

    var challengeXp = 0;
    for (final entry in byMonth.entries) {
      for (final c in challengesFor(entry.value)) {
        if (c.done) challengeXp += c.rewardXp;
      }
    }

    final greenKm = trips.where((t) => t.mode.isGreen).fold<double>(0, (a, t) => a + t.distanceKm);
    final activeKm = trips.where((t) => t.mode.isActive).fold<double>(0, (a, t) => a + t.distanceKm);
    final cycleKm = trips.where((t) => t.mode == TransportMode.cycling).fold<double>(0, (a, t) => a + t.distanceKm);
    final zones = trips.map((t) => t.destinationZone).toSet().length;
    final longest = trips.fold<double>(0, (a, t) => t.distanceKm > a ? t.distanceKm : a);
    final (streak, longestStreak) = streaks(trips, today);

    final badges = [
      RewardBadge(
          id: 'green',
          name: 'Green Badge',
          description: 'Travel 50 km on walking, cycling or public transport.',
          progress: greenKm,
          target: 50),
      RewardBadge(
          id: 'explorer',
          name: 'Explorer Badge',
          description: 'Reach 10 different parts of your city.',
          progress: zones.toDouble(),
          target: 10),
      RewardBadge(
          id: 'walker',
          name: 'Footpath Friend',
          description: 'Cover 25 km on foot or by cycle.',
          progress: activeKm,
          target: 25),
      RewardBadge(
          id: 'cyclist',
          name: 'Pedal Power',
          description: 'Cycle 20 km.',
          progress: cycleKm,
          target: 20),
      RewardBadge(
          id: 'tourism',
          name: 'Tourism Traveller',
          description: 'Complete one journey of 50 km or more.',
          progress: longest,
          target: 50),
      RewardBadge(
          id: 'regular',
          name: 'Road Regular',
          description: 'Record 50 trips.',
          progress: trips.length.toDouble(),
          target: 50),
      RewardBadge(
          id: 'streak',
          name: 'Green Week',
          description: 'Seven days in a row without a car, bike, auto or taxi.',
          progress: longestStreak.toDouble(),
          target: 7),
    ];

    final tripXp = trips.fold<int>(0, (a, t) => a + xpForTrip(t));
    final xp = tripXp + challengeXp + badges.where((b) => b.earned).length * _achievementBonusXp;

    var level = 0;
    for (var i = 0; i < _levels.length; i++) {
      if (xp >= _levels[i].$1) level = i;
    }
    final floor = _levels[level].$1;
    final hasNext = level + 1 < _levels.length;

    return RewardsState(
      ecoPoints: trips.fold<int>(0, (a, t) => a + pointsForTrip(t)),
      xp: xp,
      level: level + 1,
      levelName: _levels[level].$2,
      nextLevelName: hasNext ? _levels[level + 1].$2 : null,
      xpIntoLevel: xp - floor,
      xpForNextLevel: hasNext ? _levels[level + 1].$1 - floor : null,
      badges: badges,
      challenges: challengesFor(byMonth[thisMonth] ?? const []),
      offers: _catalogue,
      streakDays: streak,
      longestStreakDays: longestStreak,
    );
  }

  static bool isUnlocked(PartnerOffer o, RewardsState s) => s.level >= o.requiredLevel;
}
