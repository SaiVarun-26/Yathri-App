import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/soft_card.dart';
import '../../auth/providers/auth_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../places/providers/places_providers.dart';
import '../../rewards/providers/goals_providers.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/providers/settings_providers.dart';
import '../../trips/providers/tracking_providers.dart';
import '../../trips/providers/trip_providers.dart';
import '../domain/transparency_log.dart';
import '../providers/transparency_providers.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final tracking = ref.watch(trackingProvider);
    final logs = ref.watch(transparencyProvider).value ?? const <TransparencyLog>[];
    final cloud = ref.watch(firebaseAvailableProvider);
    final uploads = logs.where((l) => l.kind == TransparencyKind.sharedAnonymous).toList();

    return SafeArea(
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('Privacy', style: theme.textTheme.displaySmall),
          ),
          const SizedBox(height: 16),
          const _ScoreCard(),
          const SectionHeader('Controls'),
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            child: Column(children: [
              SwitchListTile(
                value: tracking.serviceRunning,
                title: const Text('Automatic trip detection'),
                subtitle: const Text('Runs in the background, even when the screen is off.'),
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  final n = ref.read(trackingProvider.notifier);
                  v ? n.enable() : n.disable();
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: settings.shareAnonymously,
                title: const Text('Share anonymous travel summaries'),
                subtitle: const Text('Helps plan roads and transport. You can turn this off any time.'),
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  ref.read(settingsProvider.notifier).setSharing(v);
                },
              ),
            ]),
          ),
          if (!cloud)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: SoftCard(
                color: AppColors.goldSoft,
                child: Text('Cloud is not configured. All your data stays on this phone and nothing is shared.'),
              ),
            ),
          const SectionHeader('Stored on your phone'),
          const _StoredCard(),
          const SectionHeader('What the Government can see'),
          const _Ledger(),
          const SectionHeader('Government uploads'),
          _UploadHistory(uploads: uploads, sharing: settings.shareAnonymously),
          const SectionHeader('Your data'),
          const _DataActions(),
        ],
      ),
    );
  }
}

class _ScoreCard extends ConsumerWidget {
  const _ScoreCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final score = ref.watch(privacyScoreProvider);
    final factors = ref.watch(privacyFactorsProvider);
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(alignment: Alignment.center, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: score / 100),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: v,
                    strokeWidth: 7,
                    backgroundColor: AppColors.line,
                    color: AppColors.forest,
                    strokeCap: StrokeCap.round,
                  ),
                ),
              ),
              Text('$score', style: theme.textTheme.titleLarge),
            ]),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Privacy score', style: theme.textTheme.titleLarge),
              const SizedBox(height: 2),
              Text('How little of your data ever leaves this phone.', style: theme.textTheme.bodySmall),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        for (final f in factors)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(
                f.points == f.maxPoints ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                size: 20,
                color: f.points == f.maxPoints ? AppColors.forest : AppColors.gold,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.label, style: theme.textTheme.titleMedium),
                  Text(f.explanation, style: theme.textTheme.bodySmall),
                ]),
              ),
              Text('${f.points}/${f.maxPoints}', style: theme.textTheme.bodySmall),
            ]),
          ),
      ]),
    );
  }
}

class _StoredCard extends ConsumerWidget {
  const _StoredCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(storedDataSummaryProvider);
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: StatTile(value: '${s.trips}', label: 'Trips')),
          Expanded(child: StatTile(value: '${s.routePoints}', label: 'Route points')),
          Expanded(
              child: StatTile(
                  value: s.since == null ? '–' : DateFormat('d MMM y').format(s.since!), label: 'Since')),
        ]),
        const SizedBox(height: 14),
        Text(
          'Each trip keeps its exact route, start and end, mode, distance and cost on this phone only. '
          'Your own names for places and your vehicle details are stored here too.',
          style: theme.textTheme.bodySmall,
        ),
      ]),
    );
  }
}

class _Ledger extends StatelessWidget {
  const _Ledger();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(IconData icon, Color c, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Icon(icon, size: 20, color: c),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          ]),
        );

    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Never shared', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.danger)),
        const SizedBox(height: 6),
        for (final t in const [
          'Your name, phone number or email',
          'Exact GPS locations',
          'Your routes and travel history',
          'Any ID that could link trips to you',
        ])
          row(Icons.block_rounded, AppColors.danger, t),
        const Divider(height: 28),
        Text('Shared only if you allow it', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.forest)),
        const SizedBox(height: 6),
        for (final t in const [
          'Start and end area (about 1 km wide)',
          'Mode of transport',
          'Distance, rounded to 0.5 km',
          'Hour of travel and duration (rounded to 5 min)',
        ])
          row(Icons.check_circle_rounded, AppColors.forest, t),
        const SizedBox(height: 10),
        Text('Why: the Government uses many anonymous summaries together to plan buses, roads and parking.',
            style: theme.textTheme.bodySmall),
      ]),
    );
  }
}

class _UploadHistory extends StatelessWidget {
  const _UploadHistory({required this.uploads, required this.sharing});
  final List<TransparencyLog> uploads;
  final bool sharing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (uploads.isEmpty) {
      return SoftCard(
        child: Text(
          sharing
              ? 'Sharing is on. Your next finished trip will be shared and listed here.'
              : 'Nothing has been shared. Sharing is off.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    final fmt = DateFormat('d MMM, h:mm a');
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: StatTile(value: '${uploads.length}', label: 'Summaries shared')),
          Expanded(child: StatTile(value: fmt.format(uploads.first.time), label: 'Last upload')),
        ]),
        const Divider(height: 28),
        for (final u in uploads.take(10))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.upload_rounded, size: 18, color: AppColors.terracotta),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(fmt.format(u.time), style: theme.textTheme.titleMedium),
                  Text(u.detail, style: theme.textTheme.bodySmall),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _DataActions extends ConsumerStatefulWidget {
  const _DataActions();

  @override
  ConsumerState<_DataActions> createState() => _DataActionsState();
}

class _DataActionsState extends ConsumerState<_DataActions> {
  bool _busy = false;

  Future<void> _download() async {
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(privacyDataServiceProvider);
    setState(() => _busy = true);
    try {
      final file = await service.exportAll();
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'My Yathri data'));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not export your data. Please try again.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all my data?'),
        content: const Text(
          'This erases your trips, place names, vehicle details, goals and activity log from this phone '
          'and from your private backup. It cannot be undone.\n\n'
          'Anonymous summaries already shared carry no ID, so they cannot be traced back to you or removed. '
          'Sharing will be switched off.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    // Resolve everything before awaiting; the screen may rebuild meanwhile.
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(privacyDataServiceProvider);
    final settings = ref.read(settingsProvider.notifier);
    setState(() => _busy = true);
    try {
      await service.deleteAll();
      await settings.setSharing(false);
      ref
        ..invalidate(tripsProvider)
        ..invalidate(transparencyProvider)
        ..invalidate(placesProvider)
        ..invalidate(fuelProfileProvider)
        ..invalidate(goalsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Your data has been deleted.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not delete everything. Please try again.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _download,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download my data'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete my data'),
          ),
        ),
      ]),
    );
  }
}
