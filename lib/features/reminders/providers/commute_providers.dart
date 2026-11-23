import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../places/providers/places_providers.dart';
import '../../trips/providers/trip_providers.dart';
import '../data/commute_snapshot_store.dart';
import '../domain/commute_alert.dart';
import '../domain/smart_reminders.dart';

final commuteStoreProvider = Provider((ref) => CommuteSnapshotStore());

/// Side-effect provider: hands the user's regular journeys to the background
/// service so it can warn about a late departure while the app is closed.
/// Watched once from the app shell.
final commuteSyncProvider = Provider<void>((ref) {
  final trips = ref.watch(tripListProvider);
  final namer = ref.watch(placeNamerProvider);
  final store = ref.read(commuteStoreProvider);

  final routes = [
    for (final p in SmartReminderEngine.detectPatterns(trips, DateTime.now()))
      CommuteRoute(
        originZoneId: p.origin.id,
        destinationName: namer.name(p.destination),
        weekdayKind: p.weekdayKind,
        medianMinute: p.medianMinuteOfDay,
      ),
  ];
  Future.microtask(() => store.saveRoutes(routes));
});
