import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/goals_repository.dart';
import '../domain/goals.dart';

final goalsRepositoryProvider = Provider((ref) => GoalsRepository());

class GoalsNotifier extends AsyncNotifier<TravelGoals> {
  @override
  Future<TravelGoals> build() => ref.watch(goalsRepositoryProvider).load();

  Future<void> save(TravelGoals goals) async {
    state = AsyncData(goals);
    await ref.read(goalsRepositoryProvider).save(goals);
  }
}

final goalsProvider = AsyncNotifierProvider<GoalsNotifier, TravelGoals>(GoalsNotifier.new);

final goalsValueProvider =
    Provider<TravelGoals>((ref) => ref.watch(goalsProvider).value ?? const TravelGoals());
