import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/soft_card.dart';
import '../../trips/domain/transport_mode.dart';
import '../../trips/presentation/mode_visuals.dart';
import '../domain/mobility_analytics.dart';
import '../providers/admin_providers.dart';

/// Government mobility portal. Shipped as a separate entry point
/// (`lib/admin_main.dart`) so none of this code is in the citizen app.
class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  int _index = 0;

  static const _titles = ['Overview', 'Heatmap', 'Origin–Destination', 'Tourism & Transit', 'Recommendations'];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.layers_outlined,
    Icons.compare_arrows_rounded,
    Icons.landscape_outlined,
    Icons.lightbulb_outline_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(mobilitySummaryProvider);
    final demo = ref.watch(adminDemoModeProvider);
    final wide = MediaQuery.sizeOf(context).width >= 860;

    final body = summary.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Could not load data',
          message: 'Check that this account has admin access.\n$e',
        ),
      ),
      data: (s) => s.totalTrips == 0
          ? const Center(
              child: EmptyState(
                icon: Icons.inbox_outlined,
                title: 'No summaries yet',
                message: 'Data appears once citizens opt in and complete trips.',
              ),
            )
          : _page(s),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Yathri · ${_titles[_index]}'),
        actions: [
          if (demo)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: Pill('Demo data', color: AppColors.terracotta, background: AppColors.terracottaSoft)),
            ),
        ],
      ),
      body: wide
          ? Row(children: [
              NavigationRail(
                backgroundColor: AppColors.naturalWhite,
                selectedIndex: _index,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: (i) => setState(() => _index = i),
                destinations: [
                  for (var i = 0; i < _titles.length; i++)
                    NavigationRailDestination(icon: Icon(_icons[i]), label: Text(_titles[i])),
                ],
              ),
              Expanded(child: body),
            ])
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (var i = 0; i < _titles.length; i++)
                  NavigationDestination(icon: Icon(_icons[i]), label: _titles[i].split(' ').first),
              ],
            ),
    );
  }

  Widget _page(MobilitySummary s) => switch (_index) {
        0 => _Overview(summary: s),
        1 => _Heatmap(summary: s),
        2 => _OdMatrix(summary: s),
        3 => _TourismTransit(summary: s),
        _ => _Recommendations(summary: s),
      };
}

class _Overview extends StatelessWidget {
  const _Overview({required this.summary});
  final MobilitySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHour = summary.hourly.fold<int>(0, (a, b) => b > a ? b : a);
    String hourLabel(int h) => '${h % 12 == 0 ? 12 : h % 12}${h < 12 ? 'a' : 'p'}';

    return ListView(padding: const EdgeInsets.all(20), children: [
      Wrap(spacing: 16, runSpacing: 16, children: [
        _Kpi('Trips analysed', '${summary.totalTrips}'),
        _Kpi('Public transport share', '${(summary.publicTransportShare * 100).round()}%'),
        _Kpi('Peak hours', summary.peakHours.map(hourLabel).join(', ')),
        _Kpi('Suppressed cells (k<5)', '${summary.suppressedCells}'),
      ]),
      const SectionHeader('Peak hour analytics'),
      SoftCard(
        child: SizedBox(
          height: 180,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var h = 0; h < 24; h++)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Container(
                    height: maxHour == 0 ? 2 : 2 + 130 * summary.hourly[h] / maxHour,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: summary.peakHours.contains(h) ? AppColors.terracotta : AppColors.forest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (h % 3 == 0) Text(hourLabel(h), style: theme.textTheme.bodySmall) else const SizedBox(height: 16),
                ]),
              ),
          ]),
        ),
      ),
      const SectionHeader('Mode share'),
      SoftCard(
        child: Column(children: [
          for (final e in (summary.modeShare.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Icon(e.key.icon, color: e.key.color, size: 20),
                const SizedBox(width: 10),
                SizedBox(width: 80, child: Text(e.key.label)),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                        value: e.value, minHeight: 8, backgroundColor: AppColors.line, color: e.key.color),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(width: 44, child: Text('${(e.value * 100).round()}%', textAlign: TextAlign.end)),
              ]),
            ),
        ]),
      ),
      const SectionHeader('Travel trend (trips per day)'),
      SoftCard(child: _TrendChart(days: summary.dailyTrips)),
    ]);
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: SoftCard(child: StatTile(value: value, label: label)),
      );
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.days});
  final List<MapEntry<DateTime, int>> days;

  @override
  Widget build(BuildContext context) {
    final max = days.fold<int>(0, (a, e) => e.value > a ? e.value : a);
    return SizedBox(
      height: 120,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final e in days)
          Expanded(
            child: Tooltip(
              message: '${e.key.day}/${e.key.month}: ${e.value}',
              child: Container(
                height: max == 0 ? 2 : 2 + 110 * e.value / max,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ),
      ]),
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.summary});
  final MobilitySummary summary;

  @override
  Widget build(BuildContext context) {
    final cells = summary.heat;
    if (cells.isEmpty) {
      return const Center(child: EmptyState(icon: Icons.layers_clear_outlined, title: 'Nothing to map', message: 'No zone has enough trips to display.'));
    }
    final max = cells.first.weight;
    // Zone cells are drawn as translucent squares: darker = more traffic.
    final polygons = [
      for (final c in cells)
        Polygon(
          points: [
            LatLng(c.zone.latIndex * 0.01, c.zone.lngIndex * 0.01),
            LatLng((c.zone.latIndex + 1) * 0.01, c.zone.lngIndex * 0.01),
            LatLng((c.zone.latIndex + 1) * 0.01, (c.zone.lngIndex + 1) * 0.01),
            LatLng(c.zone.latIndex * 0.01, (c.zone.lngIndex + 1) * 0.01),
          ],
          color: Color.lerp(AppColors.gold, AppColors.danger, c.weight / max)!
              .withValues(alpha: 0.25 + 0.5 * c.weight / max),
          borderStrokeWidth: 0,
        ),
    ];
    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(cells.first.zone.centerLat, cells.first.zone.centerLng),
        initialZoom: 11.5,
      ),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'in.yathri.admin'),
        PolygonLayer(polygons: polygons),
      ],
    );
  }
}

class _OdMatrix extends StatelessWidget {
  const _OdMatrix({required this.summary});
  final MobilitySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('Top origin–destination pairs. Pairs with fewer than 5 trips are hidden to protect privacy.',
          style: theme.textTheme.bodySmall),
      const SizedBox(height: 12),
      SoftCard(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Origin')),
              DataColumn(label: Text('Destination')),
              DataColumn(label: Text('Trips'), numeric: true),
              DataColumn(label: Text('Main mode')),
              DataColumn(label: Text('Avg km'), numeric: true),
            ],
            rows: [
              for (final p in summary.topOd)
                DataRow(cells: [
                  DataCell(Text('${p.origin}')),
                  DataCell(Text('${p.destination}')),
                  DataCell(Text('${p.trips}')),
                  DataCell(Row(children: [Icon(p.dominantMode.icon, size: 18, color: p.dominantMode.color), const SizedBox(width: 6), Text(p.dominantMode.label)])),
                  DataCell(Text(p.avgKm.toStringAsFixed(1))),
                ]),
            ],
          ),
        ),
      ),
    ]);
  }
}

class _TourismTransit extends StatelessWidget {
  const _TourismTransit({required this.summary});
  final MobilitySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transit = [TransportMode.bus, TransportMode.metro, TransportMode.train];
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('Public transport usage', style: theme.textTheme.titleLarge),
      const SizedBox(height: 12),
      Row(children: [
        for (final m in transit)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SoftCard(child: StatTile(value: '${((summary.modeShare[m] ?? 0) * 100).round()}%', label: m.label)),
            ),
          ),
      ]),
      const SectionHeader('Tourist flow'),
      Text('Long weekend journeys (30 km+) by destination zone.', style: theme.textTheme.bodySmall),
      const SizedBox(height: 12),
      if (summary.tourismByDestination.isEmpty)
        const SoftCard(child: Text('No destination has enough long weekend trips yet.'))
      else
        SoftCard(
          child: Column(children: [
            for (final c in summary.tourismByDestination)
              ListTile(
                dense: true,
                leading: const Icon(Icons.landscape_rounded, color: AppColors.forest),
                title: Text('Zone ${c.zone}'),
                trailing: Text('${c.weight} trips'),
              ),
          ]),
        ),
    ]);
  }
}

class _Recommendations extends StatelessWidget {
  const _Recommendations({required this.summary});
  final MobilitySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (summary.recommendations.isEmpty) {
      return const Center(child: EmptyState(icon: Icons.check_circle_outline, title: 'No recommendations yet', message: 'More data is needed to make a reliable suggestion.'));
    }
    return ListView(padding: const EdgeInsets.all(20), children: [
      for (final r in summary.recommendations) ...[
        SoftCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(_icon(r.kind), color: AppColors.terracotta),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(r.title, style: theme.textTheme.titleMedium)),
                  Pill(r.priority.name.toUpperCase(),
                      color: r.priority == Priority.high ? AppColors.danger : AppColors.forest,
                      background: r.priority == Priority.high ? AppColors.terracottaSoft : AppColors.forestSoft),
                ]),
                const SizedBox(height: 4),
                Text(r.rationale, style: theme.textTheme.bodySmall),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
      ],
    ]);
  }

  IconData _icon(RecommendationKind k) => switch (k) {
        RecommendationKind.busFrequency => Icons.directions_bus_rounded,
        RecommendationKind.newBusStop => Icons.add_location_alt_rounded,
        RecommendationKind.roadExpansion => Icons.add_road_rounded,
        RecommendationKind.tourismFacility => Icons.landscape_rounded,
        RecommendationKind.parking => Icons.local_parking_rounded,
      };
}
