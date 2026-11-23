import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';

/// OpenStreetMap-backed map with disk-cached tiles (flutter_map's built-in
/// caching provider), a route polyline and an optional live marker.
class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    this.route = const [],
    this.live,
    this.followLive = false,
    this.interactive = true,
    this.fallbackCenter = const LatLng(10.0159, 76.3419), // Kochi
  });

  final List<LatLng> route;
  final LatLng? live;
  final bool followLive;
  final bool interactive;
  final LatLng fallbackCenter;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> with SingleTickerProviderStateMixin {
  final _controller = MapController();
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  bool _ready = false;

  @override
  void dispose() {
    _anim.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RouteMap old) {
    super.didUpdateWidget(old);
    final live = widget.live;
    if (widget.followLive && live != null && live != old.live && _ready) _glideTo(live);
  }

  /// Smooth camera glide instead of a hard jump.
  void _glideTo(LatLng target) {
    final from = _controller.camera.center;
    final zoom = _controller.camera.zoom;
    final curve = CurvedAnimation(parent: _anim, curve: Curves.easeInOutCubic);
    final previous = _tick;
    if (previous != null) _anim.removeListener(previous);
    void tick() {
      final t = curve.value;
      _controller.move(
        LatLng(from.latitude + (target.latitude - from.latitude) * t,
            from.longitude + (target.longitude - from.longitude) * t),
        zoom,
      );
    }

    _tick = tick;
    _anim
      ..addListener(tick)
      ..forward(from: 0);
  }

  VoidCallback? _tick;

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final center = widget.live ?? (route.isNotEmpty ? route.last : widget.fallbackCenter);

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15,
        initialCameraFit: route.length >= 2
            ? CameraFit.coordinates(coordinates: route, padding: const EdgeInsets.all(48), maxZoom: 17)
            : null,
        interactionOptions: InteractionOptions(
          flags: widget.interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none,
        ),
        onMapReady: () => _ready = true,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'in.yathri.yathri',
          maxNativeZoom: 19,
        ),
        if (route.length >= 2)
          PolylineLayer(polylines: [
            Polyline(points: route, strokeWidth: 8, color: Colors.white, borderStrokeWidth: 0),
            Polyline(points: route, strokeWidth: 5, color: AppColors.forest),
          ]),
        MarkerLayer(markers: [
          if (route.isNotEmpty)
            Marker(
              point: route.first,
              width: 20,
              height: 20,
              child: const _Dot(color: AppColors.gold),
            ),
          if (route.length >= 2 && widget.live == null)
            Marker(
              point: route.last,
              width: 20,
              height: 20,
              child: const _Dot(color: AppColors.terracotta),
            ),
          if (widget.live != null)
            Marker(point: widget.live!, width: 36, height: 36, child: const _LiveDot()),
        ]),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
        ),
      );
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 36 * _pulse.value,
            height: 36 * _pulse.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.forest.withValues(alpha: 0.28 * (1 - _pulse.value)),
            ),
          ),
          const _Dot(color: AppColors.forest),
        ],
      ),
    );
  }
}
