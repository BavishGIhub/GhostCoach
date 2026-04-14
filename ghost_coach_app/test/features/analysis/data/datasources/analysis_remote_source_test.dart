import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ghost_coach_app/features/analysis/data/datasources/analysis_remote_source.dart';
import 'package:ghost_coach_app/domain/models/analysis_result.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late AnalysisRemoteSource remoteSource;
  late File tempFile;

  setUp(() async {
    mockDio = MockDio();
    remoteSource = AnalysisRemoteSource(mockDio);
    
    // Create temp file for upload test
    tempFile = File('test_video.mp4');
    await tempFile.writeAsBytes([0, 0, 0, 0]);
    
    // Register fallback values for mocktail
    registerFallbackValue(FormData());
  });

  tearDown(() async {
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  });

  group('AnalysisRemoteSource', () {
    test('uploadVideo returns analysis_id on success', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            onSendProgress: any(named: 'onSendProgress'),
          )).thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/analyze'),
                statusCode: 200,
                data: {'analysis_id': 'test-123'},
              ));

      final result = await remoteSource.uploadVideo(tempFile.path, 'rocket_league');
      expect(result, 'test-123');
    });

    test('getAnalysis returns AnalysisResult on 200', () async {
      when(() => mockDio.get(any())).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/analysis/123'),
            statusCode: 200,
            data: {
              'status': 'completed',
              'analysisId': '123',
              'processingTimeSeconds': 1.0,
              'features': {
                'embeddingShape': [1, 2],
                'keyMoments': [],
                'movementPatterns': [],
                'overallScore': 80.0
              },
              'recommendations': [],
              'inferenceDevice': 'cpu',
              'timestamp': '2023-01-01T00:00:00Z'
            },
          ));

      final result = await remoteSource.getAnalysis('123');
      expect(result, isA<AnalysisResult>());
      expect(result?.analysisId, '123');
      expect(result?.status, 'completed');
    });

    test('getAnalysis returns null on 202', () async {
      when(() => mockDio.get(any())).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/analysis/123'),
            statusCode: 202,
          ));

      final result = await remoteSource.getAnalysis('123');
      expect(result, isNull);
    });

    test('getAnalysis throws NotFoundException on 404', () async {
      when(() => mockDio.get(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response(
            requestOptions: RequestOptions(path: ''), statusCode: 404),
      ));

      expect(
          () => remoteSource.getAnalysis('123'),
          throwsA(isA<Exception>().having(
              (e) => e.toString(), 'message', contains('404'))));
    });

    test('getAnalysis throws ConnectionException on network error', () async {
      when(() => mockDio.get(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
        message: 'Connection failed',
      ));

      expect(
          () => remoteSource.getAnalysis('123'),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message',
              contains('Network error'))));
    });
  });
}
