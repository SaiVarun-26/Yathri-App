import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/fuel_repository.dart';
import '../domain/fuel_profile.dart';

final fuelRepositoryProvider = Provider((ref) => FuelRepository());

class FuelNotifier extends AsyncNotifier<FuelProfile> {
  @override
  Future<FuelProfile> build() => ref.watch(fuelRepositoryProvider).load();

  int get _now => DateTime.now().millisecondsSinceEpoch;

  /// Saves the user's own figures. The service clock starts the first time.
  Future<void> save(FuelProfile profile) async {
    final current = state.value ?? await future;
    final next = profile.copyWith(
      configured: true,
      lastServiceMs: current.lastServiceMs ?? _now,
    );
    state = AsyncData(next);
    await ref.read(fuelRepositoryProvider).save(next);
  }

  /// "I serviced it": restarts the distance counter.
  Future<void> markServiced() async {
    final current = state.value ?? await future;
    final next = current.copyWith(lastServiceMs: _now);
    state = AsyncData(next);
    await ref.read(fuelRepositoryProvider).save(next);
  }
}

final fuelProfileProvider = AsyncNotifierProvider<FuelNotifier, FuelProfile>(FuelNotifier.new);

/// Synchronous view with defaults while loading.
final fuelProfileValueProvider =
    Provider<FuelProfile>((ref) => ref.watch(fuelProfileProvider).value ?? const FuelProfile());
