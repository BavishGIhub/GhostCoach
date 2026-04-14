import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Reusable Glassmorphic container with BackdropFilter blur effect.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool showBorder;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? borderColor;
  final double? width;
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.blur = 20,
    this.opacity = 0.08,
    this.padding,
    this.margin,
    this.showBorder = true,
    this.onTap,
    this.gradient,
    this.borderColor,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    Widget container = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient:
                gradient ??
                LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: opacity + 0.02),
                    Colors.white.withValues(alpha: opacity * 0.6),
                  ],
                ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: showBorder
                ? Border.all(color: borderColor ?? AppColors.border, width: 1)
                : null,
          ),
          child: child,
        ),
      ),
    );

    if (margin != null) {
      container = Padding(padding: margin!, child: container);
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: container);
    }

    return container;
  }
}