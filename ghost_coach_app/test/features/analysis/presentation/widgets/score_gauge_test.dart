import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghost_coach_app/features/analysis/presentation/widgets/score_gauge.dart';

void main() {
  Widget buildTestWidget(double score) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ScoreGauge(
            score: score,
            letterGrade: 'A',
            gradeColor: Colors.green,
          ),
        ),
      ),
    );
  }

  group('ScoreGauge Widget', () {
    testWidgets('renders with score 0', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(0.0));
      await tester.pumpAndSettle();

      expect(find.text('0'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders with score 50', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(50.0));
      await tester.pumpAndSettle();

      expect(find.text('50'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders with score 100', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(100.0));
      await tester.pumpAndSettle();

      expect(find.text('100'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
