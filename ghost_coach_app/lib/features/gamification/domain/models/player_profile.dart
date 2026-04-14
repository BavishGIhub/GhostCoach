import 'package:freezed_annotation/freezed_annotation.dart';

part 'player_profile.freezed.dart';
part 'player_profile.g.dart';

@freezed
abstract class PlayerProfile with _$PlayerProfile {
  const PlayerProfile._();

  const factory PlayerProfile({
    @Default(0) int totalXp,
    @Default(1) int level,
    @Default('Rookie') String title,
    @Default(0) int analysesCount,
  }) = _PlayerProfile;

  factory PlayerProfile.fromJson(Map<String, dynamic> json) =>
      _$PlayerProfileFromJson(json);

  int get xpForNextLevel => level * 100;

  int get currentLevelXp {
    int xpBeforeThisLevel = 0;
    for (int i = 1; i < level; i++) {
      xpBeforeThisLevel += i * 100;
    }
    return totalXp - xpBeforeThisLevel;
  }

  static String getTitleForLevel(int level) {
    if (level <= 5) return "Rookie";
    if (level <= 10) return "Rising Star";
    if (level <= 15) return "Competitor";
    if (level <= 20) return "Veteran";
    if (level <= 25) return "Elite";
    if (level <= 30) return "Master";
    if (level <= 40) return "Grandmaster";
    return "Legend";
  }
}