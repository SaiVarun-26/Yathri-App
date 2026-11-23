import 'package:flutter/foundation.dart';

/// Movement measurements taken from a route. Every transport mode leaves a
/// different signature across these, so no single number decides the answer.
@immutable
class RouteFeatures {
  const RouteFeatures({
    required this.medianKmh,
    required this.p90Kmh,
    required this.maxKmh,
    required this.stopsPerKm,
    required this.stopShare,
    required this.accelP90,
    required this.decelP90,
    required this.turnsPerKm,
    required this.speedCv,
    required this.distanceKm,
    required this.durationMin,
    required this.movingSamples,
  });

  static const empty = RouteFeatures(
    medianKmh: 0,
    p90Kmh: 0,
    maxKmh: 0,
    stopsPerKm: 0,
    stopShare: 0,
    accelP90: null,
    decelP90: null,
    turnsPerKm: 0,
    speedCv: 0,
    distanceKm: 0,
    durationMin: 0,
    movingSamples: 0,
  );

  /// Typical moving speed. The median ignores brief spikes and crawls.
  final double medianKmh;
  final double p90Kmh;
  final double maxKmh;

  /// Stops of 8 seconds or more, per kilometre.
  final double stopsPerKm;

  /// Fraction of the journey spent stationary.
  final double stopShare;

  /// How hard it accelerates / brakes (90th percentile, m/s²). Null when
  /// there were too few readings to tell.
  final double? accelP90;
  final double? decelP90;

  /// Sharp turns (40 degrees or more) per kilometre.
  final double turnsPerKm;

  /// Variation of speed relative to its average.
  final double speedCv;

  final double distanceKm;
  final double durationMin;

  /// How many readings the measurements are based on.
  final int movingSamples;

  /// Typical spread of each measurement, used to compare two journeys.
  static const _scales = [15.0, 20.0, 25.0, 1.5, 0.1, 0.6, 0.6, 3.0, 0.2];

  List<double?> get _vector => [medianKmh, p90Kmh, maxKmh, stopsPerKm, stopShare, accelP90, decelP90, turnsPerKm, speedCv];

  /// Distance between two journeys in "typical spread" units. Smaller means
  /// more alike. Measurements missing from either side are skipped.
  double distanceTo(RouteFeatures other) {
    final a = _vector;
    final b = other._vector;
    var sum = 0.0;
    var n = 0;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x == null || y == null) continue;
      final z = (x - y) / _scales[i];
      sum += z * z;
      n++;
    }
    return n == 0 ? double.infinity : (sum / n);
  }

  Map<String, dynamic> toJson() => {
        'med': medianKmh,
        'p90': p90Kmh,
        'max': maxKmh,
        'stops': stopsPerKm,
        'stopShare': stopShare,
        if (accelP90 != null) 'acc': accelP90,
        if (decelP90 != null) 'dec': decelP90,
        'turns': turnsPerKm,
        'cv': speedCv,
        'km': distanceKm,
        'min': durationMin,
        'n': movingSamples,
      };

  factory RouteFeatures.fromJson(Map<dynamic, dynamic> j) => RouteFeatures(
        medianKmh: (j['med'] as num).toDouble(),
        p90Kmh: (j['p90'] as num).toDouble(),
        maxKmh: (j['max'] as num).toDouble(),
        stopsPerKm: (j['stops'] as num).toDouble(),
        stopShare: (j['stopShare'] as num).toDouble(),
        accelP90: (j['acc'] as num?)?.toDouble(),
        decelP90: (j['dec'] as num?)?.toDouble(),
        turnsPerKm: (j['turns'] as num).toDouble(),
        speedCv: (j['cv'] as num).toDouble(),
        distanceKm: (j['km'] as num).toDouble(),
        durationMin: (j['min'] as num).toDouble(),
        movingSamples: (j['n'] as num).toInt(),
      );
}
