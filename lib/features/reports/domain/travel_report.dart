import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/formatters.dart';
import '../../analytics/domain/period_stats.dart';
import '../../analytics/domain/travel_analytics.dart';
import '../../fuel/domain/fuel_profile.dart';
import '../../places/domain/place_book.dart';
import '../../trips/domain/transport_mode.dart';
import '../../trips/domain/trip.dart';

/// A "Wrapped"-style summary of a month or a year of travel.
@immutable
class TravelReport {
  const TravelReport({
    required this.title,
    required this.period,
    required this.stats,
    required this.fuelInr,
    required this.topPlace,
    required this.topMode,
    required this.longestKm,
    required this.highlights,
  });

  final String title;
  final String period;
  final PeriodStats stats;
  final double fuelInr;
  final PlaceVisit? topPlace;
  final TransportMode? topMode;
  final double longestKm;

  /// One short sentence per fact, in the order they are shown.
  final List<String> highlights;

  bool get isEmpty => stats.tripCount == 0;

  String get shareText => '$title · $period\n${highlights.join('\n')}\n#Yathri';
}

abstract final class TravelReportBuilder {
  /// Months (first day) in which at least one trip started, newest first.
  static List<DateTime> months(List<Trip> trips) {
    final set = {for (final t in trips) DateTime(t.startTime.year, t.startTime.month)};
    return set.toList()..sort((a, b) => b.compareTo(a));
  }

  static List<int> years(List<Trip> trips) {
    final set = {for (final t in trips) t.startTime.year};
    return set.toList()..sort((a, b) => b.compareTo(a));
  }

  static TravelReport month(List<Trip> trips, DateTime month, FuelProfile profile, PlaceNamer namer) {
    final from = DateTime(month.year, month.month);
    final to = DateTime(month.year, month.month + 1);
    return _build(
      DateRanges.within(trips, from, to).toList(),
      title: '${DateFormat('MMMM').format(from)} wrapped',
      period: DateFormat('MMMM y').format(from),
      profile: profile,
      namer: namer,
    );
  }

  static TravelReport year(List<Trip> trips, int year, FuelProfile profile, PlaceNamer namer) {
    return _build(
      DateRanges.within(trips, DateTime(year), DateTime(year + 1)).toList(),
      title: '$year in review',
      period: 'Year in review',
      profile: profile,
      namer: namer,
    );
  }

  static TravelReport _build(
    List<Trip> trips, {
    required String title,
    required String period,
    required FuelProfile profile,
    required PlaceNamer namer,
  }) {
    final stats = PeriodStats.of(trips);
    final fuel = FuelCalculator.totalFuel(trips, profile);
    final places = TravelAnalytics.visitsOf(trips, namer);
    final topPlace = places.isEmpty || places.first.visits < 2 ? null : places.first;
    final longest = trips.fold<double>(0, (a, t) => t.distanceKm > a ? t.distanceKm : a);
    final mode = stats.dominantMode;

    final highlights = <String>[
      if (stats.tripCount > 0) 'You travelled ${stats.distanceKm.round()} km.',
      if (stats.tripCount > 0) 'You spent ${Fmt.durationLong(stats.duration)} on the move.',
      if (topPlace != null) 'You visited ${topPlace.name} ${topPlace.visits} times.',
      if (fuel >= 50) 'You spent about ₹${fuel.round()} on fuel.',
      if (stats.co2SavedKg >= 0.5) 'You saved ${stats.co2SavedKg.round()} kg of CO₂.',
      if (mode != null && stats.tripCount >= 3) '${mode.label} was your most used way to travel.',
      if (longest >= 10) 'Your longest trip was ${longest.round()} km.',
    ];

    return TravelReport(
      title: title,
      period: period,
      stats: stats,
      fuelInr: fuel,
      topPlace: topPlace,
      topMode: mode,
      longestKm: longest,
      highlights: highlights,
    );
  }
}
