import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/commute_alert.dart';

/// Shows the "you may be running late" heads-up. Works inside the
/// foreground-service isolate, so it fires even when the app is closed.
class CommuteNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'yathri_commute',
    'Commute reminders',
    channelDescription: 'Tells you when you are past your usual departure time.',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> init() async {
    try {
      _ready = await _plugin.initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            ),
          ) ??
          false;
    } catch (e) {
      debugPrint('Commute notifications unavailable: $e');
    }
  }

  Future<void> showLate(CommuteRoute route, String usualTime) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: 4101,
        title: 'Running late?',
        body: 'You usually leave for ${route.destinationName} around $usualTime.',
        notificationDetails: const NotificationDetails(android: _channel),
      );
    } catch (e) {
      debugPrint('Could not show commute alert: $e');
    }
  }
}
