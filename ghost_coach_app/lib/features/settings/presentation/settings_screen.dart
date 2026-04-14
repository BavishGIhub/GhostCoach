import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/glass_container.dart';
import '../../../core/theme/animated_gradient_background.dart';
import '../../../core/providers.dart';
import '../../../core/auth_providers.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ref.read(baseUrlProvider));
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final quality = ref.watch(videoQualityProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: Padding(
          padding: EdgeInsets.only(left: 16),
          child: Icon(Icons.tune, color: AppColors.secondary),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.primaryGradient.createShader(bounds),
          child: Text('SETTINGS', style: AppTextStyles.brandSmall),
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
                  // ── USER PROFILE ──
                  _sectionLabel('USER PROFILE'),
                  SizedBox(height: 12),
                  Consumer(
                    builder: (context, ref, child) {
                      final user = ref.watch(currentUserProvider).value;
                      
                      return GlassContainer(
                        onTap: () => context.push('/profile'),
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withValues(alpha: 0.15),
                                border: Border.all(color: AppColors.primary, width: 2),
                              ),
                              child: user?.photoURL != null
                                  ? ClipOval(
                                      child: Image.network(
                                        user!.photoURL!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(Icons.person, color: AppColors.secondary, size: 28),
                                      ),
                                    )
                                  : Icon(Icons.person, color: AppColors.secondary, size: 28),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?.displayName ?? 'Ghost Player',
                                    style: AppTextStyles.heading3.copyWith(fontSize: 16),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    user?.email ?? 'Sign in to manage profile',
                                    style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: AppColors.textTertiary),
                          ],
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 28),

                  // ── PREFERENCES ──
                  _sectionLabel('PREFERENCES'),
                  SizedBox(height: 12),
                  GlassContainer(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VIDEO QUALITY',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Higher = more VRAM',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        DropdownButton<String>(
                          value: quality,
                          dropdownColor: Color(0xFF1A1A24),
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                          underline: SizedBox(),
                          items: [
                            DropdownMenuItem(value: 'LOW', child: Text('LOW')),
                            DropdownMenuItem(
                              value: 'MEDIUM',
                              child: Text('MEDIUM'),
                            ),
                            DropdownMenuItem(
                              value: 'HIGH',
                              child: Text('HIGH'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) controller.updateVideoQuality(val);
                          },
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 28),

                  // ── DATA ──
                  _sectionLabel('DATA MANAGEMENT'),
                  SizedBox(height: 12),
                  GlassContainer(
                    onTap: () => _showClearDialog(context, controller),
                    padding: EdgeInsets.all(16),
                    borderColor: AppColors.error.withValues(alpha: 0.15),
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_sweep,
                          color: AppColors.error.withValues(alpha: 0.8),
                          size: 22,
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CLEAR HISTORY',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.error,
                                ),
                              ),
                              Text(
                                'Delete all analysis results',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: AppColors.textTertiary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 36),

                  // ── ABOUT ──
                  _sectionLabel('ABOUT'),
                  SizedBox(height: 12),
                  GlassContainer(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ShaderMask(
                                shaderCallback: (bounds) => AppColors
                                    .primaryGradient
                                    .createShader(bounds),
                                child: Icon(
                                  Icons.auto_awesome,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'GHOST COACH AI',
                                    style: AppTextStyles.brandSmall,
                                  ),
                                  Text(
                                    'Version 1.0.0-PRO',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Powered by V-JEPA 2 from Meta FAIR. Uses unsupervised action recognition for coaching feedback from raw gameplay pixels.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  
                  // ── LEGAL ──
                  _sectionLabel('LEGAL'),
                  SizedBox(height: 12),
                  GlassContainer(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _legalLink(
                          icon: Icons.privacy_tip,
                          title: 'Privacy Policy',
                          onTap: () => context.push('/privacy-policy'),
                        ),
                        SizedBox(height: 12),
                        _legalLink(
                          icon: Icons.description,
                          title: 'Terms of Service',
                          onTap: () => context.push('/terms'),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  Center(
                    child: Text(
                      'MADE WITH ☕ BY GHOST TEAM',
                      style: AppTextStyles.brandSmall,
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

  Widget _sectionLabel(String text) {
    return Text(text, style: AppTextStyles.brandSmall);
  }

  Widget _legalLink({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: AppColors.secondary,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showClearDialog(BuildContext context, SettingsController controller) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Color(0xFF1A1A24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('CLEAR ALL HISTORY?', style: AppTextStyles.brandSmall),
        content: Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCEL',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              controller.clearAllHistory();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('History cleared')));
            },
            child: Text(
              'CLEAR ALL',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}