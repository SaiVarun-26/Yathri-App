import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../../trips/providers/tracking_providers.dart';
import '../../trips/providers/trip_providers.dart';

/// Startup pipeline (Firebase is initialised in `main()` before this runs):
///
///   anonymous sign-in → settings → trip store (+ import of trips detected
///   while the app was closed) → tracking service (permissions are checked
///   silently here; prompts happen during onboarding or from the status card).
///
/// Every step is isolated so a failure in one never blocks the app.
final appBootstrapProvider = FutureProvider<void>((ref) async {
  try {
    await ref.read(authSessionProvider.future);
  } catch (e) {
    debugPrint('Sign-in deferred: $e');
  }
  try {
    await ref.read(settingsProvider.future);
  } catch (e) {
    debugPrint('Settings load failed, using defaults: $e');
  }
  try {
    await ref.read(tripsProvider.future);
  } catch (e) {
    debugPrint('Trip load failed: $e');
  }
  // Creating the notifier restores or starts the foreground service.
  ref.read(trackingProvider);
});
