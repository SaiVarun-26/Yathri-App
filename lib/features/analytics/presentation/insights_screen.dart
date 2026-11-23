import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/soft_card.dart';
import '../../fuel/presentation/fuel_cost_card.dart';
import '../../reports/presentation/report_screen.dart';
import '../../trips/providers/trip_providers.dart';
import '../domain/travel_analytics.dart';
import '../providers/analytics_providers.dart';

/// Plain-language cards. Each answers one question: how much did I travel,
/// what did it cost, what are my habits, what is worth knowing.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasAnyTrips = ref.watch(tripListProvider).isNotEmpty;
    final period = ref.watch(insightPeriodProvider);
    final a = ref.watch(travelAnalyticsProvider);

    final title = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text('Insights', style: theme.textTheme.displaySmall),
    );

    if (!hasAnyTrips) {
      return SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), children: [
          title,
          const SizedBox(height: 60),
          const EmptyState(
            icon: Icons.insights_rounded,
            title: 'Your insights start with your first trip',
            message: 'Distance, fuel cost, habits and tips appear here as trips are recorded.',
          ),
        ]),
      );
    }

    final o = a.overview;
    final b = a.behaviour;

    return SafeArea(
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          title,
          const SizedBox(height: 16),
          SegmentedButton<InsightPeriod>(
            showSelectedIcon: false,
            segments: [for (final p in InsightPeriod.values) ButtonSegment(value: p, label: Text(p.label))],
            selected: {period},
            onSelectionChanged: (s) => ref.read(insightPeriodProvider.notifier).select(s.first),
          ),

          const SectionHeader('Travel overview'),
          if (!a.hasData)
            _NoTrips(period: period)
          else
            SoftCard(child: StatGrid(tiles: [
              (Fmt.km(o.distanceKm), 'Total distance'),
              ('${o.tripCount}', 'Total trips'),
              (Fmt.duration(o.travelTime), 'Total travel time'),
              (o.avgSpeedKmh == 0 ? '–' : '${o.avgSpeedKmh.round()} km/h', 'Average speed'),
              (o.favouriteMode?.mode.label ?? '–', 'Favourite transport'),
            ])),

          const SectionHeader('Money'),
          const FuelCostCard(),

          if (a.hasData) ...[
            const SectionHeader('Travel behaviour'),
            SoftCard(child: StatGrid(tiles: [
              (b.mostVisited?.name ?? 'Not yet', 'Most visited place'),
              (b.longestTrip == null ? '–' : Fmt.km(b.longestTrip!.distanceKm), 'Longest trip'),
              (b.shortestTrip == null ? '–' : Fmt.km(b.shortestTrip!.distanceKm), 'Shortest trip'),
              (b.avgCommuteMinutes == null ? 'Still learning' : '${b.avgCommuteMinutes!.round()} min', 'Average commute'),
              (b.mostActiveWeekday == null ? 'Not yet' : TravelAnalytics.weekdayName(b.mostActiveWeekday!), 'Most active day'),
              (b.mostActiveHour == null ? 'Not yet' : TravelAnalytics.hourLabel(b.mostActiveHour!), 'Most active hour'),
            ])),
            if (a.sentences.isNotEmpty) ...[
              const SectionHeader('In plain words'),
              SoftCard(
                child: Column(children: [
                  for (var i = 0; i < a.sentences.length; i++) ...[
                    if (i > 0) const Divider(height: 24),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.gold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(a.sentences[i], style: theme.textTheme.bodyLarge)),
                    ]),
                  ],
                ]),
              ),
            ],
          ],

          const SizedBox(height: 20),
          SoftCard(
            padding: const EdgeInsets.all(16),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ReportScreen())),
            child: Row(children: [
              const Icon(Icons.auto_stories_rounded, color: AppColors.forest),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Monthly and yearly report', style: theme.textTheme.titleMedium),
                  Text('A summary you can share as a picture.', style: theme.textTheme.bodySmall),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
            ]),
          ),
        ],
      ),
    );
  }
}

class _NoTrips extends StatelessWidget {
  const _NoTrips({required this.period});
  final InsightPeriod period;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Text(
        period == InsightPeriod.all
            ? 'No trips yet.'
            : 'No trips ${period.phrase} yet. Try "All time" to see everything.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
