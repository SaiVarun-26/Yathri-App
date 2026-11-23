import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../trips/domain/zone.dart';
import '../providers/places_providers.dart';

const _quickNames = ['Home', 'College', 'Office', 'Shopping', 'Airport', 'Friends'];

/// Lets the user name a place. Naming a destination names every trip that
/// ends there, so "College" appears wherever that place does.
Future<void> showPlaceRenameDialog(BuildContext context, WidgetRef ref, Zone zone) async {
  final namer = ref.read(placeNamerProvider);
  final notifier = ref.read(placesProvider.notifier);
  final controller = TextEditingController(text: namer.hasUserLabel(zone) ? namer.name(zone) : '');
  final suggestion = namer.suggestion(zone);

  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Name this place'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(hintText: suggestion ?? 'For example, College'),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in _quickNames)
                ActionChip(
                  label: Text(n),
                  backgroundColor: AppColors.naturalWhite,
                  side: const BorderSide(color: AppColors.line),
                  onPressed: () => Navigator.pop(ctx, n),
                ),
            ],
          ),
        ],
      ),
      actions: [
        if (namer.hasUserLabel(zone)) TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Clear name')),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save')),
      ],
    ),
  );
  controller.dispose();
  if (result != null) await notifier.rename(zone, result);
}
