import 'package:flutter/foundation.dart';

import '../../trips/domain/trip.dart';
import '../../trips/domain/zone.dart';

/// Names the user gave to places, plus area names looked up for zones.
@immutable
class PlaceBook {
  const PlaceBook({this.labels = const {}, this.geocoded = const {}});

  /// Zone id → name typed or chosen by the user.
  final Map<String, String> labels;

  /// Zone id → area name from reverse geocoding (cached).
  final Map<String, String> geocoded;

  PlaceBook copyWith({Map<String, String>? labels, Map<String, String>? geocoded}) =>
      PlaceBook(labels: labels ?? this.labels, geocoded: geocoded ?? this.geocoded);
}

/// Guesses the meaning of a zone from the user's own routine.
abstract final class PlaceInference {
  static const home = 'Home';
  static const work = 'Work / College';

  /// Home: the zone where the day's first trip most often starts.
  /// Work/College: the weekday destination reached on the most separate days.
  static Map<String, String> infer(List<Trip> trips) {
    final out = <String, String>{};

    final firstOfDay = <DateTime, Trip>{};
    for (final t in trips) {
      final day = DateTime(t.startTime.year, t.startTime.month, t.startTime.day);
      final current = firstOfDay[day];
      if (current == null || t.startTime.isBefore(current.startTime)) firstOfDay[day] = t;
    }
    final homeVotes = <Zone, int>{};
    for (final t in firstOfDay.values) {
      homeVotes[t.originZone] = (homeVotes[t.originZone] ?? 0) + 1;
    }
    Zone? homeZone;
    var best = 0;
    homeVotes.forEach((zone, votes) {
      if (votes > best) {
        best = votes;
        homeZone = zone;
      }
    });
    if (homeZone == null || best < 3) return out;
    out[homeZone!.id] = home;

    final daysAt = <Zone, Set<DateTime>>{};
    for (final t in trips) {
      if (t.startTime.weekday > DateTime.friday) continue;
      if (t.destinationZone == homeZone) continue;
      final day = DateTime(t.startTime.year, t.startTime.month, t.startTime.day);
      daysAt.putIfAbsent(t.destinationZone, () => {}).add(day);
    }
    Zone? workZone;
    var workDays = 0;
    daysAt.forEach((zone, days) {
      if (days.length > workDays) {
        workDays = days.length;
        workZone = zone;
      }
    });
    if (workZone != null && workDays >= 3) out[workZone!.id] = work;
    return out;
  }
}

/// Resolves a zone to the most meaningful name available.
/// Priority: the user's own name, then routine inference, then area name.
class PlaceNamer {
  const PlaceNamer({
    this.book = const PlaceBook(),
    this.inferred = const {},
  });

  static const unnamed = 'Unnamed place';

  final PlaceBook book;
  final Map<String, String> inferred;

  String name(Zone zone) =>
      book.labels[zone.id] ?? inferred[zone.id] ?? book.geocoded[zone.id] ?? unnamed;

  bool isHome(Zone zone) => name(zone) == PlaceInference.home;

  bool hasUserLabel(Zone zone) => book.labels.containsKey(zone.id);

  /// What we would call it if the user has not named it.
  String? suggestion(Zone zone) => inferred[zone.id] ?? book.geocoded[zone.id];
}
