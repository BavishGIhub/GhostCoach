import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../domain/models/analysis_result.dart';

class RadarChartWidget extends StatelessWidget {
  final List<MovementPattern> patterns;
  final String gameType;

  const RadarChartWidget({
    super.key,
    required this.patterns,
    this.gameType = 'general',
  });

  static const _soccerLabels = {
    'movement_quality': 'MOV',
    'spatial_awareness': 'SPA',
    'ball_control': 'BALL',
    'transitions': 'TRN',
    'composure': 'CMP',
    'decision_making': 'DEC',
    'positioning': 'POS',
    'off_ball_movement': 'OBM',
    'pressing_intensity': 'PRS',
  };

  static const _fpsLabels = {
    'consistency': 'CNS',
    'reaction_time': 'RXN',
    'positioning': 'POS',
    'decision_making': 'DEC',
    'aggression': 'AGG',
    'composure': 'CMP',
    'crosshair_control': 'AIM',
    'movement_quality': 'MOV',
    'utility_usage': 'UTL',
  };

  static const _warzoneLabels = {
    'consistency': 'CNS',
    'reaction_time': 'RXN',
    'positioning': 'POS',
    'decision_making': 'DEC',
    'aggression': 'AGG',
    'composure': 'CMP',
    'looting_efficiency': 'LOT',
    'rotation_timing': 'ROT',
    'engagement_choice': 'ENG',
  };

  String _getShortName(String name) {
    final key = name.toLowerCase().replaceAll(' ', '_');
    final game = gameType.toLowerCase();

    if (game == 'soccer') {
      final match = _soccerLabels.entries.where((e) => key.contains(e.key));
      if (match.isNotEmpty) return match.first.value;
    } else if (game == 'valorant') {
      final match = _fpsLabels.entries.where((e) => key.contains(e.key));
      if (match.isNotEmpty) return match.first.value;
    } else if (game == 'warzone') {
      final match = _warzoneLabels.entries.where((e) => key.contains(e.key));
      if (match.isNotEmpty) return match.first.value;
    } else {
      final match = _fpsLabels.entries.where((e) => key.contains(e.key));
      if (match.isNotEmpty) return match.first.value;
    }

    if (name.length <= 3) return name.toUpperCase();
    return name.substring(0, 3).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (patterns.length < 3) {
      return Center(
        child: Text(
          'Not enough data for radar chart',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return RadarChart(
      RadarChartData(
        radarShape: RadarShape.polygon,
        dataSets: [
          RadarDataSet(
            fillColor: const Color(0xFF00E3FD).withValues(alpha: 0.15),
            borderColor: const Color(0xFF00E3FD),
            entryRadius: 3,
            dataEntries: patterns
                .map((p) => RadarEntry(value: p.score))
                .toList(),
            borderWidth: 2,
          ),
        ],
        tickCount: 3,
        ticksTextStyle: const TextStyle(color: Colors.transparent),
        tickBorderData: BorderSide(
          color: const Color(0xFF4B454E).withValues(alpha: 0.3),
        ),
        gridBorderData: BorderSide(
          color: const Color(0xFF4B454E).withValues(alpha: 0.3),
        ),
        radarBorderData: const BorderSide(color: Colors.transparent),
        getTitle: (index, angle) {
          if (index >= 0 && index < patterns.length) {
            final p = patterns[index];
            return RadarChartTitle(
              text: '${p.icon} ${_getShortName(p.patternName)}',
            );
          }
          return const RadarChartTitle(text: '');
        },
        titleTextStyle: const TextStyle(
          fontFamily: 'Space Grotesk',
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: Color(0xFF968E99),
        ),
      ),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutQuart,
    ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack);
  }
}
