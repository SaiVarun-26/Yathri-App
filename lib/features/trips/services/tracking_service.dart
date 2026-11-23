import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import 'tracking_task_handler.dart';

enum TrackingPermissionResult { granted, denied, deniedForever, locationServicesOff }

/// UI-isolate facade over the foreground service.
class TrackingService {
  final _messages = StreamController<Map<dynamic, dynamic>>.broadcast();
  bool _initialised = false;

  Stream<Map<dynamic, dynamic>> get messages => _messages.stream;

  void initialize() {
    if (_initialised) return;
    _initialised = true;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'yathri_trip_detection',
        channelName: 'Trip detection',
        channelDescription: 'Keeps Yathri running so trips are detected automatically.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(15000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowAutoRestart: true,
        stopWithTask: false, // keep detecting after the app is swiped away
      ),
    );
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  void _onData(Object data) {
    if (data is Map) _messages.add(data);
  }

  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  /// Silent check (no prompts). Used on launch/resume so the user is never
  /// nagged; prompts only happen through [requestPermissions].
  Future<TrackingPermissionResult> checkPermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return TrackingPermissionResult.locationServicesOff;
      }
      return switch (await Geolocator.checkPermission()) {
        LocationPermission.always || LocationPermission.whileInUse => TrackingPermissionResult.granted,
        LocationPermission.deniedForever => TrackingPermissionResult.deniedForever,
        _ => TrackingPermissionResult.denied,
      };
    } catch (_) {
      return TrackingPermissionResult.denied;
    }
  }

  /// Location ? background location ? notifications ? battery optimisation.
  /// Foreground-only location is accepted: a service started while the app is
  /// visible keeps receiving fixes with the screen off.
  Future<TrackingPermissionResult> requestPermissions() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return TrackingPermissionResult.locationServicesOff;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return TrackingPermissionResult.deniedForever;
      }
      if (permission == LocationPermission.denied) return TrackingPermissionResult.denied;

      // Second request upgrades "while in use" to "all the time" (Android 10+).
      if (permission == LocationPermission.whileInUse) {
        permission = await Geolocator.requestPermission();
      }

      final notif = await FlutterForegroundTask.checkNotificationPermission();
      if (notif != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      // Lets the service survive aggressive OEM battery managers.
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
      return TrackingPermissionResult.granted;
    } catch (e) {
      debugPrint('Permission request failed: $e');
      return TrackingPermissionResult.denied;
    }
  }

  Future<bool> start() async {
    try {
      if (await FlutterForegroundTask.isRunningService) return true;
      final result = await FlutterForegroundTask.startService(
        serviceTypes: [ForegroundServiceTypes.location],
        notificationTitle: 'Yathri',
        notificationText: 'Ready. Trips are detected automatically.',
        callback: trackingStartCallback,
      );
      return result is ServiceRequestSuccess;
    } catch (e) {
      debugPrint('Could not start tracking service: $e');
      return false;
    }
  }

  Future<void> stop() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      debugPrint('Could not stop tracking service: $e');
    }
  }

  /// Asks a running service to re-send its current phase (after an app restart).
  void requestSnapshot() => FlutterForegroundTask.sendDataToTask(TrackingMessage.snapshot);
  Future<void> openLocationSettings() => Geolocator.openAppSettings();

  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    _messages.close();
  }
}
