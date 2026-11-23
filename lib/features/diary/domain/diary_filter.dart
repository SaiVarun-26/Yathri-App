import 'package:flutter/foundation.dart';

import '../../analytics/domain/period_stats.dart';
import '../../trips/domain/trip.dart';

enum DiaryFilterKind {
  all('All'),
  today('Today'),
  yesterday('Yesterday'),
  week('This week'),
  month('This month'),
  custom('Pick dates');

  const DiaryFilterKind(this.label);
  final String label;
}

@immutable
class DiaryFilter {
  const DiaryFilter({this.kind = DiaryFilterKind.all, this.customFrom, this.customTo});

  final DiaryFilterKind kind;

  /// First and last day (inclusive) when [kind] is [DiaryFilterKind.custom].
  final DateTime? customFrom;
  final DateTime? customTo;

  /// Trips that fall inside this filter, newest first.
  List<Trip> apply(List<Trip> trips, DateTime now) {
    final today = DateRanges.startOfDay(now);
    final (DateTime from, DateTime to)? range = switch (kind) {
      DiaryFilterKind.all => null,
      DiaryFilterKind.today => (today, today.add(const Duration(days: 1))),
      DiaryFilterKind.yesterday => (today.subtract(const Duration(days: 1)), today),
      DiaryFilterKind.week => (DateRanges.startOfWeek(now), DateRanges.startOfWeek(now).add(const Duration(days: 7))),
      DiaryFilterKind.month => (DateRanges.startOfMonth(now), DateTime(now.year, now.month + 1)),
      DiaryFilterKind.custom => customFrom == null || customTo == null
          ? null
          : (
              DateRanges.startOfDay(customFrom!),
              DateRanges.startOfDay(customTo!).add(const Duration(days: 1)),
            ),
    };
    if (range == null) return trips;
    return DateRanges.within(trips, range.$1, range.$2).toList();
  }

  /// Shown when the filter matches nothing.
  String get emptyMessage => switch (kind) {
        DiaryFilterKind.all => 'Every trip Yathri detects is written here for you.',
        DiaryFilterKind.today => 'No trips today yet.',
        DiaryFilterKind.yesterday => 'No trips yesterday.',
        DiaryFilterKind.week => 'No trips this week yet.',
        DiaryFilterKind.month => 'No trips this month yet.',
        DiaryFilterKind.custom => 'No trips on those dates.',
      };
}
