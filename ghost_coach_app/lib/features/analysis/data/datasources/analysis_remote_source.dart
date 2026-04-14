import 'package:dio/dio.dart';
import '../../../../domain/models/analysis_result.dart';

class AnalysisRemoteSource {
  final Dio _dio;

  AnalysisRemoteSource(this._dio);

  Future<String> uploadVideo(
    String filePath,
    String? gameType, {
    ProgressCallback? onSendProgress,
  }) async {
    final map = <String, dynamic>{
      'file': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split('/').last.split('\\').last,
      ),
    };
    if (gameType != null) {
      map['game_type'] = gameType;
    }
    final formData = FormData.fromMap(map);

    final response = await _dio.post(
      '/analyze',
      data: formData,
      onSendProgress: onSendProgress,
    );
    if (response.statusCode == 200 || response.statusCode == 202) {
      return response.data['analysis_id'] as String;
    }
    throw Exception('Failed to upload video: ${response.statusCode}');
  }

  Future<AnalysisResult?> getAnalysis(String analysisId) async {
    try {
      final response = await _dio.get('/analysis/$analysisId');

      if (response.statusCode == 202) {
        return null;
      } else if (response.statusCode == 200) {
        return AnalysisResult.fromJson(response.data);
      } else {
        throw Exception('Unexpected status code: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Analysis not found (404)');
      } else if (e.response?.statusCode == 500) {
        throw Exception('Server error (500) - Analysis failed on backend.');
      }
      throw Exception('Network error: ${e.message}');
    }
  }
}