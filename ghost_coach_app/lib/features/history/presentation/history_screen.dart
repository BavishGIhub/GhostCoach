import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/glass_container.dart';
import '../../../core/theme/animated_gradient_background.dart';
import '../../../database/app_database.dart';
import 'history_controller.dart';
import '../../../shared/widgets/game_icon.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHistory = ref.watch(historyListProvider);
    final controller = ref.read(historyControllerProvider.notifier);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: Padding(
          padding: EdgeInsets.only(left: 16),
          child: Icon(Icons.history, color: AppColors.secondary),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.primaryGradient.createShader(bounds),
          child: Text('SESSION HISTORY', style: AppTextStyles.brandSmall),
        ),
      ),
      body: Stack(
        children: [
          AnimatedGradientBackground(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(historyListProvider);
                return ref.read(historyListProvider.future);
              },
              color: AppColors.secondary,
              backgroundColor: AppColors.background,
              child: CustomScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: _FilterChips(),
                    ),
                  ),
                  asyncHistory.when(
                    loading: () => SliverFillRemaining(
                      child: Shimmer.fromColors(
                        baseColor: Colors.white.withValues(alpha: 0.05),
                        highlightColor: Colors.white.withValues(alpha: 0.1),
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          itemCount: 5,
                          itemBuilder: (_, _) => Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: GlassContainer(
                              padding: EdgeInsets.all(16),
                              borderRadius: 12,
                              child: SizedBox(
                                height: 60,
                                width: double.infinity,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    error: (e, _) => SliverFillRemaining(
                      child: Center(
                        child: Text(
                          'Error: $e',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ),
                    data: (sessions) {
                      if (sessions.isEmpty) return _buildEmpty(context);
                      return SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final item = sessions[index];
                            return Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: Dismissible(
                                key: Key(item.id),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (_) => _confirmDelete(context),
                                onDismissed: (_) {
                                  controller.removeSession(item.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Session deleted'),
                                    ),
                                  );
                                },
                                background: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.centerRight,
                                  padding: EdgeInsets.only(right: 20),
                                  child: Icon(
                                    Icons.delete,
                                    color: AppColors.error,
                                  ),
                                ),
                                child: _HistoryCard(
                                  session: item,
                                  onTap: () => context.push(
                                    '/analysis/results/${item.id}',
                                  ),
                                ),
                              ),
                            );
                          }, childCount: sessions.length),
                        ),
                      );
                    },
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 100,
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

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Color(0xFF1A1A24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('DELETE SESSION', style: AppTextStyles.brandSmall),
        content: Text('Delete this analysis permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCEL',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'DELETE',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: GlassContainer(
          padding: EdgeInsets.symmetric(vertical: 40, horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_toggle_off,
                size: 56,
                color: AppColors.textTertiary,
              ),
              SizedBox(height: 16),
              Text('NO SESSIONS YET', style: AppTextStyles.brandSmall),
              SizedBox(height: 6),
              Text(
                'Analyze gameplay to see history',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(historyFilterProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(ref, 'ALL', HistoryFilter.all, active),
          SizedBox(width: 8),
          _chip(ref, 'THIS WEEK', HistoryFilter.week, active),
          SizedBox(width: 8),
          _chip(ref, 'THIS MONTH', HistoryFilter.month, active),
        ],
      ),
    );
  }

  Widget _chip(
    WidgetRef ref,
    String label,
    HistoryFilter filter,
    HistoryFilter active,
  ) {
    final isActive = filter == active;
    return GestureDetector(
      onTap: () => ref.read(historyFilterProvider.notifier).set(filter),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive ? AppColors.primaryGradient : null,
          color: isActive ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: isActive ? null : Border.all(color: AppColors.borderSubtle),
          boxShadow: isActive
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 8)]
              : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.sectionLabel.copyWith(
            fontSize: 10,
            color: isActive ? Colors.white : AppColors.textSecondary,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Analysis session;
  final VoidCallback onTap;
  const _HistoryCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scoreColor = AppColors.scoreColor(session.overallScore);
    final gameColor = AppColors.gameColor(session.gameType ?? 'general');
    final dateStr = DateFormat(
      'MMM dd, yyyy • HH:mm',
    ).format(session.createdAt).toUpperCase();

    return GlassContainer(
      onTap: onTap,
      padding: EdgeInsets.all(0),
      borderRadius: 12,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 72,
            decoration: BoxDecoration(
              color: gameColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: gameColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: GameIcon(
              gameType: session.gameType ?? 'general',
              size: 24,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (session.gameType ?? 'GENERAL').toUpperCase(),
                  style: AppTextStyles.brandSmall,
                ),
                SizedBox(height: 3),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  session.overallScore.toInt().toString(),
                  style: AppTextStyles.brandSmall,
                ),
              ),
              SizedBox(height: 4),
              Text(
                _rankLabel(session.overallScore),
                style: AppTextStyles.brandSmall,
              ),
            ],
          ),
          SizedBox(width: 14),
        ],
      ),
    );
  }

  String _rankLabel(double s) {
    if (s >= 90) return 'GHOST ELITE';
    if (s >= 80) return 'DIAMOND';
    if (s >= 70) return 'PLATINUM';
    if (s >= 50) return 'GOLD';
    return 'RECRUIT';
  }
}