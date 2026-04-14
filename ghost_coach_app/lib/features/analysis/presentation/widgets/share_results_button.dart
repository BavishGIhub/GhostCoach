import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../domain/models/analysis_result.dart';
import 'share_card.dart';
import '../../../../core/theme/app_text_styles.dart';

class ShareResultsButton extends StatelessWidget {
  final AnalysisResult result;

  const ShareResultsButton({super.key, required this.result});

  Future<void> _captureAndShare(BuildContext context, bool isStory) async {
    try {
      final size = isStory ? const Size(1080, 1920) : const Size(1080, 1080);

      final widgetToRender = MediaQuery(
        data: MediaQueryData(size: size),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            child: ShareCard(result: result, isStory: isStory),
          ),
        ),
      );

      final captureKey = GlobalKey();

      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Stack(
          children: [
            Positioned(
              left: -5000,
              child: RepaintBoundary(
                key: captureKey,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: widgetToRender,
                ),
              ),
            ),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      );

      await Future.delayed(const Duration(milliseconds: 600));

      final boundary =
          captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        if (context.mounted) Navigator.pop(context);
        return;
      }

      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();

      if (context.mounted) Navigator.pop(context);

      if (pngBytes != null) {
        final directory = await getTemporaryDirectory();
        final imagePath =
            '${directory.path}/ghost_coach_${isStory ? 'story' : 'post'}.png';
        final file = File(imagePath);
        await file.writeAsBytes(pngBytes);

        // ignore: deprecated_member_use
        await Share.shareXFiles([
          XFile(imagePath),
        ], text: 'Check out my analysis on Ghost Coach!');
      }
    } catch (e) {
      debugPrint('Error sharing image: $e');
    }
  }

  void _showShareOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131313),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('SHARE RESULTS', style: AppTextStyles.sectionLabel),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.crop_portrait, color: Colors.white),
              title: Text(
                'Share as Story (9:16)',
                style: AppTextStyles.body.copyWith(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _captureAndShare(context, true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.crop_square, color: Colors.white),
              title: Text(
                'Share as Post (1:1)',
                style: AppTextStyles.body.copyWith(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _captureAndShare(context, false);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showShareOptions(context),
      icon: const Icon(Icons.share, color: Colors.white, size: 20),
      label: Text('SHARE RESULTS', style: AppTextStyles.sectionLabel),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF131313),
        side: const BorderSide(color: Color(0xFF4B454E)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}