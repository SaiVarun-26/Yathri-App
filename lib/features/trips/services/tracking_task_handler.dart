import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../../reminders/data/commute_snapshot_store.dart';
import '../../reminders/domain/commute_alert.dart';
import '../../reminders/domain/smart_reminders.dart';
import '../../reminders/services/commute_notifier.dart';
import '../data/trip_dto.dart';
import '../data/trip_local_source.dart';
import '../domain/track_point.dart';
import '../domain/trip.dart';
import 'trip_detection_engine.dart';

/// Message types exchanged between the service isolate and the UI isolate.
abstract final class TrackingMessage {
  static const type = 'type';
  static const phase = 'phase';
  static const point = 'point';
  static const trip = 'trip';
  static const gps = 'gps';

  /// UI → service: please re-send the current state.
  static const snapshot = 'snapshot';
}

/// Entry point for the foreground service. Must be top-level.
@pragma('vm:entry-point')
void trackingStartCallback() {
  FlutterForegroundTask.setTaskHandler(TrackingTaskHandler());
}

/// Runs inside the foreground-service isolate, so detection continues with the
/// screen off, phone locked, or the app minimised (or even swiped away).
///
/// Pipeline: Geolocator stream → cleaning → [TripDetectionEngine] → pending
/// inbox on disk → message to UI (which imports, saves, syncs, shares).
///
/// Battery strategy: while WAITING the GPS is asked for fixes only every ~30 m
/// of displacement. Once movement is seen it switches to dense sampling, then
/// drops back after the trip is saved.
class TrackingTaskHandler extends TaskHandler {
  late final TripDetectionEngine _engine;
  StreamSubscription<Position>? _subscription;
  StreamSubscription<ServiceStatus>? _gpsStatus;
  bool? _dense;
  bool _gpsEnabled = true;
  bool _stopped = false;
  TrackPoint? _lastPoint;
  final List<Future<void>> _writes = [];

  // Late-for-your-usual-trip alert.
  final _commuteStore = CommuteSnapshotStore();
  final _commuteNotifier = CommuteNotifier();
  List<CommuteRoute> _routes = const [];
  Set<String> _alerted = {};
  DateTime _routesLoadedAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _lastActiveAt;
  bool _checkingLate = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _engine = TripDetectionEngine(
      onPhaseChanged: _onPhase,
      onTripCompleted: _onTrip,
    );
    await _commuteNotifier.init();
    _alerted = await _commuteStore.loadAlerted();
    _gpsEnabled = await _safeGpsEnabled();
    _gpsStatus = Geolocator.getServiceStatusStream().listen(_onGpsStatus, onError: (_) {});
    _send({TrackingMessage.type: TrackingMessage.gps, 'enabled': _gpsEnabled});
    if (_gpsEnabled) _listen(dense: false);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Fixes stop arriving when the user is stationary, so time out on a timer.
    _engine.tick(DateTime.now());
    unawaited(_checkLate());
    // Self-heal: the location stream may have died (signal loss, OEM kill).
    if (_subscription == null && _gpsEnabled && !_stopped) _listen(dense: _dense ?? false, force: true);
  }

  @override
  void onReceiveData(Object data) {
    if (data == TrackingMessage.snapshot) {
      _send({TrackingMessage.type: TrackingMessage.gps, 'enabled': _gpsEnabled});
      _send({TrackingMessage.type: TrackingMessage.phase, 'phase': _engine.phase.name});
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // flush() below fires phase callbacks; make sure they cannot re-subscribe.
    _stopped = true;
    await _subscription?.cancel();
    await _gpsStatus?.cancel();
    _engine.flush();
    await Future.wait(List.of(_writes));
  }

  /// If it is a little past the user's usual departure time and the phone has
  /// not moved from where they usually leave, send one heads-up per route per day.
  Future<void> _checkLate() async {
    if (_checkingLate || _stopped) return;
    _checkingLate = true;
    try {
      final now = DateTime.now();
      if (now.difference(_routesLoadedAt) > const Duration(minutes: 10)) {
        _routes = await _commuteStore.loadRoutes(fresh: true);
        _routesLoadedAt = now;
      }
      if (_routes.isEmpty) return;
      final last = _lastPoint;
      final due = LateCommuteChecker.check(
        now: now,
        routes: _routes,
        lat: last?.lat,
        lng: last?.lng,
        lastActiveAt: _lastActiveAt,
        alreadyAlerted: _alerted,
      );
      if (due == null) return;
      final key = due.dayKey(now);
      _alerted.add(key);
      await _commuteStore.markAlerted(key);
      await _commuteNotifier.showLate(due, RecurringPattern.labelFor(due.medianMinute));
    } catch (e) {
      debugPrint('Late-commute check failed: $e');
    } finally {
      _checkingLate = false;
    }
  }

  Future<bool> _safeGpsEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return true;
    }
  }

  void _onGpsStatus(ServiceStatus status) {
    final enabled = status == ServiceStatus.enabled;
    if (enabled == _gpsEnabled) return;
    _gpsEnabled = enabled;
    _send({TrackingMessage.type: TrackingMessage.gps, 'enabled': enabled});
    if (enabled) {
      _listen(dense: _dense ?? false, force: true);
    } else {
      _subscription?.cancel();
      _subscription = null;
    }
    FlutterForegroundTask.updateService(
      notificationTitle: 'Yathri',
      notificationText: enabled ? 'Ready. Trips are detected automatically.' : 'Location is off. Turn it on to detect trips.',
    );
  }

  void _listen({required bool dense, bool force = false}) {
    if (_stopped || (!force && _dense == dense && _subscription != null)) return;
    _dense = dense;
    _subscription?.cancel();

    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: dense ? 5 : 30,
      intervalDuration: Duration(seconds: dense ? 3 : 20),
    );

    _subscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onPosition,
      onError: (Object e) {
        // Permission revoked, provider disabled or timeout. Drop the stream;
        // onRepeatEvent re-subscribes when conditions allow.
        debugPrint('Location stream error: $e');
        _subscription?.cancel();
        _subscription = null;
      },
      onDone: () => _subscription = null,
      cancelOnError: true,
    );
  }

  void _onPosition(Position pos) {
    final point = TrackPoint(
      lat: pos.latitude,
      lng: pos.longitude,
      time: pos.timestamp,
      speed: pos.speed < 0 || pos.speed.isNaN ? 0 : pos.speed,
      accuracy: pos.accuracy,
      heading: pos.heading >= 0 ? pos.heading : null,
    );

    // Duplicate fix (some providers re-deliver the last location).
    final last = _lastPoint;
    if (last != null &&
        last.time == point.time &&
        last.lat == point.lat &&
        last.lng == point.lng) {
      return;
    }
    _lastPoint = point;

    // Accuracy filtering and unrealistic-jump rejection happen in the engine.
    _engine.ingest(point);

    if (_engine.phase != TrackingPhase.waiting) {
      _lastActiveAt = DateTime.now();
      _send({
        TrackingMessage.type: TrackingMessage.point,
        'lat': point.lat,
        'lng': point.lng,
        'speed': point.speed,
        'heading': point.heading,
        'distance': _engine.currentDistanceMeters,
        'startMs': _engine.currentTripStart?.millisecondsSinceEpoch,
      });
    }
  }

  void _onPhase(TrackingPhase phase) {
    _listen(dense: phase != TrackingPhase.waiting);
    _send({TrackingMessage.type: TrackingMessage.phase, 'phase': phase.name});
    FlutterForegroundTask.updateService(
      notificationTitle: 'Yathri',
      notificationText: switch (phase) {
        TrackingPhase.waiting => 'Ready. Trips are detected automatically.',
        TrackingPhase.detecting => 'Movement detected…',
        TrackingPhase.travelling => 'Recording your trip',
      },
    );
  }

  void _onTrip(Trip trip) {
    // Persist first; the UI isolate may not be alive to receive the message.
    final write = PendingTripInbox.put(TripDto.fromDomain(trip)).then((_) {
      _send({TrackingMessage.type: TrackingMessage.trip, 'id': trip.id});
    }).catchError((Object e) {
      debugPrint('Could not persist detected trip: $e');
    });
    _writes.add(write);
    write.whenComplete(() => _writes.remove(write));
  }

  void _send(Map<String, Object?> data) {
    try {
      FlutterForegroundTask.sendDataToMain(data);
    } catch (_) {
      // UI isolate not attached; trips are safe in the inbox.
    }
  }
}
