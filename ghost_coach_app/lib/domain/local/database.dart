import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class SessionHistory extends Table {
  TextColumn get id => text()();
  TextColumn get gameType => text()();
  DateTimeColumn get createdAt => dateTime()();
  RealColumn get overallScore => real()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [SessionHistory])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'ghost_coach_db'));

  @override
  int get schemaVersion => 1;

  Future<List<SessionHistoryData>> getAllSessions() =>
      select(sessionHistory).get();
  Future<int> addSession(SessionHistoryCompanion entry) =>
      into(sessionHistory).insert(entry);
  Future<int> deleteSession(String id) =>
      (delete(sessionHistory)..where((t) => t.id.equals(id))).go();
}