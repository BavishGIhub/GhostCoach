import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/glass_container.dart';
import '../../../core/theme/animated_gradient_background.dart';

final metaDataProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, gameType) async {
      final dio = ref.watch(dioProvider);
      final res = await dio.get('/meta/$gameType');
      return res.data;
    });

class MetaScreen extends ConsumerWidget {
  final String gameType;

  const MetaScreen({super.key, required this.gameType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMeta = ref.watch(metaDataProvider(gameType));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.secondary),
          onPressed: () => context.pop(),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.primaryGradient.createShader(bounds),
          child: Text(
            '${gameType.toUpperCase()} META',
            style: AppTextStyles.brandSmall,
          ),
        ),
      ),
      body: Stack(
        children: [
          AnimatedGradientBackground(),
          SafeArea(
            child: asyncMeta.when(
              loading: () => ListView.separated(
                padding: EdgeInsets.all(16),
                itemCount: 3,
                separatorBuilder: (_, _) => SizedBox(height: 16),
                itemBuilder: (_, _) => _buildShimmerCard(),
              ),
              error: (err, _) => Center(
                child: Text(
                  'Failed to load meta: $err',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
              data: (data) => _buildContent(context, data),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
    final metaTips =
        (data['meta_tips'] as List<dynamic>?)?.cast<String>() ?? [];
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.textTertiary,
                size: 16,
              ),
              SizedBox(width: 8),
              Text('LIVE SEASON DATA', style: AppTextStyles.brandSmall),
              Spacer(),
              Text(
                'Updated recently',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          for (final tip in metaTips)
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: GlassContainer(
                padding: EdgeInsets.all(16),
                borderRadius: 16,
                borderColor: AppColors.secondary.withValues(alpha: 0.3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lightbulb_outline,
                        color: AppColors.secondary,
                        size: 16,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        tip,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          height: 1.4,
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

  Widget _buildShimmerCard() {
    return GlassContainer(
      padding: EdgeInsets.all(16),
      borderRadius: 16,
      borderColor: AppColors.borderSubtle,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 14,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                SizedBox(height: 8),
                Container(
                  width: 200,
                  height: 14,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}