import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../history/presentation/history_controller.dart';

class HomeStats {
  final int totalAnalyses;
  final double avgScore;
  final int bestScore;

  HomeStats({this.totalAnalyses = 0, this.avgScore = 0.0, this.bestScore = 0});
}

// Stats provider derived from history
final homeStatsProvider = Provider.autoDispose<HomeStats>((ref) {
  final historyAsync = ref.watch(historyListProvider);

  return historyAsync.maybeWhen(
    data: (sessions) {
      if (sessions.isEmpty) return HomeStats();

      final total = sessions.length;
      final sum = sessions.fold<double>(
        0,
        (prev, curr) => prev + curr.overallScore,
      );
      final best = sessions.fold<double>(
        0,
        (prev, curr) => curr.overallScore > prev ? curr.overallScore : prev,
      );

      return HomeStats(
        totalAnalyses: total,
        avgScore: double.parse((sum / total).toStringAsFixed(1)),
        bestScore: best.round(),
      );
    },
    orElse: () => HomeStats(),
  );
});

// Health check provider
final healthCheckProvider = FutureProvider.autoDispose<bool>((ref) async {
  // Simulate health check or call /api/v1/health
  await Future.delayed(const Duration(seconds: 1));
  return true;
});