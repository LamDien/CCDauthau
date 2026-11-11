import 'dart:math';

import 'package:cc_dau_thau/app/theme/app_theme.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_result.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/services/exam_engine.dart';
import 'package:cc_dau_thau/features/mobile_ui/controllers/mock_exam_controller.dart';
import 'package:cc_dau_thau/features/mobile_ui/screens/mock_exam_screen.dart';
import 'package:cc_dau_thau/features/study_progress/data/sqlite_progress_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sample_bank_builder.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('MockExamScreen warns exact unanswered count before submit and jumps via 70-question navigator', (tester) async {
    final bank = buildSampleQuestionBank();
    final engine = ExamEngine();
    final exam = (engine.generateMockExam(
      bank,
      config: const ExamConfig(totalQuestions: 70, durationSeconds: 3600),
      random: Random(21),
    ) as ExamSuccess<GeneratedExam>)
        .data;

    final repo = SqliteProgressRepository(
      dbPathProvider: () async => inMemoryDatabasePath,
      dbFactory: databaseFactoryFfiNoIsolate,
    );
    addTearDown(repo.close);

    final ctrl = MockExamController(
      exam: exam,
      engine: engine,
      progressRepo: repo,
      passScoreThreshold: 70.0,
    );
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildLightTheme(),
        home: MockExamScreen(
          controller: ctrl,
          currentBank: bank,
          autoStartTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Answer question 1 -> 69 unanswered
    await tester.tap(find.text(exam.items.first.shuffledOptions.first.text));
    await tester.pumpAndSettle();
    final navButton = find.widgetWithText(OutlinedButton, '1/70');
    expect(navButton, findsOneWidget);

    // Open navigator sheet and jump to question #5
    await tester.tap(navButton);
    await tester.pumpAndSettle();
    expect(find.text('Danh sách 70 câu hỏi'), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byType(GridView), matching: find.text('5')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Câu 5/70'), findsOneWidget);

    // Tap Nộp bài -> dialog shows exact unanswered count = 69
    await tester.tap(find.text('Nộp bài'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bạn còn 69 câu chưa trả lời.'), findsOneWidget);

    // Tap "Xem câu chưa làm đầu tiên" -> jumps to index 1 (question 2/70)
    await tester.tap(find.text('Xem câu chưa làm đầu tiên'));
    await tester.pumpAndSettle();
    expect(find.text('Câu 2/70'), findsOneWidget);

    // Toggle to Full Paper view keeps answer on question 1
    await tester.tap(find.text('Toàn bộ đề'));
    await tester.pumpAndSettle();
    expect(find.text('Câu 1/70'), findsOneWidget);
    expect(ctrl.selectedByPosition[1], 0);
  });
}
