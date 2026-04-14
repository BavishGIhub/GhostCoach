import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/glass_container.dart';
import '../../../core/theme/animated_gradient_background.dart';
import '../../../core/auth_providers.dart';
import 'providers/home_providers.dart';
import '../../history/presentation/history_controller.dart';
import '../../../database/app_database.dart';
import '../../gamification/presentation/widgets/xp_progress_bar.dart';
import '../../gamification/presentation/widgets/streak_widget.dart';
import '../../gamification/presentation/widgets/score_trend_chart.dart';
import '../../gamification/application/gamification_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthState = ref.watch(healthCheckProvider);
    final stats = ref.watch(homeStatsProvider);
    final historyState = ref.watch(historyListProvider);
    final profileState = ref.watch(playerProfileStreamProvider);
    final streakState = ref.watch(streakDataStreamProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: AppBar(
              backgroundColor: AppColors.background.withValues(alpha: 0.7),
              elevation: 0,
              leading: Padding(
                padding: EdgeInsets.only(left: 16),
                child: Center(
                  child: Icon(Icons.auto_awesome, color: AppColors.secondary, size: 28),
                ),
              ),
              title: ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.primaryGradient.createShader(bounds),
                child: Text('GHOST COACH', style: AppTextStyles.brandSmall),
              ),
              actions: [
                Center(
                  child: Padding(
                    padding: EdgeInsets.only(right: 16.0),
                    child: Consumer(
                      builder: (context, ref, child) {
                        final user = ref.watch(currentUserProvider).value;
                        return GestureDetector(
                          onTap: () => context.push('/profile'),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(alpha: 0.2),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                            ),
                            child: user?.photoURL != null
                                ? ClipOval(
                                    child: Image.network(
                                      user!.photoURL!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(Icons.person, color: AppColors.secondary, size: 20),
                                    ),
                                  )
                                : Icon(Icons.person, color: AppColors.secondary, size: 20),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(healthCheckProvider);
          ref.invalidate(historyListProvider);
        },
        color: AppColors.secondary,
        child: Stack(
          children: [
            AnimatedGradientBackground(),
            SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                top: 130,
                bottom: MediaQuery.of(context).padding.bottom + 100,
              ),
              child: Column(
                children: [
                  // Hero Section
                  _PulseHero(onTap: () => context.go('/upload')),
                  SizedBox(height: 10),
                  Text(
                    'ANALYZE YOUR GAMEPLAY',
                    style: AppTextStyles.sectionLabel.copyWith(
                      fontSize: 10,
                      letterSpacing: 3,
                      color: AppColors.textSecondary,
                    ),
                  ).animate().fadeIn(delay: 300.ms, duration: 600.ms),
                  SizedBox(height: 28),

                  // Gamification Section
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        profileState.when(
                          data: (profile) => XpProgressBar(profile: profile),
                          loading: () => SizedBox(height: 40),
                          error: (e, s) => SizedBox(),
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: streakState.when(
                                data: (streak) => StreakWidget(streak: streak),
                                loading: () => SizedBox(),
                                error: (e, s) => SizedBox(),
                              ),
                            ),
                            SizedBox(width: 10),
                            GlassContainer(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              borderRadius: 12,
                              onTap: () => context.push('/achievements'),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.emoji_events,
                                    color: Colors.amber,
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'BADGES',
                                    style: AppTextStyles.sectionLabel.copyWith(
                                      fontSize: 10,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 28),

                  // Stats Row
                  Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: _BentoStats(stats: stats),
                      )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 500.ms)
                      .slideY(begin: 0.1),
                  SizedBox(height: 28),

                  // Trend Chart
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: historyState.when(
                      data: (sessions) => ScoreTrendChart(analyses: sessions),
                      loading: () => SizedBox(height: 100),
                      error: (e, s) => SizedBox(),
                    ),
                  ),
                  SizedBox(height: 28),

                  // Recent Sessions
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: _RecentSessions(historyState: historyState),
                  ).animate().fadeIn(delay: 500.ms, duration: 500.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── PULSE HERO ───
class _PulseHero extends StatelessWidget {
  final VoidCallback onTap;
  const _PulseHero({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.secondary,
                  Color(0xFF1A0033),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 40,
                  spreadRadius: 0,
                ),
              ],
            ),
            padding: EdgeInsets.all(4),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.background,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload_outlined, color: AppColors.secondary, size: 36),
                  SizedBox(height: 6),
                  Text(
                    'ANALYZE',
                    style: AppTextStyles.sectionLabel.copyWith(
                      fontSize: 10,
                      color: AppColors.textPrimary,
                      letterSpacing: 2.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate(onPlay: (ctrl) => ctrl.repeat(reverse: true))
        .scaleXY(
          begin: 0.97,
          end: 1.03,
          duration: 2.seconds,
          curve: Curves.easeInOut,
        );
  }
}

// ─── SERVER STATUS ───
class _ServerStatusChip extends StatelessWidget {
  final AsyncValue<bool> healthState;
  const _ServerStatusChip({required this.healthState});

  @override
  Widget build(BuildContext context) {
    final isOnline = healthState.maybeWhen(data: (v) => v, orElse: () => false);
    final isLoading = healthState.isLoading;
    final color = isOnline
        ? AppColors.success
        : (isLoading ? Colors.grey : AppColors.error);
    final label = isOnline ? 'ONLINE' : (isLoading ? '...' : 'OFFLINE');

    return GlassContainer(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      borderRadius: 20,
      blur: 12,
      borderColor: color.withValues(alpha: 0.3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.sectionLabel.copyWith(
              fontSize: 9,
              color: color,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── BENTO STATS ───
class _BentoStats extends StatelessWidget {
final HomeStats stats;
const _BentoStats({required this.stats});

@override
Widget build(BuildContext context) {
  return Row(
    children: [
      Expanded(
        child: _StatCard(
          label: 'ANALYSES',
          value: stats.totalAnalyses.toString(),
          color: AppColors.primary,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StatCard(
          label: 'AVG SCORE',
          value: stats.avgScore.toStringAsFixed(0),
          color: AppColors.secondary,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StatCard(
          label: 'BEST',
          value: stats.bestScore.toString(),
          color: AppColors.success,
        ),
      ),
    ],
  );
}
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      borderRadius: 14,
      borderColor: color.withValues(alpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.sectionLabel.copyWith(
              fontSize: 9,
              color: color.withValues(alpha: 0.8),
            ),
          ),
          SizedBox(height: 8),
          AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Text(
              value,
              key: ValueKey(value),
              style: AppTextStyles.statMedium.copyWith(
                fontSize: 22,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── RECENT SESSIONS ───
class _RecentSessions extends StatelessWidget {
  final AsyncValue<List<Analysis>> historyState;
  const _RecentSessions({required this.historyState});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text('RECENT SESSIONS',
                style: AppTextStyles.sectionLabel.copyWith(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () => context.go('/history'),
              child: Text('See All',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 14),
        historyState.when(
          data: (sessions) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (sessions.isEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.borderSubtle,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.videogame_asset_off,
                          color: AppColors.textTertiary,
                          size: 36,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No sessions yet',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Upload a gameplay clip to get started',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  )
                else ...[
                  ...sessions.take(3).map(
                    (item) => Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: _SessionItem(session: item),
                    ),
                  ),
                  if (sessions.length > 3)
                    Center(
                      child: TextButton(
                        onPressed: () => context.push('/history'),
                        child: Text(
                          'View All',
                          style: AppTextStyles.label.copyWith(color: AppColors.primary),
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
          loading: () => Shimmer.fromColors(
            baseColor: Colors.white.withValues(alpha: 0.05),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: Column(
              children: List.generate(
                3,
                (index) => Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: GlassContainer(
                    padding: EdgeInsets.all(14),
                    borderRadius: 12,
                    child: SizedBox(height: 50, width: double.infinity),
                  ),
                ),
              ),
            ),
          ),
          error: (e, s) =>
              Text('Error: $e', style: TextStyle(color: AppColors.error, fontSize: 12)),
        ),
      ],
    );
  }
}

class _SessionItem extends StatelessWidget {
  final Analysis session;
  const _SessionItem({required this.session});

  @override
  Widget build(BuildContext context) {
    final scoreColor = AppColors.scoreColor(session.overallScore);

    return GlassContainer(
      onTap: () => context.push('/analysis/results/${session.id}'),
      padding: EdgeInsets.all(14),
      borderRadius: 14,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                AppColors.gameEmoji(session.gameType ?? 'general'),
                style: TextStyle(fontSize: 20),
              ),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (session.gameType ?? 'General').toUpperCase(),
                  style: AppTextStyles.heading3.copyWith(fontSize: 14),
                ),
                SizedBox(height: 2),
                Text(
                  _formatTime(session.createdAt),
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scoreColor.withValues(alpha: 0.1),
              border: Border.all(
                color: scoreColor.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              session.overallScore.round().toString(),
              style: AppTextStyles.statSmall.copyWith(
                color: scoreColor,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 1) return '${diff.inDays} days ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}