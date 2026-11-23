import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../domain/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);
  final FirebaseAuth _auth;

  @override
  bool get isCloudBacked => true;

  @override
  Future<String> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing.uid;
    final cred = await _auth.signInAnonymously();
    return cred.user!.uid;
  }
}

/// Used when Firebase is not configured or sign-in is impossible offline on
/// first launch. Generates a random on-device id.
class LocalAuthRepository implements AuthRepository {
  static const _key = 'local_user_id';

  @override
  bool get isCloudBacked => false;

  @override
  Future<String> ensureSignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? await _create(prefs);
  }

  Future<String> _create(SharedPreferences prefs) async {
    final id = 'local-${const Uuid().v4()}';
    await prefs.setString(_key, id);
    return id;
  }
}
