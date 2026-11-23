import '../../trips/domain/transport_mode.dart';
import '../../trips/domain/trip.dart';

/// How much lighter on the planet a set of trips was than driving the same
/// distance. 100 means zero emissions (walking, cycling); 0 means car-like.
abstract final class EcoScore {
  static int? of(Iterable<Trip> trips) {
    var km = 0.0;
    var emitted = 0.0;
    for (final t in trips) {
      km += t.distanceKm;
      emitted += t.co2Grams;
    }
    if (km < 0.5) return null;
    final carEquivalent = TransportMode.car.gramsCo2PerKm * km;
    return (100 * (1 - emitted / carEquivalent)).round().clamp(0, 100);
  }
}
