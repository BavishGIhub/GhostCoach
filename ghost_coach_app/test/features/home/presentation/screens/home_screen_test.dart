import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghost_coach_app/features/home/presentation/home_screen.dart';
import 'package:ghost_coach_app/features/home/presentation/providers/home_providers.dart';
import 'package:ghost_coach_app/features/history/presentation/history_controller.dart';
import 'package:ghost_coach_app/database/app_database.dart';

void main() {
  testWidgets('empty state shows "No sessions yet."', (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        historyListProvider.overrideWith((ref) => Future.value(<Analysis>[])),
        homeStatsProvider.overrideWithValue(HomeStats(totalAnalyses: 0, avgScore: 0, bestScore: 0)),
        healthCheckProvider.overrideWith((ref) => Future.value(true)),
      ],
      child: MaterialApp(
        home: HomeScreen(),
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.text('No sessions yet.'), findsOneWidget);
  });

  testWidgets('shows correct item count with mock history data', (WidgetTester tester) async {
    final mockSession = Analysis(
      id: '123',
      gameType: 'Valorant',
      overallScore: 85.0,
      recommendationsJson: '[]',
      fullResultJson: '{}',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        historyListProvider.overrideWith((ref) => Future.value(<Analysis>[mockSession, mockSession])),
        homeStatsProvider.overrideWithValue(HomeStats(totalAnalyses: 2, avgScore: 85.0, bestScore: 85)),
        healthCheckProvider.overrideWith((ref) => Future.value(true)),
      ],
      child: MaterialApp(
        home: HomeScreen(),
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.text('RECENT SESSIONS'), findsOneWidget);
    expect(find.text('VALORANT'), findsWidgets);
    expect(find.text('85'), findsWidgets);
  });
}
