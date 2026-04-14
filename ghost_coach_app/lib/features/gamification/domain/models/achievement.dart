import 'package:freezed_annotation/freezed_annotation.dart';

part 'achievement.freezed.dart';
part 'achievement.g.dart';

enum AchievementCategory { beginner, skill, streak, improvement, gameSpecific }

@freezed
abstract class Achievement with _$Achievement {
  const factory Achievement({
    required String id,
    required String title,
    required String description,
    required AchievementCategory category,
    required String icon,
    @Default(false) bool isUnlocked,
    DateTime? unlockedAt,
  }) = _Achievement;

  factory Achievement.fromJson(Map<String, dynamic> json) =>
      _$AchievementFromJson(json);
}

class AchievementDefinitions {
  static const List<Achievement> all = [
    // BEGINNER
    Achievement(
      id: 'first_blood',
      title: 'First Blood',
      description: 'Complete your first analysis',
      category: AchievementCategory.beginner,
      icon: '🩸',
    ),
    Achievement(
      id: 'triple_threat',
      title: 'Triple Threat',
      description: 'Analyze 3 different games',
      category: AchievementCategory.beginner,
      icon: '🎲',
    ),
    Achievement(
      id: 'dedicated',
      title: 'Dedicated',
      description: 'Analyze 10 sessions total',
      category: AchievementCategory.beginner,
      icon: '📚',
    ),
    Achievement(
      id: 'social_butterfly',
      title: 'Social Butterfly',
      description: 'Share an analysis result',
      category: AchievementCategory.beginner,
      icon: '🦋',
    ),

    // SKILL
    Achievement(
      id: 'sharpshooter',
      title: 'Sharpshooter',
      description: 'Get reaction_speed score > 80',
      category: AchievementCategory.skill,
      icon: '🎯',
    ),
    Achievement(
      id: 'rock_steady',
      title: 'Rock Steady',
      description: 'Get consistency score > 85',
      category: AchievementCategory.skill,
      icon: '🪨',
    ),
    Achievement(
      id: 'big_brain',
      title: 'Big Brain',
      description: 'Get decision_quality score > 90',
      category: AchievementCategory.skill,
      icon: '🧠',
    ),
    Achievement(
      id: 'ice_cold',
      title: 'Ice Cold',
      description: 'Get composure score > 90',
      category: AchievementCategory.skill,
      icon: '🥶',
    ),
    Achievement(
      id: 's_tier',
      title: 'S-Tier',
      description: 'Get letter grade S on any analysis',
      category: AchievementCategory.skill,
      icon: '🏆',
    ),

    // TIME & STREAK
    Achievement(
      id: 'early_bird',
      title: 'Early Bird',
      description: 'Analyze a game before 8 AM',
      category: AchievementCategory.streak,
      icon: '🌅',
    ),
    Achievement(
      id: 'night_owl',
      title: 'Night Owl',
      description: 'Analyze a game after midnight',
      category: AchievementCategory.streak,
      icon: '🦉',
    ),
    Achievement(
      id: 'on_fire',
      title: 'On Fire',
      description: '7-day streak',
      category: AchievementCategory.streak,
      icon: '🔥',
    ),
    Achievement(
      id: 'unstoppable',
      title: 'Unstoppable',
      description: '30-day streak',
      category: AchievementCategory.streak,
      icon: '🚀',
    ),
    Achievement(
      id: 'legendary_dedication',
      title: 'Legendary Dedication',
      description: '100-day streak',
      category: AchievementCategory.streak,
      icon: '👑',
    ),

    // IMPROVEMENT
    Achievement(
      id: 'leveling_up',
      title: 'Leveling Up',
      description: 'Improve overall score by 10+ between two sessions',
      category: AchievementCategory.improvement,
      icon: '📈',
    ),
    Achievement(
      id: 'comeback_kid',
      title: 'Comeback Kid',
      description: 'Get score > 70 after getting score < 40',
      category: AchievementCategory.improvement,
      icon: '🔄',
    ),
    Achievement(
      id: 'perfect_week',
      title: 'Perfect Week',
      description: 'Average score > 75 across 7+ analyses in one week',
      category: AchievementCategory.improvement,
      icon: '🌟',
    ),

    // GAME-SPECIFIC
    Achievement(
      id: 'builder_pro',
      title: 'Builder Pro',
      description: 'Score > 80 in Fortnite',
      category: AchievementCategory.gameSpecific,
      icon: '🔨',
    ),
    Achievement(
      id: 'tactician',
      title: 'Tactician',
      description: 'Score > 80 in Valorant',
      category: AchievementCategory.gameSpecific,
      icon: '🎯',
    ),
    Achievement(
      id: 'warzone_winner',
      title: 'Warzone Winner',
      description: 'Score > 80 in Warzone',
      category: AchievementCategory.gameSpecific,
      icon: '🪂',
    ),
  ];
}