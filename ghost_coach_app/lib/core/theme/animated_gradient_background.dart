import 'dart:math';
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Full-screen animated gradient background with drifting color orbs.
/// Place behind all content via Stack.
class AnimatedGradientBackground extends StatefulWidget {
  const AnimatedGradientBackground({super.key});

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * pi;

        return Container(
          width: size.width,
          height: size.height,
          color: AppColors.background,
          child: Stack(
            children: [
              // Purple orb — top-left drift
              Positioned(
                left: -80 + sin(t) * 30,
                top: size.height * 0.1 + cos(t) * 20,
                child: _GlowOrb(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  size: 350,
                ),
              ),
              // Cyan orb — center-right drift
              Positioned(
                right: -60 + cos(t + 1) * 25,
                top: size.height * 0.4 + sin(t + 1) * 30,
                child: _GlowOrb(
                  color: AppColors.secondary.withValues(alpha: 0.10),
                  size: 300,
                ),
              ),
              // Pink orb — bottom drift
              Positioned(
                left: size.width * 0.3 + sin(t + 2) * 20,
                bottom: -40 + cos(t + 2) * 25,
                child: _GlowOrb(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  size: 280,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}