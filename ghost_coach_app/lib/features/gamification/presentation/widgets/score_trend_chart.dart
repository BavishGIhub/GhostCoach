import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../database/app_database.dart';
import '../../../../core/theme/ghost_theme.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';

class ScoreTrendChart extends StatefulWidget {
  final List<Analysis> analyses;

  const ScoreTrendChart({super.key, required this.analyses});

  @override
  State<ScoreTrendChart> createState() => _ScoreTrendChartState();
}

class _ScoreTrendChartState extends State<ScoreTrendChart> {
  String _selectedGame = 'All';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    // Filter and sort analyses
    var filtered = widget.analyses;
    if (_selectedGame != 'All') {
      filtered = widget.analyses
          .where(
            (a) => a.gameType?.toLowerCase() == _selectedGame.toLowerCase(),
          )
          .toList();
    }

    filtered.sort(
      (a, b) => a.createdAt.compareTo(b.createdAt),
    ); // Oldest to newest

    // Calculate Personal Best
    double personalBest = 0;
    for (var a in filtered) {
      if (a.overallScore > personalBest) personalBest = a.overallScore;
    }

    final hasEnoughData = filtered.length >= 2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ExtraColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'PERFORMANCE TREND',
                  style: AppTextStyles.brandSmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedGame,
                    icon: Icon(Icons.keyboard_arrow_down, color: AppColors.primary, size: 16),
                    dropdownColor: AppColors.background,
                    style: AppTextStyles.sectionLabel.copyWith(fontSize: 10, color: AppColors.primary),
                    items: ['All', 'Fortnite', 'Valorant', 'Warzone', 'Soccer'].map((
                      String value,
                    ) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedGame = newValue!;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),

          if (hasEnoughData) ...[
            Text(
              'PB: ${personalBest.toStringAsFixed(1)}',
              style: TextStyle(
                color: theme.tertiary,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(height: 200, child: _buildChart(filtered, theme)),
          ] else ...[
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.show_chart,
                    color: theme.onSurface.withValues(alpha: 0.2),
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Analyze more clips to see your trend',
                    style: TextStyle(
                      color: theme.onSurface.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildChart(List<Analysis> data, ColorScheme theme) {
    if (data.isEmpty) return const SizedBox();

    List<FlSpot> spots = [];
    double minY = 100;
    double maxY = 0;

    for (int i = 0; i < data.length; i++) {
      final score = data[i].overallScore;
      spots.add(FlSpot(i.toDouble(), score));
      if (score < minY) minY = score;
      if (score > maxY) maxY = score;
    }

    // Determine trend color (last point vs first point in window)
    final trendIsUp =
        data.length > 1 && data.last.overallScore >= data.first.overallScore;
    final lineColor = trendIsUp ? Colors.greenAccent : Colors.redAccent;
    final gradientColors = [
      lineColor.withValues(alpha: 0.3),
      lineColor.withValues(alpha: 0.0),
    ];

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.white.withValues(alpha: 0.1),
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < data.length) {
                  final date = data[value.toInt()].createdAt;
                  // Only show label if it's start, middle, or end to prevent crowding
                  if (value.toInt() == 0 ||
                      value.toInt() == data.length - 1 ||
                      value.toInt() == data.length ~/ 2) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('MM/dd').format(date),
                        style: TextStyle(
                          color: theme.onSurface.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 20,
              reservedSize: 35,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: theme.onSurface.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: (minY - 10).clamp(0.0, 100.0),
        maxY: (maxY + 10).clamp(0.0, 100.0),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lineColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => ExtraColors.surfaceContainerHigh,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                final date = data[touchedSpot.x.toInt()].createdAt;
                return LineTooltipItem(
                  'Score: ${touchedSpot.y.toStringAsFixed(1)}\n${DateFormat('MMM d').format(date)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    );
  }
}