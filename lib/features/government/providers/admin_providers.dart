import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo_data.dart';
import '../data/gov_trip_reader.dart';
import '../domain/anonymous_trip_summary.dart';
import '../domain/mobility_analytics.dart';

/// True when the portal is showing synthetic data instead of the backend.
final adminDemoModeProvider = Provider<bool>((ref) => true);

final adminTripsProvider = StreamProvider<List<AnonymousTripSummary>>((ref) {
  if (ref.watch(adminDemoModeProvider)) return Stream.value(DemoData.generate());
  return GovTripReader(FirebaseDatabase.instance).watch();
});

final mobilitySummaryProvider = Provider<AsyncValue<MobilitySummary>>((ref) {
  return ref.watch(adminTripsProvider).whenData((trips) => const MobilityAnalytics().summarise(trips));
});
