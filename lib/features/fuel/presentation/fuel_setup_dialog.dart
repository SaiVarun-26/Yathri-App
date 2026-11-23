import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/fuel_providers.dart';
import 'vehicle_form.dart';

/// Edit vehicle type, mileage, fuel price and service interval. These make
/// fuel cost and the service reminder match the user's own vehicle.
Future<void> showFuelSetupDialog(BuildContext context, WidgetRef ref) async {
  final notifier = ref.read(fuelProfileProvider.notifier);
  var edited = ref.read(fuelProfileValueProvider);

  final save = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Your vehicle'),
      content: SingleChildScrollView(
        child: VehicleForm(
          initial: edited,
          showService: true,
          onChanged: (p) => edited = p,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
    ),
  );

  if (save == true) await notifier.save(edited);
}
