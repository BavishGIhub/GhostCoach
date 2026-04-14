import 'package:flutter/material.dart';
import '../../../../domain/models/analysis_result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/glass_container.dart';

class ShareCard extends StatelessWidget {
  final AnalysisResult result;
  final bool isStory;

  const ShareCard({super.key, required this.result, required this.isStory});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isStory ? 1080 : 1080,
      height: isStory ? 1920 : 1080,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A0A0F), Color(0xFF1A0033)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Background ambient glows
          Positioned(
            top: -200,
            right: -200,
            child: Container(
              width: 800,
              height: 800,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 200,
                    spreadRadius: 100,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -300,
            left: -200,
            child: Container(
              width: 1000,
              height: 1000,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    blurRadius: 250,
                    spreadRadius: 150,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(80.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // App Header
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppColors.primaryGradient.createShader(bounds),
                    child: Text(
                      'GHOST COACH',
                      style: AppTextStyles.brand.copyWith(
                        fontSize: 64,
                        letterSpacing: 8.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),

                  // Game info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppColors.gameEmoji(result.gameType),
                        style: const TextStyle(fontSize: 48),
                      ),
                      const SizedBox(width: 24),
                      Text(
                        result.gameType.toUpperCase(),
                        style: AppTextStyles.heading1.copyWith(
                          fontSize: 48,
                          letterSpacing: 4.0,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 60),

                  // Score Box
                  GlassContainer(
                    padding: const EdgeInsets.symmetric(
                      vertical: 80,
                      horizontal: 60,
                    ),
                    borderRadius: 48,
                    borderColor: AppColors.gradeColor(
                      result.letterGrade,
                    ).withValues(alpha: 0.5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          result.letterGrade,
                          style: AppTextStyles.heading1.copyWith(
                            fontSize: 240,
                            height: 1.0,
                            color: AppColors.gradeColor(result.letterGrade),
                            shadows: [
                              Shadow(
                                color: AppColors.gradeColor(
                                  result.letterGrade,
                                ).withValues(alpha: 0.4),
                                blurRadius: 40,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 60),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              result.features.overallScore.toStringAsFixed(1),
                              style: AppTextStyles.stat.copyWith(
                                fontSize: 120,
                                height: 1.0,
                              ),
                            ),
                            Text(
                              'OVERALL RATING',
                              style: AppTextStyles.sectionLabel.copyWith(
                                fontSize: 32,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),

                  if (isStory) ...[
                    // Key stat
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Text(
                        '🔥 ${result.features.keyMoments.length} KEY MOMENTS DETECTED',
                        style: AppTextStyles.sectionLabel.copyWith(
                          fontSize: 28,
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),

                    // Metrics
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: result.features.movementPatterns
                              .take(6)
                              .map((pattern) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 40),
                                  child: Row(
                                    children: [
                                      Text(
                                        pattern.icon,
                                        style: const TextStyle(fontSize: 48),
                                      ),
                                      const SizedBox(width: 32),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  pattern.patternName
                                                      .toUpperCase(),
                                                  style: AppTextStyles.label
                                                      .copyWith(
                                                        fontSize: 28,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        letterSpacing: 2.0,
                                                      ),
                                                ),
                                                Text(
                                                  '${pattern.score.toInt()}',
                                                  style: AppTextStyles.statSmall
                                                      .copyWith(fontSize: 32),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: LinearProgressIndicator(
                                                value: pattern.score / 100,
                                                backgroundColor: Colors.black45,
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                      AppColors.scoreColor(
                                                        pattern.score,
                                                      ),
                                                    ),
                                                minHeight: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              })
                              .toList(),
                        ),
                      ),
                    ),
                  ] else ...[
                    const Spacer(),
                  ],

                  // Watermark
                  Text(
                    'ghostcoach.app',
                    style: AppTextStyles.brandSmall.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}