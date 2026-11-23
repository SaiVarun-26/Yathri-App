import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../settings/providers/settings_providers.dart';
import '../services/tracking_service.dart';
import '../services/tracking_task_handler.dart';
import '../services/trip_detection_engine.dart';
import 'trip_providers.dart';

@immutable
class TrackingState {
  const TrackingState({
    this.phase = TrackingPhase.waiting,
    this.serviceRunning = false,
    this.gpsEnabled = true,
    this.permission,
    this.livePosition,
    this.liveSpeedKmh = 0,
    this.liveDistanceM = 0,
    this.liveRoute = const [],
    this.tripStart,
  });

  final TrackingPhase phase;
  final bool serviceRunning;
  final bool gpsEnabled;
  final TrackingPermissionResult? permission;
  final LatLng? livePosition;
  final double liveSpeedKmh;
  final double liveDistanceM;
  final List<LatLng> liveRoute;
  final DateTime? tripStart;

  TrackingState copyWith({
    TrackingPhase? phase,
    bool? serviceRunning,
    bool? gpsEnabled,
    TrackingPermissionResult? permission,
    LatLng? livePosition,
    double? liveSpeedKmh,
    double? liveDistanceM,
    List<LatLng>? liveRoute,
    DateTime? tripStart,
    bool clearLive = false,
  }) =>
      TrackingState(
        phase: phase ?? this.phase,
        serviceRunning: serviceRunning ?? this.serviceRunning,
        gpsEnabled: gpsEnabled ?? this.gpsEnabled,
        permission: permission ?? this.permission,
        livePosition: clearLive ? null : (livePosition ?? this.livePosition),
        liveSpeedKmh: clearLive ? 0 : (liveSpeedKmh ?? this.liveSpeedKmh),
        liveDistanceM: clearLive ? 0 : (liveDistanceM ?? this.liveDistanceM),
        liveRoute: clearLive ? const [] : (liveRoute ?? this.liveRoute),
        tripStart: clearLive ? null : (tripStart ?? this.tripStart),
      );
}

final trackingServiceProvider = Provider<TrackingService>((ref) {
  final service = TrackingService()..initialize();
  ref.onDispose(service.dispose);
  return service;
});

class TrackingNotifier extends Notifier<TrackingState> {
  StreamSubscription<Map<dynamic, dynamic>>? _sub;

  @override
  TrackingState build() {
    final service = ref.watch(trackingServiceProvider);
    _sub = service.messages.listen((m) {
      try {
        _onMessage(m);
      } catch (e) {
        debugPrint('Ignoring malformed tracking message: $e');
      }
    });
    ref.onDispose(() => _sub?.cancel());
    unawaited(_resume(service));
    return const TrackingState();
  }

  /// On launch, bring the service back if the user had tracking enabled.
  Future<void> _resume(TrackingService service) => refreshFromService();

  /// Reconciles UI state with the real service. Called on launch and every
  /// time the app returns to the foreground. If the service died (OEM kill,
  /// reboot, crash) and tracking is enabled, it is restarted silently.
  /// Uses a prompt-free permission check so the user is never nagged.
  Future<void> refreshFromService() async {
    try {
      final service = ref.read(trackingServiceProvider);
      final settings = await ref.read(settingsProvider.future);
      var running = await service.isRunning;

      if (settings.trackingEnabled) {
        final perm = await service.checkPermission();
        state = state.copyWith(permission: perm);
        if (perm == TrackingPermissionResult.granted) {
          if (!running) running = await service.start();
        } else if (running && perm != TrackingPermissionResult.locationServicesOff) {
          // Permission was revoked while the service was alive: stop it so the
          // notification does not claim we are tracking. It restarts
          // automatically once permission is granted again.
          await service.stop();
          running = false;
        }
      }
      state = state.copyWith(serviceRunning: running);
      if (running) service.requestSnapshot();
    } catch (e) {
      debugPrint('Tracking refresh failed: $e');
    }
  }

  void _onMessage(Map<dynamic, dynamic> msg) {
    switch (msg[TrackingMessage.type]) {
      case TrackingMessage.phase:
        final phase = TrackingPhase.values.firstWhere(
          (p) => p.name == msg['phase'],
          orElse: () => TrackingPhase.waiting,
        );
        state = phase == TrackingPhase.waiting
            ? state.copyWith(phase: phase, clearLive: true)
            : state.copyWith(phase: phase);
      case TrackingMessage.point:
        final p = LatLng((msg['lat'] as num).toDouble(), (msg['lng'] as num).toDouble());
        final startMs = msg['startMs'] as int?;
        state = state.copyWith(
          livePosition: p,
          liveSpeedKmh: ((msg['speed'] as num?)?.toDouble() ?? 0) * 3.6,
          liveDistanceM: (msg['distance'] as num?)?.toDouble() ?? 0,
          liveRoute: [...state.liveRoute, p],
          tripStart: startMs == null ? null : DateTime.fromMillisecondsSinceEpoch(startMs),
        );
      case TrackingMessage.gps:
        state = state.copyWith(gpsEnabled: msg['enabled'] as bool? ?? true);
      case TrackingMessage.trip:
        unawaited(ref.read(tripsProvider.notifier).importPending());
    }
  }

  Future<TrackingPermissionResult> enable() async {
    final service = ref.read(trackingServiceProvider);
    final perm = await service.requestPermissions();
    state = state.copyWith(permission: perm);
    if (perm != TrackingPermissionResult.granted) return perm;
    final ok = await service.start();
    state = state.copyWith(serviceRunning: ok);
    if (ok) await ref.read(settingsProvider.notifier).setTracking(true);
    return perm;
  }

  Future<void> disable() async {
    await ref.read(trackingServiceProvider).stop();
    await ref.read(settingsProvider.notifier).setTracking(false);
    state = state.copyWith(serviceRunning: false, phase: TrackingPhase.waiting, clearLive: true);
  }
}

final trackingProvider = NotifierProvider<TrackingNotifier, TrackingState>(TrackingNotifier.new);
