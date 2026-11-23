import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'features/auth/providers/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Last line of defence: log instead of crashing on unhandled async errors.
  FlutterError.onError = (details) => FlutterError.dumpErrorToConsole(details);
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled error: $error');
    return true;
  };
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  final firebaseReady = await FirebaseBootstrap.init();

  runApp(ProviderScope(
    overrides: [firebaseAvailableProvider.overrideWithValue(firebaseReady)],
    child: const YathriApp(),
  ));
}
