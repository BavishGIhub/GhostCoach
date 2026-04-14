import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../domain/repositories/analysis_repository.dart';
import '../../../domain/models/analysis_result.dart';
import '../../gamification/application/gamification_service.dart';

part 'loading_controller.g.dart';

class LoadingState {
  final bool isComplete;
  final AnalysisResult? result;
  final String? error;
  final GamificationResult? gamificationResult;

  LoadingState({
    this.isComplete = false,
    this.result,
    this.error,
    this.gamificationResult,
  });
}

@riverpod
class LoadingController extends _$LoadingController {
  @override
  LoadingState build(String analysisId) {
    Future.microtask(() => _loadResult(analysisId));
    return LoadingState();
  }

  Future<void> _loadResult(String analysisId) async {
    try {
      final cache = ref.read(analysisResultCacheProvider);
      final cachedResult = cache[analysisId];

      if (cachedResult != null) {
        debugPrint('✅ Found cached result for $analysisId');
        await _processResult(cachedResult);
        return;
      }

      debugPrint('⚠️ Result not found in cache for $analysisId');
      state = LoadingState(
        error: "Analysis result not found. Please try uploading again.",
      );
    } catch (e, stack) {
      debugPrint('🔴 LOADING ERROR: $e');
      debugPrint('🔴 STACK: $stack');
      state = LoadingState(error: "Failed to load results: ${e.toString()}");
    }
  }

  Future<void> _processResult(AnalysisResult result) async {
    try {
      final gamification = ref.read(gamificationServiceProvider);
      final gamiResult = await gamification.processAnalysis(result);

      state = LoadingState(
        isComplete: true,
        result: result,
        gamificationResult: gamiResult,
      );
    } catch (e) {
      debugPrint('⚠️ Gamification failed, continuing without it: $e');
      state = LoadingState(
        isComplete: true,
        result: result,
        gamificationResult: null,
      );
    }
  }

  void retry() {
    state = LoadingState();
    _loadResult(analysisId);
  }
}