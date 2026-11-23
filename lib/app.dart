import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/home/presentation/home_shell.dart';
import 'features/home/providers/app_bootstrap_provider.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/settings/providers/settings_providers.dart';

class YathriApp extends ConsumerWidget {
  const YathriApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    // Kick off the startup pipeline; screens render immediately regardless.
    ref.watch(appBootstrapProvider);

    return MaterialApp(
      title: 'Yathri',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: settings.when(
        loading: () => const Scaffold(body: SizedBox.shrink()),
        error: (_, _) => const OnboardingScreen(),
        data: (s) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: s.onboardingDone ? const HomeShell(key: ValueKey('home')) : const OnboardingScreen(key: ValueKey('onboarding')),
        ),
      ),
    );
  }
}
