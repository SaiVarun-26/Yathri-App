/// Identity for the citizen app. Always anonymous: no name, phone or email.
abstract interface class AuthRepository {
  /// Returns a stable anonymous user id, signing in if required.
  Future<String> ensureSignedIn();

  /// True when the id is backed by Firebase and cloud features are available.
  bool get isCloudBacked;
}
