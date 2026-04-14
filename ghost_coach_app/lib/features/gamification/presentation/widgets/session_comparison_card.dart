import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/glass_container.dart';
import '../../../../domain/models/analysis_result.dart';

/// Glassmorphic comparison card showing delta between current and previous session.
class SessionComparisonCard extends StatelessWidget {
  final AnalysisResult current;
  final AnalysisResult previous;

  const SessionComparisonCard({
    super.key,
    required this.current,
    required this.previous,
  });

  @override
  Widget build(BuildContext context) {
    final currentScore = current.features.overallScore;
    final previousScore = previous.features.overallScore;
    final delta = currentScore - previousScore;
    final isImproved = delta >= 0;

    return GlassContainer(
      padding: EdgeInsets.all(16),
      borderRadius: 14,
      borderColor: (isImproved ? AppColors.success : AppColors.error)
          .withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isImproved ? Icons.trending_up : Icons.trending_down,
                color: isImproved ? AppColors.success : AppColors.error,
                size: 18,
              ),
              SizedBox(width: 8),
              Text('VS LAST SESSION', style: AppTextStyles.brandSmall),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isImproved ? AppColors.success : AppColors.error)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${isImproved ? '+' : ''}${delta.toStringAsFixed(1)}%',
                  style: AppTextStyles.brandSmall,
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          // Compare individual patterns
          ...List.generate(
            current.features.movementPatterns.length.clamp(0, 6),
            (i) {
              final cp = current.features.movementPatterns[i];
              // Try to find matching pattern in previous
              final pp = previous.features.movementPatterns.where(
                (p) => p.patternName == cp.patternName,
              );
              if (pp.isEmpty) return SizedBox.shrink();
              final d = cp.score - pp.first.score;
              final up = d >= 0;

              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      up ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 12,
                      color: up ? AppColors.success : AppColors.error,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        cp.patternName.toUpperCase(),
                        style: AppTextStyles.brandSmall,
                      ),
                    ),
                    Text(
                      '${pp.first.score.toInt()} → ${cp.score.toInt()}',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '${up ? '+' : ''}${d.toStringAsFixed(0)}',
                      style: AppTextStyles.brandSmall,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: (100 * i).ms, duration: 300.ms);
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1);
  }
}