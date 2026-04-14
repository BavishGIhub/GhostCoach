import 'package:freezed_annotation/freezed_annotation.dart';

part 'phase_analysis.freezed.dart';
part 'phase_analysis.g.dart';

@freezed
abstract class PhaseAnalysis with _$PhaseAnalysis {
  const factory PhaseAnalysis({
    @JsonKey(name: 'phase_name') required String phaseName,
    @JsonKey(name: 'time_range') required String timeRange,
    @JsonKey(name: 'pace_rating') required String paceRating,
    required String description,
  }) = _PhaseAnalysis;

  factory PhaseAnalysis.fromJson(Map<String, dynamic> json) =>
      _$PhaseAnalysisFromJson(json);
}