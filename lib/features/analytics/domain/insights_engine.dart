import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/formatters.dart';
import '../../fuel/domain/fuel_profile.dart';
import '../../places/domain/place_book.dart';
import '../../reminders/domain/smart_reminders.dart';
import '../../trips/domain/trip.dart';
import 'traffic_analyzer.dart';
import 'travel_analytics.dart';

enum InsightKind { behaviour, commute, carbon, money, trend, timing, traffic, place }

@immutable
class Insight {
  const Insight(this.kind, this.title, this.body);
  final InsightKind kind;
  final String title;
  final String body;
}

/// Chooses the single most useful thing to tell the user right now.
///
/// Home already shows today's, this week's and this month's totals, so this
/// card never repeats them. It says something the numbers do not: how today
/// compares with usual, your routine, or a way to save.
/// Everything is computed on the phone from the user's own history.
abstract final class SmartInsights {
  static String _hour(int h) => DateFormat('h a').format(DateTime(2000, 1, 1, h));

  static Insight pick({
    required List<Trip> trips,
    required DateTime now,
    required FuelProfile profile,
    required PlaceNamer namer,
  }) {
    if (trips.isEmpty) {
      return const Insight(
        InsightKind.behaviour,
        'Just go about your day',
        'After a few trips, this card will point out patterns, delays and ways to save.',
      );
    }

    // 1. Today's trip against the usual time on the same route.
    final traffic = TrafficAnalyzer.todayVsUsual(trips, now);
    if (traffic != null && traffic.deltaFraction.abs() >= 0.15) {
      final pct = (traffic.deltaFraction.abs() * 100).round();
      final place = namer.name(traffic.trip.destinationZone);
      return traffic.deltaFraction > 0
          ? Insight(InsightKind.traffic, 'Traffic is $pct% worse than usual',
              'Your trip to $place took ${Fmt.durationLong(traffic.trip.duration)}. It usually takes ${Fmt.durationLong(traffic.usual)}.')
          : Insight(InsightKind.traffic, 'Roads were $pct% clearer than usual',
              'Your trip to $place took ${Fmt.durationLong(traffic.trip.duration)} against the usual ${Fmt.durationLong(traffic.usual)}.');
    }

    // 2. How this week compares with last week, up to the same day.
    final (week, lastWeek) = TravelAnalytics.split(trips, InsightPeriod.week, now);
    final weekKm = week.fold(0.0, (a, t) => a + t.distanceKm);
    final lastKm = lastWeek.fold(0.0, (a, t) => a + t.distanceKm);
    if (lastKm >= 5 && weekKm > 0) {
      final change = ((weekKm - lastKm) / lastKm * 100).round();
      if (change.abs() >= 15) {
        return Insight(
          InsightKind.trend,
          change > 0 ? '$change% more travel than last week' : '${-change}% less travel than last week',
          'Counting up to the same day of the week.',
        );
      }
    }

    // 3. A time of day that has been reliably faster.
    final advice = TrafficAnalyzer.departureAdvice(trips, now);
    if (advice != null) {
      return Insight(
        InsightKind.traffic,
        'Leave around ${_hour(advice.betterHour)} to save ${advice.minutesSaved} min',
        'Trips to ${namer.name(advice.destination)} have been faster then than at ${_hour(advice.usualHour)}.',
      );
    }

    // 4. The routine for today.
    // Only routines still ahead of us today; one that has passed is old news.
    final weekday = now.weekday <= DateTime.friday;
    final nowMinute = now.hour * 60 + now.minute;
    for (final p in SmartReminderEngine.detectPatterns(trips, now)) {
      if (p.weekdayKind != weekday || p.medianMinuteOfDay < nowMinute) continue;
      return Insight(
        InsightKind.commute,
        'You usually leave for ${namer.name(p.destination)} at ${p.timeLabel}',
        'Based on ${p.occurrences} similar ${weekday ? 'weekdays' : 'weekend days'}.',
      );
    }

    // 5. Money saved against driving, or a cheaper way to travel.
    final month = TravelAnalytics.split(trips, InsightPeriod.month, now).$1;
    final saved = TravelAnalytics.savedVersusCar(month, profile);
    if (saved >= 50) {
      return Insight(
        InsightKind.money,
        'You saved ${Fmt.rupees(saved)} this month',
        'That is what you would have spent driving every trip by car, minus what you actually spent.',
      );
    }

    // 6. When the user travels most.
    if (trips.length >= 5) {
      final byHour = <int, int>{};
      for (final t in trips) {
        byHour[t.startTime.hour] = (byHour[t.startTime.hour] ?? 0) + 1;
      }
      final peak = byHour.entries.reduce((a, b) => a.value >= b.value ? a : b);
      return Insight(
        InsightKind.timing,
        'Most of your trips start between ${_hour(peak.key)} and ${_hour(peak.key + 1)}',
        '${peak.value} of your ${trips.length} trips began in that hour.',
      );
    }

    return const Insight(
      InsightKind.behaviour,
      'Getting to know your routine',
      'A few more trips and Yathri can spot your regular journeys.',
    );
  }
}
