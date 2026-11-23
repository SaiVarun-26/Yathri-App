import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../trips/domain/trip.dart';
import '../../trips/domain/zone.dart';

enum ReminderKind { upcoming, runningLate, missed }

@immutable
class RecurringPattern {
  const RecurringPattern({
    required this.origin,
    required this.destination,
    required this.weekdayKind,
    required this.medianMinuteOfDay,
    required this.windowStartMinute,
    required this.windowEndMinute,
    required this.occurrences,
  });

  final Zone origin;
  final Zone destination;

  /// True for Mon–Fri patterns, false for weekend patterns.
  final bool weekdayKind;
  final int medianMinuteOfDay;

  /// Middle half of the departure times (25th to 75th percentile).
  final int windowStartMinute;
  final int windowEndMinute;
  final int occurrences;

  static String labelFor(int minuteOfDay) =>
      DateFormat('h:mm a').format(DateTime(2000, 1, 1, minuteOfDay ~/ 60, minuteOfDay % 60));

  String get timeLabel => labelFor(medianMinuteOfDay);
  /// "around 8:30 AM" when departures are tightly clustered, otherwise a range.
  String get departureLabel => windowEndMinute - windowStartMinute < 10
      ? 'around $timeLabel'
      : 'between ${labelFor(windowStartMinute)} and ${labelFor(windowEndMinute)}';
}

@immutable
class SmartReminder {
  const SmartReminder(this.kind, this.title, this.body);
  final ReminderKind kind;
  final String title;
  final String body;
}

abstract final class SmartReminderEngine {
  static const _lookbackDays = 35;
  static const _clusterToleranceMin = 45;
  static const _minDistinctDays = 3;

  static bool _isWeekday(DateTime d) => d.weekday <= DateTime.friday;
  static int _minuteOfDay(DateTime d) => d.hour * 60 + d.minute;

  /// Finds routes the user repeats at a similar time on similar kinds of day.
  static List<RecurringPattern> detectPatterns(List<Trip> trips, DateTime now) {
    final since = now.subtract(const Duration(days: _lookbackDays));
    final recent = trips
        .where((t) => t.startTime.isAfter(since) && t.originZone != t.destinationZone)
        .toList();

    final groups = <String, List<Trip>>{};
    for (final t in recent) {
      final key = '${t.originZone.id}>${t.destinationZone.id}|${_isWeekday(t.startTime)}';
      groups.putIfAbsent(key, () => []).add(t);
    }

    final patterns = <RecurringPattern>[];
    for (final group in groups.values) {
      group.sort((a, b) => _minuteOfDay(a.startTime).compareTo(_minuteOfDay(b.startTime)));
      final median = _minuteOfDay(group[group.length ~/ 2].startTime);
      final cluster = group
          .where((t) => (_minuteOfDay(t.startTime) - median).abs() <= _clusterToleranceMin)
          .toList();
      final days = cluster
          .map((t) => DateTime(t.startTime.year, t.startTime.month, t.startTime.day))
          .toSet();
      if (days.length >= _minDistinctDays) {
        final minutes = cluster.map((t) => _minuteOfDay(t.startTime)).toList()..sort();
        patterns.add(RecurringPattern(
          origin: group.first.originZone,
          destination: group.first.destinationZone,
          weekdayKind: _isWeekday(group.first.startTime),
          medianMinuteOfDay: median,
          windowStartMinute: minutes[(minutes.length * 0.25).floor()],
          windowEndMinute: minutes[((minutes.length - 1) * 0.75).ceil()],
          occurrences: days.length,
        ));
      }
    }
    patterns.sort((a, b) => b.occurrences.compareTo(a.occurrences));
    return patterns;
  }

  static List<SmartReminder> remindersFor(
    List<Trip> trips,
    DateTime now, {
    String Function(Zone zone)? nameOf,
  }) {
    final reminders = <SmartReminder>[];
    final nowMin = _minuteOfDay(now);
    final todayTrips = trips.where((t) =>
        t.startTime.year == now.year && t.startTime.month == now.month && t.startTime.day == now.day);

    for (final p in detectPatterns(trips, now)) {
      if (p.weekdayKind != _isWeekday(now)) continue;
      final startedAround = todayTrips.any((t) =>
          t.originZone == p.origin &&
          (_minuteOfDay(t.startTime) - p.medianMinuteOfDay).abs() <= 120);
      if (startedAround) continue;

      final place = nameOf?.call(p.destination);
      final to = place == null ? '' : ' for $place';
      final delta = nowMin - p.medianMinuteOfDay;
      if (delta >= -60 && delta < 0) {
        reminders.add(SmartReminder(ReminderKind.upcoming, 'You usually leave$to around ${p.timeLabel}',
            'Based on ${p.occurrences} similar days recently.'));
      } else if (delta >= 0 && delta <= 30) {
        reminders.add(SmartReminder(ReminderKind.runningLate, 'You may be running late',
            'Your usual ${p.timeLabel} trip${place == null ? '' : ' to $place'} has not started yet.'));
      } else if (delta > 90 && delta <= 300) {
        reminders.add(SmartReminder(ReminderKind.missed, 'No trip detected yet today',
            'You normally travel around ${p.timeLabel}. If you did, check that tracking is on.'));
      }
    }
    return reminders;
  }
}
