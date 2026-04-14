import 'package:freezed_annotation/freezed_annotation.dart';

import 'key_moment.dart';
import 'movement_pattern.dart';
import 'phase_analysis.dart';

export 'key_moment.dart';
export 'movement_pattern.dart';
export 'phase_analysis.dart';

part 'analysis_result.freezed.dart';
part 'analysis_result.g.dart';

@freezed
abstract class AnalysisResult with _$AnalysisResult {
  const factory AnalysisResult({
    required String status,
    @JsonKey(name: 'analysis_id') required String analysisId,
    @JsonKey(name: 'processing_time_seconds')
    required double processingTimeSeconds,
    required AnalysisFeatures features,
    required List<String> recommendations,
    @JsonKey(name: 'inference_device') required String inferenceDevice,
    required String timestamp,
    @JsonKey(name: 'game_type') @Default("general") String gameType,
    @JsonKey(name: 'letter_grade') @Default("C") String letterGrade,
    @JsonKey(name: 'phase_analysis')
    @Default([])
    List<PhaseAnalysis> phaseAnalysis,
    @JsonKey(name: 'session_summary') @Default("") String sessionSummary,
    @JsonKey(name: 'video_url') @Default(null) String? videoUrl,
  }) = _AnalysisResult;

  factory AnalysisResult.fromJson(Map<String, dynamic> json) =>
      _$AnalysisResultFromJson(json);
}

@freezed
abstract class AnalysisFeatures with _$AnalysisFeatures {
  const factory AnalysisFeatures({
    @JsonKey(name: 'embedding_shape') required List<int> embeddingShape,
    @JsonKey(name: 'key_moments') required List<KeyMoment> keyMoments,
    @JsonKey(name: 'movement_patterns')
    required List<MovementPattern> movementPatterns,
    @JsonKey(name: 'overall_score') required double overallScore,
    @JsonKey(name: 'storyboard_frames')
    @Default([])
    List<StoryboardFrame> storyboardFrames,
  }) = _AnalysisFeatures;

  factory AnalysisFeatures.fromJson(Map<String, dynamic> json) =>
      _$AnalysisFeaturesFromJson(json);
}

@freezed
abstract class StoryboardFrame with _$StoryboardFrame {
  const factory StoryboardFrame({
    required double timestamp,
    required String label,
    required String image,
  }) = _StoryboardFrame;

  factory StoryboardFrame.fromJson(Map<String, dynamic> json) =>
      _$StoryboardFrameFromJson(json);
}