import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository_impl.dart';
import '../domain/auth_repository.dart';

/// Overridden in `main()` once Firebase initialisation has been attempted.
final firebaseAvailableProvider = Provider<bool>((ref) => false);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (ref.watch(firebaseAvailableProvider)) {
    return FirebaseAuthRepository(FirebaseAuth.instance);
  }
  return LocalAuthRepository();
});

class AuthSession {
  const AuthSession({required this.uid, required this.cloud});
  final String uid;

  /// True when [uid] is a Firebase uid and cloud features can be used.
  final bool cloud;

  String? get cloudUid => cloud ? uid : null;
}

/// Anonymous sign-in. If the cloud is unreachable on first launch, the app
/// carries on locally and retries on the next launch.
final authSessionProvider = FutureProvider<AuthSession>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  try {
    final uid = await repo.ensureSignedIn().timeout(const Duration(seconds: 8));
    return AuthSession(uid: uid, cloud: repo.isCloudBacked);
  } catch (_) {
    final local = await LocalAuthRepository().ensureSignedIn();
    return AuthSession(uid: local, cloud: false);
  }
});
