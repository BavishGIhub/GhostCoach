import 'package:freezed_annotation/freezed_annotation.dart';

part 'key_moment.freezed.dart';
part 'key_moment.g.dart';

@freezed
abstract class KeyMoment with _$KeyMoment {
  const factory KeyMoment({
    required double timestamp,
    @JsonKey(name: 'moment_type') required String momentType,
    required double confidence,
    required String description,
    @Default(0.5) double intensity,
    @JsonKey(name: 'annotated_frame') String? annotatedFrame,
  }) = _KeyMoment;

  factory KeyMoment.fromJson(Map<String, dynamic> json) =>
      _$KeyMomentFromJson(json);
}