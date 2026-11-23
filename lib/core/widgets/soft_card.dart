import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Rounded card with a soft, warm shadow. Set [glass] for a subtle frosted
/// look when it floats over a map or gradient.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.gradient,
    this.onTap,
    this.glass = false,
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final bool glass;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final decoration = BoxDecoration(
      color: gradient == null ? (color ?? (glass ? AppColors.naturalWhite.withValues(alpha: 0.82) : AppColors.naturalWhite)) : null,
      gradient: gradient,
      borderRadius: borderRadius,
      boxShadow: const [
        BoxShadow(color: Color(0x14402C14), blurRadius: 24, offset: Offset(0, 8)),
        BoxShadow(color: Color(0x0A402C14), blurRadius: 4, offset: Offset(0, 1)),
      ],
    );

    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(borderRadius: borderRadius, onTap: onTap, child: content);
    }

    Widget card = DecoratedBox(
      decoration: decoration,
      child: Material(type: MaterialType.transparency, borderRadius: borderRadius, child: content),
    );

    if (glass) {
      card = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: card),
      );
    }
    return card;
  }
}
