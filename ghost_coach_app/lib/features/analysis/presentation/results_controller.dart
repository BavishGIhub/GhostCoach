import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/analysis_result.dart';
import '../../../domain/repositories/analysis_repository.dart';

final resultsControllerProvider = FutureProvider.family<AnalysisResult, String>(
  (ref, id) async {
    final repo = ref.watch(analysisRepositoryProvider);
    final result = await repo.checkAnalysisStatus(id);
    if (result == null) {
      throw Exception('Analysis not yet complete or not found');
    }
    return result;
  },
);