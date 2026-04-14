import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference
  CollectionReference get _usersCollection => _firestore.collection('users');

  // Create or update user document
  Future<void> createOrUpdateUser({
    required String uid,
    required String email,
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      final userDoc = _usersCollection.doc(uid);
      final userSnapshot = await userDoc.get();

      if (!userSnapshot.exists) {
        // Create new user document
        await userDoc.set({
          'uid': uid,
          'email': email,
          'displayName': displayName ?? '',
          'photoUrl': photoUrl ?? '',
          'totalAnalyses': 0,
          'totalXp': 0,
          'level': 1,
          'streak': 0,
          'lastAnalysisDate': null,
          'achievements': [],
          'settings': {
            'notifications': true,
            'darkMode': false,
            'autoUpload': false,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Update existing user document
        final userData = userSnapshot.data() as Map<String, dynamic>?;
        await userDoc.update({
          'email': email,
          'displayName': displayName ?? userData?['displayName'] ?? '',
          'photoUrl': photoUrl ?? userData?['photoUrl'] ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw 'Failed to save user data: $e';
    }
  }

  // Get user document
  Future<Map<String, dynamic>?> getUser(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      throw 'Failed to fetch user data: $e';
    }
  }

  // Stream user document
  Stream<Map<String, dynamic>?> streamUser(String uid) {
    return _usersCollection.doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return snapshot.data() as Map<String, dynamic>?;
      }
      return null;
    });
  }

  // Update user statistics after analysis
  Future<void> updateAfterAnalysis({
    required int xpEarned,
    required String gameType,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'No user is signed in.';

      final userDoc = _usersCollection.doc(user.uid);
      final userSnapshot = await userDoc.get();

      if (!userSnapshot.exists) {
        // Create user document if it doesn't exist
        await createOrUpdateUser(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          photoUrl: user.photoURL,
        );
      }

      final data = userSnapshot.data() as Map<String, dynamic>? ?? {};
      final currentTotalAnalyses = data['totalAnalyses'] as int? ?? 0;
      final currentTotalXp = data['totalXp'] as int? ?? 0;
      final currentStreak = data['streak'] as int? ?? 0;
      final lastAnalysisDate = data['lastAnalysisDate'] as Timestamp?;

      // Calculate new streak
      final now = DateTime.now();
      final newStreak = _calculateStreak(currentStreak, lastAnalysisDate, now);

      // Calculate new level (1000 XP per level)
      final newTotalXp = currentTotalXp + xpEarned;
      final newLevel = (newTotalXp ~/ 1000) + 1;

      // Update user document
      await userDoc.update({
        'totalAnalyses': currentTotalAnalyses + 1,
        'totalXp': newTotalXp,
        'level': newLevel,
        'streak': newStreak,
        'lastAnalysisDate': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add to game-specific statistics
      await _updateGameStatistics(user.uid, gameType, xpEarned);
    } catch (e) {
      throw 'Failed to update user statistics: $e';
    }
  }

  // Update game-specific statistics
  Future<void> _updateGameStatistics(
    String uid,
    String gameType,
    int xpEarned,
  ) async {
    try {
      final gameStatsDoc = _firestore
          .collection('users')
          .doc(uid)
          .collection('gameStatistics')
          .doc(gameType);

      final gameStatsSnapshot = await gameStatsDoc.get();

      if (!gameStatsSnapshot.exists) {
        await gameStatsDoc.set({
          'gameType': gameType,
          'totalAnalyses': 1,
          'totalXp': xpEarned,
          'averageScore': xpEarned,
          'lastAnalysisDate': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = gameStatsSnapshot.data() as Map<String, dynamic>;
        final currentTotalAnalyses = data['totalAnalyses'] as int? ?? 0;
        final currentTotalXp = data['totalXp'] as int? ?? 0;

        final newTotalAnalyses = currentTotalAnalyses + 1;
        final newTotalXp = currentTotalXp + xpEarned;
        final newAverageScore = newTotalXp / newTotalAnalyses;

        await gameStatsDoc.update({
          'totalAnalyses': newTotalAnalyses,
          'totalXp': newTotalXp,
          'averageScore': newAverageScore,
          'lastAnalysisDate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Silently fail for game statistics - not critical
      developer.log('Failed to update game statistics: $e');
    }
  }

  // Calculate streak
  int _calculateStreak(int currentStreak, Timestamp? lastDate, DateTime now) {
    if (lastDate == null) {
      return 1; // First analysis
    }

    final lastAnalysisDate = lastDate.toDate();
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    // Check if last analysis was yesterday (maintains streak)
    if (lastAnalysisDate.year == yesterday.year &&
        lastAnalysisDate.month == yesterday.month &&
        lastAnalysisDate.day == yesterday.day) {
      return currentStreak + 1;
    }
    // Check if last analysis was today (no change)
    else if (lastAnalysisDate.year == now.year &&
        lastAnalysisDate.month == now.month &&
        lastAnalysisDate.day == now.day) {
      return currentStreak;
    }
    // Otherwise, reset streak
    else {
      return 1;
    }
  }

  // Add achievement
  Future<void> addAchievement(String uid, String achievementId) async {
    try {
      final userDoc = _usersCollection.doc(uid);
      await userDoc.update({
        'achievements': FieldValue.arrayUnion([achievementId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to add achievement: $e';
    }
  }

  // Update user settings
  Future<void> updateSettings(
    String uid,
    Map<String, dynamic> settings,
  ) async {
    try {
      final userDoc = _usersCollection.doc(uid);
      await userDoc.update({
        'settings': settings,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to update settings: $e';
    }
  }

  // Delete user data (for account deletion)
  Future<void> deleteUserData(String uid) async {
    try {
      // Delete user document
      await _usersCollection.doc(uid).delete();

      // Delete game statistics subcollection
      final gameStatsCollection = _usersCollection.doc(uid).collection('gameStatistics');
      final gameStatsSnapshot = await gameStatsCollection.get();
      for (final doc in gameStatsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete analysis history subcollection
      final analysisCollection = _usersCollection.doc(uid).collection('analysisHistory');
      final analysisSnapshot = await analysisCollection.get();
      for (final doc in analysisSnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      throw 'Failed to delete user data: $e';
    }
  }

  // Get leaderboard (top users by XP)
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 10}) async {
    try {
      final query = await _usersCollection
          .orderBy('totalXp', descending: true)
          .limit(limit)
          .get();

      return query.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'uid': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      throw 'Failed to fetch leaderboard: $e';
    }
  }

  // Get user's game statistics
  Future<Map<String, dynamic>> getGameStatistics(String uid, String gameType) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('gameStatistics')
          .doc(gameType)
          .get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }

      return {
        'gameType': gameType,
        'totalAnalyses': 0,
        'totalXp': 0,
        'averageScore': 0,
        'lastAnalysisDate': null,
      };
    } catch (e) {
      throw 'Failed to fetch game statistics: $e';
    }
  }
}