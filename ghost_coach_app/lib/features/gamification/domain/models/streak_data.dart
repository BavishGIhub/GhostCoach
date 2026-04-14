import 'package:freezed_annotation/freezed_annotation.dart';

part 'streak_data.freezed.dart';
part 'streak_data.g.dart';

@freezed
abstract class StreakData with _$StreakData {
  const StreakData._();

  const factory StreakData({
    @Default(0) int currentStreak,
    @Default(0) int longestStreak,
    DateTime? lastAnalysisDate,
    @Default(true) bool freezeAvailable,
  }) = _StreakData;

  factory StreakData.fromJson(Map<String, dynamic> json) =>
      _$StreakDataFromJson(json);

  double get xpMultiplier {
    if (currentStreak >= 7) return 2.0;
    if (currentStreak >= 3) return 1.5;
    if (currentStreak >= 2) return 1.2;
    return 1.0;
  }

  bool isStreakActive(DateTime now) {
    if (lastAnalysisDate == null) return false;
    final difference = now.difference(lastAnalysisDate!).inDays;
    return difference == 0 ||
        difference == 1 ||
        (difference == 2 && freezeAvailable);
  }

  bool isAboutToBreak(DateTime now) {
    if (lastAnalysisDate == null || currentStreak == 0) return false;
    final lastDate = DateTime(
      lastAnalysisDate!.year,
      lastAnalysisDate!.month,
      lastAnalysisDate!.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(lastDate).inDays ==
        1; // Played yesterday, but not yet today
  }
}