import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/track_point.dart';

/// A tiny drawing of the route's shape. No map tiles, so it is instant,
/// works offline and is cheap to show in a long list.
class RoutePreview extends StatelessWidget {
  const RoutePreview({
    super.key,
    required this.route,
    this.width = 64,
    this.height = 48,
    this.color = AppColors.forest,
  });

  final List<TrackPoint> route;
  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (route.length < 2) {
      return SizedBox(
        width: width,
        height: height,
        child: const Icon(Icons.route_rounded, color: AppColors.line),
      );
    }
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.ivory,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(painter: _RoutePainter(route, color)),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(List<TrackPoint> route, this.color) : _points = _thin(route);

  final List<TrackPoint> _points;
  final Color color;

  /// Keeps at most ~60 points; the shape survives, the cost stays tiny.
  static List<TrackPoint> _thin(List<TrackPoint> route) {
    if (route.length <= 60) return route;
    final step = route.length / 60;
    return [for (var i = 0; i < 60; i++) route[(i * step).floor()], route.last];
  }

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 8.0;
    var minLat = double.infinity, maxLat = -double.infinity;
    var minLng = double.infinity, maxLng = -double.infinity;
    for (final p in _points) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLng = math.min(minLng, p.lng);
      maxLng = math.max(maxLng, p.lng);
    }
    // Longitude degrees shrink with latitude; keep the shape undistorted.
    final lngScale = math.cos(_points.first.lat * math.pi / 180);
    final spanX = math.max((maxLng - minLng) * lngScale, 1e-6);
    final spanY = math.max(maxLat - minLat, 1e-6);
    final scale = math.min((size.width - pad * 2) / spanX, (size.height - pad * 2) / spanY);
    final offsetX = (size.width - spanX * scale) / 2;
    final offsetY = (size.height - spanY * scale) / 2;

    Offset at(TrackPoint p) => Offset(
          offsetX + (p.lng - minLng) * lngScale * scale,
          size.height - offsetY - (p.lat - minLat) * scale,
        );

    final path = Path()..moveTo(at(_points.first).dx, at(_points.first).dy);
    for (final p in _points.skip(1)) {
      final o = at(p);
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(at(_points.first), 3.2, Paint()..color = AppColors.gold);
    canvas.drawCircle(at(_points.last), 3.2, Paint()..color = AppColors.terracotta);
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old._points != _points || old.color != color;
}
