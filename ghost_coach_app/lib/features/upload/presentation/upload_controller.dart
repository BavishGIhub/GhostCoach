import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../../domain/repositories/analysis_repository.dart';
import '../../../domain/models/analysis_result.dart';
import '../../../database/app_database.dart';
import '../../history/presentation/history_controller.dart';
import 'package:video_compress/video_compress.dart';

class UploadState {
  final File? selectedFile;
  final String gameType;
  final String? soccerPosition;
  final bool isUploading;
  final double uploadProgress;
  final String? error;

  UploadState({
    this.selectedFile,
    this.gameType = 'valorant',
    this.soccerPosition,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.error,
  });

  UploadState copyWith({
    File? selectedFile,
    String? gameType,
    String? soccerPosition,
    bool? isUploading,
    double? uploadProgress,
    String? error,
    bool clearError = false,
  }) {
    return UploadState(
      selectedFile: selectedFile ?? this.selectedFile,
      gameType: gameType ?? this.gameType,
      soccerPosition: soccerPosition ?? this.soccerPosition,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class UploadController extends Notifier<UploadState> {
  @override
  UploadState build() => UploadState();

  void setFile(File file) {
    state = state.copyWith(selectedFile: file, clearError: true);
  }

  void setGameType(String type) {
    state = state.copyWith(gameType: type, clearError: true);
  }

  void setSoccerPosition(String position) {
    state = state.copyWith(soccerPosition: position, clearError: true);
  }

  void clearFile() {
    state = UploadState(gameType: state.gameType);
  }

  Future<String?> startUpload() async {
    if (state.selectedFile == null) {
      state = state.copyWith(
        error: 'Please select a video file first.',
      );
      return null;
    }

    state = state.copyWith(
      isUploading: true,
      uploadProgress: 0.0,
      clearError: true,
    );

    try {
      final repository = ref.read(analysisRepositoryProvider);
      File fileToUpload = state.selectedFile!;

      // ── Step 1: Compress Video ──
      try {
        debugPrint('🗜️ Starting video compression for ${fileToUpload.path}...');
        
        final subscription = VideoCompress.compressProgress$.subscribe((progress) {
          // Map compression to 0% -> 30% of the overall progress bar
          state = state.copyWith(uploadProgress: (progress / 100) * 0.3);
        });

        final info = await VideoCompress.compressVideo(
          fileToUpload.path,
          quality: VideoQuality.Res1280x720Quality, // 720p is perfect for YOLO analysis
          deleteOrigin: false,
          includeAudio: false, // Drop audio to save bandwidth, model doesn't need it
        );

        subscription.unsubscribe(); // Clean up listener

        if (info != null && info.file != null) {
          final oldSize = (fileToUpload.lengthSync() / 1024 / 1024).toStringAsFixed(2);
          final newSize = (info.file!.lengthSync() / 1024 / 1024).toStringAsFixed(2);
          debugPrint('✅ Compression success: ${oldSize}MB -> ${newSize}MB');
          fileToUpload = info.file!;
        }
      } catch (compErr) {
        debugPrint('⚠️ Compression failed, uploading original file: $compErr');
      }

      // ── Step 2: Upload to Backend ──
      // Health check before uploading
      final isServerUp = await repository.healthCheck();
      if (!isServerUp) {
        state = state.copyWith(
          isUploading: false,
          error: 'Analysis failed: Cannot reach the Ghost Coach server. The Kaggle backend may be offline — try again in a few minutes.',
        );
        return null;
      }

      // Upload with retry logic (up to 2 retries for connection drops)
      const maxRetries = 2;
      late final AnalysisResult result;
      for (var attempt = 0; attempt <= maxRetries; attempt++) {
        try {
          result = await repository.uploadAndAnalyze(
            fileToUpload,
            state.gameType,
            soccerPosition: state.gameType == 'soccer' ? state.soccerPosition : null,
            onSendProgress: (sent, total) {
              if (total > 0) {
                state = state.copyWith(uploadProgress: 0.3 + ((sent / total) * 0.6));
              }
            },
          );
          break;
        } catch (e) {
          final errStr = e.toString();
          final isRetryable = errStr.contains('Connection reset') ||
              errStr.contains('reset by peer') ||
              errStr.contains('Connection closed') ||
              errStr.contains('SocketException');

          if (isRetryable && attempt < maxRetries) {
            debugPrint('🔄 Upload attempt ${attempt + 1} failed, retrying in ${(attempt + 1) * 3}s...');
            state = state.copyWith(uploadProgress: 0.3);
            await Future.delayed(Duration(seconds: (attempt + 1) * 3));
            continue;
          }
          rethrow;
        }
      }

      // Show complete
      state = state.copyWith(uploadProgress: 1.0);

      // Cache the result so loading screen can access it instantly
      ref
          .read(analysisResultCacheProvider.notifier)
          .addResult(result.analysisId, result);

      // Persist to local database for Recent Sessions / History
      // Use a direct DB instance to avoid autoDispose lifecycle issues
      try {
        final db = AppDatabase();
        debugPrint('💾 Saving analysis to DB: ${result.analysisId}');
        debugPrint('💾 Game type: ${result.gameType}, Score: ${result.features.overallScore}');
        
        final jsonResult = result.toJson();
        debugPrint('💾 JSON serialized successfully');
        
        await db.insertAnalysis(AnalysesCompanion.insert(
          id: result.analysisId,
          gameType: Value(result.gameType),
          overallScore: result.features.overallScore,
          recommendationsJson: jsonEncode(result.recommendations),
          fullResultJson: jsonEncode(jsonResult),
          createdAt: DateTime.now(),
        ));
        debugPrint('✅ Analysis saved to DB successfully');
        await db.close();
        
        // Invalidate history so the home screen picks it up
        ref.invalidate(historyListProvider);
      } catch (e, stack) {
        debugPrint('❌ Failed to save analysis to DB: $e');
        debugPrint('❌ Stack: $stack');
      }

      state = state.copyWith(isUploading: false);
      return result.analysisId;
    } catch (e) {
      String errorMessage = e.toString().replaceAll('Exception:', '').trim();

      if (e is DioException) {
        if (e.response?.data != null) {
          final data = e.response!.data;
          if (data is Map && data['detail'] != null) {
            errorMessage = data['detail'].toString();
          } else {
            errorMessage = data.toString();
          }
        } else {
          final errStr = e.error?.toString() ?? e.message ?? '';
          if (errStr.contains('Connection reset') || errStr.contains('reset by peer')) {
            errorMessage = 'Server connection dropped after retries. The Kaggle backend may be offline — please try again later.';
          } else if (errStr.contains('Connection refused')) {
            errorMessage = 'Server is not running. Check that the Kaggle backend is active.';
          }
        }
      }

      state = state.copyWith(
        isUploading: false,
        error: "Analysis failed: $errorMessage",
      );
      return null;
    }
  }
}

final uploadControllerProvider =
    NotifierProvider.autoDispose<UploadController, UploadState>(
      UploadController.new,
    );