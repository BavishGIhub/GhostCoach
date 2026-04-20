import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

final dioProvider = Provider.autoDispose<Dio>((ref) {
  final baseUrl = ref.watch(baseUrlProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 300), // 5 minutes (for V-JEPA/YOLO inference)
      sendTimeout: const Duration(seconds: 300), // 5 minutes (for 4G upload speeds)
      headers: {
        'ngrok-skip-browser-warning': 'true',
        'Accept': 'application/json',
      },
    ),
  );

  // Error interceptor — converts Dio errors to readable messages
  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (DioException error, ErrorInterceptorHandler handler) {
        String message;
        switch (error.type) {
          case DioExceptionType.connectionTimeout:
            message = 'Connection timeout. Is the server running?';
          case DioExceptionType.sendTimeout:
            message = 'Upload timeout. Try a shorter video.';
          case DioExceptionType.receiveTimeout:
            message = 'Server took too long. Video may be too large.';
          case DioExceptionType.connectionError:
            message = 'Cannot reach server. Check your URL in Settings.';
          default:
            final errMsg = error.message ?? error.error?.toString() ?? '';
            if (errMsg.contains('Connection reset') || errMsg.contains('reset by peer')) {
              message = 'Server connection dropped. The backend may be restarting — please try again.';
            } else if (errMsg.contains('Connection refused')) {
              message = 'Server is not running. Check that the Kaggle backend is active.';
            } else {
              message = errMsg.isNotEmpty ? errMsg : 'Unknown network error';
            }
        }
        debugPrint('🔴 Dio Error: $message');
        handler.next(error);
      },
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestHeader: false,
        responseHeader: false,
        requestBody: false, // Don't log video binary data
        responseBody: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ),
    );
  }

  return dio;
});