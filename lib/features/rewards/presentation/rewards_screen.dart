import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/soft_card.dart';
import '../../analytics/providers/analytics_providers.dart';
import '../domain/goals.dart';
import '../domain/rewards.dart';
import '../providers/goals_providers.dart';

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final r = ref.watch(rewardsProvider);
    final goals = ref.watch(goalProgressProvider);

    return SafeArea(
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('Rewards', style: theme.textTheme.displaySmall),
          ),
          const SizedBox(height: 20),
          _LevelCard(r: r),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _StreakTile(
                  icon: Icons.local_fire_department_rounded,
                  value: '${r.streakDays}',
                  label: 'Green streak, days'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StreakTile(
                  icon: Icons.emoji_events_outlined, value: '${r.longestStreakDays}', label: 'Best streak'),
            ),
          ]),
          const SectionHeader('Your goals'),
          for (final g in goals) ...[
            _GoalTile(goal: g, onTap: () => _editGoal(context, ref, g)),
            const SizedBox(height: 12),
          ],
          const SectionHeader('This month\'s challenges'),
          for (final c in r.challenges) ...[_ChallengeTile(challenge: c), const SizedBox(height: 12)],
          const SectionHeader('Achievements'),
          for (final b in r.badges) ...[_BadgeTile(badge: b), const SizedBox(height: 12)],
          const SectionHeader('Partner offers'),
          for (final o in r.offers) ...[
            _OfferTile(offer: o, unlocked: RewardsEngine.isUnlocked(o, r)),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Future<void> _editGoal(BuildContext context, WidgetRef ref, GoalProgress goal) async {
    final notifier = ref.read(goalsProvider.notifier);
    final current = ref.read(goalsValueProvider);
    final (label, initial) = switch (goal.kind) {
      GoalKind.walk => ('Kilometres to walk each week', current.walkKmPerWeek),
      GoalKind.cycle => ('Kilometres to cycle each week', current.cycleKmPerWeek),
      GoalKind.fuel => ('Fuel budget per month (₹, 0 for none)', current.fuelBudgetPerMonth),
      GoalKind.eco => ('Eco score to reach (1 to 100)', current.ecoScoreTarget.toDouble()),
    };
    final controller = TextEditingController(text: initial == 0 ? '' : initial.toStringAsFixed(initial % 1 == 0 ? 0 : 1));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change goal'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    final value = double.tryParse(controller.text.trim());
    controller.dispose();
    if (ok != true || value == null || value < 0) return;

    await notifier.save(switch (goal.kind) {
      GoalKind.walk => current.copyWith(walkKmPerWeek: value < 1 ? 1 : value),
      GoalKind.cycle => current.copyWith(cycleKmPerWeek: value < 1 ? 1 : value),
      GoalKind.fuel => current.copyWith(fuelBudgetPerMonth: value),
      GoalKind.eco => current.copyWith(ecoScoreTarget: value.round().clamp(1, 100)),
    });
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.r});
  final RewardsState r;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.forest, AppColors.forestDeep],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('LEVEL ${r.level}',
            style: const TextStyle(color: AppColors.gold, letterSpacing: 2, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(r.levelName, style: theme.textTheme.headlineMedium?.copyWith(color: AppColors.naturalWhite)),
        const SizedBox(height: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${r.xp}', style: theme.textTheme.displaySmall?.copyWith(color: AppColors.naturalWhite)),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('XP', style: TextStyle(color: AppColors.naturalWhite.withValues(alpha: 0.7))),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('${r.ecoPoints} eco points',
                style: TextStyle(color: AppColors.naturalWhite.withValues(alpha: 0.7))),
          ),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: r.levelFraction),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: Colors.white24,
              color: AppColors.gold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          r.xpForNextLevel == null
              ? 'Top level reached'
              : '${r.xpForNextLevel! - r.xpIntoLevel} XP to ${r.nextLevelName}',
          style: TextStyle(color: AppColors.naturalWhite.withValues(alpha: 0.75), fontSize: 12.5),
        ),
      ]),
    );
  }
}

class _StreakTile extends StatelessWidget {
  const _StreakTile({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Icon(icon, color: AppColors.terracotta, size: 28),
        const SizedBox(width: 12),
        Expanded(child: StatTile(value: value, label: label, accent: AppColors.terracotta)),
      ]),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal, required this.onTap});
  final GoalProgress goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = goal.warning ? AppColors.terracotta : (goal.achieved ? AppColors.gold : AppColors.forest);
    return SoftCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(goal.title, style: theme.textTheme.titleMedium)),
          if (goal.achieved && goal.isSet) const Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 20),
          if (!goal.achieved || !goal.isSet) const Icon(Icons.edit_outlined, size: 18, color: AppColors.inkMuted),
        ]),
        const SizedBox(height: 4),
        Text(goal.detail, style: theme.textTheme.bodySmall),
        if (goal.isSet) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: goal.fraction),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: AppColors.line,
                color: color,
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  const _ChallengeTile({required this.challenge});
  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = challenge;
    return SoftCard(
      color: c.done ? AppColors.goldSoft : null,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(c.title, style: theme.textTheme.titleMedium)),
          Pill(c.done ? 'Done' : '+${c.rewardXp} XP',
              color: c.done ? AppColors.gold : AppColors.forest,
              background: c.done ? AppColors.naturalWhite : AppColors.forestSoft),
        ]),
        const SizedBox(height: 2),
        Text(c.description, style: theme.textTheme.bodySmall),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: c.fraction,
            minHeight: 6,
            backgroundColor: AppColors.line,
            color: c.done ? AppColors.gold : AppColors.forest,
          ),
        ),
        const SizedBox(height: 6),
        Text('${c.progress.toStringAsFixed(c.unit == 'days' ? 0 : 1)} of ${c.target.toStringAsFixed(0)} ${c.unit}',
            style: theme.textTheme.bodySmall),
      ]),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});
  final RewardBadge badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: badge.earned ? AppColors.goldSoft : AppColors.ivory,
            border: Border.all(color: badge.earned ? AppColors.gold : AppColors.line, width: 2),
          ),
          child: Icon(
            badge.earned ? Icons.workspace_premium_rounded : Icons.lock_outline_rounded,
            color: badge.earned ? AppColors.gold : AppColors.inkMuted,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(badge.name, style: theme.textTheme.titleMedium),
            Text(badge.description, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: badge.fraction,
                minHeight: 5,
                backgroundColor: AppColors.line,
                color: badge.earned ? AppColors.gold : AppColors.forest,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({required this.offer, required this.unlocked});
  final PartnerOffer offer;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: unlocked ? 1 : 0.55,
      child: SoftCard(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(unlocked ? Icons.local_offer_rounded : Icons.lock_outline_rounded,
              color: unlocked ? AppColors.terracotta : AppColors.inkMuted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(offer.title, style: theme.textTheme.titleMedium),
              Text(offer.partner, style: theme.textTheme.bodySmall),
            ]),
          ),
          Pill(unlocked ? 'Unlocked' : 'Level ${offer.requiredLevel}',
              color: unlocked ? AppColors.forest : AppColors.inkMuted,
              background: unlocked ? AppColors.forestSoft : AppColors.ivory),
        ]),
      ),
    );
  }
}
