import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/soft_card.dart';
import '../../milestones/domain/milestone_card.dart';
import '../../milestones/presentation/milestone_card_view.dart';
import '../../fuel/domain/fuel_profile.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../places/presentation/place_rename_dialog.dart';
import '../../places/providers/places_providers.dart';
import '../../rewards/domain/rewards.dart';
import '../domain/transport_mode.dart';
import '../domain/trip.dart';
import '../domain/trip_segments.dart';
import '../domain/zone.dart';
import '../providers/trip_providers.dart';
import 'mode_visuals.dart';
import 'widgets/route_map.dart';

class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripByIdProvider(tripId));
    if (trip == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('This trip is no longer available.')));
    }
    final theme = Theme.of(context);
    final route = trip.route.map((p) => LatLng(p.lat, p.lng)).toList();
    final segments = TripSegments.of(trip);
    final cost = FuelCalculator.tripCost(trip, ref.watch(fuelProfileValueProvider));

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppColors.ivory,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: AppColors.naturalWhite,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: route.length >= 2
                  ? RouteMap(route: route, interactive: false)
                  : Container(
                      color: AppColors.forestSoft,
                      alignment: Alignment.center,
                      child: Text('Route not stored on this device',
                          style: theme.textTheme.bodySmall)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            sliver: SliverList.list(children: [
              const SizedBox(height: 12),
              Row(children: [
                Hero(tag: 'mode-${trip.id}', child: ModeBadge(trip.mode, size: 56)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(trip.modeText, style: theme.textTheme.headlineMedium),
                    Text(
                      '${Fmt.dayHeading(trip.startTime, DateTime.now())}, ${Fmt.time(trip.startTime)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ]),
                ),
                if (trip.userCorrectedMode) const Pill('Confirmed by you'),
                if (trip.modeIsUncertain) const Pill('Not sure', color: AppColors.terracotta, background: AppColors.terracottaSoft),
              ]),
              const SizedBox(height: 20),
              SoftCard(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Column(children: [
                  _PlaceRow(label: 'From', zone: trip.originZone),
                  const Divider(height: 1),
                  _PlaceRow(label: 'To', zone: trip.destinationZone),
                ]),
              ),
              const SizedBox(height: 16),
              SoftCard(
                child: Column(children: [
                  Row(children: [
                    Expanded(child: StatTile(value: Fmt.km(trip.distanceKm), label: 'Distance')),
                    Expanded(child: StatTile(value: Fmt.duration(trip.duration), label: 'Duration')),
                    Expanded(
                        child: StatTile(
                            value: cost < 1 ? 'Free' : Fmt.rupees(cost),
                            label: 'Cost estimate',
                            accent: AppColors.terracotta)),
                  ]),
                  const Divider(height: 32),
                  Row(children: [
                    Expanded(child: StatTile(value: '${trip.avgSpeedKmh.round()} km/h', label: 'Average speed')),
                    Expanded(child: StatTile(value: '${trip.maxSpeedKmh.round()} km/h', label: 'Max speed')),
                    Expanded(
                        child: StatTile(
                            value: '${(trip.co2SavedGrams / 1000).toStringAsFixed(2)} kg',
                            label: 'CO₂ saved')),
                  ]),
                  const Divider(height: 32),
                  Row(children: [
                    Expanded(
                        child: StatTile(
                            value: '${RewardsEngine.pointsForTrip(trip)}', label: 'Eco points', accent: AppColors.gold)),
                    const Expanded(child: SizedBox.shrink()),
                    const Expanded(child: SizedBox.shrink()),
                  ]),
                ]),
              ),
              SectionHeader(trip.modeIsUncertain ? 'How did you travel?' : 'Not quite right?'),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  trip.modeIsUncertain
                      ? 'Yathri is not certain. Tap the right one and it will remember for next time.'
                      : 'Tap the right one. Yathri learns from your corrections.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              _ModePicker(trip: trip),
              const SectionHeader('Timeline'),
              SoftCard(
                child: Column(children: [
                  for (var i = 0; i < segments.length; i++)
                    _TimelineRow(segment: segments[i], trip: trip, last: i == segments.length - 1),
                ]),
              ),
              const SectionHeader('Trip summary card'),
              MilestoneCardView(card: MilestoneGenerator.forTrip(trip)),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () => _confirmDelete(context, ref, trip),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete this trip'),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Trip trip) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete trip?'),
        content: const Text('It will be removed from this device and your account backup.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref.read(tripsProvider.notifier).delete(trip);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _ModePicker extends ConsumerWidget {
  const _ModePicker({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modes = TransportMode.values.where((m) => m != TransportMode.unknown);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in modes)
          ChoiceChip(
            avatar: Icon(m.icon, size: 18, color: m == trip.mode ? AppColors.naturalWhite : m.color),
            label: Text(m.label),
            selected: m == trip.mode,
            showCheckmark: false,
            selectedColor: AppColors.forest,
            backgroundColor: AppColors.naturalWhite,
            side: const BorderSide(color: AppColors.line),
            labelStyle: TextStyle(color: m == trip.mode ? AppColors.naturalWhite : AppColors.ink),
            onSelected: (_) {
              HapticFeedback.selectionClick();
              ref.read(tripsProvider.notifier).correctMode(trip, m);
            },
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.segment, required this.trip, required this.last});
  final TripSegment segment;
  final Trip trip;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = segment.isStop ? AppColors.gold : trip.mode.color;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 28,
          child: Column(children: [
            Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            if (!last) Expanded(child: Container(width: 2, color: AppColors.line)),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                segment.isStop
                    ? 'Stopped · ${Fmt.duration(segment.duration)}'
                    : '${trip.mode.label} · ${Fmt.km(segment.distanceMeters / 1000)}',
                style: theme.textTheme.titleMedium,
              ),
              Text('${Fmt.time(segment.start)} – ${Fmt.time(segment.end)}', style: theme.textTheme.bodySmall),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _PlaceRow extends ConsumerWidget {
  const _PlaceRow({required this.label, required this.zone});
  final String label;
  final Zone zone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final namer = ref.watch(placeNamerProvider);
    return InkWell(
      onTap: () => showPlaceRenameDialog(context, ref, zone),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          SizedBox(width: 48, child: Text(label, style: theme.textTheme.bodySmall)),
          Expanded(child: Text(namer.name(zone), style: theme.textTheme.titleMedium)),
          const Icon(Icons.edit_outlined, size: 18, color: AppColors.inkMuted),
        ]),
      ),
    );
  }
}
