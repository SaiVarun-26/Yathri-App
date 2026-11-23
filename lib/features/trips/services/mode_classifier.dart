import 'dart:math' as math;

import '../../../core/geo/geo_utils.dart';
import '../domain/mode_feedback.dart';
import '../domain/route_features.dart';
import '../domain/track_point.dart';
import '../domain/transport_mode.dart';

class ModeClassification {
  const ModeClassification(this.mode, this.confidence, {this.alternatives = const []});

  final TransportMode mode;

  /// 0..1. How sure the classifier is that [mode] is right.
  final double confidence;

  /// The next most likely answers with their probabilities.
  final List<(TransportMode, double)> alternatives;

  static const unknown = ModeClassification(TransportMode.unknown, 0);
}

/// Typical value and spread of each measurement for one mode.
class _Profile {
  const _Profile({
    required this.median,
    required this.p90,
    required this.max,
    required this.stops,
    required this.stopShare,
    required this.accel,
    required this.decel,
    required this.turns,
    required this.cv,
  });

  /// Each pair is (typical value, spread).
  final (double, double) median, p90, max, stops, stopShare, accel, decel, turns, cv;
}

/// Works out how a journey was made from its movement, not from speed alone.
///
/// Nine measurements are compared against a profile of each mode:
/// typical speed, fast-end speed, top speed, how often it stops, how much
/// time is spent stopped, how hard it accelerates and brakes, how much it
/// turns, and how steady the speed is. A scooter and a bicycle can share a
/// speed, but a scooter accelerates and cruises very differently. A bus and
/// a car can share a speed, but a bus stops far more often and brakes gently.
///
/// Three things keep the answer honest:
///  * Likelihoods are combined with how common each mode is (and what the
///    user owns), so a rare mode needs strong evidence.
///  * Confidence is the probability of the winner, reduced when there is
///    little data. The UI shows "Probably X" when it is low.
///  * Journeys the user has corrected pull similar journeys the same way.
///
/// There is no road matching or OS activity recognition here. Those can be
/// added as extra evidence terms in [_logLikelihood].
class ModeClassifier {
  const ModeClassifier({this.feedback = const [], this.context = ModeContext.unknown});

  /// Past corrections by the user.
  final List<ModeFeedback> feedback;
  final ModeContext context;

  static const double _movingMps = 1.0;
  static const double _minStopSeconds = 8;

  /// Softens the probabilities so near-ties are reported as uncertain.
  static const double _temperature = 2.4;

  static const _weights = (
    median: 1.4,
    p90: 1.0,
    max: 0.6,
    stops: 1.0,
    stopShare: 0.6,
    accel: 0.9,
    decel: 0.5,
    turns: 0.5,
    cv: 0.4,
  );

  static const Map<TransportMode, _Profile> _profiles = {
    TransportMode.walking: _Profile(
      median: (4.5, 1.0),
      p90: (5.8, 1.2),
      max: (8.0, 2.5),
      stops: (2.0, 2.0),
      stopShare: (0.08, 0.08),
      accel: (0.3, 0.2),
      decel: (0.3, 0.2),
      turns: (6.0, 4.0),
      cv: (0.25, 0.15),
    ),
    TransportMode.running: _Profile(
      median: (9.5, 2.2),
      p90: (12.5, 3.0),
      max: (16.0, 4.0),
      stops: (0.5, 0.8),
      stopShare: (0.04, 0.05),
      accel: (0.3, 0.2),
      decel: (0.3, 0.2),
      turns: (3.0, 3.0),
      cv: (0.2, 0.1),
    ),
    TransportMode.cycling: _Profile(
      median: (15.0, 3.5),
      p90: (21.0, 4.5),
      max: (27.0, 6.0),
      stops: (1.0, 1.0),
      stopShare: (0.07, 0.07),
      accel: (0.5, 0.3),
      decel: (0.6, 0.3),
      turns: (3.0, 3.0),
      cv: (0.3, 0.15),
    ),
    TransportMode.bike: _Profile(
      median: (30.0, 9.0),
      p90: (44.0, 11.0),
      max: (55.0, 14.0),
      stops: (1.6, 1.3),
      stopShare: (0.12, 0.1),
      accel: (1.5, 0.6),
      decel: (1.8, 0.7),
      turns: (2.5, 2.0),
      cv: (0.4, 0.15),
    ),
    TransportMode.car: _Profile(
      median: (36.0, 14.0),
      p90: (58.0, 20.0),
      max: (75.0, 25.0),
      stops: (1.2, 1.0),
      stopShare: (0.12, 0.1),
      accel: (1.2, 0.5),
      decel: (1.5, 0.6),
      turns: (2.0, 2.0),
      cv: (0.5, 0.2),
    ),
    TransportMode.auto: _Profile(
      median: (23.0, 7.0),
      p90: (36.0, 7.0),
      max: (45.0, 8.0),
      stops: (1.8, 1.3),
      stopShare: (0.15, 0.1),
      accel: (0.9, 0.4),
      decel: (1.2, 0.5),
      turns: (4.0, 2.5),
      cv: (0.45, 0.15),
    ),
    TransportMode.bus: _Profile(
      median: (26.0, 8.0),
      p90: (38.0, 10.0),
      max: (50.0, 12.0),
      stops: (2.8, 1.2),
      stopShare: (0.25, 0.1),
      accel: (0.8, 0.3),
      decel: (1.0, 0.35),
      turns: (2.0, 2.0),
      cv: (0.5, 0.2),
    ),
    // Metro rides look like trains; the user can correct to Metro.
    TransportMode.train: _Profile(
      median: (55.0, 20.0),
      p90: (90.0, 25.0),
      max: (110.0, 30.0),
      stops: (0.2, 0.3),
      stopShare: (0.05, 0.06),
      accel: (0.5, 0.25),
      decel: (0.6, 0.3),
      turns: (0.3, 0.6),
      cv: (0.35, 0.15),
    ),
  };

  /// How common each mode is among everyday trips.
  static const Map<TransportMode, double> _basePrior = {
    TransportMode.walking: 0.20,
    TransportMode.running: 0.03,
    TransportMode.cycling: 0.07,
    TransportMode.bike: 0.22,
    TransportMode.car: 0.25,
    TransportMode.auto: 0.08,
    TransportMode.bus: 0.12,
    TransportMode.train: 0.04,
  };

  // ---------------------------------------------------------------------
  // Feature extraction
  // ---------------------------------------------------------------------

  RouteFeatures extractFeatures(List<TrackPoint> route) {
    if (route.length < 2) return RouteFeatures.empty;

    final speeds = <double>[]; // metres per second, one per segment
    final gaps = <double>[]; // seconds, one per segment
    final moving = <double>[];
    var distance = 0.0;
    var totalSeconds = 0.0;
    var stopSeconds = 0.0;
    var stopRun = 0.0;
    var stops = 0;

    for (var i = 1; i < route.length; i++) {
      final a = route[i - 1];
      final b = route[i];
      final dt = b.time.difference(a.time).inMilliseconds / 1000;
      if (dt <= 0) continue;
      final d = GeoUtils.haversine(a.lat, a.lng, b.lat, b.lng);
      final displacement = d / dt;
      if (displacement > 70) continue; // GPS jump

      // Prefer the receiver's own speed (Doppler) over position differences,
      // which are noisy. Fall back to displacement; ignore sub-walking jitter.
      final reported = b.speed;
      // Position wobble of a few metres is normal while standing still, so a
      // position change only counts as movement when it clearly exceeds the
      // GPS error.
      final jitterFloor = math.max(12.0, b.accuracy * 1.5);
      final v = reported >= 0.5
          ? reported
          : (d >= jitterFloor && displacement >= _movingMps ? displacement : 0.0);

      totalSeconds += dt;
      speeds.add(v);
      gaps.add(dt);
      if (v >= _movingMps) {
        distance += d;
        moving.add(v);
        if (stopRun >= _minStopSeconds) stops++;
        stopRun = 0;
      } else {
        stopSeconds += dt;
        stopRun += dt;
      }
    }

    if (moving.length < 3 || distance <= 0) return RouteFeatures.empty;

    final kmh = moving.map((v) => v * 3.6).toList()..sort();
    final mean = kmh.reduce((a, b) => a + b) / kmh.length;
    final variance = kmh.fold(0.0, (a, v) => a + (v - mean) * (v - mean)) / kmh.length;

    // Acceleration between neighbouring segments (skip long gaps).
    final accel = <double>[];
    final decel = <double>[];
    for (var i = 1; i < speeds.length; i++) {
      if (gaps[i] > 10 || gaps[i - 1] > 10 || gaps[i] < 0.5 || gaps[i - 1] < 0.5) continue;
      final a = (speeds[i] - speeds[i - 1]) / ((gaps[i] + gaps[i - 1]) / 2);
      if (a > 0.05) {
        accel.add(a);
      } else if (a < -0.05) {
        decel.add(-a);
      }
    }
    accel.sort();
    decel.sort();

    final km = distance / 1000;
    return RouteFeatures(
      medianKmh: _percentile(kmh, 0.5),
      p90Kmh: _percentile(kmh, 0.9),
      maxKmh: _percentile(kmh, 0.99),
      stopsPerKm: stops / km,
      stopShare: totalSeconds > 0 ? stopSeconds / totalSeconds : 0,
      accelP90: accel.length >= 5 ? _percentile(accel, 0.9) : null,
      decelP90: decel.length >= 5 ? _percentile(decel, 0.9) : null,
      turnsPerKm: _sharpTurnsPerKm(route, km),
      speedCv: mean > 0 ? math.sqrt(variance) / mean : 0,
      distanceKm: km,
      durationMin: route.last.time.difference(route.first.time).inSeconds / 60,
      movingSamples: moving.length,
    );
  }

  static double _percentile(List<double> sorted, double p) {
    final index = ((sorted.length - 1) * p).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  /// Counts turns of 40 degrees or more, comparing directions over steps of at
  /// least 30 m. Small wobbles from GPS error, or from standing still, never
  /// reach that size, so only genuine turns are counted.
  static double _sharpTurnsPerKm(List<TrackPoint> route, double km) {
    if (km <= 0) return 0;
    var anchor = route.first;
    double? previous;
    var turns = 0;
    for (final p in route.skip(1)) {
      if (GeoUtils.haversine(anchor.lat, anchor.lng, p.lat, p.lng) < 30) continue;
      final bearing = GeoUtils.bearing(anchor.lat, anchor.lng, p.lat, p.lng);
      if (previous != null && GeoUtils.bearingDelta(bearing, previous) >= 40) turns++;
      previous = bearing;
      anchor = p;
    }
    return turns / km;
  }

  // ---------------------------------------------------------------------
  // Classification
  // ---------------------------------------------------------------------

  ModeClassification classify(List<TrackPoint> route) => classifyFeatures(extractFeatures(route));

  ModeClassification classifyFeatures(RouteFeatures f) {
    if (f.movingSamples < 3) return ModeClassification.unknown;

    final logits = <TransportMode, double>{};
    for (final mode in _profiles.keys) {
      logits[mode] = _logLikelihood(_profiles[mode]!, f) + math.log(_prior(mode, f)) + _feedbackBonus(mode, f);
    }

    // Softmax with temperature.
    final top = logits.values.reduce(math.max);
    final exps = {for (final e in logits.entries) e.key: math.exp((e.value - top) / _temperature)};
    final total = exps.values.fold(0.0, (a, b) => a + b);
    final probs = [for (final e in exps.entries) (e.key, e.value / total)]
      ..sort((a, b) => b.$2.compareTo(a.$2));

    var confidence = probs.first.$2;
    // Little data means less certainty, whatever the numbers say.
    if (f.movingSamples < 6) {
      confidence *= 0.5;
    } else if (f.movingSamples < 12) {
      confidence *= 0.75;
    }

    return ModeClassification(
      probs.first.$1,
      confidence.clamp(0.0, 1.0),
      alternatives: probs.skip(1).take(2).toList(),
    );
  }

  /// Weighted agreement between the journey and a mode's profile. Each term
  /// is capped, so one odd reading cannot rule a mode out on its own.
  double _logLikelihood(_Profile p, RouteFeatures f) {
    double term((double, double) profile, double? x, double weight) {
      if (x == null) return 0;
      final z = (x - profile.$1) / profile.$2;
      return -0.5 * weight * math.min(z * z, 9);
    }

    return term(p.median, f.medianKmh, _weights.median) +
        term(p.p90, f.p90Kmh, _weights.p90) +
        term(p.max, f.maxKmh, _weights.max) +
        term(p.stops, f.stopsPerKm, _weights.stops) +
        term(p.stopShare, f.stopShare, _weights.stopShare) +
        term(p.accel, f.accelP90, _weights.accel) +
        term(p.decel, f.decelP90, _weights.decel) +
        term(p.turns, f.turnsPerKm, _weights.turns) +
        term(p.cv, f.speedCv, _weights.cv);
  }

  /// How likely the mode is before looking at movement: how common it is,
  /// what the user owns, and whether the distance makes sense for it.
  double _prior(TransportMode mode, RouteFeatures f) {
    var p = _basePrior[mode] ?? 0.01;

    switch (mode) {
      case TransportMode.bike:
        if (context.ownsBike == true) p *= 1.4;
        if (context.ownsBike == false) p *= 0.7;
      case TransportMode.car:
        if (context.ownsCar == true) p *= 1.25;
        if (context.ownsCar == false) p *= 0.7;
      case TransportMode.bus || TransportMode.auto:
        if (context.ownsBike == false && context.ownsCar == false) p *= 1.3;
      default:
        break;
    }

    final km = f.distanceKm;
    switch (mode) {
      case TransportMode.train:
        if (km < 1.5) {
          p *= 0.02;
        } else if (km < 3) {
          p *= 0.1;
        } else if (km < 5) {
          p *= 0.4;
        }
      case TransportMode.bus:
        if (km < 0.8) p *= 0.3;
      case TransportMode.walking:
        if (km > 12) p *= 0.2;
      case TransportMode.running:
        if (km > 25) p *= 0.2;
        if (km < 0.6) p *= 0.5;
      case TransportMode.cycling:
        if (km > 80) p *= 0.2;
      default:
        break;
    }
    return p;
  }

  /// Corrections by the user on journeys that looked like this one.
  double _feedbackBonus(TransportMode mode, RouteFeatures f) {
    if (feedback.isEmpty) return 0;
    var bonus = 0.0;
    for (final fb in feedback) {
      final d2 = f.distanceTo(fb.features);
      if (d2 > 4) continue;
      final weight = math.exp(-d2 / (2 * 0.5));
      if (fb.corrected == mode) bonus += 6.0 * weight;
      if (fb.detected == mode && fb.corrected != mode) bonus -= 3.0 * weight;
    }
    return bonus.clamp(-6.0, 12.0);
  }
}
