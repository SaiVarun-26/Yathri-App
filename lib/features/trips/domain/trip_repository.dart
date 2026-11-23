import 'trip.dart';

abstract interface class TripRepository {
  /// All trips on this device, newest first.
  Future<List<Trip>> loadAll();

  /// Pulls trips detected by the background service while the UI was away.
  /// Returns only the newly imported trips.
  Future<List<Trip>> importPending();

  /// Inserts or replaces a trip.
  Future<void> save(Trip trip);

  Future<void> delete(String id);

  /// Erases every trip from this device and from the user's cloud backup.
  Future<void> deleteAll();

  /// Merges cloud state into local state using last-writer-wins. Returns the
  /// full merged list, or null if sync was not possible (offline / local-only).
  Future<List<Trip>?> sync();
}
