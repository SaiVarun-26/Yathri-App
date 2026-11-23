import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../../../core/geo/geo_utils.dart';
import '../domain/track_point.dart';
import '../domain/trip.dart';
import '../domain/zone.dart';
import 'mode_classifier.dart';

enum TrackingPhase { waiting, detecting, travelling }

/// Tunable thresholds for automatic trip detection.
class DetectionConfig {
  const DetectionConfig({
    this.maxAccuracyM = 50,
    this.movingSpeedMps = 1.0,
    this.confirmDistanceM = 120,
    this.detectingGrace = const Duration(seconds: 60),
    this.stationaryTimeout = const Duration(minutes: 3),
    this.minTripDistanceM = 300,
    this.minTripDuration = const Duration(minutes: 2),
    this.maxPlausibleSpeedMps = 70,
    this.staleAnchorGap = const Duration(seconds: 90),
  });

  /// If the previous fix is older than this, it is not used as a trip origin
  /// or to estimate speed (the phone was stationary and silent).
  final Duration staleAnchorGap;

  /// Fixes less accurate than this are discarded.
  final double maxAccuracyM;

  /// Speed above which the user is considered to be moving.
  final double movingSpeedMps;

  /// Distance of sustained movement needed to confirm a trip has started.
  final double confirmDistanceM;

  /// How long "detecting" may continue without movement before it is dropped.
  final Duration detectingGrace;

  /// Time without movement after which a trip is considered finished.
  final Duration stationaryTimeout;

  final double minTripDistanceM;
  final Duration minTripDuration;

  /// Fixes implying more than this speed are treated as GPS glitches.
  final double maxPlausibleSpeedMps;
}

typedef PhaseListener = void Function(TrackingPhase phase);
typedef TripListener = void Function(Trip trip);

/// Pure-Dart state machine: Waiting → Detecting → Travelling → (save) → Waiting.
///
/// It has no Flutter or plugin dependencies, so it runs identically inside the
/// foreground-service isolate and in unit tests.
class TripDetectionEngine {
  TripDetectionEngine({
    this.config = const DetectionConfig(),
    this.classifier = const ModeClassifier(),
    this.onPhaseChanged,
    this.onTripCompleted,
    String Function()? idGenerator,
  }) : _newId = idGenerator ?? (() => const Uuid().v4());

  final DetectionConfig config;
  final ModeClassifier classifier;
  final PhaseListener? onPhaseChanged;
  final TripListener? onTripCompleted;
  final String Function() _newId;

  TrackingPhase _phase = TrackingPhase.waiting;
  TrackPoint? _last;
  final List<TrackPoint> _route = [];
  DateTime? _lastMoving;
  double _distance = 0;
  double _maxSpeed = 0;
  double _movingSeconds = 0;

  TrackingPhase get phase => _phase;
  double get currentDistanceMeters => _distance;
  List<TrackPoint> get currentRoute => List.unmodifiable(_route);
  DateTime? get currentTripStart => _route.isEmpty ? null : _route.first.time;

  void ingest(TrackPoint p) {
    if (p.accuracy > config.maxAccuracyM) return;

    final last = _last;
    var distance = 0.0;
    var speed = 0.0;
    var gap = Duration.zero;
    if (last != null) {
      gap = p.time.difference(last.time);
      final dt = gap.inMilliseconds / 1000;
      if (dt <= 0) return; // duplicate or out-of-order fix
      distance = GeoUtils.haversine(last.lat, last.lng, p.lat, p.lng);
      speed = distance / dt;
      if (speed > config.maxPlausibleSpeedMps) return; // GPS glitch
    }

    // A trip cannot silently span a long stationary period, even if the timer
    // tick never ran (service was dead). Close it, then treat p as a new fix.
    final idle = _lastMoving == null ? Duration.zero : p.time.difference(_lastMoving!);
    if (_phase == TrackingPhase.travelling && idle >= config.stationaryTimeout) {
      _finish();
      ingest(p);
      return;
    }
    if (_phase == TrackingPhase.detecting && idle > config.detectingGrace) {
      _reset();
      ingest(p);
      return;
    }

    // While waiting, the GPS only reports every ~30 m, so the previous fix can
    // be hours old. Displacement from such an anchor says nothing about speed.
    final staleAnchor = gap > config.staleAnchorGap;
    final moving = last != null &&
        (p.speed >= config.movingSpeedMps ||
            (!staleAnchor && distance > math.max(15, p.accuracy * 1.5) && speed >= config.movingSpeedMps));

    switch (_phase) {
      case TrackingPhase.waiting:
        if (moving) {
          _route.clear();
          if (staleAnchor) {
            // Start from this fix; the old anchor would backdate the trip.
            _route.add(p);
            _distance = 0;
            _maxSpeed = p.speed;
            _movingSeconds = 0;
          } else {
            _route
              ..add(last)
              ..add(p);
            _distance = distance;
            _maxSpeed = math.max(p.speed, speed);
            _movingSeconds = gap.inMilliseconds / 1000;
          }
          _lastMoving = p.time;
          _setPhase(TrackingPhase.detecting);
        }
      case TrackingPhase.detecting:
        _append(p, last!, distance, speed, moving);
        if (_distance >= config.confirmDistanceM) _setPhase(TrackingPhase.travelling);
      case TrackingPhase.travelling:
        _append(p, last!, distance, speed, moving);
    }
    _last = p;
  }

  /// Call periodically (e.g. every 15 s). Ends trips when the phone stops
  /// delivering fixes because the user has stopped moving.
  void tick(DateTime now) {
    final lastMoving = _lastMoving;
    if (lastMoving == null) return;
    final idle = now.difference(lastMoving);
    if (_phase == TrackingPhase.travelling && idle >= config.stationaryTimeout) {
      _finish();
    } else if (_phase == TrackingPhase.detecting && idle > config.detectingGrace) {
      _reset();
    }
  }

  /// Forces completion of an in-progress trip (e.g. service shutting down).
  void flush() {
    if (_phase == TrackingPhase.travelling) {
      _finish();
    } else {
      _reset();
    }
  }

  void _append(TrackPoint p, TrackPoint last, double distance, double speed, bool moving) {
    _route.add(p);
    if (moving) {
      _distance += distance;
      _lastMoving = p.time;
      _movingSeconds += p.time.difference(last.time).inMilliseconds / 1000;
      _maxSpeed = math.max(_maxSpeed, p.speed > 0 ? p.speed : speed);
    }
  }

  void _finish() {
    final lastMoving = _lastMoving!;
    // Drop the trailing stationary tail; keep one point after the last move.
    final trimmed = _route.where((p) => !p.time.isAfter(lastMoving)).toList();
    final duration = trimmed.isEmpty ? Duration.zero : lastMoving.difference(trimmed.first.time);

    if (trimmed.length >= 2 &&
        _distance >= config.minTripDistanceM &&
        duration >= config.minTripDuration) {
      final result = classifier.classify(trimmed);
      final km = _distance / 1000;
      final trip = Trip(
        id: _newId(),
        startTime: trimmed.first.time,
        endTime: lastMoving,
        mode: result.mode,
        modeConfidence: result.confidence,
        distanceMeters: _distance,
        maxSpeedMps: _maxSpeed,
        movingSeconds: _movingSeconds.round(),
        route: List.unmodifiable(trimmed),
        originZone: Zone.fromLatLng(trimmed.first.lat, trimmed.first.lng),
        destinationZone: Zone.fromLatLng(trimmed.last.lat, trimmed.last.lng),
        costInr: result.mode.estimateCost(km),
      );
      _reset();
      onTripCompleted?.call(trip);
    } else {
      _reset();
    }
  }

  void _reset() {
    _route.clear();
    _distance = 0;
    _maxSpeed = 0;
    _movingSeconds = 0;
    _lastMoving = null;
    _setPhase(TrackingPhase.waiting);
  }

  void _setPhase(TrackingPhase next) {
    if (next == _phase) return;
    _phase = next;
    onPhaseChanged?.call(next);
  }
}
