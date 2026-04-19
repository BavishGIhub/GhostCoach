import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/models/analysis_result.dart';
import '../../../../domain/repositories/analysis_repository.dart';
import '../../../history/presentation/history_controller.dart';

// This provider reads from cache first, then falls back to local DB
final analysisProvider = FutureProvider.autoDispose
    .family<AnalysisResult, String>((ref, analysisId) async {
      // Check in-memory cache first (result was stored during upload)
      final cache = ref.watch(analysisResultCacheProvider);
      final cachedResult = cache[analysisId];

      if (cachedResult != null) {
        debugPrint('📦 Analysis found in cache: $analysisId');
        return cachedResult;
      }

      // Fallback: check local database
      debugPrint('🔍 Cache miss, checking local DB for: $analysisId');
      try {
        final db = ref.read(databaseProvider);
        final dbResult = await db.getAnalysisById(analysisId);

        if (dbResult != null && dbResult.fullResultJson.isNotEmpty) {
          debugPrint('📦 Analysis found in DB: $analysisId');
          final json = jsonDecode(dbResult.fullResultJson) as Map<String, dynamic>;
          return AnalysisResult.fromJson(json);
        }
      } catch (e) {
        debugPrint('⚠️ DB fallback failed: $e');
      }

      // If not in cache or DB, throw error
      throw Exception('Analysis result not found. Please try uploading again.');
    });

final previousAnalysisProvider = FutureProvider.autoDispose
    .family<AnalysisResult?, (String, String)>((ref, params) async {
      final (currentId, gameType) = params;
      try {
        final db = ref.read(databaseProvider);
        final allAnalyses = await db.getAllAnalyses();

        final previous = allAnalyses
            .where((a) => a.id != currentId && a.gameType == gameType)
            .toList();

        if (previous.isEmpty) return null;

        final prev = previous.first;
        if (prev.fullResultJson.isEmpty) return null;

        final json = jsonDecode(prev.fullResultJson) as Map<String, dynamic>;
        return AnalysisResult.fromJson(json);
      } catch (e) {
        debugPrint('⚠️ Previous analysis lookup failed: $e');
        return null;
      }
    });
