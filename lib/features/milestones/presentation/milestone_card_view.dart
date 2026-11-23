import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../trips/presentation/mode_visuals.dart';
import '../domain/milestone_card.dart';

class MilestoneCardView extends StatelessWidget {
  const MilestoneCardView({super.key, required this.card, this.width});
  final MilestoneCard card;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const onDark = AppColors.naturalWhite;
    final mode = card.mode;

    Widget metric(String value, String label) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: theme.textTheme.titleLarge?.copyWith(color: onDark, fontSize: 19)),
            const SizedBox(height: 2),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: onDark.withValues(alpha: 0.7))),
          ]),
        );

    return Container(
      width: width,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest, AppColors.forestDeep],
        ),
        boxShadow: const [BoxShadow(color: Color(0x33402C14), blurRadius: 24, offset: Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(card.period,
                  style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            if (mode != null) Icon(mode.icon, color: AppColors.gold),
          ]),
          const SizedBox(height: 18),
          Text(card.title,
              style: theme.textTheme.headlineMedium?.copyWith(color: onDark, fontSize: 24)),
          const SizedBox(height: 20),
          Row(children: [
            metric(Fmt.km(card.distanceKm), 'Distance'),
            metric(Fmt.duration(card.duration), 'Travel time'),
            metric(mode?.label ?? '—', 'Mode'),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            metric(Fmt.rupees(card.moneySavedInr), 'Money saved'),
            metric('${card.ecoPoints}', 'Eco points'),
            const Expanded(child: SizedBox.shrink()),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            Text('YATHRI',
                style: TextStyle(
                    color: onDark.withValues(alpha: 0.5), letterSpacing: 3, fontWeight: FontWeight.w800)),
            const Spacer(),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.gold),
              onPressed: () => SharePlus.instance.share(ShareParams(text: card.shareText)),
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('Share'),
            ),
          ]),
        ],
      ),
    );
  }
}
