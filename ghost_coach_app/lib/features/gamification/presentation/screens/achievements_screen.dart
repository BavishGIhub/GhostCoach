import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/glass_container.dart';
import '../../../../core/theme/animated_gradient_background.dart';
import '../../domain/models/achievement.dart';
import '../../application/gamification_service.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAchievements = ref
        .watch(gamificationServiceProvider)
        .watchUnlockedAchievements();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.secondary),
          onPressed: () => context.go('/home'),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.primaryGradient.createShader(bounds),
          child: Text('ACHIEVEMENTS', style: AppTextStyles.brandSmall),
        ),
      ),
      body: Stack(
        children: [
          AnimatedGradientBackground(),
          SafeArea(
            child: StreamBuilder<List<Achievement>>(
              stream: asyncAchievements,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return Shimmer.fromColors(
                    baseColor: Colors.white.withValues(alpha: 0.05),
                    highlightColor: Colors.white.withValues(alpha: 0.1),
                    child: GridView.builder(
                      padding: EdgeInsets.all(16),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: 12,
                      itemBuilder: (_, _) => GlassContainer(
                        padding: EdgeInsets.all(8),
                        borderRadius: 12,
                        child: SizedBox.shrink(),
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: AppColors.error),
                    ),
                  );
                }

                final achievements =
                    snapshot.data ?? AchievementDefinitions.all;
                final unlockedCount = achievements
                    .where((a) => a.isUnlocked)
                    .length;

                final beginner = achievements
                    .where((a) => a.category == AchievementCategory.beginner)
                    .toList();
                final skill = achievements
                    .where((a) => a.category == AchievementCategory.skill)
                    .toList();
                final streak = achievements
                    .where((a) => a.category == AchievementCategory.streak)
                    .toList();
                final improvement = achievements
                    .where((a) => a.category == AchievementCategory.improvement)
                    .toList();
                final gameSpecific = achievements
                    .where(
                      (a) => a.category == AchievementCategory.gameSpecific,
                    )
                    .toList();

                return CustomScrollView(
                  slivers: [
                    // Progress summary
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: GlassContainer(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => AppColors
                                    .primaryGradient
                                    .createShader(bounds),
                                child: Icon(
                                  Icons.emoji_events,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$unlockedCount / ${achievements.length} UNLOCKED',
                                      style: AppTextStyles.brandSmall,
                                    ),
                                    SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: achievements.isEmpty
                                            ? 0
                                            : unlockedCount /
                                                  achievements.length,
                                        backgroundColor: Colors.black26,
                                        valueColor:
                                            AlwaysStoppedAnimation(
                                              AppColors.primary,
                                            ),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    _buildCategoryHeader('BEGINNER'),
                    _buildGrid(beginner),

                    _buildCategoryHeader('SKILL'),
                    _buildGrid(skill),

                    _buildCategoryHeader('TIME & STREAK'),
                    _buildGrid(streak),

                    _buildCategoryHeader('IMPROVEMENT'),
                    _buildGrid(improvement),

                    _buildCategoryHeader('GAME SPECIFIC'),
                    _buildGrid(gameSpecific),

                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 100,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 28, 16, 12),
        child: Text(title, style: AppTextStyles.brandSmall),
      ),
    );
  }

  Widget _buildGrid(List<Achievement> items) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _AchievementCard(achievement: items[index]),
          childCount: items.length,
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  const _AchievementCard({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final isUnlocked = achievement.isUnlocked;

    return GlassContainer(
      padding: EdgeInsets.all(14),
      borderRadius: 16,
      borderColor: isUnlocked
          ? AppColors.primary.withValues(alpha: 0.3)
          : AppColors.borderSubtle,
      onTap: () => _showDetail(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : Colors.black26,
                  shape: BoxShape.circle,
                  boxShadow: isUnlocked
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  isUnlocked ? achievement.icon : '🔒',
                  style: TextStyle(
                    fontSize: isUnlocked ? 28 : 20,
                    color: isUnlocked
                        ? null
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              )
              .animate(target: isUnlocked ? 1 : 0)
              .shimmer(duration: 2.seconds, blendMode: BlendMode.srcOver)
              .scaleXY(end: 1.05, curve: Curves.easeOutBack),
          SizedBox(height: 10),
          Text(
            isUnlocked ? achievement.title : 'Locked',
            textAlign: TextAlign.center,
            style: AppTextStyles.brandSmall,
          ),
          SizedBox(height: 4),
          Text(
            isUnlocked ? achievement.description : '???',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              color: isUnlocked
                  ? AppColors.textSecondary
                  : AppColors.textTertiary,
            ),
          ),
          if (isUnlocked && achievement.unlockedAt != null) ...[
            Spacer(),
            Text(
              DateFormat('MMM d, yyyy').format(achievement.unlockedAt!),
              style: TextStyle(
                fontSize: 8,
                color: AppColors.primary.withValues(alpha: 0.8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          padding: EdgeInsets.all(24),
          borderRadius: 20,
          borderColor: achievement.isUnlocked
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.borderSubtle,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(achievement.icon, style: TextStyle(fontSize: 48)),
              SizedBox(height: 14),
              Text(
                achievement.isUnlocked ? achievement.title : 'LOCKED',
                style: AppTextStyles.brandSmall,
              ),
              SizedBox(height: 8),
              Text(
                achievement.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              if (achievement.isUnlocked && achievement.unlockedAt != null) ...[
                SizedBox(height: 12),
                Text(
                  'Unlocked ${DateFormat('MMMM d, yyyy').format(achievement.unlockedAt!)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.primary.withValues(alpha: 0.8),
                  ),
                ),
              ],
              SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('CLOSE', style: AppTextStyles.brandSmall),
              ),
            ],
          ),
        ),
      ),
    );
  }
}