import 'package:freezed_annotation/freezed_annotation.dart';

part 'movement_pattern.freezed.dart';
part 'movement_pattern.g.dart';

@freezed
abstract class MovementPattern with _$MovementPattern {
  const factory MovementPattern({
    @JsonKey(name: 'pattern_name') required String patternName,
    required double score,
    required String description,
    @Default("🎮") String icon,
    @Default("C") String grade,
  }) = _MovementPattern;

  factory MovementPattern.fromJson(Map<String, dynamic> json) =>
      _$MovementPatternFromJson(json);
}