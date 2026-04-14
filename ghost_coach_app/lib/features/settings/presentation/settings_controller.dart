import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/providers.dart';
import '../../history/presentation/history_controller.dart';

class SettingsState {
  final bool isChecking;
  final String? connectionStatus;

  SettingsState({this.isChecking = false, this.connectionStatus});

  SettingsState copyWith({bool? isChecking, String? connectionStatus}) {
    return SettingsState(
      isChecking: isChecking ?? this.isChecking,
      connectionStatus: connectionStatus ?? this.connectionStatus,
    );
  }
}

class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() => SettingsState();

  Future<void> updateBaseUrl(String url) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('base_url', url);
    ref.read(baseUrlProvider.notifier).set(url);
  }

  Future<void> updateVideoQuality(String quality) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('video_quality', quality);
    ref.read(videoQualityProvider.notifier).set(quality);
  }

  Future<void> testConnection() async {
    state = state.copyWith(isChecking: true, connectionStatus: null);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/api/v1/health');
      if (response.statusCode == 200) {
        state = state.copyWith(isChecking: false, connectionStatus: 'SUCCESS');
      } else {
        state = state.copyWith(
          isChecking: false,
          connectionStatus: 'ERROR: status ${response.statusCode}',
        );
      }
    } catch (e) {
      state = state.copyWith(isChecking: false, connectionStatus: 'ERROR: $e');
    }
  }

  Future<void> clearAllHistory() async {
    await ref.read(historyControllerProvider.notifier).clearAll();
  }
}

final settingsControllerProvider =
    NotifierProvider.autoDispose<SettingsController, SettingsState>(
      SettingsController.new,
    );