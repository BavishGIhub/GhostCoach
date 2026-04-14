import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DataClassName('Analysis')
class Analyses extends Table {
  TextColumn get id => text()();
  TextColumn get gameType => text().nullable()();
  RealColumn get overallScore => real()();
  TextColumn get recommendationsJson => text()();
  TextColumn get fullResultJson => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PlayerProfileEntity')
class PlayerProfiles extends Table {
  TextColumn get id => text()(); // Fixed to 'user_profile'
  IntColumn get totalXp => integer().withDefault(const Constant(0))();
  IntColumn get level => integer().withDefault(const Constant(1))();
  TextColumn get title => text().withDefault(const Constant('Rookie'))();
  IntColumn get analysesCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StreakDataEntity')
class StreakDataEntries extends Table {
  TextColumn get id => text()(); // Fixed to 'user_streak'
  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get longestStreak => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAnalysisDate => dateTime().nullable()();
  BoolColumn get freezeAvailable =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('UnlockedAchievementEntity')
class UnlockedAchievements extends Table {
  TextColumn get achievementId => text()();
  DateTimeColumn get unlockedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {achievementId};
}

@DriftDatabase(
  tables: [Analyses, PlayerProfiles, StreakDataEntries, UnlockedAchievements],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'ghost_coach_db'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from == 1) {
          await m.createTable(playerProfiles);
          await m.createTable(streakDataEntries);
          await m.createTable(unlockedAchievements);
        }
      },
    );
  }

  // DAO-like methods directly in the database class for simplicity
  Future<int> insertAnalysis(AnalysesCompanion entry) =>
      into(analyses).insert(entry);

  Future<List<Analysis>> getAllAnalyses() =>
      (select(analyses)..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
          .get();

  Future<Analysis?> getAnalysisById(String id) =>
      (select(analyses)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> deleteAnalysis(String id) =>
      (delete(analyses)..where((t) => t.id.equals(id))).go();

  Future<int> deleteAll() => delete(analyses).go();

  Future<List<Analysis>> getAnalysesSince(DateTime since) => (select(
    analyses,
  )..where((t) => t.createdAt.isBiggerThanValue(since))).get();

  // GAMIFICATION DAOs

  // Profile
  Future<PlayerProfileEntity?> getPlayerProfile() => (select(
    playerProfiles,
  )..where((t) => t.id.equals('user_profile'))).getSingleOrNull();

  Future<void> savePlayerProfile(PlayerProfilesCompanion entry) =>
      into(playerProfiles).insertOnConflictUpdate(entry);

  // Streak
  Future<StreakDataEntity?> getStreakData() => (select(
    streakDataEntries,
  )..where((t) => t.id.equals('user_streak'))).getSingleOrNull();

  Future<void> saveStreakData(StreakDataEntriesCompanion entry) =>
      into(streakDataEntries).insertOnConflictUpdate(entry);

  // Achievements
  Future<List<UnlockedAchievementEntity>> getUnlockedAchievements() =>
      select(unlockedAchievements).get();

  Future<void> unlockAchievement(UnlockedAchievementsCompanion entry) =>
      into(unlockedAchievements).insert(entry);
}