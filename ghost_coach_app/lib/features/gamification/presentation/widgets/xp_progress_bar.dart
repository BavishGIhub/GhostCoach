import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../domain/models/player_profile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/glass_container.dart';

class XpProgressBar extends StatelessWidget {
  final PlayerProfile profile;
  final bool animateGain;
  final int? xpGained;

  const XpProgressBar({
    super.key,
    required this.profile,
    this.animateGain = false,
    this.xpGained,
  });

  @override
  Widget build(BuildContext context) {
    final currentXp = profile.currentLevelXp;
    final nextXp = profile.xpForNextLevel;
    final progress = (currentXp / nextXp).clamp(0.0, 1.0);

    return GlassContainer(
      padding: EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${profile.level}',
                        style: AppTextStyles.statSmall.copyWith(
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.title.toUpperCase(),
                            style: AppTextStyles.sectionLabel.copyWith(
                              fontSize: 11,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Level ${profile.level}',
                            style: AppTextStyles.caption.copyWith(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              if (animateGain && xpGained != null)
                Text('+$xpGained XP',
                  style: AppTextStyles.statSmall.copyWith(
                    fontSize: 12,
                    color: AppColors.success,
                  ),
                  overflow: TextOverflow.clip,
                )
                    .animate(
                      onPlay: (controller) => controller.repeat(reverse: true),
                    )
                    .fadeOut(delay: 2.seconds, duration: 500.ms)
                    .slideY(begin: 0, end: -0.5, duration: 800.ms),
              if (!animateGain)
                Text(
                  '$currentXp / $nextXp XP',
                  style: AppTextStyles.mono.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.clip,
                ),
            ],
          ),
          SizedBox(height: 14),
          Stack(
            children: [
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                        height: 6,
                        width: constraints.maxWidth * progress,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 6,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                      )
                      .animate(target: animateGain ? 1 : 0)
                      .scaleX(
                        begin: 0,
                        end: 1,
                        duration: 1.seconds,
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.centerLeft,
                      );
                },
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }
}