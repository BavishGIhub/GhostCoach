import 'package:flutter_test/flutter_test.dart';
import 'package:ghost_coach_app/domain/models/analysis_result.dart';

void main() {
  group('AnalysisResult Model', () {
    test('fromJson parses full valid JSON correctly', () {
      final json = {
        'status': 'completed',
        'analysisId': 'test-id',
        'processingTimeSeconds': 1.5,
        'features': {
          'embeddingShape': [1, 2, 3],
          'keyMoments': [
            {
              'timestamp': 0.5,
              'momentType': 'action',
              'confidence': 0.9,
              'description': 'fast movement'
            }
          ],
          'movementPatterns': [
            {
              'patternName': 'Consistency',
              'score': 85.0,
              'description': 'good'
            }
          ],
          'overallScore': 90.0
        },
        'recommendations': ['Keep it up'],
        'inferenceDevice': 'cuda',
        'timestamp': '2023-01-01T12:00:00Z'
      };

      final result = AnalysisResult.fromJson(json);

      expect(result.status, 'completed');
      expect(result.analysisId, 'test-id');
      expect(result.processingTimeSeconds, 1.5);
      expect(result.features.overallScore, 90.0);
      expect(result.features.embeddingShape, [1, 2, 3]);
      expect(result.features.keyMoments.length, 1);
      expect(result.features.movementPatterns.length, 1);
      expect(result.features.keyMoments.first.confidence, 0.9);
      expect(result.features.movementPatterns.first.patternName, 'Consistency');
      expect(result.recommendations, ['Keep it up']);
      expect(result.inferenceDevice, 'cuda');
    });

    test('fromJson parses correctly with minimal data', () {
      final json = {
        'status': 'processing',
        'analysisId': '67890',
        'processingTimeSeconds': 0.0,
        'features': {
          'embeddingShape': [],
          'keyMoments': [],
          'movementPatterns': [],
          'overallScore': 0.0
        },
        'recommendations': [],
        'inferenceDevice': 'cpu',
        'timestamp': '2023-01-01T12:00:00Z'
      };
      final result = AnalysisResult.fromJson(json);
      expect(result.status, 'processing');
      expect(result.analysisId, '67890');
    });
  });

  group('KeyMoment Model', () {
    test('fromJson parses correctly', () {
      final json = {
        'timestamp': 2.5,
        'momentType': 'dash',
        'confidence': 0.8,
        'description': 'quick dash'
      };

      final result = KeyMoment.fromJson(json);

      expect(result.timestamp, 2.5);
      expect(result.momentType, 'dash');
      expect(result.confidence, 0.8);
      expect(result.description, 'quick dash');
    });
  });

  group('MovementPattern Model', () {
    test('fromJson parses correctly', () {
      final json = {
        'patternName': 'Positioning',
        'score': 75.0,
        'description': 'average positioning'
      };

      final result = MovementPattern.fromJson(json);

      expect(result.patternName, 'Positioning');
      expect(result.score, 75.0);
      expect(result.description, 'average positioning');
    });
  });
}
