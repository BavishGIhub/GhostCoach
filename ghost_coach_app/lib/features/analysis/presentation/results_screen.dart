import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/glass_container.dart';
import '../../../core/theme/animated_gradient_background.dart';
import '../../../domain/models/analysis_result.dart';
import '../../gamification/application/gamification_service.dart';
import 'providers/analysis_providers.dart';
import 'widgets/score_gauge.dart';
import 'widgets/radar_chart_widget.dart';
import 'widgets/share_results_button.dart';
import '../../../shared/widgets/achievement_popup.dart';
import 'widgets/video_player_widget.dart';
import '../../../shared/widgets/game_icon.dart';
import '../../../core/providers.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  final String analysisId;
  final GamificationResult? gamificationResult;

  const ResultsScreen({
    super.key,
    required this.analysisId,
    this.gamificationResult,
  });

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  late ConfettiController _confettiController;
  VideoPlayerController? _videoPlayerController;
  late ScrollController _scrollController;
  late ScrollController _storyboardScrollController;
  int _activeStoryboardIndex = 0;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: Duration(seconds: 3),
    );
    _scrollController = ScrollController();
    _storyboardScrollController = ScrollController();
    _storyboardScrollController.addListener(_onStoryboardScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final g = widget.gamificationResult;
      if (g != null && (g.leveledUp || g.newlyUnlocked.isNotEmpty)) {
        _confettiController.play();
      }
      if (g != null && g.newlyUnlocked.isNotEmpty) {
        _showAchievementPopups(g.newlyUnlocked);
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _videoPlayerController?.dispose();
    _scrollController.dispose();
    _storyboardScrollController.removeListener(_onStoryboardScroll);
    _storyboardScrollController.dispose();
    super.dispose();
  }

  void _onStoryboardScroll() {
    if (!_storyboardScrollController.hasClients) return;
    const cardWidth = 332.0;
    final index = (_storyboardScrollController.offset / cardWidth).round();
    if (index != _activeStoryboardIndex) {
      setState(() => _activeStoryboardIndex = index);
    }
  }

  List<Widget> _buildGroupedTips(List<String> tips) {
    final strengths = <String>[];
    final improve = <String>[];
    final meta = <String>[];
    final general = <String>[];

    for (final tip in tips) {
      final l = tip.toLowerCase();
      if (l.contains('meta tip') || (l.contains('meta') && l.contains('🎯'))) {
        meta.add(tip);
      } else if (l.contains('incredible') || l.contains('strength') || l.contains('greatest') || l.contains('excellent') || l.contains('impressive')) {
        strengths.add(tip);
      } else if (l.contains('improve') || l.contains('work on') || l.contains('develop') || l.contains('practice') || l.contains('drill') || l.contains('focus on')) {
        improve.add(tip);
      } else {
        general.add(tip);
      }
    }

    final widgets = <Widget>[];
    var animIndex = 0;

    void addGroup(String label, Color color, IconData icon, List<String> items) {
      if (items.isEmpty) return;
      widgets.add(
        Padding(
          padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 16, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 8),
              Icon(icon, size: 14, color: color),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
      for (final tip in items) {
        widgets.add(
          _CoachingTipCard(tip: tip, index: animIndex)
              .animate(delay: Duration(milliseconds: 100 * animIndex))
              .fadeIn(duration: 400.ms)
              .slideX(begin: 0.05),
        );
        animIndex++;
      }
    }

    addGroup('STRENGTHS', AppColors.success, Icons.star, strengths);
    addGroup('IMPROVE', AppColors.warning, Icons.trending_up, improve);
    addGroup('META INTEL', AppColors.accent, Icons.gamepad, meta);
    addGroup('INSIGHTS', AppColors.secondary, Icons.lightbulb_outline, general);

    return widgets;
  }

  void _showAchievementPopups(List<dynamic> achievements) async {
    for (var a in achievements) {
      if (!mounted) return;
      AchievementPopup.show(context, a);
      await Future.delayed(Duration(seconds: 5));
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncResult = ref.watch(analysisProvider(widget.analysisId));

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
          child: Text('ANALYSIS RESULTS', style: AppTextStyles.brandSmall),
        ),
      ),
      body: asyncResult.when(
        loading: () => _buildShimmer(),
        error: (err, _) => _buildError(err.toString()),
        data: (result) => Stack(
          children: [
            AnimatedGradientBackground(),
            _buildBody(context, result),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: [
                  AppColors.primary,
                  AppColors.secondary,
                  AppColors.accent,
                  AppColors.success,
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: asyncResult.hasValue && asyncResult.value != null
          ? SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: ShareResultsButton(result: asyncResult.value!),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(BuildContext context, AnalysisResult result) {
    final gradeColor = AppColors.gradeColor(result.letterGrade);
    final gameColor = AppColors.gameColor(result.gameType);
    final previousAsync = ref.watch(previousAnalysisProvider((widget.analysisId, result.gameType)));
    final previousPatternScores = <String, double>{};
    double? previousOverallScore;
    previousAsync.whenData((prev) {
      if (prev != null) {
        previousOverallScore = prev.features.overallScore;
        for (final p in prev.features.movementPatterns) {
          previousPatternScores[p.patternName] = p.score;
        }
      }
    });
    final baseUrl = ref.watch(baseUrlProvider);

    // Parse the actual root URL cleanly
    String parsedVideoUrl = '';
    if (result.videoUrl != null && result.videoUrl!.isNotEmpty) {
      final rootUrl = baseUrl.endsWith('/api/v1') 
          ? baseUrl.substring(0, baseUrl.length - 7) 
          : baseUrl;
      parsedVideoUrl = result.videoUrl!.startsWith('/') 
          ? '$rootUrl${result.videoUrl}' 
          : '$rootUrl/${result.videoUrl}';
    }

    // Initialize video controller if we have a video URL
    if (parsedVideoUrl.isNotEmpty && _videoPlayerController == null) {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(parsedVideoUrl));
      // Let AnalysisVideoPlayer handle the initialization sequence safely.
    }

    // Function to seek to a specific timestamp (in seconds)
    void seekToTimestamp(double timestampSeconds) {
      if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
        _videoPlayerController!.seekTo(Duration(seconds: timestampSeconds.toInt()));
        if (!_videoPlayerController!.value.isPlaying) {
          _videoPlayerController!.play();
        }
      }
      // Auto-scroll to video player
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).padding.bottom + 80,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // XP announcement
            if (widget.gamificationResult != null)
              Center(
                    child: Text(
                      '+${widget.gamificationResult!.xpEarned} XP EARNED',
                      style: AppTextStyles.brandSmall,
                    ),
                  )
                  .animate(delay: 800.ms)
                  .slideY(
                    begin: 0.5,
                    duration: 600.ms,
                    curve: Curves.easeOutBack,
                  )
                  .fadeIn(),

            // Video player
            if (parsedVideoUrl.isNotEmpty)
              AnalysisVideoPlayer(
                videoUrl: parsedVideoUrl,
                externalController: _videoPlayerController,
                onSeek: (position) {
                  if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
                    _videoPlayerController!.seekTo(position);
                  }
                },
              ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.08),

            SizedBox(height: 16),

            // ── HEADER CARD ──
            GlassContainer(
              borderColor: gameColor.withValues(alpha: 0.4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [gameColor.withValues(alpha: 0.2), Colors.transparent],
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: gameColor.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome, size: 12, color: gameColor),
                                  SizedBox(width: 4),
                                  Text(
                                    'GHOST COACH VISION AI',
                                    style: TextStyle(
                                      color: gameColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                GameIcon(gameType: result.gameType, size: 20),
                                SizedBox(width: 6),
                                Text(
                                  '${result.gameType.toUpperCase()} ANALYSIS',
                                  style: TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 10,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              'SESSION REPORT',
                              style: AppTextStyles.brandSmall,
                            ),
                          ],
                        ),
                      ),
                      _GradeBadge(grade: result.letterGrade, color: gradeColor, score: result.features.overallScore),
                    ],
                  ),
                  if (result.sessionSummary.isNotEmpty) ...[
                    SizedBox(height: 14),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(left: BorderSide(color: gradeColor, width: 3)),
                      ),
                      child: Text(
                        result.sessionSummary,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 12, color: AppColors.textTertiary),
                      SizedBox(width: 4),
                      Text(
                        'Analyzed in ${result.processingTimeSeconds.toStringAsFixed(1)}s',
                        style: AppTextStyles.mono.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                      if (previousOverallScore != null) ...[
                        SizedBox(width: 12),
                        _DeltaChip(
                          current: result.features.overallScore,
                          previous: previousOverallScore!,
                          label: 'vs last',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08),

            SizedBox(height: 16),

            // ── SCORE + RADAR ──
            LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GlassContainer(
                            height: 240,
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Text(
                                  'PERFORMANCE',
                                  style: AppTextStyles.brandSmall.copyWith(fontSize: 10),
                                ),
                                Expanded(
                                  child: ScoreGauge(
                                    score: result.features.overallScore,
                                    letterGrade: result.letterGrade,
                                    gradeColor: gradeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GlassContainer(
                            height: 240,
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TACTICAL RADAR',
                                  style: AppTextStyles.brandSmall.copyWith(fontSize: 10),
                                ),
                                const SizedBox(height: 4),
                                Expanded(
                                  child: RadarChartWidget(
                                    patterns: result.features.movementPatterns,
                                    gameType: result.gameType,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            )
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms)
            .slideY(begin: 0.08),

            SizedBox(height: 20),

            // ── MOVEMENT PATTERNS ──
            if (result.features.movementPatterns.isNotEmpty) ...[
              _SectionHeader(
                icon: Icons.radar,
                title: 'MOVEMENT PATTERNS',
                color: AppColors.secondary,
              ),
              SizedBox(height: 12),
              // 2-column grid
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: result.features.movementPatterns
                    .map(
                      (p) => ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: 140,
                          maxWidth: (MediaQuery.of(context).size.width - 52) / 2,
                        ),
                        child: _PatternCard(
                          pattern: p,
                          previousScore: previousPatternScores[p.patternName],
                        ),
                      ),
                    )
                    .toList(),
              ),
              SizedBox(height: 24),
            ],

            // ── PHASE ANALYSIS ──
            if (result.phaseAnalysis.isNotEmpty) ...[
              _SectionHeader(
                icon: Icons.timeline,
                title: 'PHASE ANALYSIS',
                color: AppColors.secondary,
              ),
              SizedBox(height: 12),
              SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: result.phaseAnalysis.length,
                  separatorBuilder: (_, _) => SizedBox(width: 10),
                  itemBuilder: (_, i) =>
                      _PhaseTile(phase: result.phaseAnalysis[i]),
                ),
              ),
              SizedBox(height: 24),
            ],

            // ── STORYBOARD ──
            if (result.features.storyboardFrames.isNotEmpty) ...[
              _SectionHeader(
                icon: Icons.movie_filter,
                title: 'VISUAL STORYBOARD',
                color: AppColors.accent,
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.swipe, size: 14, color: AppColors.textTertiary),
                  SizedBox(width: 6),
                  Text(
                    'Swipe through frames • Tap to jump to timestamp',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                  ),
                ],
              ),
              SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: ListView.separated(
                  controller: _storyboardScrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: result.features.storyboardFrames.length,
                  separatorBuilder: (_, _) => SizedBox(width: 12),
                  itemBuilder: (_, i) => _StoryboardCard(
                    frame: result.features.storyboardFrames[i],
                    index: i + 1,
                    total: result.features.storyboardFrames.length,
                    onTap: () => seekToTimestamp(result.features.storyboardFrames[i].timestamp),
                  ),
                ),
              ),
              // Frame indicator dots
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  result.features.storyboardFrames.length,
                  (i) => AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    width: i == _activeStoryboardIndex ? 16 : 6,
                    height: 6,
                    margin: EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: i == _activeStoryboardIndex
                          ? AppColors.accent
                          : AppColors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),
            ],

            // ── KEY MOMENTS ──
            if (result.features.keyMoments.isNotEmpty) ...[
              _SectionHeader(
                icon: Icons.bolt,
                title: 'KEY MOMENTS',
                color: Colors.amber,
              ),
              SizedBox(height: 12),
              ...result.features.keyMoments.map((m) => _MomentTile(
                moment: m,
                onTap: () => seekToTimestamp(m.timestamp),
              )),
              SizedBox(height: 24),
            ],

            // ── COACHING TIPS ──
            if (result.recommendations.isNotEmpty) ...[
              _SectionHeader(
                icon: Icons.psychology,
                title: 'AI COACH TIPS',
                color: AppColors.primary,
              ),
              SizedBox(height: 12),
              ..._buildGroupedTips(result.recommendations),
            ],

            SizedBox(height: 32),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/meta/${result.gameType}'),
                icon: Icon(
                  Icons.explore,
                  color: AppColors.secondary,
                  size: 20,
                ),
                label: Text(
                  'VIEW CURRENT META',
                  style: AppTextStyles.brandSmall,
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.secondary.withValues(alpha: 0.5),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: AppColors.surface,
                ),
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Stack(
      children: [
        AnimatedGradientBackground(),
        SafeArea(
          child: Shimmer.fromColors(
            baseColor: Colors.white.withValues(alpha: 0.05),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    margin: EdgeInsets.only(bottom: 16),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String error) {
    return Stack(
      children: [
        AnimatedGradientBackground(),
        Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: GlassContainer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 56,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Analysis Failed',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () =>
                        ref.invalidate(analysisProvider(widget.analysisId)),
                    child: Text('RETRY'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── SHARED WIDGETS ───

class _GradeBadge extends StatelessWidget {
  final String grade;
  final Color color;
  final double score;
  const _GradeBadge({required this.grade, required this.color, required this.score});

  String _rankLabel(double s) {
    if (s >= 90) return 'GHOST ELITE';
    if (s >= 80) return 'DIAMOND';
    if (s >= 70) return 'PLATINUM';
    if (s >= 50) return 'GOLD';
    return 'RECRUIT';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 12),
            ],
          ),
          alignment: Alignment.center,
          child: Text(grade, style: AppTextStyles.brandSmall),
        ),
        SizedBox(height: 6),
        Text(
          _rankLabel(score),
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            SizedBox(width: 10),
            Text(title, style: AppTextStyles.brandSmall),
          ],
        ),
        SizedBox(height: 4),
        Container(
          height: 2,
          width: 40,
          margin: EdgeInsets.only(left: 38),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.0)]),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }
}

class _PatternCard extends StatelessWidget {
  final MovementPattern pattern;
  final double? previousScore;
  const _PatternCard({required this.pattern, this.previousScore});

  @override
  Widget build(BuildContext context) {
    final gradeColor = AppColors.gradeColor(pattern.grade);

    return GlassContainer(
      padding: EdgeInsets.all(12),
      borderRadius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(pattern.icon, style: TextStyle(fontSize: 18)),
              Spacer(),
              if (previousScore != null)
                Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: _DeltaChip(
                    current: pattern.score,
                    previous: previousScore!,
                  ),
                ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: gradeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: gradeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  pattern.grade,
                  style: TextStyle(
                    color: gradeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            pattern.patternName.replaceAll('_', ' ').toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.8,
              color: AppColors.textPrimary,
            ),
          ),
          if (pattern.description.isNotEmpty) ...[
            SizedBox(height: 4),
            Text(
              pattern.description,
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pattern.score / 100,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation(gradeColor),
              minHeight: 5,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '${pattern.score.toStringAsFixed(0)} / 100',
            style: AppTextStyles.brandSmall,
          ),
        ],
      ),
    );
  }
}

class _PhaseTile extends StatelessWidget {
  final PhaseAnalysis phase;
  const _PhaseTile({required this.phase});

  @override
  Widget build(BuildContext context) {
    Color accent = AppColors.success;
    if (phase.paceRating.contains('Passive')) accent = AppColors.secondary;
    if (phase.paceRating.contains('Aggressive')) accent = AppColors.error;

    return GlassContainer(
      width: 220,
      padding: EdgeInsets.all(14),
      borderRadius: 12,
      borderColor: accent.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  phase.phaseName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                phase.timeRange,
                style: TextStyle(color: AppColors.textTertiary, fontSize: 10),
              ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              phase.paceRating.toUpperCase(),
              style: TextStyle(
                color: accent,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: Text(
              phase.description,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              overflow: TextOverflow.fade,
            ),
          ),
        ],
      ),
    );
  }
}

class _MomentTile extends StatelessWidget {
  final KeyMoment moment;
  final VoidCallback? onTap;
  const _MomentTile({required this.moment, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isHigh = moment.intensity >= 0.7;
    final isMedium = moment.intensity >= 0.4;
    final accentColor = isHigh
        ? Colors.amber
        : (isMedium ? AppColors.secondary : AppColors.accent);
    final hasAnnotatedFrame = moment.annotatedFrame != null && moment.annotatedFrame!.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: GlassContainer(
          padding: EdgeInsets.all(14),
          borderRadius: 12,
          borderColor: isHigh ? Colors.amber.withValues(alpha: 0.25) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: intensity dot + moment type + timestamp
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 10 + (moment.intensity * 8),
                    height: 10 + (moment.intensity * 8),
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                      boxShadow: isHigh
                          ? [BoxShadow(color: Colors.amber.withValues(alpha: 0.4), blurRadius: 8)]
                          : null,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      moment.momentType.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${moment.timestamp}s',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              // Description
              Padding(
                padding: EdgeInsets.only(left: 30),
                child: Text(
                  moment.description,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              // Confidence/Intensity bar
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.only(left: 30),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: moment.intensity,
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          valueColor: AlwaysStoppedAnimation(accentColor.withValues(alpha: 0.7)),
                          minHeight: 3,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '${(moment.intensity * 100).toInt()}%',
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              // Visual Analysis Frame
              if (hasAnnotatedFrame) ...[
                SizedBox(height: 12),
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      base64Decode(moment.annotatedFrame!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(Icons.broken_image, color: AppColors.textTertiary, size: 40),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, color: AppColors.accent, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'VISION AI CAPTURE',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.touch_app, color: AppColors.textTertiary, size: 12),
                        SizedBox(width: 3),
                        Text(
                          'TAP TO SEEK',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachingTipCard extends StatelessWidget {
  final String tip;
  final int index;
  const _CoachingTipCard({required this.tip, required this.index});

  String _tipEmoji(String t) {
    final l = t.toLowerCase();
    if (l.contains('meta') || l.contains('🎯')) return '🎮';
    if (l.contains('mindset') || l.contains('🧠')) return '🧠';
    if (l.contains('incredible') ||
        l.contains('strength') ||
        l.contains('greatest')) {
      return '💪';
    }
    if (l.contains('drill') || l.contains('practice')) return '🏋️';
    return '📈';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: GlassContainer(
        padding: EdgeInsets.all(14),
        borderRadius: 12,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(_tipEmoji(tip), style: TextStyle(fontSize: 16)),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                tip,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryboardCard extends StatelessWidget {
  final StoryboardFrame frame;
  final int index;
  final int total;
  final VoidCallback onTap;

  const _StoryboardCard({
    required this.frame,
    required this.index,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
          color: Colors.black45,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              base64Decode(frame.image),
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const [0.0, 0.4, 0.7],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      frame.label.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${frame.timestamp}s',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              child: Text(
                'FRAME $index/$total',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white54,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final double current;
  final double previous;
  final String? label;
  const _DeltaChip({required this.current, required this.previous, this.label});

  @override
  Widget build(BuildContext context) {
    final delta = current - previous;
    if (delta.abs() < 0.5) return SizedBox.shrink();

    final isPositive = delta > 0;
    final color = isPositive ? AppColors.success : AppColors.error;
    final icon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;
    final text = '${isPositive ? '+' : ''}${delta.toStringAsFixed(0)}${label != null ? ' $label' : ''}';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}