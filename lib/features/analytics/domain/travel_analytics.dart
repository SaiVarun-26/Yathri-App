import 'package:flutter/foundation.dart';

import '../../../core/utils/formatters.dart';
import '../../fuel/domain/fuel_profile.dart';
import '../../places/domain/place_book.dart';
import '../../reminders/domain/smart_reminders.dart';
import '../../trips/domain/transport_mode.dart';
import '../../trips/domain/trip.dart';
import '../../trips/domain/zone.dart';
import 'alternatives.dart';
import 'period_stats.dart';

/// The span the Insights page is looking at.
enum InsightPeriod {
  week('This week', 'this week'),
  month('This month', 'this month'),
  all('All time', 'so far');

  const InsightPeriod(this.label, this.phrase);

  final String label;

  /// For use inside a sentence.
  final String phrase;
}

@immutable
class PlaceVisit {
  const PlaceVisit(this.zone, this.name, this.visits);
  final Zone zone;
  final String name;
  final int visits;
}

@immutable
class ModeUse {
  const ModeUse(this.mode, this.trips, this.share);
  final TransportMode mode;
  final int trips;
  final double share;
}

/// "Travel overview" card.
@immutable
class OverviewStats {
  const OverviewStats({
    required this.distanceKm,
    required this.tripCount,
    required this.travelTime,
    required this.avgSpeedKmh,
    required this.favouriteMode,
  });

  final double distanceKm;
  final int tripCount;
  final Duration travelTime;

  /// Speed while actually moving, stops excluded.
  final double avgSpeedKmh;
  final ModeUse? favouriteMode;
}

/// "Travel behaviour" card.
@immutable
class BehaviourStats {
  const BehaviourStats({
    required this.mostVisited,
    required this.longestTrip,
    required this.shortestTrip,
    required this.avgCommuteMinutes,
    required this.mostActiveWeekday,
    required this.mostActiveHour,
  });

  final PlaceVisit? mostVisited;
  final Trip? longestTrip;
  final Trip? shortestTrip;
  final double? avgCommuteMinutes;

  /// 1 = Monday. Null until there is enough history to say.
  final int? mostActiveWeekday;
  final int? mostActiveHour;
}

/// Everything the Insights screen shows for one period.
@immutable
class TravelAnalytics {
  const TravelAnalytics({
    required this.period,
    required this.overview,
    required this.behaviour,
    required this.sentences,
  });

  final InsightPeriod period;
  final OverviewStats overview;
  final BehaviourStats behaviour;

  /// Plain sentences, most useful first.
  final List<String> sentences;

  bool get hasData => overview.tripCount > 0;

  static const _weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static String weekdayName(int weekday) => _weekdayNames[weekday - 1];

  static String hourLabel(int hour) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h ${hour < 12 ? 'AM' : 'PM'}';
  }

  /// Cost of making [km] by [mode] for this user.
  static double priceFor(TransportMode mode, double km, FuelProfile p) => switch (mode) {
        TransportMode.car => km / p.carKmpl * p.pricePerLitre,
        TransportMode.bike => km / p.bikeKmpl * p.pricePerLitre,
        _ => mode.estimateCost(km),
      };

  static List<PlaceVisit> visitsOf(List<Trip> trips, PlaceNamer namer) {
    final counts = <Zone, int>{};
    for (final t in trips) {
      counts[t.destinationZone] = (counts[t.destinationZone] ?? 0) + 1;
    }
    return [
      for (final e in counts.entries)
        if (!namer.isHome(e.key)) PlaceVisit(e.key, namer.name(e.key), e.value),
    ]..sort((a, b) => b.visits.compareTo(a.visits));
  }

  /// Trips in [period], and the equivalent span just before it, cut to the
  /// same length so a half-finished month is compared like with like.
  static (List<Trip> current, List<Trip> previous) split(List<Trip> all, InsightPeriod period, DateTime now) {
    switch (period) {
      case InsightPeriod.all:
        return (all, const []);
      case InsightPeriod.week:
        final start = DateRanges.startOfWeek(now);
        final prevStart = start.subtract(const Duration(days: 7));
        return (
          DateRanges.within(all, start, start.add(const Duration(days: 7))).toList(),
          DateRanges.within(all, prevStart, prevStart.add(now.difference(start))).toList(),
        );
      case InsightPeriod.month:
        final start = DateRanges.startOfMonth(now);
        final prevStart = DateTime(now.year, now.month - 1);
        final prevEnd = start;
        var prevCut = prevStart.add(now.difference(start));
        if (prevCut.isAfter(prevEnd)) prevCut = prevEnd;
        return (
          DateRanges.within(all, start, DateTime(now.year, now.month + 1)).toList(),
          DateRanges.within(all, prevStart, prevCut).toList(),
        );
    }
  }

  /// How much cheaper the trips were than driving every one by car, in rupees.
  static double savedVersusCar(List<Trip> trips, FuelProfile profile) {
    var carCost = 0.0;
    var actual = 0.0;
    for (final t in trips) {
      carCost += priceFor(TransportMode.car, t.distanceKm, profile);
      actual += FuelCalculator.tripCost(t, profile);
    }
    return carCost - actual;
  }

  factory TravelAnalytics.build({
    required List<Trip> allTrips,
    required InsightPeriod period,
    required DateTime now,
    required FuelProfile profile,
    required PlaceNamer namer,
  }) {
    final (trips, previous) = split(allTrips, period, now);

    // Overview -------------------------------------------------------------
    final stats = PeriodStats.of(trips);
    final movingSeconds = trips.fold<int>(0, (a, t) => a + t.movingSeconds);
    final modeCounts = <TransportMode, int>{};
    for (final t in trips) {
      if (t.mode != TransportMode.unknown) modeCounts[t.mode] = (modeCounts[t.mode] ?? 0) + 1;
    }
    ModeUse? favourite;
    if (modeCounts.isNotEmpty) {
      final top = modeCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);
      favourite = ModeUse(top.key, top.value, top.value / modeCounts.values.fold(0, (a, b) => a + b));
    }
    final overview = OverviewStats(
      distanceKm: stats.distanceKm,
      tripCount: trips.length,
      travelTime: stats.duration,
      avgSpeedKmh: movingSeconds > 0 ? stats.distanceKm / (movingSeconds / 3600) : 0,
      favouriteMode: favourite,
    );

    // Behaviour ------------------------------------------------------------
    final visits = visitsOf(trips, namer);

    Trip? longest, shortest;
    final byWeekday = <int, int>{};
    final byHour = <int, int>{};
    for (final t in trips) {
      if (longest == null || t.distanceMeters > longest.distanceMeters) longest = t;
      if (shortest == null || t.distanceMeters < shortest.distanceMeters) shortest = t;
      byWeekday[t.startTime.weekday] = (byWeekday[t.startTime.weekday] ?? 0) + 1;
      byHour[t.startTime.hour] = (byHour[t.startTime.hour] ?? 0) + 1;
    }
    int? topOf(Map<int, int> counts) {
      if (trips.length < 6 || counts.isEmpty) return null;
      // Only name a day or hour when it clearly stands out from the rest.
      final ranked = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final top = ranked.first;
      final runnerUp = ranked.length > 1 ? ranked[1].value : 0;
      return top.value >= 2 && top.value >= runnerUp * 1.2 ? top.key : null;
    }

    // Commute is judged on the whole history so a quiet week does not erase it.
    final patterns = SmartReminderEngine.detectPatterns(allTrips, now);
    double? avgCommute;
    if (patterns.isNotEmpty) {
      final commute = allTrips.where((t) =>
          now.difference(t.startTime) < const Duration(days: 35) &&
          patterns.any((p) =>
              p.origin == t.originZone &&
              p.destination == t.destinationZone &&
              p.weekdayKind == (t.startTime.weekday <= DateTime.friday))).toList();
      if (commute.isNotEmpty) {
        avgCommute = commute.fold<int>(0, (a, t) => a + t.duration.inSeconds) / commute.length / 60;
      }
    }

    final behaviour = BehaviourStats(
      mostVisited: visits.isEmpty || visits.first.visits < 2 ? null : visits.first,
      longestTrip: longest,
      shortestTrip: shortest,
      avgCommuteMinutes: avgCommute,
      mostActiveWeekday: topOf(byWeekday),
      mostActiveHour: topOf(byHour),
    );

    return TravelAnalytics(
      period: period,
      overview: overview,
      behaviour: behaviour,
      sentences: _sentences(
        trips: trips,
        previous: previous,
        period: period,
        overview: overview,
        behaviour: behaviour,
        profile: profile,
      ),
    );
  }

  /// Short, friendly sentences. No jargon; each says one thing.
  static List<String> _sentences({
    required List<Trip> trips,
    required List<Trip> previous,
    required InsightPeriod period,
    required OverviewStats overview,
    required BehaviourStats behaviour,
    required FuelProfile profile,
  }) {
    if (trips.isEmpty) return const [];
    final out = <String>[];

    out.add('You travelled ${overview.distanceKm.round()} km ${period.phrase}.');

    final fuel = FuelCalculator.totalFuel(trips, profile);
    if (fuel >= 20) out.add('You spent ${Fmt.rupees(fuel)} on fuel ${period.phrase}.');

    final prevKm = previous.fold(0.0, (a, t) => a + t.distanceKm);
    if (prevKm >= 2) {
      final change = ((overview.distanceKm - prevKm) / prevKm * 100).round();
      final last = period == InsightPeriod.week ? 'last week' : 'last month';
      if (change.abs() >= 10) {
        out.add(change > 0
            ? 'You travelled $change% more than $last, up to the same day.'
            : 'You travelled ${-change}% less than $last, up to the same day.');
      }
    }

    final saved = savedVersusCar(trips, profile);
    if (saved >= 20) out.add('You saved ${Fmt.rupees(saved)} compared with driving every trip by car.');

    if (period == InsightPeriod.month) {
      final swaps = Alternatives.forMonth(trips, (t) => FuelCalculator.tripCost(t, profile));
      if (swaps.isNotEmpty) {
        final s = swaps.first;
        out.add('You could save about ${Fmt.rupees(s.monthlySavingInr)} a month by taking '
            'the ${s.to.label.toLowerCase()} instead of the ${s.from.label.toLowerCase()} '
            'for ${s.tripsConsidered} of your trips.');
      }
    }

    final hour = behaviour.mostActiveHour;
    if (hour != null) out.add('You usually travel between ${hourLabel(hour)} and ${hourLabel(hour + 1)}.');

    final day = behaviour.mostActiveWeekday;
    if (day != null) out.add('${weekdayName(day)} is your busiest travel day.');

    final longest = behaviour.longestTrip;
    if (longest != null && longest.distanceKm >= 2) {
      out.add('Your longest trip was ${longest.distanceKm.round()} km.');
    }

    final fav = overview.favouriteMode;
    if (fav != null && trips.length >= 4) {
      final how = _howPhrase(fav.mode);
      out.add(fav.share >= 0.5 ? 'Most of your trips are $how.' : 'You travel $how more than any other way.');
    }

    return out.take(8).toList();
  }

  /// "by car", "on foot": how a mode reads in a sentence.
  static String _howPhrase(TransportMode m) => switch (m) {
        TransportMode.walking => 'on foot',
        TransportMode.running => 'runs',
        TransportMode.cycling => 'by cycle',
        TransportMode.bike => 'by bike or scooter',
        TransportMode.auto => 'by auto',
        _ => 'by ${m.label.toLowerCase()}',
      };
}
