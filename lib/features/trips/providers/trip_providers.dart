import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../../transparency/providers/transparency_providers.dart';
import '../data/trip_local_source.dart';
import 'mode_providers.dart';
import '../data/trip_remote_source.dart';
import '../data/trip_repository_impl.dart';
import '../domain/transport_mode.dart';
import '../domain/trip.dart';
import '../domain/trip_repository.dart';

final tripRemoteSourceProvider = Provider<TripRemoteSource?>((ref) {
  if (!ref.watch(firebaseAvailableProvider)) return null;
  return FirebaseTripRemoteSource(FirebaseDatabase.instance);
});

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepositoryImpl(
    local: FileTripLocalSource(),
    remote: ref.watch(tripRemoteSourceProvider),
    // Read lazily so the repository is not rebuilt when auth resolves.
    cloudUid: () => ref.read(authSessionProvider).value?.cloudUid,
  );
});

/// Single owner of the trip list. Every completed trip flows through here:
/// import → local save → UI refresh → sharing + transparency → cloud queue.
class TripsNotifier extends AsyncNotifier<List<Trip>> {
  StreamSubscription<bool>? _connectionSub;
  bool _syncing = false;

  @override
  Future<List<Trip>> build() async {
    final repo = ref.watch(tripRepositoryProvider);
    ref.onDispose(() => _connectionSub?.cancel());

    final local = await repo.loadAll();
    unawaited(_postLoad());
    return local;
  }

  Future<void> _postLoad() async {
    await importPending();
    await _syncWhenOnline();

    // Re-sync every time the backend connection comes back.
    final remote = ref.read(tripRemoteSourceProvider);
    _connectionSub = remote?.connection.listen((online) {
      if (online) unawaited(_syncWhenOnline());
    });
  }

  /// Resolves the anonymous session, retrying sign-in if the first attempt
  /// happened offline.
  Future<AuthSession?> _ensureAuth({bool retry = false}) async {
    try {
      var session = await ref.read(authSessionProvider.future);
      if (!session.cloud && retry && ref.read(firebaseAvailableProvider)) {
        ref.invalidate(authSessionProvider);
        session = await ref.read(authSessionProvider.future);
      }
      return session;
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncWhenOnline() async {
    if (_syncing) return;
    _syncing = true;
    try {
      await _ensureAuth(retry: true);
      final merged = await ref.read(tripRepositoryProvider).sync();
      if (merged != null) state = AsyncData(merged);
      await retryPendingShares();
    } catch (e) {
      debugPrint('Sync failed, will retry on reconnect: $e');
    } finally {
      _syncing = false;
    }
  }

  /// Imports trips detected by the background service, saves them, refreshes
  /// every dependent provider, then processes sharing. Never throws.
  Future<void> importPending() async {
    try {
      final repo = ref.read(tripRepositoryProvider);
      final detected = await repo.importPending();
      if (detected.isEmpty) return;

      // The detector's first guess is refined with what the user has told us
      // (their vehicles and past corrections). Already on disk either way, so
      // publish to the UI immediately.
      final added = await ref.read(modeRefinerProvider).refine(detected);
      state = AsyncData(_merge(state.value ?? const [], added));
      await _shareAndQueue(added, logKept: true);
    } catch (e) {
      debugPrint('Importing detected trips failed: $e');
    }
  }

  /// Shares trips whose upload previously failed (offline, signed-out), but
  /// only those that started after consent was given.
  Future<void> retryPendingShares() async {
    final settings = ref.read(settingsProvider).value;
    if (settings == null || !settings.shareAnonymously) return;
    final since = settings.consentSinceMs ?? 0;
    final candidates = (state.value ?? const <Trip>[])
        .where((t) => !t.sharedWithGovernment && t.startTime.millisecondsSinceEpoch >= since)
        .toList();
    if (candidates.isEmpty) return;
    await _shareAndQueue(candidates, logKept: false);
  }

  Future<void> _shareAndQueue(List<Trip> trips, {required bool logKept}) async {
    final repo = ref.read(tripRepositoryProvider);
    final settings = ref.read(settingsProvider).value;
    final session = await _ensureAuth();
    final sharing = ref.read(governmentSharingServiceProvider);

    for (final trip in trips) {
      var result = trip;
      try {
        // Only trips that began after consent are eligible; needs a signed-in cloud session.
        final eligible = (settings?.shareAnonymously ?? false) &&
            (session?.cloud ?? false) &&
            trip.startTime.millisecondsSinceEpoch >= (settings?.consentSinceMs ?? 0);
        final outcome = await sharing.process(trip, consented: eligible, logKept: logKept);
        ref.read(transparencyProvider.notifier).replace(outcome.logs);
        result = outcome.trip;
      } catch (e) {
        debugPrint('Sharing step failed for ${trip.id}: $e');
      }
      // Saves locally and queues the private cloud copy (offline-safe).
      await repo.save(result);
      state = AsyncData(_merge(state.value ?? const [], [result]));
    }
  }

  /// User correction of the detected mode. Recomputes cost.
  Future<void> correctMode(Trip trip, TransportMode mode) async {
    // Keep the movement signature of this journey with the right answer, so
    // similar journeys are recognised better next time.
    await ref.read(modeRefinerProvider).recordCorrection(trip, mode);
    final updated = trip.copyWith(
      mode: mode,
      modeConfidence: 1,
      costInr: mode.estimateCost(trip.distanceKm),
      userCorrectedMode: true,
    );
    await ref.read(tripRepositoryProvider).save(updated);
    state = AsyncData(_merge(state.value ?? const [], [updated]));
  }

  Future<void> delete(Trip trip) async {
    await ref.read(tripRepositoryProvider).delete(trip.id);
    state = AsyncData((state.value ?? const <Trip>[]).where((t) => t.id != trip.id).toList());
  }

  List<Trip> _merge(List<Trip> base, List<Trip> changes) {
    final byId = {for (final t in base) t.id: t};
    for (final t in changes) {
      byId[t.id] = t;
    }
    return byId.values.toList()..sort((a, b) => b.startTime.compareTo(a.startTime));
  }
}

final tripsProvider = AsyncNotifierProvider<TripsNotifier, List<Trip>>(TripsNotifier.new);

/// Convenience: trips list or empty while loading.
final tripListProvider = Provider<List<Trip>>((ref) => ref.watch(tripsProvider).value ?? const []);

final tripByIdProvider = Provider.family<Trip?, String>((ref, id) {
  for (final t in ref.watch(tripListProvider)) {
    if (t.id == id) return t;
  }
  return null;
});
