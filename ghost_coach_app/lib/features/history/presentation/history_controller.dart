import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';

final databaseProvider = Provider.autoDispose<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

enum HistoryFilter { all, week, month }

class HistoryFilterNotifier extends Notifier<HistoryFilter> {
  @override
  HistoryFilter build() => HistoryFilter.all;

  void set(HistoryFilter filter) => state = filter;
}

final historyFilterProvider =
    NotifierProvider.autoDispose<HistoryFilterNotifier, HistoryFilter>(
      HistoryFilterNotifier.new,
    );

final historyListProvider = FutureProvider.autoDispose<List<Analysis>>((
  ref,
) async {
  final db = ref.watch(databaseProvider);
  final filter = ref.watch(historyFilterProvider);

  final all = await db.getAllAnalyses();
  debugPrint('📊 historyListProvider: Found ${all.length} analyses in DB');

  if (filter == HistoryFilter.all) return all;

  final now = DateTime.now();
  if (filter == HistoryFilter.week) {
    final startOfWeek = now.subtract(const Duration(days: 7));
    return all.where((a) => a.createdAt.isAfter(startOfWeek)).toList();
  } else if (filter == HistoryFilter.month) {
    final startOfMonth = now.subtract(const Duration(days: 30));
    return all.where((a) => a.createdAt.isAfter(startOfMonth)).toList();
  }

  return all;
});

class HistoryController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> removeSession(String id) async {
    state = const AsyncValue.loading();
    try {
      final db = ref.read(databaseProvider);
      await db.deleteAnalysis(id);
      ref.invalidate(historyListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> clearAll() async {
    state = const AsyncValue.loading();
    try {
      final db = ref.read(databaseProvider);
      await db.deleteAll();
      ref.invalidate(historyListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final historyControllerProvider =
    NotifierProvider.autoDispose<HistoryController, AsyncValue<void>>(
      HistoryController.new,
    );