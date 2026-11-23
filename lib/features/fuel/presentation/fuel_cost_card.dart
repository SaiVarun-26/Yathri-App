import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/soft_card.dart';
import '../../analytics/providers/analytics_providers.dart';
import '../domain/fuel_profile.dart';
import '../providers/fuel_providers.dart';
import 'fuel_setup_dialog.dart';

/// Fuel cost for every period, and exactly how the number is worked out.
class FuelCostCard extends ConsumerWidget {
  const FuelCostCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fuel = ref.watch(fuelSummaryProvider);
    final profile = ref.watch(fuelProfileValueProvider);

    if (profile.vehicleType == VehicleType.none) {
      return SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('No fuel cost', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('You said you have no vehicle, so only bus, auto and taxi fares are counted.',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          TextButton(onPressed: () => showFuelSetupDialog(context, ref), child: const Text('Add a vehicle')),
        ]),
      );
    }

    Widget cell(String label, FuelPeriod p) => Expanded(
          child: StatTile(value: Fmt.rupees(p.costInr), label: label, accent: AppColors.terracotta),
        );

    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [cell('Today', fuel.today), cell('This week', fuel.week), cell('This month', fuel.month)]),
        const SizedBox(height: 18),
        Row(children: [
          cell('This year', fuel.year),
          cell('Since you started', fuel.allTime),
          Expanded(
            child: StatTile(value: '${fuel.month.litres.toStringAsFixed(1)} L', label: 'Fuel used this month'),
          ),
        ]),
        if (fuel.monthTrend != null) ...[
          const SizedBox(height: 14),
          Text(_trendText(fuel.monthTrend!), style: theme.textTheme.bodyMedium),
        ],
        if (fuel.monthFaresInr >= 1) ...[
          const SizedBox(height: 14),
          Text('Plus about ${Fmt.rupees(fuel.monthFaresInr)} in bus, auto and taxi fares this month.',
              style: theme.textTheme.bodySmall),
        ],
        const Divider(height: 28),
        _HowItWorks(profile: profile, fuel: fuel),
      ]),
    );
  }
}

String _trendText(double trend) {
  final pct = (trend.abs() * 100).round();
  if (pct < 5) return 'About the same as the same days last month.';
  return trend > 0
      ? 'You have spent $pct% more on fuel than the same days last month.'
      : 'You have spent $pct% less on fuel than the same days last month.';
}

class _HowItWorks extends ConsumerWidget {
  const _HowItWorks({required this.profile, required this.fuel});
  final FuelProfile profile;
  final FuelSummary fuel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    String km(double v) => v.toStringAsFixed(v < 10 ? 1 : 0);
    final vehicles = [
      if (profile.vehicleType.hasBike) 'bike ${_n(profile.bikeKmpl)} km/L',
      if (profile.vehicleType.hasCar) 'car ${_n(profile.carKmpl)} km/L',
    ].join(', ');

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text('How is this worked out?', style: theme.textTheme.titleMedium),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Fuel used = distance ÷ mileage', style: theme.textTheme.bodyMedium),
              Text('Fuel cost = fuel used × petrol price', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 10),
              Text(
                'Your figures: $vehicles, petrol ₹${_n(profile.pricePerLitre)} a litre'
                '${profile.configured ? '' : ' (typical values, until you enter yours)'}.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Text(
                fuel.month.km > 0
                    ? 'This month: ${km(fuel.month.km)} km ÷ mileage = ${fuel.month.litres.toStringAsFixed(1)} L, '
                        '× ₹${_n(profile.pricePerLitre)} = ${Fmt.rupees(fuel.month.costInr)}.'
                    : 'Once you travel by car or bike, a worked example for your month appears here.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Only car and bike trips use fuel. The same price is used for all past trips, so changing it updates every total.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => showFuelSetupDialog(context, ref),
                child: const Text('Change vehicle or price'),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  static String _n(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}
