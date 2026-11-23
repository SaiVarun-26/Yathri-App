import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/soft_card.dart';
import '../../../fuel/domain/fuel_profile.dart';
import '../../../fuel/providers/fuel_providers.dart';
import '../../../places/providers/places_providers.dart';
import '../../domain/trip.dart';
import '../mode_visuals.dart';
import '../trip_detail_screen.dart';
import 'route_preview.dart';

/// One diary entry: where from, where to, how, how long, what it cost, and
/// the shape of the route.
class TripCard extends ConsumerWidget {
  const TripCard({super.key, required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final namer = ref.watch(placeNamerProvider);
    final profile = ref.watch(fuelProfileValueProvider);
    final cost = FuelCalculator.tripCost(trip, profile);
    final from = namer.name(trip.originZone);
    final to = namer.name(trip.destinationZone);
    final title = trip.originZone == trip.destinationZone ? 'Around $to' : '$from → $to';

    return SoftCard(
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => TripDetailScreen(tripId: trip.id)),
      ),
      child: Row(
        children: [
          Hero(tag: 'mode-${trip.id}', child: ModeBadge(trip.mode, size: 48)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text('${trip.modeText} · ${Fmt.km(trip.distanceKm)} · ${Fmt.duration(trip.duration)}',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                Text('${Fmt.time(trip.startTime)} – ${Fmt.time(trip.endTime)}', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(cost < 1 ? 'Free' : Fmt.rupees(cost),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cost < 1 ? AppColors.forest : AppColors.ink,
                  )),
              if (cost >= 1) Text(trip.mode.usesOwnFuel ? 'fuel' : 'fare', style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              RoutePreview(route: trip.route, color: trip.mode.color),
            ],
          ),
        ],
      ),
    );
  }
}
