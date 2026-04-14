import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'Initialize shared preferences before running the app.',
  );
});

class BaseUrlNotifier extends Notifier<String> {
  @override
  String build() {
    // Hardcoding specific ngrok URL with API v1 path as requested
    return 'https://chanel-herblike-kristian.ngrok-free.dev/api/v1';
  }

  void set(String url) => state = url;
}

final baseUrlProvider = NotifierProvider<BaseUrlNotifier, String>(
  BaseUrlNotifier.new,
);

class VideoQualityNotifier extends Notifier<String> {
  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString('video_quality') ?? 'MEDIUM';
  }

  void set(String quality) => state = quality;
}

final videoQualityProvider = NotifierProvider<VideoQualityNotifier, String>(
  VideoQualityNotifier.new,
);