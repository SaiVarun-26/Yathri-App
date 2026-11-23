import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../places/providers/places_providers.dart';
import '../../reminders/providers/commute_providers.dart';
import '../../rewards/providers/goals_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../../trips/providers/mode_providers.dart';
import '../../trips/providers/trip_providers.dart';
import '../../government/data/gov_trip_uploader.dart';
import '../../government/services/government_sharing_service.dart';
import '../data/transparency_repository.dart';
import '../domain/transparency_log.dart';
import '../services/privacy_data_service.dart';

final transparencyRepositoryProvider = Provider((ref) => TransparencyRepository());

final governmentSharingServiceProvider = Provider((ref) {
  final cloud = ref.watch(firebaseAvailableProvider);
  return GovernmentSharingService(
    transparency: ref.watch(transparencyRepositoryProvider),
    uploader: cloud ? FirebaseGovTripUploader(FirebaseDatabase.instance) : null,
  );
});

final privacyDataServiceProvider = Provider((ref) => PrivacyDataService(
      trips: ref.watch(tripRepositoryProvider),
      transparency: ref.watch(transparencyRepositoryProvider),
      places: ref.watch(placesRepositoryProvider),
      fuel: ref.watch(fuelRepositoryProvider),
      goals: ref.watch(goalsRepositoryProvider),
      commute: ref.watch(commuteStoreProvider),
      modeFeedback: ref.watch(modeFeedbackStoreProvider),
    ));

/// What is stored on the phone, in plain numbers.
@immutable
class StoredDataSummary {
  const StoredDataSummary({required this.trips, required this.routePoints, required this.since});
  final int trips;
  final int routePoints;
  final DateTime? since;
}

final storedDataSummaryProvider = Provider<StoredDataSummary>((ref) {
  final trips = ref.watch(tripListProvider);
  var points = 0;
  DateTime? since;
  for (final t in trips) {
    points += t.route.length;
    if (since == null || t.startTime.isBefore(since)) since = t.startTime;
  }
  return StoredDataSummary(trips: trips.length, routePoints: points, since: since);
});

/// Plain-language privacy score. Each part is shown to the user, so the
/// number is never a black box.
@immutable
class PrivacyFactor {
  const PrivacyFactor(this.label, this.points, this.maxPoints, this.explanation);
  final String label;
  final int points;
  final int maxPoints;
  final String explanation;
}

final privacyFactorsProvider = Provider<List<PrivacyFactor>>((ref) {
  final sharing = ref.watch(settingsProvider).value?.shareAnonymously ?? false;
  final cloud = ref.watch(authSessionProvider).value?.cloud ?? false;
  return [
    const PrivacyFactor('Your routes', 40, 40, 'Exact routes and places never leave your phone.'),
    const PrivacyFactor('Your identity', 30, 30, 'No name, phone number or email is ever asked for.'),
    PrivacyFactor(
      'Sharing with Government',
      sharing ? 10 : 20,
      20,
      sharing
          ? 'On. Only coarse areas, mode, distance and hour are sent, with no ID.'
          : 'Off. Nothing is sent to the Government.',
    ),
    PrivacyFactor(
      'Cloud backup',
      cloud ? 5 : 10,
      10,
      cloud
          ? 'Trip summaries (without routes) are backed up to your private account.'
          : 'Off. Everything stays on this phone.',
    ),
  ];
});

final privacyScoreProvider =
    Provider<int>((ref) => ref.watch(privacyFactorsProvider).fold(0, (a, f) => a + f.points));

class TransparencyNotifier extends AsyncNotifier<List<TransparencyLog>> {
  @override
  Future<List<TransparencyLog>> build() => ref.watch(transparencyRepositoryProvider).load();

  void replace(List<TransparencyLog> logs) => state = AsyncData(logs);
}

final transparencyProvider =
    AsyncNotifierProvider<TransparencyNotifier, List<TransparencyLog>>(TransparencyNotifier.new);
