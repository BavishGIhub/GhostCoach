import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../../domain/repositories/analysis_repository.dart';
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
      // Get the FULL result directly from upload - no polling needed!
      final result = await repository.uploadAndAnalyze(
        fileToUpload,
        state.gameType,
        soccerPosition: state.gameType == 'soccer' ? state.soccerPosition : null,
        onSendProgress: (sent, total) {
          if (total > 0) {
            // Map network upload to 30% -> 90% of overall progress. Final 10% is AI inference.
            state = state.copyWith(uploadProgress: 0.3 + ((sent / total) * 0.6));
          }
        },
      );

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
      
      // If it's a Dio error, try to extract the specific server message
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data['detail'] != null) {
          errorMessage = data['detail'].toString();
        } else {
          errorMessage = data.toString();
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