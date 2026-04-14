import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../domain/models/streak_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/glass_container.dart';

class StreakWidget extends StatelessWidget {
  final StreakData streak;
  final bool animateUpdate;

  const StreakWidget({
    super.key,
    required this.streak,
    this.animateUpdate = false,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = streak.isStreakActive(DateTime.now());
    final isDanger = streak.isAboutToBreak(DateTime.now());

    Color streakColor = isActive ? AppColors.warning : AppColors.textTertiary;
    if (isDanger) streakColor = AppColors.error;

    return GlassContainer(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 12,
      borderColor: streakColor.withValues(alpha: 0.3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
                Icons.local_fire_department,
                color: streakColor,
                size: isActive ? 26 : 22,
              )
              .animate(
                onPlay: (controller) => isActive ? controller.repeat() : null,
              )
              .shimmer(duration: 2.seconds, color: Colors.white24)
              .scaleXY(
                begin: 1.0,
                end: 1.1,
                duration: 1.seconds,
                curve: Curves.easeInOutSine,
              )
              .then()
              .scaleXY(
                begin: 1.1,
                end: 1.0,
                duration: 1.seconds,
                curve: Curves.easeInOutSine,
              ),

          SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${streak.currentStreak} Day Streak',
                  style: AppTextStyles.heading3.copyWith(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                if (streak.currentStreak > 0)
                  Text(
                    isDanger
                        ? 'Analyze today to keep it!'
                        : '${streak.xpMultiplier}x XP Multiplier',
                    style: AppTextStyles.caption.copyWith(
                      color: isDanger ? AppColors.error : AppColors.textTertiary,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          if (animateUpdate)
            Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(
                    Icons.arrow_upward,
                    color: AppColors.success,
                    size: 16,
                  ),
                )
                .animate()
                .slideY(begin: 0.5, end: -0.5, duration: 1.seconds)
                .fadeOut(delay: 500.ms),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}