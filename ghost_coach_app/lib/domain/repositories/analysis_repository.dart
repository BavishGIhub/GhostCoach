import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../models/analysis_result.dart';

// Cache for storing analysis results
class AnalysisResultCache extends Notifier<Map<String, AnalysisResult>> {
  @override
  Map<String, AnalysisResult> build() => {};

  void addResult(String id, AnalysisResult result) {
    state = {...state, id: result};
  }
}

final analysisResultCacheProvider =
    NotifierProvider<AnalysisResultCache, Map<String, AnalysisResult>>(
      AnalysisResultCache.new,
    );

final analysisRepositoryProvider = Provider.autoDispose<AnalysisRepository>((
  ref,
) {
  return AnalysisRepository(ref.watch(dioProvider));
});

class AnalysisRepository {
  final Dio _dio;

  AnalysisRepository(this._dio);

  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get(
        '/health',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Uploads video and returns the FULL analysis result
  /// The server processes synchronously and returns everything in one response
  Future<AnalysisResult> uploadAndAnalyze(
    File file,
    String gameType, {
    String? soccerPosition,
    ProgressCallback? onSendProgress,
  }) async {
    final fileName = file.path.split('/').last.split('\\').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
    });

    final response = await _dio.post(
      '/analyze',
      queryParameters: {
        'game_type': gameType,
      },
      data: formData,
      onSendProgress: onSendProgress,
    );

    // Server returns the FULL result directly - no polling needed!
    return AnalysisResult.fromJson(response.data);
  }

  // Keep old method for backwards compatibility
  Future<String> uploadVideo(
    File file,
    String gameType, {
    String? soccerPosition,
    ProgressCallback? onSendProgress,
  }) async {
    final result = await uploadAndAnalyze(
      file,
      gameType,
      soccerPosition: soccerPosition,
      onSendProgress: onSendProgress,
    );
    return result.analysisId;
  }

  /// Returns null if still processing (202), or AnalysisResult if complete (200)
  Future<AnalysisResult?> checkAnalysisStatus(String analysisId) async {
    try {
      final response = await _dio.get(
        '/analysis/$analysisId',
        options: Options(
          validateStatus: (status) => status == 200 || status == 202,
        ),
      );

      if (response.statusCode == 202) {
        return null;
      }
      return AnalysisResult.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }
}