import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/glass_container.dart';
import '../../../core/theme/animated_gradient_background.dart';
import '../../../domain/repositories/analysis_repository.dart';
import '../../../features/gamification/application/gamification_service.dart';

class LoadingScreen extends ConsumerStatefulWidget {
  final String analysisId;
  const LoadingScreen({super.key, required this.analysisId});

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _tips = [
    "Detecting key moments...",
    "Analyzing movement patterns...",
    "Generating coaching tips...",
    "Comparing to meta strategies...",
    "Identifying game phases...",
  ];
  int _currentTipIndex = 0;
  late AnimationController _tipsController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tipsController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              if (mounted) {
                setState(
                  () =>
                      _currentTipIndex = (_currentTipIndex + 1) % _tips.length,
                );
                _tipsController.forward(from: 0.0);
              }
            }
          });
    _tipsController.forward();

    // Navigate to results after brief animation
    _navigateToResults();
  }

  Future<void> _navigateToResults() async {
    // Show loading animation for a nice UX
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    // Check if result is cached
    final cache = ref.read(analysisResultCacheProvider);
    final result = cache[widget.analysisId];

    if (result != null) {
      // Process gamification if you have that service
      GamificationResult? gamificationResult;
      try {
        final gamificationService = ref.read(gamificationServiceProvider);
        gamificationResult = await gamificationService.processAnalysis(result);
      } catch (e) {
        // Gamification is optional, continue without it
        debugPrint('Gamification skipped: $e');
      }

      if (mounted) {
        context.go(
          '/analysis/results/${widget.analysisId}',
          extra: gamificationResult,
        );
      }
    } else {
      // Result not found in cache - shouldn't happen normally
      if (mounted) {
        setState(() {
          _error = 'Analysis result not found. Please try uploading again.';
        });
      }
    }
  }

  void _retry() {
    setState(() => _error = null);
    context.go('/upload');
  }

  @override
  void dispose() {
    _tipsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close, color: AppColors.secondary),
          onPressed: () => context.go('/home'),
        ),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.primaryGradient.createShader(bounds),
          child: Text('GHOST COACH', style: AppTextStyles.brandSmall),
        ),
      ),
      body: Stack(
        children: [
          const AnimatedGradientBackground(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Loading Ring + Ghost
                SizedBox(
                  width: 192,
                  height: 192,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                            size: const Size(176, 176),
                            painter: _LoadingRingPainter(
                              color: AppColors.secondary,
                            ),
                          )
                          .animate(onPlay: (ctrl) => ctrl.repeat())
                          .rotate(duration: 2.seconds, curve: Curves.linear),

                      GlassContainer(
                            width: 120,
                            height: 120,
                            borderRadius: 16,
                            padding: const EdgeInsets.all(0),
                            child: Center(
                              child: ShaderMask(
                                shaderCallback: (bounds) => AppColors
                                    .primaryGradient
                                    .createShader(bounds),
                                child: const Icon(
                                  Icons.bubble_chart,
                                  size: 56,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                          .animate(onPlay: (ctrl) => ctrl.repeat(reverse: true))
                          .scaleXY(
                            begin: 0.95,
                            end: 1.05,
                            duration: 1.seconds,
                            curve: Curves.easeInOut,
                          ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                if (_error != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _error!,
                      style: TextStyle(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('RETRY'),
                  ),
                ] else ...[
                  SizedBox(
                    height: 30,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        _tips[_currentTipIndex],
                        key: ValueKey(_currentTipIndex),
                        style: AppTextStyles.heading3,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PREPARING YOUR RESULTS',
                    style: AppTextStyles.sectionLabel,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingRingPainter extends CustomPainter {
  final Color color;
  _LoadingRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [AppColors.primary, color],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      1.5 * pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}