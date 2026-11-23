import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/soft_card.dart';
import '../../fuel/domain/fuel_profile.dart';
import '../../fuel/presentation/vehicle_form.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../../trips/providers/tracking_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;
  bool _share = false;
  FuelProfile _vehicle = const FuelProfile();
  bool _busy = false;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    // Completing onboarding swaps this screen out, after which `ref` is
    // unusable. Resolve every notifier before the first await.
    final settings = ref.read(settingsProvider.notifier);
    final tracking = ref.read(trackingProvider.notifier);
    final fuel = ref.read(fuelProfileProvider.notifier);
    await fuel.save(_vehicle);
    await settings.completeOnboarding(share: _share);
    // Permission prompts come after the user has seen what they are agreeing to.
    await tracking.enable();
  }

  void _next() {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    _page.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = <Widget>[
      const _Intro(
        icon: Icons.route_rounded,
        title: 'Your journeys,\nwritten for you',
        body:
            'Yathri notices when you travel and keeps a diary of every trip, with costs, carbon and insights. There is never a start button to press.',
      ),
      const _Intro(
        icon: Icons.shield_outlined,
        title: 'Private by design',
        body:
            'Your routes and exact places stay on your phone. We never ask for your name or phone number. Only a coarse area, the mode, distance and hour can be shared, and only if you say so.',
      ),
      _VehiclePage(onChanged: (p) => _vehicle = p),
      _Consent(share: _share, onChanged: (v) => setState(() => _share = v)),
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(children: [
            Expanded(
              child: PageView(
                controller: _page,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (i) => setState(() => _index = i),
                children: pages,
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < pages.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 26 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index ? AppColors.forest : AppColors.line,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : (_index == pages.length - 1 ? _finish : _next),
                child: _busy
                    ? const SizedBox(
                        width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(_index == pages.length - 1 ? 'Allow location and start' : 'Continue',
                        style: theme.textTheme.labelLarge?.copyWith(color: AppColors.naturalWhite)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(color: AppColors.forestSoft, borderRadius: BorderRadius.circular(28)),
        child: Icon(icon, size: 42, color: AppColors.forest),
      ),
      const SizedBox(height: 32),
      Text(title, style: theme.textTheme.displaySmall),
      const SizedBox(height: 16),
      Text(body, style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted)),
    ]);
  }
}

/// Asks about the user's vehicle so fuel cost is worked out from their own
/// mileage and the current petrol price.
class _VehiclePage extends StatelessWidget {
  const _VehiclePage({required this.onChanged});
  final ValueChanged<FuelProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 24),
        Text('Your vehicle', style: theme.textTheme.displaySmall),
        const SizedBox(height: 12),
        Text(
          'This lets Yathri work out your petrol cost in two simple steps:',
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: 10),
        Text('Fuel used = distance ÷ mileage', style: theme.textTheme.titleMedium),
        Text('Fuel cost = fuel used × petrol price', style: theme.textTheme.titleMedium),
        const SizedBox(height: 22),
        SoftCard(child: VehicleForm(initial: const FuelProfile(), onChanged: onChanged)),
        const SizedBox(height: 12),
        Text('Not sure? The usual figures are filled in. You can change them any time in Insights.',
            style: theme.textTheme.bodySmall),
      ]),
    );
  }
}

class _Consent extends StatelessWidget {
  const _Consent({required this.share, required this.onChanged});
  final bool share;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 24),
        Text('Help plan better roads', style: theme.textTheme.displaySmall),
        const SizedBox(height: 12),
        Text(
          'You can contribute anonymous trip summaries so the Government can plan buses, roads and parking. This is optional and off by default.',
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: 24),
        SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('If you turn it on, only this is sent', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final t in const [
              'Start and end area (about 1 km wide)',
              'Mode of transport',
              'Distance and hour of travel',
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  const Icon(Icons.check_rounded, size: 18, color: AppColors.forest),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t)),
                ]),
              ),
            const Divider(height: 28),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: share,
              title: const Text('Share anonymous summaries'),
              onChanged: onChanged,
            ),
          ]),
        ),
      ]),
    );
  }
}
