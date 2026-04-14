import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/glass_container.dart';
import '../../../core/theme/animated_gradient_background.dart';
import 'upload_controller.dart';

class UploadScreen extends ConsumerWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(uploadControllerProvider);
    final controller = ref.read(uploadControllerProvider.notifier);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.secondary),
          onPressed: () => context.go('/home'),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.primaryGradient.createShader(bounds),
          child: Text('UPLOAD GAMEPLAY', style: AppTextStyles.brandSmall.copyWith(fontSize: 11)),
        ),
      ),
      body: Stack(
        children: [
          AnimatedGradientBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Upload Zone
                  GlassContainer(
                    onTap: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.video,
                      );
                      if (result != null && result.files.single.path != null) {
                        controller.setFile(File(result.files.single.path!));
                      }
                    },
                    padding: EdgeInsets.all(0),
                    borderRadius: 16,
                    opacity: 0.06,
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.cloud_upload_rounded,
                                  color: AppColors.secondary,
                                  size: 36,
                                ),
                              )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .moveY(
                                begin: 0,
                                end: -6,
                                duration: 1500.ms,
                                curve: Curves.easeInOut,
                              ),
                          SizedBox(height: 16),
                          Text(
                            'TAP TO SELECT VIDEO',
                            style: AppTextStyles.sectionLabel.copyWith(
                              fontSize: 11,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'MP4, MOV up to 100MB',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05),

                  SizedBox(height: 24),

                  // Selected File Info
                  if (state.selectedFile != null) ...[
                    Text('SELECTED FILE', style: AppTextStyles.sectionLabel),
                    SizedBox(height: 10),
                    GlassContainer(
                      padding: EdgeInsets.all(14),
                      borderRadius: 12,
                      borderColor: AppColors.success.withValues(alpha: 0.2),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.selectedFile!.path
                                      .split('/')
                                      .last
                                      .split('\\')
                                      .last,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '${(state.selectedFile!.lengthSync() / (1024 * 1024)).toStringAsFixed(1)} MB',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: AppColors.error.withValues(alpha: 0.8),
                              size: 20,
                            ),
                            onPressed: () => controller.clearFile(),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.05),
                    SizedBox(height: 24),
                  ],

                  // Game Selector
                  Text('SELECT GAME PROFILE', style: AppTextStyles.sectionLabel),
                  SizedBox(height: 12),
                  GlassContainer(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    borderRadius: 12,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: state.gameType,
                        isExpanded: true,
                        icon: Icon(
                          Icons.expand_more,
                          color: AppColors.textSecondary,
                        ),
                        dropdownColor: Color(0xFF1A1A24),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'fortnite',
                            child: Text('🏗️  Fortnite'),
                          ),
                          DropdownMenuItem(
                            value: 'valorant',
                            child: Text('🎯  Valorant'),
                          ),
                          DropdownMenuItem(
                            value: 'warzone',
                            child: Text('🪖  Warzone'),
                          ),
                          DropdownMenuItem(
                            value: 'soccer',
                            child: Text('⚽  Soccer'),
                          ),
                          DropdownMenuItem(
                            value: 'general',
                            child: Text('🎮  General'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) controller.setGameType(val);
                        },
                      ),
                    ),
                  ),

                  // Soccer Position Selector (only shown when soccer is selected)
                  if (state.gameType == 'soccer') ...[
                    SizedBox(height: 20),
                    Text('SELECT SOCCER POSITION', style: AppTextStyles.sectionLabel),
                    SizedBox(height: 12),
                    GlassContainer(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      borderRadius: 12,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: state.soccerPosition,
                          isExpanded: true,
                          icon: Icon(
                            Icons.expand_more,
                            color: AppColors.textSecondary,
                          ),
                          dropdownColor: Color(0xFF1A1A24),
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                          hint: Text('Select position...'),
                          items: [
                            DropdownMenuItem(
                              value: 'goalkeeper',
                              child: Text('🧤 Goalkeeper'),
                            ),
                            DropdownMenuItem(
                              value: 'defender',
                              child: Text('🛡️ Defender'),
                            ),
                            DropdownMenuItem(
                              value: 'midfielder',
                              child: Text('⚙️ Midfielder'),
                            ),
                            DropdownMenuItem(
                              value: 'forward',
                              child: Text('⚽ Forward'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) controller.setSoccerPosition(val);
                          },
                        ),
                      ),
                    ),
                  ],

                  SizedBox(height: 28),

                  // Error
                  if (state.error != null) ...[
                    Text(
                      state.error!,
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 16),
                  ],

                  // Start Analysis Button
                  GestureDetector(
                    onTap: state.isUploading
                        ? null
                        : () async {
                            final id = await controller.startUpload();
                            if (id != null && context.mounted) {
                              context.push('/analysis/loading/$id');
                            }
                          },
                    child: Container(
                      height: 56,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: AppColors.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (state.isUploading)
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: LinearProgressIndicator(
                                  value: state.uploadProgress,
                                  backgroundColor: Colors.transparent,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),
                              ),
                            ),
                          Text(
                            state.isUploading
                                ? 'UPLOADING... ${(state.uploadProgress * 100).toInt()}%'
                                : 'START ANALYSIS',
                            style: AppTextStyles.sectionLabel.copyWith(
                              fontSize: 12,
                              color: Colors.white,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 300.ms, duration: 500.ms),

                  SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Videos processed on secure cloud server',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}