import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class AppSettings {
  const AppSettings({
    this.onboardingDone = false,
    this.trackingEnabled = false,
    this.shareAnonymously = false,
    this.consentSinceMs,
  });

  final bool onboardingDone;

  /// Automatic trip detection on/off.
  final bool trackingEnabled;

  /// Explicit, revocable consent to share anonymous zone-level summaries.
  /// Off by default.
  final bool shareAnonymously;

  /// When sharing consent was last granted. Only trips that started after this
  /// are ever shared; consent is never retroactive.
  final int? consentSinceMs;

  AppSettings copyWith({bool? onboardingDone, bool? trackingEnabled, bool? shareAnonymously, int? consentSinceMs}) =>
      AppSettings(
        onboardingDone: onboardingDone ?? this.onboardingDone,
        trackingEnabled: trackingEnabled ?? this.trackingEnabled,
        shareAnonymously: shareAnonymously ?? this.shareAnonymously,
        consentSinceMs: consentSinceMs ?? this.consentSinceMs,
      );
}

class SettingsRepository {
  static const _onboarding = 'onboarding_done';
  static const _tracking = 'tracking_enabled';
  static const _share = 'share_anonymously';
  static const _consentSince = 'consent_since_ms';

  Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return AppSettings(
      onboardingDone: p.getBool(_onboarding) ?? false,
      trackingEnabled: p.getBool(_tracking) ?? false,
      shareAnonymously: p.getBool(_share) ?? false,
      consentSinceMs: p.getInt(_consentSince),
    );
  }

  Future<void> save(AppSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_onboarding, s.onboardingDone);
    await p.setBool(_tracking, s.trackingEnabled);
    await p.setBool(_share, s.shareAnonymously);
    final since = s.consentSinceMs;
    if (since != null) await p.setInt(_consentSince, since);
  }
}
