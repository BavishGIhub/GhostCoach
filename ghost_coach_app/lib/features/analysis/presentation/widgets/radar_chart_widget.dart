import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../domain/models/analysis_result.dart';

class RadarChartWidget extends StatelessWidget {
  final List<MovementPattern> patterns;

  const RadarChartWidget({super.key, required this.patterns});

  String _getShortName(String name) {
    if (name.toLowerCase().contains('consistency')) return 'CNS';
    if (name.toLowerCase().contains('reaction')) return 'RXN';
    if (name.toLowerCase().contains('positioning')) return 'POS';
    if (name.toLowerCase().contains('decision')) return 'DEC';
    if (name.toLowerCase().contains('aggression')) return 'AGG';
    if (name.toLowerCase().contains('composure')) return 'CMP';
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