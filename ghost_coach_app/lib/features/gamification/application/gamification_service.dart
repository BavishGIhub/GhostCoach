import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../database/app_database.dart';
import '../../../domain/models/analysis_result.dart';
import '../domain/models/player_profile.dart';
import '../domain/models/streak_data.dart';
import '../domain/models/achievement.dart';
import 'package:drift/drift.dart' as drift;

final gamificationServiceProvider = Provider<GamificationService>((ref) {
  final db = ref.watch(
    appDatabaseProvider,
  ); // Assuming this provider exists, let's just make sure we get the DB.
  return GamificationService(db);
});

// Using a simple provider for AppDatabase. Will add it if missing.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

class GamificationResult {
  final int xpEarned;
  final bool leveledUp;
  final List<Achievement> newlyUnlocked;

  GamificationResult({
    required this.xpEarned,
    required this.leveledUp,
    required this.newlyUnlocked,
  });
}

class GamificationService {
  final AppDatabase _db;

  GamificationService(this._db);

  String get _uid {
    return FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  }

  // Expose Streams for UI
  Stream<PlayerProfile> watchProfile() {
    return (_db.select(_db.playerProfiles)
          ..where((t) => t.id.equals(_uid)))
        .watchSingleOrNull()
        .map((entity) {
          if (entity == null) return const PlayerProfile();
          return PlayerProfile(
            totalXp: entity.totalXp,
            level: entity.level,
            title: entity.title,
            analysesCount: entity.analysesCount,
          );
        });
  }

  Stream<StreakData> watchStreak() {
    return (_db.select(_db.streakDataEntries)
          ..where((t) => t.id.equals(_uid)))
        .watchSingleOrNull()
        .map((entity) {
          if (entity == null) return const StreakData();
          return StreakData(
            currentStreak: entity.currentStreak,
            longestStreak: entity.longestStreak,
            lastAnalysisDate: entity.lastAnalysisDate,
            freezeAvailable: entity.freezeAvailable,
          );
        });
  }

  Stream<List<Achievement>> watchUnlockedAchievements() {
    return _db.select(_db.unlockedAchievements).watch().map((entities) {
      final prefix = '${_uid}_';
      final unlockedIds = entities
          .where((e) => e.achievementId.startsWith(prefix))
          .map((e) => e.achievementId.replaceFirst(prefix, ''))
          .toSet();
      return AchievementDefinitions.all.map((def) {
        return def.copyWith(isUnlocked: unlockedIds.contains(def.id));
      }).toList();
    });
  }

  Future<GamificationResult> processAnalysis(AnalysisResult result) async {
    final now = DateTime.now();

    // 1. Process Streak
    var streakEntity = await (_db.select(_db.streakDataEntries)
          ..where((t) => t.id.equals(_uid)))
        .getSingleOrNull();
    var currentStreak = streakEntity?.currentStreak ?? 0;
    var longestStreak = streakEntity?.longestStreak ?? 0;
    bool freezeAvailable = streakEntity?.freezeAvailable ?? true;

    final lastDate = streakEntity?.lastAnalysisDate;

    if (lastDate != null) {
      final difference = DateTime(now.year, now.month, now.day)
          .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
          .inDays;

      if (difference == 1) {
        currentStreak++; // Consecutive day
      } else if (difference == 2 && freezeAvailable) {
        currentStreak++; // Used freeze
        freezeAvailable = false;
      } else if (difference > 1) {
        currentStreak = 1; // Streak broken
      }
      // if difference == 0, already analyzed today, don't increment streak
    } else {
      currentStreak = 1; // First ever
    }

    if (currentStreak > longestStreak) longestStreak = currentStreak;

    await _db.into(_db.streakDataEntries).insertOnConflictUpdate(
      StreakDataEntriesCompanion(
        id: drift.Value(_uid),
        currentStreak: drift.Value(currentStreak),
        longestStreak: drift.Value(longestStreak),
        lastAnalysisDate: drift.Value(now),
        freezeAvailable: drift.Value(freezeAvailable),
      ),
    );

    // 2. Calculate XP
    final features = result.features;
    final baseXP = 50;
    final scoreXP = (features.overallScore * 2).toInt();
    final momentsXP = features.keyMoments.length * 10;
    int letterBonus = 0;
    if (result.letterGrade == 'S') letterBonus = 100;
    if (result.letterGrade == 'A') letterBonus = 50;

    double streakMultiplier = 1.0;
    if (currentStreak >= 7) {
      streakMultiplier = 2.0;
    } else if (currentStreak >= 3) {
      streakMultiplier = 1.5;
    } else if (currentStreak >= 2) {
      streakMultiplier = 1.2;
    }

    final xpEarned =
        ((baseXP + scoreXP + momentsXP + letterBonus) * streakMultiplier)
            .toInt();

    // 3. Process Profile (Level Up)
    var profileEntity = await (_db.select(_db.playerProfiles)
          ..where((t) => t.id.equals(_uid)))
        .getSingleOrNull();
    var currentXp = (profileEntity?.totalXp ?? 0) + xpEarned;
    var currentLevel = profileEntity?.level ?? 1;
    var analysesCount = (profileEntity?.analysesCount ?? 0) + 1;
    var title = profileEntity?.title ?? 'Rookie';

    bool leveledUp = false;
    while (true) {
      int xpForNext = currentLevel * 100;
      int xpBeforeThisLevel = 0;
      for (int i = 1; i < currentLevel; i++) {
        xpBeforeThisLevel += i * 100;
      }

      if (currentXp - xpBeforeThisLevel >= xpForNext) {
        currentLevel++;
        leveledUp = true;
      } else {
        break;
      }
    }

    if (leveledUp) {
      title = PlayerProfile.getTitleForLevel(currentLevel);
    }

    await _db.into(_db.playerProfiles).insertOnConflictUpdate(
      PlayerProfilesCompanion(
        id: drift.Value(_uid),
        totalXp: drift.Value(currentXp),
        level: drift.Value(currentLevel),
        title: drift.Value(title),
        analysesCount: drift.Value(analysesCount),
      ),
    );

    // 4. Process Achievements
    final unlocked = await _db.select(_db.unlockedAchievements).get();
    final prefix = '${_uid}_';
    final unlockedIds = unlocked
        .where((e) => e.achievementId.startsWith(prefix))
        .map((e) => e.achievementId.replaceFirst(prefix, ''))
        .toSet();
        
    List<Achievement> newlyUnlocked = [];

    // Helper to unlock
    Future<void> unlockBadge(String id) async {
      if (!unlockedIds.contains(id)) {
        await _db.into(_db.unlockedAchievements).insertOnConflictUpdate(
          UnlockedAchievementsCompanion(
            achievementId: drift.Value('$prefix$id'),
            unlockedAt: drift.Value(now),
          ),
        );
        newlyUnlocked.add(
          AchievementDefinitions.all.firstWhere((a) => a.id == id),
        );
        unlockedIds.add(id);
      }
    }

    // Beginner
    if (analysesCount == 1) await unlockBadge('first_blood');
    if (analysesCount >= 10) await unlockBadge('dedicated');
    // For triple_threat, need DB query for distinct gameTypes, skipping for brevity/assuming implemented later

    // Skill
    final rxn = features.movementPatterns
        .firstWhere(
          (p) => p.patternName.toLowerCase().contains('reaction'),
          orElse: () =>
              MovementPattern(patternName: '', score: 0, description: ''),
        )
        .score;
    if (rxn > 80) await unlockBadge('sharpshooter');

    final cns = features.movementPatterns
        .firstWhere(
          (p) => p.patternName.toLowerCase().contains('consistency'),
          orElse: () =>
              MovementPattern(patternName: '', score: 0, description: ''),
        )
        .score;
    if (cns > 85) await unlockBadge('rock_steady');

    final dec = features.movementPatterns
        .firstWhere(
          (p) => p.patternName.toLowerCase().contains('decision'),
          orElse: () =>
              MovementPattern(patternName: '', score: 0, description: ''),
        )
        .score;
    if (dec > 90) await unlockBadge('big_brain');

    final cmp = features.movementPatterns
        .firstWhere(
          (p) => p.patternName.toLowerCase().contains('composure'),
          orElse: () =>
              MovementPattern(patternName: '', score: 0, description: ''),
        )
        .score;
    if (cmp > 90) await unlockBadge('ice_cold');

    if (result.letterGrade == 'S') await unlockBadge('s_tier');

    // Time & Streak
    if (now.hour < 8) await unlockBadge('early_bird');
    if (now.hour == 0 || now.hour < 4) await unlockBadge('night_owl');
    if (currentStreak >= 7) await unlockBadge('on_fire');
    if (currentStreak >= 30) await unlockBadge('unstoppable');
    if (currentStreak >= 100) await unlockBadge('legendary_dedication');

    // Game Specific
    if (result.gameType.toLowerCase() == 'fortnite' &&
        features.overallScore > 80) {
      await unlockBadge('builder_pro');
    }
    if (result.gameType.toLowerCase() == 'valorant' &&
        features.overallScore > 80) {
      await unlockBadge('tactician');
    }
    if (result.gameType.toLowerCase() == 'warzone' &&
        features.overallScore > 80) {
      await unlockBadge('warzone_winner');
    }

    // For social_butterfly, we'll expose a separate method triggerShareAchievement()

    return GamificationResult(
      xpEarned: xpEarned,
      leveledUp: leveledUp,
      newlyUnlocked: newlyUnlocked,
    );
  }

  Future<void> triggerShareAchievement() async {
    final prefix = '${_uid}_';
    final unlocked = await _db.select(_db.unlockedAchievements).get();
    final unlockedIds = unlocked
        .where((e) => e.achievementId.startsWith(prefix))
        .map((e) => e.achievementId.replaceFirst(prefix, ''))
        .toSet();
        
    if (!unlockedIds.contains('social_butterfly')) {
      await _db.into(_db.unlockedAchievements).insertOnConflictUpdate(
        UnlockedAchievementsCompanion(
          achievementId: drift.Value('${prefix}social_butterfly'),
          unlockedAt: drift.Value(DateTime.now()),
        ),
      );
    }
  }
}