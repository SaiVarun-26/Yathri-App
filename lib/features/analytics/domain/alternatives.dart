import 'package:flutter/foundation.dart';

import '../../trips/domain/transport_mode.dart';
import '../../trips/domain/trip.dart';

/// "You could take the bus instead of the car and save about ₹520 a month."
@immutable
class AlternativeSuggestion {
  const AlternativeSuggestion({
    required this.from,
    required this.to,
    required this.tripsConsidered,
    required this.monthlySavingInr,
    required this.extraMinutesPerTrip,
  });

  final TransportMode from;
  final TransportMode to;
  final int tripsConsidered;
  final double monthlySavingInr;
  final int extraMinutesPerTrip;
}

abstract final class Alternatives {
  // Typical door-to-door speeds used to estimate the time impact.
  static const _busKmh = 18.0;
  static const _carKmh = 28.0;
  static const _metroKmh = 32.0;

  /// The best swaps for a month of trips, biggest saving first. [costOf]
  /// prices each trip as the traveller actually paid for it.
  static List<AlternativeSuggestion> forMonth(Iterable<Trip> trips, double Function(Trip) costOf) {
    final out = <AlternativeSuggestion>[];
    for (final from in [TransportMode.car, TransportMode.taxi, TransportMode.auto, TransportMode.bike]) {
      // Only trips where a bus is a realistic substitute.
      final candidates =
          trips.where((t) => t.mode == from && t.distanceKm >= 2 && t.distanceKm <= 40).toList();
      if (candidates.length < 3) continue; // one-off trips do not make a habit

      var saving = 0.0;
      var extraMinutes = 0.0;
      for (final t in candidates) {
        saving += costOf(t) - TransportMode.bus.estimateCost(t.distanceKm);
        extraMinutes += t.distanceKm / _busKmh * 60 - t.distanceKm / _carKmh * 60;
      }
      if (saving < 50) continue;
      out.add(AlternativeSuggestion(
        from: from,
        to: TransportMode.bus,
        tripsConsidered: candidates.length,
        monthlySavingInr: saving,
        extraMinutesPerTrip: (extraMinutes / candidates.length).round(),
      ));
    }

    // Where a metro corridor is plausible (longer car trips), suggest it too.
    final longCar = trips.where((t) => t.mode == TransportMode.car && t.distanceKm >= 8).toList();
    if (longCar.length >= 3) {
      var saving = 0.0;
      var extra = 0.0;
      for (final t in longCar) {
        saving += costOf(t) - TransportMode.metro.estimateCost(t.distanceKm);
        extra += t.distanceKm / _metroKmh * 60 - t.distanceKm / _carKmh * 60;
      }
      if (saving >= 50) {
        out.add(AlternativeSuggestion(
          from: TransportMode.car,
          to: TransportMode.metro,
          tripsConsidered: longCar.length,
          monthlySavingInr: saving,
          extraMinutesPerTrip: (extra / longCar.length).round(),
        ));
      }
    }

    out.sort((a, b) => b.monthlySavingInr.compareTo(a.monthlySavingInr));
    return out.take(3).toList();
  }
}
