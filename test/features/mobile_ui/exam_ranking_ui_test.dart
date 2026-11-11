import 'dart:typed_data';

import 'package:cc_dau_thau/app/theme/app_theme.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/vault_result.dart';
import 'package:cc_dau_thau/features/data_vault/domain/repositories/vault_repository.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_result.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/services/exam_engine.dart';
import 'package:cc_dau_thau/features/mobile_ui/controllers/app_state_controller.dart';
import 'package:cc_dau_thau/features/mobile_ui/screens/exam_result_screen.dart';
import 'package:cc_dau_thau/features/mobile_ui/screens/history_tab.dart';
import 'package:cc_dau_thau/features/mobile_ui/screens/home_tab.dart';
import 'package:cc_dau_thau/features/mobile_ui/widgets/exam_rank_badge.dart';
import 'package:cc_dau_thau/features/study_progress/data/sqlite_progress_repository.dart';
import 'package:cc_dau_thau/features/study_progress/domain/models/progress_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sample_bank_builder.dart';

class _StubVaultRepository implements VaultRepository {
  _StubVaultRepository(this._bank);

  final QuestionBank _bank;

  @override
  Future<VaultResult<QuestionBank>> loadActiveBank() async =>
      VaultSuccess(_bank);

  @override
  Future<VaultResult<ImportSummary>> importFromBytes(
    Uint8List bytes, {
    required ImportFileType type,
  }) async =>
      VaultSuccess(_bank.toSummary());

  @override
  Future<VaultResult<QuestionBank>> resetToBundledBank() async =>
      VaultSuccess(_bank);
}

ExamHistoryEntry _buildEntry({
  required ExamMode mode,
  required double scoreOn100,
  required int totalQuestions,
  required int correctCount,
  double passThresholdUsed = ExamRank.passingScore,
}) {
  return ExamHistoryEntry(
    summary: ExamHistorySummary(
      attemptId: 'ATT_${mode.name}_${scoreOn100.round()}',
      mode: mode,
      submittedAt: DateTime.utc(2026, 11, 11, 10, 30),
      elapsedSeconds: 1845,
      autoSubmittedByTimeout: false,
      totalQuestions: totalQuestions,
      correctCount: correctCount,
      scoreOn100: scoreOn100,
      passThresholdUsed: passThresholdUsed,
      isPassed: scoreOn100 >= passThresholdUsed,
      topicBreakdowns: const [
        TopicBreakdown(
          topicId: 'T01',
          topicName: 'Chuyên đề 1',
          totalInExam: 10,
          correctCount: 5,
        ),
      ],
    ),
    items: const [],
  );
}

void main() {
  sqfliteFfiInit();

  group('Exam ranking UI integration', () {
    testWidgets('ExamResultScreen displays 5-tier rank and legend for mockExam & diagnosticMiniTest, but hides rank for retryWrong', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 1. Mock exam 90.0 -> Xuất sắc + expandable 5-tier scale
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: ExamResultScreen(
            entry: _buildEntry(
              mode: ExamMode.mockExam,
              scoreOn100: 90.0,
              totalQuestions: 70,
              correctCount: 63,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('90.00 / 100 điểm'), findsOneWidget);
      expect(find.text('Xuất sắc'), findsOneWidget);
      expect(find.text('ĐẠT'), findsNothing);
      expect(find.text('CHƯA ĐẠT'), findsNothing);
      expect(find.textContaining('Đạt yêu cầu: từ 50/100'), findsOneWidget);

      await tester.tap(find.text('Bảng xếp loại (thang điểm 100)'));
      await tester.pumpAndSettle();
      expect(find.text('Từ 90% trở lên'), findsOneWidget);
      expect(find.text('Từ 80% đến dưới 90%'), findsOneWidget);
      expect(find.text('Giỏi'), findsOneWidget);
      expect(find.text('Từ 60% đến dưới 80%'), findsOneWidget);
      expect(find.text('Khá'), findsOneWidget);
      expect(find.text('Từ 50% đến dưới 60%'), findsOneWidget);
      expect(find.text('Trung bình'), findsOneWidget);
      expect(find.text('Dưới 50%'), findsOneWidget);
      expect(find.text('Không đạt yêu cầu'), findsOneWidget);

      // 2. Narrow 360dp phone with failing score -> Không đạt yêu cầu without overflow
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: ExamResultScreen(
            key: const ValueKey('diag_fail'),
            entry: _buildEntry(
              mode: ExamMode.diagnosticMiniTest,
              scoreOn100: 46.15,
              totalQuestions: 26,
              correctCount: 12,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('46.15 / 100 điểm'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ExamRankBadge),
          matching: find.text('Không đạt yêu cầu'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // 3. RetryWrong omits rank badge & legend table
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: ExamResultScreen(
            key: const ValueKey('retry_only'),
            entry: _buildEntry(
              mode: ExamMode.retryWrong,
              scoreOn100: 80.0,
              totalQuestions: 10,
              correctCount: 8,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('80.00 / 100 điểm'), findsOneWidget);
      expect(find.text('Giỏi'), findsNothing);
      expect(find.text('Bảng xếp loại (thang điểm 100)'), findsNothing);
      expect(find.textContaining('Đạt yêu cầu: từ 50/100'), findsNothing);
    });

    testWidgets('HistoryTab and HomeTab show ranks for mock/diagnostic attempts and omit rank for retryWrong', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bank = buildSampleQuestionBank();
      final repo = SqliteProgressRepository(
        dbPathProvider: () async => inMemoryDatabasePath,
        dbFactory: databaseFactoryFfiNoIsolate,
      );
      addTearDown(repo.close);

      final engine = ExamEngine();
      final mockExam = (engine.generateMockExam(bank) as ExamSuccess<GeneratedExam>).data;
      final diagExam = (engine.generateDiagnosticTest(bank) as ExamSuccess<GeneratedExam>).data;
      final retryExam = (engine.generateRetrySession(
        bank,
        bank.questions.take(10).map((q) => q.code).toList(),
      ) as ExamSuccess<GeneratedExam>)
          .data;

      // Record mock exam with 45/70 (64.29 -> Khá)
      final mockAnswers = {
        for (var i = 0; i < 45; i++)
          mockExam.items[i].position: mockExam.items[i].correctDisplayIndex,
      };
      final mockSub = ExamSubmission(
        exam: mockExam,
        selectedOptionByPosition: mockAnswers,
        elapsedSeconds: 2000,
        submittedAt: DateTime.utc(2026, 11, 11, 9),
        autoSubmittedByTimeout: false,
      );
      await repo.recordExamEvaluation(mockSub, engine.gradeExam(mockSub));

      // Record diagnostic with 10/26 (38.46 -> Không đạt yêu cầu)
      final diagAnswers = {
        for (var i = 0; i < 10; i++)
          diagExam.items[i].position: diagExam.items[i].correctDisplayIndex,
      };
      final diagSub = ExamSubmission(
        exam: diagExam,
        selectedOptionByPosition: diagAnswers,
        elapsedSeconds: 400,
        submittedAt: DateTime.utc(2026, 11, 11, 10),
        autoSubmittedByTimeout: false,
      );
      await repo.recordExamEvaluation(diagSub, engine.gradeExam(diagSub));

      // Record retry session with 10/10 (100.0 -> would be Xuất sắc if shown, must stay hidden!)
      final retryAnswers = {
        for (final q in retryExam.items) q.position: q.correctDisplayIndex,
      };
      final retrySub = ExamSubmission(
        exam: retryExam,
        selectedOptionByPosition: retryAnswers,
        elapsedSeconds: 180,
        submittedAt: DateTime.utc(2026, 11, 11, 11),
        autoSubmittedByTimeout: false,
      );
      await repo.recordExamEvaluation(retrySub, engine.gradeExam(retrySub));

      final appState = AppStateController(
        vaultRepository: _StubVaultRepository(bank),
        examEngine: engine,
        progressRepository: repo,
      );
      await appState.initialize();

      // Verify HistoryTab
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: Scaffold(
            body: HistoryTab(
              controller: appState,
              onOpenAttemptDetail: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Khá'), findsOneWidget);
      expect(find.text('Không đạt yêu cầu'), findsOneWidget);
      expect(find.text('Xuất sắc'), findsNothing);
      expect(find.text('ĐẠT'), findsNothing);
      expect(find.text('CHƯA ĐẠT'), findsNothing);
      expect(tester.takeException(), isNull);

      // Verify HomeTab readiness card uses Mục tiêu nắm vững chuyên đề and renders mock rank
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: Scaffold(
            body: HomeTab(
              controller: appState,
              onStartMockExam: () {},
              onOpenStudyTab: () {},
              onStartRevengeStudy: () {},
              onStartDiagnosticMiniTest: () {},
              onStartTopicStudy: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mục tiêu nắm vững chuyên đề: 70%'), findsOneWidget);
      expect(find.text('64.3/100'), findsNWidgets(2));
      expect(find.text('Khá'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });
}
