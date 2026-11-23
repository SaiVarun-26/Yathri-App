import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/soft_card.dart';
import '../../alerts/domain/local_alert.dart';
import '../../analytics/presentation/insight_icons.dart';
import '../../analytics/providers/analytics_providers.dart';
import '../../fuel/domain/fuel_profile.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../reminders/domain/smart_reminders.dart';
import '../../trips/presentation/widgets/route_map.dart';
import '../../trips/presentation/widgets/status_card.dart';
import '../../trips/presentation/widgets/trip_card.dart';
import '../../trips/providers/tracking_providers.dart';
import '../../trips/providers/trip_providers.dart';
import '../../trips/services/trip_detection_engine.dart';

/// The daily dashboard. Top to bottom: what is happening now, three plain
/// summaries (today, this week, this month), one thing worth knowing, then
/// today's trips. Each fact appears once.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = ref.watch(nowProvider);
    final today = ref.watch(todaysTripsProvider);
    final summary = ref.watch(homeSummaryProvider);
    final profile = ref.watch(fuelProfileValueProvider);
    final reminders = ref.watch(remindersProvider);
    final alerts = ref.watch(alertsProvider).value ?? const <LocalAlert>[];
    final tracking = ref.watch(trackingProvider);
    final maintenance = ref.watch(maintenanceProvider);
    final loading = ref.watch(tripsProvider).isLoading;
    final showFuel = profile.vehicleType != VehicleType.none;

    final week = summary.week;
    final fuel = summary.fuel;

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.forest,
        onRefresh: () => ref.read(tripsProvider.notifier).importPending(),
        child: ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(Fmt.greeting(now), style: theme.textTheme.bodySmall),
            const SizedBox(height: 2),
            Text('Your journeys', style: theme.textTheme.displaySmall),
            const SizedBox(height: 20),
            const StatusCard(),
            AnimatedSize(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              child: tracking.phase == TrackingPhase.travelling && tracking.livePosition != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: SizedBox(
                          height: 220,
                          child: RouteMap(
                            route: tracking.liveRoute,
                            live: tracking.livePosition,
                            followLive: true,
                            interactive: false,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            for (final a in alerts.take(2)) ...[const SizedBox(height: 16), _AlertCard(alert: a)],
            for (final r in reminders) ...[const SizedBox(height: 16), _ReminderCard(reminder: r)],
            if (maintenance != null && maintenance.fraction >= 0.9) ...[
              const SizedBox(height: 16),
              _MaintenanceCard(
                kmSince: maintenance.kmSinceService,
                due: maintenance.due,
                onServiced: () {
                  HapticFeedback.mediumImpact();
                  ref.read(fuelProfileProvider.notifier).markServiced();
                },
              ),
            ],
            const SectionHeader('Today'),
            SoftCard(child: StatGrid(rowGap: 18, tiles: [
              (Fmt.km(summary.today.distanceKm), 'Distance'),
              (_time(summary.today.duration), 'Travel time'),
              if (showFuel) (Fmt.rupees(fuel.today.costInr), 'Fuel spent'),
              ('${summary.today.tripCount}', summary.today.tripCount == 1 ? 'Trip completed' : 'Trips completed'),
            ])),
            const SectionHeader('This week'),
            SoftCard(child: StatGrid(rowGap: 18, tiles: [
              (Fmt.km(week.distanceKm), 'Distance'),
              (_time(week.duration), 'Travel time'),
              if (showFuel) (Fmt.rupees(fuel.week.costInr), 'Fuel spent'),
              (week.dominantMode?.label ?? '–', 'Most used'),
            ])),
            const SectionHeader('This month'),
            SoftCard(child: StatGrid(rowGap: 18, tiles: [
              (Fmt.km(summary.month.distanceKm), 'Kilometres'),
              ('${summary.month.tripCount}', 'Trips'),
              if (showFuel) (Fmt.rupees(fuel.month.costInr), 'Fuel cost'),
              (_time(summary.avgDailyTravel), 'Daily travel time'),
            ])),
            const SizedBox(height: 16),
            const _InsightCard(),
            if (loading && today.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (today.isNotEmpty) ...[
              const SectionHeader('Trips today'),
              for (final t in today) ...[TripCard(trip: t), const SizedBox(height: 12)],
            ] else ...[
              const SizedBox(height: 16),
              Text('No trips yet today. Go about your day and they will appear here.',
                  style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }

  static String _time(Duration d) => d.inSeconds < 30 ? '0 min' : Fmt.duration(d);
}

class _InsightCard extends ConsumerWidget {
  const _InsightCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final insight = ref.watch(smartInsightProvider);
    return SoftCard(
      color: AppColors.goldSoft,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: Row(
          key: ValueKey(insight.title),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(14)),
              child: Icon(insightIcon(insight.kind), color: AppColors.gold),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('GOOD TO KNOW',
                    style: theme.textTheme.bodySmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(insight.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(insight.body, style: theme.textTheme.bodySmall),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard({required this.kmSince, required this.due, required this.onServiced});
  final double kmSince;
  final bool due;
  final VoidCallback onServiced;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      color: AppColors.terracottaSoft,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        const Icon(Icons.build_circle_rounded, color: AppColors.terracotta),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(due ? 'Service is due' : 'Service due soon', style: theme.textTheme.titleMedium),
            Text('${kmSince.round()} km driven or ridden since your last service.',
                style: theme.textTheme.bodySmall),
          ]),
        ),
        TextButton(onPressed: onServiced, child: const Text('Done')),
      ]),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.reminder});
  final SmartReminder reminder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (reminder.kind) {
      ReminderKind.upcoming => Icons.schedule_rounded,
      ReminderKind.runningLate => Icons.timer_outlined,
      ReminderKind.missed => Icons.help_outline_rounded,
    };
    return SoftCard(
      color: AppColors.goldSoft,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Icon(icon, color: AppColors.gold),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(reminder.title, style: theme.textTheme.titleMedium),
            Text(reminder.body, style: theme.textTheme.bodySmall),
          ]),
        ),
      ]),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});
  final LocalAlert alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (alert.type) {
      AlertType.roadClosure => Icons.block_rounded,
      AlertType.weather => Icons.thunderstorm_rounded,
      AlertType.construction => Icons.construction_rounded,
      AlertType.festival => Icons.celebration_rounded,
      AlertType.tourism => Icons.landscape_rounded,
    };
    return SoftCard(
      color: AppColors.terracottaSoft,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Icon(icon, color: AppColors.terracotta),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(alert.title, style: theme.textTheme.titleMedium),
            Text(alert.message, style: theme.textTheme.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}
