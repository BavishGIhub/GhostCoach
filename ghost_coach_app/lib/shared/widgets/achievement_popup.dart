import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/glass_container.dart';
import '../../features/gamification/domain/models/achievement.dart';

/// Full-screen glass overlay with confetti for newly unlocked achievements.
/// Auto-dismisses after 4 seconds.
class AchievementPopup extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback? onDismiss;

  const AchievementPopup({
    super.key,
    required this.achievement,
    this.onDismiss,
  });

  /// Show directly as an overlay.
  static void show(BuildContext context, Achievement achievement) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: true,
      builder: (_) => AchievementPopup(
        achievement: achievement,
        onDismiss: () => Navigator.of(context, rootNavigator: true).pop(),
      ),
    );
  }

  @override
  State<AchievementPopup> createState() => _AchievementPopupState();
}

class _AchievementPopupState extends State<AchievementPopup> {
  late ConfettiController _confetti;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: Duration(seconds: 3));
    _confetti.play();
    _timer = Timer(Duration(seconds: 4), () {
      if (mounted) widget.onDismiss?.call();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.03,
            numberOfParticles: 20,
            gravity: 0.15,
            colors: [
              AppColors.primary,
              AppColors.secondary,
              AppColors.accent,
              Colors.white,
            ],
          ),
        ),

        // Glass card
        Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            padding: EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            borderRadius: 24,
            borderColor: AppColors.primary.withValues(alpha: 0.4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ACHIEVEMENT UNLOCKED', style: AppTextStyles.brandSmall),
                SizedBox(height: 20),
                Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.achievement.icon,
                        style: TextStyle(fontSize: 40),
                      ),
                    )
                    .animate()
                    .scale(
                      begin: Offset(0.3, 0.3),
                      end: Offset(1.0, 1.0),
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                    )
                    .shimmer(delay: 600.ms, duration: 1.seconds),
                SizedBox(height: 18),
                Text(
                  widget.achievement.title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.brandSmall,
                ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                SizedBox(height: 8),
                Text(
                  widget.achievement.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
              ],
            ),
          ),
        ),
      ],
    );
  }
}