import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/providers/analytics_providers.dart';
import '../../trips/domain/trip.dart';
import '../../trips/providers/trip_providers.dart';
import '../domain/diary_filter.dart';

class DiaryFilterNotifier extends Notifier<DiaryFilter> {
  @override
  DiaryFilter build() => const DiaryFilter();

  void select(DiaryFilterKind kind) => state = DiaryFilter(kind: kind);

  void selectDates(DateTime from, DateTime to) =>
      state = DiaryFilter(kind: DiaryFilterKind.custom, customFrom: from, customTo: to);
}

final diaryFilterProvider = NotifierProvider<DiaryFilterNotifier, DiaryFilter>(DiaryFilterNotifier.new);

/// Trips matching the chosen filter. All trips are kept on the phone, so
/// earlier months are always available.
final diaryTripsProvider = Provider<List<Trip>>((ref) =>
    ref.watch(diaryFilterProvider).apply(ref.watch(tripListProvider), ref.watch(nowProvider)));
