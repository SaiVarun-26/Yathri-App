import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../analytics/providers/analytics_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../milestones/presentation/milestone_card_view.dart';
import '../../places/providers/places_providers.dart';
import '../../trips/presentation/mode_visuals.dart';
import '../../trips/providers/trip_providers.dart';
import '../domain/travel_report.dart';

/// Month and year summaries in the style of a "Wrapped" card, shareable as a
/// picture. Everything is built on the phone from the user's own trips.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _cardKey = GlobalKey();
  bool _yearly = false;
  int _selected = 0;
  bool _sharing = false;

  Future<void> _share(TravelReport report) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/yathri-report.png');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: report.shareText));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not create the picture. Please try again.')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trips = ref.watch(tripListProvider);
    final profile = ref.watch(fuelProfileValueProvider);
    final namer = ref.watch(placeNamerProvider);
    final weekly = ref.watch(weeklyMilestoneProvider);

    final months = TravelReportBuilder.months(trips);
    final years = TravelReportBuilder.years(trips);
    final periods = _yearly ? years.length : months.length;
    final index = _selected.clamp(0, periods == 0 ? 0 : periods - 1);

    TravelReport? report;
    if (periods > 0) {
      report = _yearly
          ? TravelReportBuilder.year(trips, years[index], profile, namer)
          : TravelReportBuilder.month(trips, months[index], profile, namer);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          if (report == null)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: EmptyState(
                icon: Icons.auto_stories_rounded,
                title: 'No reports yet',
                message: 'Your first monthly report appears after your first trip.',
              ),
            )
          else ...[
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Month')),
                ButtonSegment(value: true, label: Text('Year')),
              ],
              selected: {_yearly},
              onSelectionChanged: (s) => setState(() {
                _yearly = s.first;
                _selected = 0;
              }),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: periods,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ChoiceChip(
                  label: Text(_yearly ? '${years[i]}' : DateFormat('MMM y').format(months[i])),
                  selected: i == index,
                  showCheckmark: false,
                  selectedColor: AppColors.forest,
                  backgroundColor: AppColors.naturalWhite,
                  side: const BorderSide(color: AppColors.line),
                  labelStyle: TextStyle(color: i == index ? AppColors.naturalWhite : AppColors.ink),
                  onSelected: (_) => setState(() => _selected = i),
                ),
              ),
            ),
            const SizedBox(height: 16),
            RepaintBoundary(key: _cardKey, child: _ReportCard(report: report)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _sharing ? null : () => _share(report!),
              icon: _sharing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.ios_share_rounded),
              label: const Text('Share as picture'),
            ),
          ],
          if (weekly != null) ...[
            const SectionHeader('This week'),
            MilestoneCardView(card: weekly),
          ],
          const SizedBox(height: 8),
          Text(
            'Reports are made on your phone. Only the picture you choose to share leaves it.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});
  final TravelReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const onDark = AppColors.naturalWhite;
    final mode = report.topMode;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest, AppColors.forestDeep],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(report.period,
                style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          if (mode != null) Icon(mode.icon, color: AppColors.gold),
        ]),
        const SizedBox(height: 18),
        Text(report.title, style: theme.textTheme.headlineMedium?.copyWith(color: onDark)),
        const SizedBox(height: 20),
        if (report.isEmpty)
          Text('No trips in this period.', style: theme.textTheme.bodyLarge?.copyWith(color: onDark))
        else
          for (final line in report.highlights)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 7, color: AppColors.gold),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(line, style: theme.textTheme.titleMedium?.copyWith(color: onDark, fontSize: 18))),
              ]),
            ),
        const SizedBox(height: 6),
        Text('YATHRI',
            style: TextStyle(color: onDark.withValues(alpha: 0.5), letterSpacing: 3, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
