import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'gamification_service.dart';
import '../domain/models/player_profile.dart';
import '../domain/models/streak_data.dart';
import '../domain/models/achievement.dart';

final playerProfileStreamProvider = StreamProvider<PlayerProfile>((ref) {
  final service = ref.watch(gamificationServiceProvider);
  return service.watchProfile();
});

final streakDataStreamProvider = StreamProvider<StreakData>((ref) {
  final service = ref.watch(gamificationServiceProvider);
  return service.watchStreak();
});

final unlockedAchievementsStreamProvider = StreamProvider<List<Achievement>>((
  ref,
) {
  final service = ref.watch(gamificationServiceProvider);
  return service.watchUnlockedAchievements();
});