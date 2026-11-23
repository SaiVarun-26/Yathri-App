import 'dart:math' as math;

import '../../trips/domain/transport_mode.dart';
import '../../trips/domain/zone.dart';
import '../domain/anonymous_trip_summary.dart';

/// Synthetic dataset for previewing the admin portal without a backend.
/// Clearly labelled as demo data in the UI. Never written to Firebase.
abstract final class DemoData {
  static List<AnonymousTripSummary> generate({int count = 3000, int seed = 7}) {
    final rnd = math.Random(seed);
    // Rough Kochi-area zone centres.
    final hubs = [
      Zone.fromLatLng(9.9816, 76.2999), // Ernakulam
      Zone.fromLatLng(10.0261, 76.3125), // Kakkanad
      Zone.fromLatLng(9.9312, 76.2673), // Fort Kochi
      Zone.fromLatLng(10.0159, 76.3419), // Edappally
      Zone.fromLatLng(9.9674, 76.2455), // Willingdon Island
      Zone.fromLatLng(10.1000, 76.3500), // Aluva
      Zone.fromLatLng(9.9490, 76.3200), // Thevara
    ];
    final now = DateTime.now();
    final out = <AnonymousTripSummary>[];

    TransportMode pickMode(double km) {
      final r = rnd.nextDouble();
      if (km < 1.5) return r < 0.8 ? TransportMode.walking : TransportMode.cycling;
      if (km < 6) {
        return r < 0.35 ? TransportMode.auto : r < 0.6 ? TransportMode.bike : r < 0.8 ? TransportMode.car : TransportMode.bus;
      }
      return r < 0.5 ? TransportMode.car : r < 0.7 ? TransportMode.bike : r < 0.85 ? TransportMode.bus : TransportMode.metro;
    }

    for (var i = 0; i < count; i++) {
      final o = hubs[rnd.nextInt(hubs.length)];
      var d = hubs[rnd.nextInt(hubs.length)];
      if (d == o) d = Zone(o.latIndex + 1, o.lngIndex);
      final km = (3 + rnd.nextDouble() * 12);
      final day = now.subtract(Duration(days: rnd.nextInt(30)));
      // Morning and evening peaks.
      final peak = rnd.nextDouble();
      final hour = peak < 0.4 ? 8 + rnd.nextInt(2) : peak < 0.75 ? 17 + rnd.nextInt(3) : rnd.nextInt(24);
      final mode = pickMode(km);
      final congestion = (hour >= 8 && hour <= 9) || (hour >= 17 && hour <= 19) ? 0.55 : 1.0;
      final speed = switch (mode) {
        TransportMode.walking => 4.5,
        TransportMode.cycling => 13.0,
        TransportMode.bus => 17.0,
        _ => 28.0 * congestion,
      };
      out.add(AnonymousTripSummary(
        originZone: o,
        destinationZone: d,
        mode: mode,
        distanceKm: (km * 2).round() / 2,
        hourStart: DateTime(day.year, day.month, day.day, hour),
        durationMinutes: ((km / speed * 60) / 5).round() * 5,
      ));
    }
    return out;
  }
}
