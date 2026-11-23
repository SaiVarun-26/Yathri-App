import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';

final settingsRepositoryProvider = Provider((ref) => SettingsRepository());

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.watch(settingsRepositoryProvider).load();

  Future<void> _update(AppSettings Function(AppSettings) change) async {
    final current = state.value ?? await future;
    final next = change(current);
    state = AsyncData(next);
    await ref.read(settingsRepositoryProvider).save(next);
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;

  Future<void> completeOnboarding({required bool share}) => _update((s) => s.copyWith(
        onboardingDone: true,
        shareAnonymously: share,
        consentSinceMs: share ? _now : null,
      ));

  Future<void> setTracking(bool value) => _update((s) => s.copyWith(trackingEnabled: value));

  /// Consent applies from now on; it is never retroactive.
  Future<void> setSharing(bool value) => _update((s) => s.copyWith(
        shareAnonymously: value,
        consentSinceMs: value ? _now : null,
      ));
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
