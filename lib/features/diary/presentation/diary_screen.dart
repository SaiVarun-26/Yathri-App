import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../analytics/domain/period_stats.dart';
import '../../analytics/providers/analytics_providers.dart';
import '../../fuel/domain/fuel_profile.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../trips/domain/trip.dart';
import '../../trips/presentation/widgets/trip_card.dart';
import '../../trips/providers/trip_providers.dart';
import '../domain/diary_filter.dart';
import '../providers/diary_providers.dart';

/// Every trip ever recorded, newest first, with quick date filters.
class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final everything = ref.watch(tripListProvider);
    final filter = ref.watch(diaryFilterProvider);
    final trips = ref.watch(diaryTripsProvider);
    final now = ref.watch(nowProvider);
    final profile = ref.watch(fuelProfileValueProvider);

    final items = _flatten(trips, now);

    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Text('Travel diary', style: theme.textTheme.displaySmall),
            ),
          ),
          if (everything.isNotEmpty) ...[
            SliverToBoxAdapter(child: _FilterBar(filter: filter, everything: everything)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                child: Text(_summaryLine(trips, profile), style: theme.textTheme.bodySmall),
              ),
            ),
          ],
          if (trips.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: EmptyState(
                  icon: Icons.menu_book_rounded,
                  title: everything.isEmpty ? 'Your diary is empty' : 'Nothing here',
                  message: filter.emptyMessage,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverList.builder(
                itemCount: items.length,
                itemBuilder: (context, i) => switch (items[i]) {
                  _MonthHeader(:final month) => Padding(
                      padding: const EdgeInsets.fromLTRB(4, 24, 4, 0),
                      child: Text(DateFormat('MMMM y').format(month),
                          style: theme.textTheme.titleLarge?.copyWith(color: AppColors.forest)),
                    ),
                  _DayHeader(:final day, :final count, :final km) => SectionHeader(
                      Fmt.dayHeading(day, now),
                      trailing: Text('$count ${count == 1 ? 'trip' : 'trips'} · ${Fmt.km(km)}',
                          style: theme.textTheme.bodySmall),
                    ),
                  _TripItem(:final trip) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TripCard(trip: trip),
                    ),
                },
              ),
            ),
        ],
      ),
    );
  }

  static String _summaryLine(List<Trip> trips, FuelProfile profile) {
    if (trips.isEmpty) return '';
    final km = trips.fold(0.0, (a, t) => a + t.distanceKm);
    final fuel = FuelCalculator.totalFuel(trips, profile);
    final parts = [
      '${trips.length} ${trips.length == 1 ? 'trip' : 'trips'}',
      Fmt.km(km),
      if (profile.vehicleType != VehicleType.none && fuel >= 1) '${Fmt.rupees(fuel)} fuel',
    ];
    return parts.join(' · ');
  }

  /// Month headings, day headings and trips in one list, so a long history
  /// scrolls smoothly without nesting lists.
  static List<_Item> _flatten(List<Trip> trips, DateTime now) {
    final out = <_Item>[];
    DateTime? month;
    DateTime? day;
    final byDay = <DateTime, List<Trip>>{};
    for (final t in trips) {
      byDay.putIfAbsent(DateRanges.startOfDay(t.startTime), () => []).add(t);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final spansMonths = {for (final d in days) DateTime(d.year, d.month)}.length > 1;
    for (final d in days) {
      final m = DateTime(d.year, d.month);
      if (spansMonths && m != month) {
        out.add(_MonthHeader(m));
        month = m;
      }
      if (d != day) {
        final list = byDay[d]!;
        out.add(_DayHeader(d, list.length, list.fold(0.0, (a, t) => a + t.distanceKm)));
        day = d;
      }
      out.addAll(byDay[d]!.map(_TripItem.new));
    }
    return out;
  }
}

sealed class _Item {
  const _Item();
}

class _MonthHeader extends _Item {
  const _MonthHeader(this.month);
  final DateTime month;
}

class _DayHeader extends _Item {
  const _DayHeader(this.day, this.count, this.km);
  final DateTime day;
  final int count;
  final double km;
}

class _TripItem extends _Item {
  const _TripItem(this.trip);
  final Trip trip;
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.filter, required this.everything});
  final DiaryFilter filter;
  final List<Trip> everything;

  Future<void> _pickDates(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(diaryFilterProvider.notifier);
    final now = DateTime.now();
    final earliest = everything.map((t) => t.startTime).reduce((a, b) => a.isBefore(b) ? a : b);
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(earliest.year, earliest.month, earliest.day),
      lastDate: now,
      initialDateRange: filter.customFrom != null && filter.customTo != null
          ? DateTimeRange(start: filter.customFrom!, end: filter.customTo!)
          : null,
      helpText: 'Choose a day, or a start and end day',
    );
    if (range != null) notifier.selectDates(range.start, range.end);
  }

  String _label(DiaryFilterKind kind) {
    if (kind == DiaryFilterKind.custom && filter.kind == DiaryFilterKind.custom && filter.customFrom != null) {
      final f = DateFormat('d MMM');
      final from = filter.customFrom!;
      final to = filter.customTo!;
      return DateRanges.startOfDay(from) == DateRanges.startOfDay(to) ? f.format(from) : '${f.format(from)} – ${f.format(to)}';
    }
    return kind.label;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: DiaryFilterKind.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final kind = DiaryFilterKind.values[i];
          final selected = filter.kind == kind;
          return ChoiceChip(
            avatar: kind == DiaryFilterKind.custom
                ? Icon(Icons.calendar_month_rounded, size: 18, color: selected ? AppColors.naturalWhite : AppColors.forest)
                : null,
            label: Text(_label(kind)),
            selected: selected,
            showCheckmark: false,
            selectedColor: AppColors.forest,
            backgroundColor: AppColors.naturalWhite,
            side: const BorderSide(color: AppColors.line),
            labelStyle: TextStyle(color: selected ? AppColors.naturalWhite : AppColors.ink),
            onSelected: (_) => kind == DiaryFilterKind.custom
                ? _pickDates(context, ref)
                : ref.read(diaryFilterProvider.notifier).select(kind),
          );
        },
      ),
    );
  }
}
