import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/transport_mode.dart';

extension TransportModeVisuals on TransportMode {
  IconData get icon => switch (this) {
        TransportMode.walking => Icons.directions_walk_rounded,
        TransportMode.running => Icons.directions_run_rounded,
        TransportMode.cycling => Icons.directions_bike_rounded,
        TransportMode.bike => Icons.two_wheeler_rounded,
        TransportMode.car => Icons.directions_car_rounded,
        TransportMode.bus => Icons.directions_bus_rounded,
        TransportMode.metro => Icons.subway_rounded,
        TransportMode.train => Icons.train_rounded,
        TransportMode.auto => Icons.electric_rickshaw_rounded,
        TransportMode.taxi => Icons.local_taxi_rounded,
        TransportMode.unknown => Icons.route_rounded,
      };

  Color get color => switch (this) {
        TransportMode.walking || TransportMode.running || TransportMode.cycling => AppColors.forest,
        TransportMode.bus || TransportMode.metro || TransportMode.train => const Color(0xFF6E8B3D),
        TransportMode.bike || TransportMode.auto => AppColors.gold,
        TransportMode.car || TransportMode.taxi => AppColors.terracotta,
        TransportMode.unknown => AppColors.inkMuted,
      };
}

class ModeBadge extends StatelessWidget {
  const ModeBadge(this.mode, {super.key, this.size = 44});
  final TransportMode mode;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: mode.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(mode.icon, color: mode.color, size: size * 0.52),
    );
  }
}
