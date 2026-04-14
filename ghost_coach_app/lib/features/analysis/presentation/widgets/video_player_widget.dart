import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../../../core/theme/glass_container.dart';
import '../../../../core/theme/app_colors.dart';

class AnalysisVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final Function(Duration)? onSeek;
  final VideoPlayerController? externalController;

  const AnalysisVideoPlayer({
    super.key,
    required this.videoUrl,
    this.onSeek,
    this.externalController,
  });

  @override
  State<AnalysisVideoPlayer> createState() => _AnalysisVideoPlayerState();
}

class _AnalysisVideoPlayerState extends State<AnalysisVideoPlayer> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      if (widget.externalController == null) {
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
        await _videoPlayerController.initialize();
      } else {
        _videoPlayerController = widget.externalController!;
        if (!_videoPlayerController.value.isInitialized) {
          await _videoPlayerController.initialize();
        }
      }
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        aspectRatio: 16 / 9,
        autoPlay: false,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        allowPlaybackSpeedChanging: true,
        playbackSpeeds: const [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
        optionsBuilder: (context, chewieOptions) async {
          await showModalBottomSheet<void>(
            context: context,
            backgroundColor: AppColors.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (ctx) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...chewieOptions.map((option) => ListTile(
                      dense: true,
                      title: Text(
                        option.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        option.onTap(ctx);
                      },
                    )),
                    ListTile(
                      dense: true,
                      title: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                      onTap: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              );
            },
          );
        },
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.primary,
          backgroundColor: AppColors.surface.withValues(alpha: 0.3),
          bufferedColor: AppColors.surface.withValues(alpha: 0.5),
        ),
        placeholder: Container(
          color: AppColors.surface,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'Video expired or unavailable',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.red,
                      ),
                ),
              ],
            ),
          );
        },
      );
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (e is PlatformException && e.code == '404') {
        _errorMessage = 'Video expired';
      } else {
        _errorMessage = 'Failed to load video';
      }
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  // ignore: unused_element
  void _seekTo(Duration position) {
    if (_videoPlayerController.value.isInitialized) {
      _videoPlayerController.seekTo(position);
      widget.onSeek?.call(position);
      if (_chewieController?.isPlaying == false) {
        _videoPlayerController.play();
      }
    }
  }

  @override
  void didUpdateWidget(AnalysisVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _reinitializeVideo();
    }
  }

  Future<void> _reinitializeVideo() async {
    if (_chewieController != null) {
      _chewieController!.dispose();
    }
    if (widget.externalController == null) {
      await _videoPlayerController.dispose();
    }
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    await _initializeVideo();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    if (widget.externalController == null) {
      _videoPlayerController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return GlassContainer(
        borderRadius: 16,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    if (_hasError) {
      return GlassContainer(
        borderRadius: 16,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? 'Video unavailable',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.red,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GlassContainer(
      borderRadius: 16,
      padding: EdgeInsets.zero,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Chewie(
          controller: _chewieController!,
        ),
      ),
    );
  }
}