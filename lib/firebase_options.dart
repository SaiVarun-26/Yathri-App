// PLACEHOLDER. Replace by running `flutterfire configure` in the project root;
// it generates a file of the same name exposing `DefaultFirebaseOptions`.
//
// Until then the app runs in local-only mode: trips are detected and stored on
// the device, and nothing is synced or shared.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
        'Firebase is not configured. Run `flutterfire configure`.',
      );
}
