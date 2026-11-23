import 'package:flutter/foundation.dart';

import '../../trips/domain/transport_mode.dart';
import '../../trips/domain/zone.dart';
import 'anonymous_trip_summary.dart';

@immutable
class OdPair {
  const OdPair(this.origin, this.destination, this.trips, this.dominantMode, this.avgKm);
  final Zone origin;
  final Zone destination;
  final int trips;
  final TransportMode dominantMode;
  final double avgKm;
}

@immutable
class HeatCell {
  const HeatCell(this.zone, this.weight);
  final Zone zone;

  /// Trips starting or ending in this zone.
  final int weight;
}

enum RecommendationKind { busFrequency, newBusStop, roadExpansion, tourismFacility, parking }

enum Priority { high, medium, low }

@immutable
class Recommendation {
  const Recommendation({
    required this.kind,
    required this.priority,
    required this.title,
    required this.rationale,
    required this.zones,
  });

  final RecommendationKind kind;
  final Priority priority;
  final String title;
  final String rationale;
  final List<Zone> zones;
}

@immutable
class MobilitySummary {
  const MobilitySummary({
    required this.totalTrips,
    required this.hourly,
    required this.modeShare,
    required this.topOd,
    required this.heat,
    required this.tourismByDestination,
    required this.dailyTrips,
    required this.publicTransportShare,
    required this.peakHours,
    required this.recommendations,
    required this.suppressedCells,
  });

  final int totalTrips;

  /// Trips per hour of day, length 24.
  final List<int> hourly;
  final Map<TransportMode, double> modeShare;
  final List<OdPair> topOd;
  final List<HeatCell> heat;
  final List<HeatCell> tourismByDestination;

  /// Trips per day, oldest first.
  final List<MapEntry<DateTime, int>> dailyTrips;
  final double publicTransportShare;
  final List<int> peakHours;
  final List<Recommendation> recommendations;

  /// Cells hidden because they had fewer than k trips.
  final int suppressedCells;
}

/// Pure aggregation over anonymous summaries.
///
/// Enforces k-anonymity: any zone or origin–destination pair with fewer than
/// [minGroupSize] trips is suppressed from outputs.
class MobilityAnalytics {
  const MobilityAnalytics({this.minGroupSize = 5});

  final int minGroupSize;

  MobilitySummary summarise(List<AnonymousTripSummary> trips) {
    final hourly = List<int>.filled(24, 0);
    final modeCounts = <TransportMode, int>{};
    final odCounts = <(Zone, Zone), List<AnonymousTripSummary>>{};
    final zoneCounts = <Zone, int>{};
    final tourism = <Zone, int>{};
    final daily = <DateTime, int>{};

    for (final t in trips) {
      hourly[t.hour]++;
      modeCounts[t.mode] = (modeCounts[t.mode] ?? 0) + 1;
      odCounts.putIfAbsent((t.originZone, t.destinationZone), () => []).add(t);
      zoneCounts[t.originZone] = (zoneCounts[t.originZone] ?? 0) + 1;
      zoneCounts[t.destinationZone] = (zoneCounts[t.destinationZone] ?? 0) + 1;
      final day = DateTime(t.hourStart.year, t.hourStart.month, t.hourStart.day);
      daily[day] = (daily[day] ?? 0) + 1;
      if (_isTourismTrip(t)) tourism[t.destinationZone] = (tourism[t.destinationZone] ?? 0) + 1;
    }

    final total = trips.length;
    final modeShare = {
      for (final e in modeCounts.entries) e.key: total == 0 ? 0.0 : e.value / total,
    };
    final publicShare = modeShare.entries.where((e) => e.key.isPublic).fold(0.0, (a, e) => a + e.value);

    var suppressed = 0;
    final od = <OdPair>[];
    for (final e in odCounts.entries) {
      if (e.value.length < minGroupSize) {
        suppressed++;
        continue;
      }
      final modes = <TransportMode, int>{};
      for (final t in e.value) {
        modes[t.mode] = (modes[t.mode] ?? 0) + 1;
      }
      final dominant = modes.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      final avgKm = e.value.fold(0.0, (a, t) => a + t.distanceKm) / e.value.length;
      od.add(OdPair(e.key.$1, e.key.$2, e.value.length, dominant, avgKm));
    }
    od.sort((a, b) => b.trips.compareTo(a.trips));

    final heat = [
      for (final e in zoneCounts.entries)
        if (e.value >= minGroupSize) HeatCell(e.key, e.value),
    ]..sort((a, b) => b.weight.compareTo(a.weight));

    final tourismCells = [
      for (final e in tourism.entries)
        if (e.value >= minGroupSize) HeatCell(e.key, e.value),
    ]..sort((a, b) => b.weight.compareTo(a.weight));

    final hourOrder = List.generate(24, (i) => i)..sort((a, b) => hourly[b].compareTo(hourly[a]));
    final peaks = total == 0 ? <int>[] : hourOrder.take(3).where((h) => hourly[h] > 0).toList()..sort();

    final dailyList = daily.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return MobilitySummary(
      totalTrips: total,
      hourly: hourly,
      modeShare: modeShare,
      topOd: od.take(25).toList(),
      heat: heat.take(200).toList(),
      tourismByDestination: tourismCells.take(25).toList(),
      dailyTrips: dailyList,
      publicTransportShare: publicShare,
      peakHours: peaks,
      recommendations: _recommend(trips, od, heat, tourismCells, peaks),
      suppressedCells: suppressed,
    );
  }

  /// Long weekend journeys are treated as a proxy for tourism movement.
  bool _isTourismTrip(AnonymousTripSummary t) =>
      t.distanceKm >= 30 && (t.weekday == DateTime.saturday || t.weekday == DateTime.sunday);

  List<Recommendation> _recommend(
    List<AnonymousTripSummary> trips,
    List<OdPair> od,
    List<HeatCell> heat,
    List<HeatCell> tourism,
    List<int> peaks,
  ) {
    final out = <Recommendation>[];

    // 1. Busy corridors dominated by private vehicles → more buses.
    for (final pair in od.take(10)) {
      if (pair.trips < minGroupSize * 2) continue;
      final privateShare = _shareFor(trips, pair, (m) => m == TransportMode.car || m == TransportMode.bike);
      final publicShare = _shareFor(trips, pair, (m) => m.isPublic);
      if (privateShare >= 0.55 && publicShare < 0.2 && pair.avgKm >= 3) {
        out.add(Recommendation(
          kind: RecommendationKind.busFrequency,
          priority: pair.trips >= minGroupSize * 4 ? Priority.high : Priority.medium,
          title: 'Increase bus frequency on zone ${pair.origin} → ${pair.destination}',
          rationale:
              '${pair.trips} trips, ${(privateShare * 100).round()}% by private vehicle and only ${(publicShare * 100).round()}% by public transport over ~${pair.avgKm.toStringAsFixed(1)} km.',
          zones: [pair.origin, pair.destination],
        ));
      }
    }

    // 2. Congested car corridors → road/junction improvement.
    for (final pair in od.take(15)) {
      final cars = trips.where((t) =>
          t.originZone == pair.origin &&
          t.destinationZone == pair.destination &&
          (t.mode == TransportMode.car || t.mode == TransportMode.taxi) &&
          t.durationMinutes > 0);
      final list = cars.toList();
      if (list.length < minGroupSize) continue;
      final avgSpeed = list.fold(0.0, (a, t) => a + t.distanceKm / (t.durationMinutes / 60)) / list.length;
      if (avgSpeed < 15) {
        out.add(Recommendation(
          kind: RecommendationKind.roadExpansion,
          priority: avgSpeed < 10 ? Priority.high : Priority.medium,
          title: 'Review road capacity on ${pair.origin} → ${pair.destination}',
          rationale:
              'Car trips average ${avgSpeed.toStringAsFixed(0)} km/h across ${list.length} trips, indicating persistent congestion.',
          zones: [pair.origin, pair.destination],
        ));
      }
    }

    // 3. Busy origins with little public transport → new bus stop.
    final originStats = <Zone, List<AnonymousTripSummary>>{};
    for (final t in trips) {
      originStats.putIfAbsent(t.originZone, () => []).add(t);
    }
    for (final cell in heat.take(20)) {
      final list = originStats[cell.zone] ?? const [];
      if (list.length < minGroupSize * 2) continue;
      final publicShare = list.where((t) => t.mode.isPublic).length / list.length;
      final avgKm = list.fold(0.0, (a, t) => a + t.distanceKm) / list.length;
      if (publicShare < 0.1 && avgKm > 3) {
        out.add(Recommendation(
          kind: RecommendationKind.newBusStop,
          priority: Priority.medium,
          title: 'Consider a new bus stop in zone ${cell.zone}',
          rationale:
              '${list.length} trips start here with ${(publicShare * 100).round()}% public transport use and a typical distance of ${avgKm.toStringAsFixed(1)} km.',
          zones: [cell.zone],
        ));
      }
    }

    // 4. Tourism hotspots.
    for (final cell in tourism.take(5)) {
      out.add(Recommendation(
        kind: RecommendationKind.tourismFacility,
        priority: cell.weight >= minGroupSize * 4 ? Priority.high : Priority.low,
        title: 'Plan visitor facilities near zone ${cell.zone}',
        rationale: '${cell.weight} long weekend journeys ended here. Consider signage, restrooms and shuttle links.',
        zones: [cell.zone],
      ));
    }

    // 5. Parking pressure: many private-vehicle arrivals concentrated in a zone.
    final arrivals = <Zone, int>{};
    for (final t in trips) {
      if (t.mode == TransportMode.car || t.mode == TransportMode.bike) {
        arrivals[t.destinationZone] = (arrivals[t.destinationZone] ?? 0) + 1;
      }
    }
    final parkingZones = arrivals.entries.where((e) => e.value >= minGroupSize * 3).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in parkingZones.take(3)) {
      out.add(Recommendation(
        kind: RecommendationKind.parking,
        priority: Priority.medium,
        title: 'Add or manage parking in zone ${e.key}',
        rationale: '${e.value} private-vehicle trips ended here.',
        zones: [e.key],
      ));
    }

    out.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return out;
  }

  double _shareFor(List<AnonymousTripSummary> trips, OdPair pair, bool Function(TransportMode) test) {
    final list = trips.where((t) => t.originZone == pair.origin && t.destinationZone == pair.destination);
    var n = 0;
    var hit = 0;
    for (final t in list) {
      n++;
      if (test(t.mode)) hit++;
    }
    return n == 0 ? 0 : hit / n;
  }
}
