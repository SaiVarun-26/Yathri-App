import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/soft_card.dart';
import '../../providers/tracking_providers.dart';
import '../../services/tracking_service.dart';
import '../../services/trip_detection_engine.dart';

/// Shows what Yathri is doing right now: Waiting, Detecting or Travelling.
class StatusCard extends ConsumerWidget {
  const StatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(trackingProvider);
    final enabled = tracking.serviceRunning;

    final String key;
    final Widget body;
    if (!enabled) {
      key = 'off';
      body = _Off(tracking: tracking);
    } else if (!tracking.gpsEnabled) {
      key = 'gps-off';
      body = const _Phase(
          icon: Icons.location_disabled_rounded,
          label: 'Paused',
          title: 'Location is off',
          message: 'Turn location back on and detection resumes by itself.',
          pulsing: false);
    } else {
      key = tracking.phase.name;
      body = switch (tracking.phase) {
        TrackingPhase.waiting => const _Phase(
            icon: Icons.hourglass_empty_rounded,
            label: 'Waiting',
            title: 'All set',
            message: 'We will notice when you start moving. Nothing to press.',
            pulsing: false),
        TrackingPhase.detecting => const _Phase(
            icon: Icons.sensors_rounded,
            label: 'Detecting',
            title: 'Movement noticed',
            message: 'Checking whether this is a trip…',
            pulsing: true),
        TrackingPhase.travelling => _Travelling(tracking: tracking),
      };
    }

    final dark = enabled && tracking.phase == TrackingPhase.travelling;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [AppColors.forest, AppColors.forestDeep]
              : const [AppColors.naturalWhite, AppColors.naturalWhite],
        ),
        boxShadow: const [BoxShadow(color: Color(0x1A402C14), blurRadius: 28, offset: Offset(0, 10))],
      ),
      child: SoftCard(
        color: Colors.transparent,
        padding: const EdgeInsets.all(20),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(key), child: body),
        ),
      ),
    );
  }
}

class _Phase extends StatelessWidget {
  const _Phase({
    required this.icon,
    required this.label,
    required this.title,
    required this.message,
    required this.pulsing,
  });

  final IconData icon;
  final String label;
  final String title;
  final String message;
  final bool pulsing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _PulseIcon(icon: icon, pulsing: pulsing, color: AppColors.forest),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(message, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _Travelling extends StatefulWidget {
  const _Travelling({required this.tracking});
  final TrackingState tracking;

  @override
  State<_Travelling> createState() => _TravellingState();
}

class _TravellingState extends State<_Travelling> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact(); // a trip just started
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tracking;
    final elapsed = t.tripStart == null ? Duration.zero : DateTime.now().difference(t.tripStart!);
    const onDark = AppColors.naturalWhite;
    final theme = Theme.of(context);
    Widget stat(String v, String l) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v, style: theme.textTheme.titleLarge?.copyWith(color: onDark)),
            Text(l, style: theme.textTheme.bodySmall?.copyWith(color: onDark.withValues(alpha: 0.7))),
          ]),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const _PulseIcon(icon: Icons.navigation_rounded, pulsing: true, color: onDark),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TRAVELLING',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: onDark.withValues(alpha: 0.75), letterSpacing: 1.2, fontWeight: FontWeight.w700)),
              Text('Recording your trip', style: theme.textTheme.titleLarge?.copyWith(color: onDark)),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          stat(Fmt.km(t.liveDistanceM / 1000), 'Distance'),
          stat(Fmt.duration(elapsed), 'Time'),
          stat('${t.liveSpeedKmh.round()} km/h', 'Speed'),
        ]),
      ],
    );
  }
}

class _Off extends ConsumerWidget {
  const _Off({required this.tracking});
  final TrackingState tracking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final perm = tracking.permission;
    final message = switch (perm) {
      TrackingPermissionResult.deniedForever =>
        'Location permission is blocked. Open app settings to allow it.',
      TrackingPermissionResult.denied => 'Yathri needs location access to notice your trips.',
      TrackingPermissionResult.locationServicesOff => 'Turn on location services to start detecting trips.',
      _ => 'Turn on detection and your trips will appear here by themselves.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const _PulseIcon(icon: Icons.location_off_rounded, pulsing: false, color: AppColors.terracotta),
          const SizedBox(width: 16),
          Expanded(child: Text('Trip detection is off', style: theme.textTheme.titleLarge)),
        ]),
        const SizedBox(height: 10),
        Text(message, style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () async {
              HapticFeedback.selectionClick();
              // This card is replaced once tracking starts; resolve before awaiting.
              final notifier = ref.read(trackingProvider.notifier);
              final service = ref.read(trackingServiceProvider);
              final result = await notifier.enable();
              if (result == TrackingPermissionResult.deniedForever) {
                await service.openLocationSettings();
              }
            },
            child: Text(perm == TrackingPermissionResult.deniedForever ? 'Open settings' : 'Turn on detection'),
          ),
        ),
      ],
    );
  }
}

class _PulseIcon extends StatefulWidget {
  const _PulseIcon({required this.icon, required this.pulsing, required this.color});
  final IconData icon;
  final bool pulsing;
  final Color color;

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Stack(
          alignment: Alignment.center,
          children: [
            if (widget.pulsing)
              Container(
                width: 56 * (0.7 + 0.3 * _c.value),
                height: 56 * (0.7 + 0.3 * _c.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.25 * (1 - _c.value)),
                ),
              ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: 0.16)),
              child: Icon(widget.icon, color: widget.color, size: 24),
            ),
          ],
        ),
      ),
    );
  }
}
