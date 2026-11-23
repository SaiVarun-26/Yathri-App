import 'package:flutter/foundation.dart';

import '../../trips/domain/zone.dart';

/// A regular journey, in a form the background service can read without any
/// of the app's providers.
@immutable
class CommuteRoute {
  const CommuteRoute({
    required this.originZoneId,
    required this.destinationName,
    required this.weekdayKind,
    required this.medianMinute,
  });

  final String originZoneId;
  final String destinationName;
  final bool weekdayKind;
  final int medianMinute;

  Map<String, dynamic> toJson() => {
        'o': originZoneId,
        'd': destinationName,
        'w': weekdayKind,
        'm': medianMinute,
      };

  factory CommuteRoute.fromJson(Map<dynamic, dynamic> j) => CommuteRoute(
        originZoneId: j['o'] as String,
        destinationName: j['d'] as String? ?? 'your usual place',
        weekdayKind: j['w'] as bool? ?? true,
        medianMinute: (j['m'] as num).toInt(),
      );

  /// One alert per route per day.
  String dayKey(DateTime now) => '${now.year}-${now.month}-${now.day}|$originZoneId|$destinationName';
}

/// Decides whether to nudge the user: it is a little past their usual
/// departure time, the phone is still where they usually leave from, and
/// nothing has moved since well before that time.
abstract final class LateCommuteChecker {
  static const _earliestAfterMin = 10;
  static const _latestAfterMin = 45;
  static const _quietBeforeMin = 90;

  static CommuteRoute? check({
    required DateTime now,
    required List<CommuteRoute> routes,
    required double? lat,
    required double? lng,
    required DateTime? lastActiveAt,
    required Set<String> alreadyAlerted,
  }) {
    if (lat == null || lng == null) return null;
    final here = Zone.fromLatLng(lat, lng).id;
    final nowMin = now.hour * 60 + now.minute;
    final isWeekday = now.weekday <= DateTime.friday;
    final midnight = DateTime(now.year, now.month, now.day);

    for (final r in routes) {
      if (r.weekdayKind != isWeekday) continue;
      final late = nowMin - r.medianMinute;
      if (late < _earliestAfterMin || late > _latestAfterMin) continue;
      if (r.originZoneId != here) continue;
      if (alreadyAlerted.contains(r.dayKey(now))) continue;
      final quietSince = midnight.add(Duration(minutes: r.medianMinute - _quietBeforeMin));
      if (lastActiveAt != null && lastActiveAt.isAfter(quietSince)) continue;
      return r;
    }
    return null;
  }
}
