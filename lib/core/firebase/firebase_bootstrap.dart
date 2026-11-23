import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Initialises Firebase if it has been configured. Returns false when running
/// in local-only mode so the app degrades gracefully instead of crashing.
abstract final class FirebaseBootstrap {
  static Future<bool> init() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      if (!kIsWeb) _enableOfflinePersistence();
      return true;
    } catch (e) {
      debugPrint('Firebase unavailable, running local-only: $e');
      return false;
    }
  }

  /// Writes queue locally and flush when online. This throws if the database
  /// was already used (e.g. after a hot restart), which must not be mistaken
  /// for Firebase being unavailable, so it is handled separately.
  static void _enableOfflinePersistence() {
    try {
      FirebaseDatabase.instance.setPersistenceEnabled(true);
      FirebaseDatabase.instance.setPersistenceCacheSizeBytes(20 * 1024 * 1024);
    } catch (e) {
      debugPrint('Offline persistence already configured: $e');
    }
  }
}
